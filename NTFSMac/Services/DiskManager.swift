import Foundation
import DiskArbitration
import Combine

@MainActor
final class DiskManager: ObservableObject {
    @Published var disks: [NTFSDisk] = []
    @Published var lastError: String?

    private var session: DASession?
    private let queue = DispatchQueue(label: "com.ntfsmac.diskmanager")

    // NTFS-3G binary path candidates
    private let ntfs3gPaths = [
        "/usr/local/bin/ntfs-3g",
        "/opt/homebrew/bin/ntfs-3g",
        "/usr/local/sbin/ntfs-3g",
        "/opt/homebrew/sbin/ntfs-3g",
        "/usr/local/bin/ntfs-3g-mac",
        "/opt/homebrew/bin/ntfs-3g-mac",
        "/usr/local/sbin/mount_ntfs",
        "/opt/homebrew/sbin/mount_ntfs"
    ]

    init() {
        startMonitoring()
        scanExistingDisks()
    }

    // MARK: - Public API

    func mount(disk: NTFSDisk) {
        guard let index = disks.firstIndex(where: { $0.id == disk.id }) else { return }
        disks[index].mountStatus = .mounting
        let ntfs3g = self.ntfs3gPath

        Task.detached {
            do {
                let mountPoint = try await Self.performMount(disk: disk, ntfs3gPath: ntfs3g)
                await MainActor.run {
                    if let idx = self.disks.firstIndex(where: { $0.id == disk.id }) {
                        self.disks[idx].mountPoint = mountPoint
                        self.disks[idx].mountStatus = .mounted
                    }
                }
            } catch {
                await MainActor.run {
                    if let idx = self.disks.firstIndex(where: { $0.id == disk.id }) {
                        self.disks[idx].mountStatus = .error
                    }
                    self.lastError = error.localizedDescription
                }
            }
        }
    }

    func unmount(disk: NTFSDisk) {
        guard let index = disks.firstIndex(where: { $0.id == disk.id }) else { return }
        disks[index].mountStatus = .unmounting

        Task.detached {
            do {
                try await Self.performUnmount(disk: disk)
                await MainActor.run {
                    if let idx = self.disks.firstIndex(where: { $0.id == disk.id }) {
                        self.disks[idx].mountPoint = nil
                        self.disks[idx].mountStatus = .unmounted
                    }
                }
            } catch {
                await MainActor.run {
                    if let idx = self.disks.firstIndex(where: { $0.id == disk.id }) {
                        self.disks[idx].mountStatus = .error
                    }
                    self.lastError = error.localizedDescription
                }
            }
        }
    }

    func refreshDisks() {
        scanExistingDisks()
    }

    var ntfs3gPath: String? {
        ntfs3gPaths.first { FileManager.default.fileExists(atPath: $0) }
    }

    var isNTFS3GInstalled: Bool {
        ntfs3gPath != nil
    }

    var isMacFUSEInstalled: Bool {
        let paths = [
            "/Library/Filesystems/macfuse.fs",
            "/Library/Filesystems/osxfuse.fs",
            "/usr/local/lib/libfuse.dylib",
            "/opt/homebrew/lib/libfuse.dylib"
        ]
        return paths.contains { FileManager.default.fileExists(atPath: $0) }
    }

    var isHomebrewInstalled: Bool {
        FileManager.default.fileExists(atPath: "/opt/homebrew/bin/brew") ||
        FileManager.default.fileExists(atPath: "/usr/local/bin/brew")
    }

    var isAppleSilicon: Bool {
        var sysinfo = utsname()
        uname(&sysinfo)
        let machine = withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        return machine.hasPrefix("arm64")
    }

    var cpuArchDescription: String {
        isAppleSilicon ? "Apple Silicon (ARM)" : "Intel (x86_64)"
    }

    var dependencyStatus: DependencyStatus {
        DependencyStatus(
            homebrew: isHomebrewInstalled,
            macFUSE: isMacFUSEInstalled,
            ntfs3g: isNTFS3GInstalled,
            isAppleSilicon: isAppleSilicon
        )
    }

    var isReady: Bool {
        isMacFUSEInstalled && isNTFS3GInstalled
    }

    func recheckDependencies() {
        objectWillChange.send()
    }

    // MARK: - Disk Monitoring

    private func startMonitoring() {
        session = DASessionCreate(kCFAllocatorDefault)
        guard let session = session else { return }

        DASessionSetDispatchQueue(session, queue)

        let matchDict: [String: Any] = [
            kDADiskDescriptionVolumeMountableKey as String: true
        ]

        let unmanagedSelf = Unmanaged.passUnretained(self).toOpaque()

        DARegisterDiskAppearedCallback(
            session,
            matchDict as CFDictionary,
            { disk, context in
                guard let context = context else { return }
                DiskManager.handleDiskAppearedStatic(disk, context: context)
            },
            unmanagedSelf
        )

        DARegisterDiskDisappearedCallback(
            session,
            matchDict as CFDictionary,
            { disk, context in
                guard let context = context else { return }
                DiskManager.handleDiskDisappearedStatic(disk, context: context)
            },
            unmanagedSelf
        )
    }

    private static nonisolated func handleDiskAppearedStatic(_ daDisk: DADisk, context: UnsafeMutableRawPointer) {
        let manager = Unmanaged<DiskManager>.fromOpaque(context).takeUnretainedValue()
        guard let desc = DADiskCopyDescription(daDisk) as? [String: Any] else { return }
        guard isNTFSVolume(description: desc) else { return }

        if let disk = parseDisk(from: desc, daDisk: daDisk) {
            Task { @MainActor in
                if !manager.disks.contains(where: { $0.id == disk.id }) {
                    manager.disks.append(disk)
                    NotificationManager.shared.notifyDiskAppeared(disk: disk)
                }
            }
        }
    }

    private static nonisolated func handleDiskDisappearedStatic(_ daDisk: DADisk, context: UnsafeMutableRawPointer) {
        let manager = Unmanaged<DiskManager>.fromOpaque(context).takeUnretainedValue()
        guard let bsdName = DADiskGetBSDName(daDisk) else { return }
        let diskId = String(cString: bsdName)

        Task { @MainActor in
            manager.disks.removeAll { $0.id == diskId }
        }
    }

    // MARK: - Disk Scanning

    private func scanExistingDisks() {
        Task.detached {
            let foundDisks = await Self.findNTFSDisks()
            await MainActor.run { [weak self] in
                self?.disks = foundDisks
            }
        }
    }

    private static nonisolated func findNTFSDisks() async -> [NTFSDisk] {
        var results: [NTFSDisk] = []

        if let listOutput = runCommand("/usr/sbin/diskutil", arguments: ["list"]) {
            let lines = listOutput.components(separatedBy: "\n")
            for line in lines {
                if line.contains("Windows_NTFS") || line.contains("Microsoft Basic Data") {
                    let components = line.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces)
                    if let diskId = components.last {
                        if let disk = getDiskInfo(identifier: diskId) {
                            results.append(disk)
                        }
                    }
                }
            }
        }

        return results
    }

    private static nonisolated func getDiskInfo(identifier: String) -> NTFSDisk? {
        guard let output = runCommand("/usr/sbin/diskutil", arguments: ["info", identifier]) else {
            return nil
        }

        var name = ""
        var totalSize: UInt64 = 0
        var mountPoint: String?

        let lines = output.components(separatedBy: "\n")
        for line in lines {
            let parts = line.components(separatedBy: ":")
            guard parts.count >= 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)

            switch key {
            case "Volume Name":
                name = value
            case "Disk Size":
                if let match = value.range(of: #"\((\d+) Bytes\)"#, options: .regularExpression) {
                    let bytesStr = value[match].replacingOccurrences(of: "(", with: "").replacingOccurrences(of: " Bytes)", with: "")
                    totalSize = UInt64(bytesStr) ?? 0
                }
            case "Mount Point":
                if !value.isEmpty {
                    mountPoint = value
                }
            default:
                break
            }
        }

        let devicePath = "/dev/\(identifier)"
        let status: MountStatus = mountPoint != nil ? .mounted : .unmounted

        return NTFSDisk(
            id: identifier,
            name: name,
            devicePath: devicePath,
            totalSize: totalSize,
            mountPoint: mountPoint,
            mountStatus: status
        )
    }

    // MARK: - Mount/Unmount Operations

    private static nonisolated func performMount(disk: NTFSDisk, ntfs3gPath: String?) async throws -> String {
        guard let ntfs3g = ntfs3gPath else {
            throw NTFSError.ntfs3gNotFound
        }

        let mountPoint = "/Volumes/\(disk.displayName)"

        if !FileManager.default.fileExists(atPath: mountPoint) {
            try? FileManager.default.createDirectory(atPath: mountPoint, withIntermediateDirectories: true)
        }

        if disk.mountPoint != nil {
            _ = runCommand("/usr/sbin/diskutil", arguments: ["unmount", disk.devicePath])
            try await Task.sleep(nanoseconds: 500_000_000)
        }

        let result = runCommandWithStatus(
            ntfs3g,
            arguments: [disk.devicePath, mountPoint, "-o", "local,allow_other,auto_xattr,volname=\(disk.displayName)"]
        )

        if result.exitCode != 0 {
            throw NTFSError.mountFailed(result.stderr)
        }

        return mountPoint
    }

    private static nonisolated func performUnmount(disk: NTFSDisk) async throws {
        guard let mountPoint = disk.mountPoint else {
            throw NTFSError.notMounted
        }

        let result = runCommandWithStatus("/sbin/umount", arguments: [mountPoint])
        if result.exitCode != 0 {
            let forceResult = runCommandWithStatus("/usr/sbin/diskutil", arguments: ["unmount", "force", mountPoint])
            if forceResult.exitCode != 0 {
                throw NTFSError.unmountFailed(forceResult.stderr)
            }
        }
    }

    // MARK: - Helpers

    private static nonisolated func isNTFSVolume(description: [String: Any]) -> Bool {
        if let fsType = description[kDADiskDescriptionVolumeKindKey as String] as? String {
            return fsType.lowercased() == "ntfs"
        }
        return false
    }

    private static nonisolated func parseDisk(from desc: [String: Any], daDisk: DADisk) -> NTFSDisk? {
        guard let bsdName = DADiskGetBSDName(daDisk) else { return nil }
        let diskId = String(cString: bsdName)

        let name = desc[kDADiskDescriptionVolumeNameKey as String] as? String ?? ""
        let size = desc[kDADiskDescriptionMediaSizeKey as String] as? UInt64 ?? 0
        let mountURL = desc[kDADiskDescriptionVolumePathKey as String] as? URL
        let mountPoint = mountURL?.path

        let status: MountStatus = mountPoint != nil ? .mounted : .unmounted

        return NTFSDisk(
            id: diskId,
            name: name,
            devicePath: "/dev/\(diskId)",
            totalSize: size,
            mountPoint: mountPoint,
            mountStatus: status
        )
    }

    private static nonisolated func runCommand(_ path: String, arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    private static nonisolated func runCommandWithStatus(_ path: String, arguments: [String]) -> (exitCode: Int32, stdout: String, stderr: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()

            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

            return (
                process.terminationStatus,
                String(data: stdoutData, encoding: .utf8) ?? "",
                String(data: stderrData, encoding: .utf8) ?? ""
            )
        } catch {
            return (-1, "", error.localizedDescription)
        }
    }
}

// MARK: - Errors

enum NTFSError: LocalizedError {
    case ntfs3gNotFound
    case mountFailed(String)
    case unmountFailed(String)
    case notMounted

    var errorDescription: String? {
        switch self {
        case .ntfs3gNotFound:
            return "未找到 NTFS-3G，请先安装 macFUSE 和 NTFS-3G。\n可通过 Homebrew 安装: brew install macfuse ntfs-3g-mac"
        case .mountFailed(let msg):
            return "挂载失败: \(msg)"
        case .unmountFailed(let msg):
            return "卸载失败: \(msg)"
        case .notMounted:
            return "磁盘未挂载"
        }
    }
}
