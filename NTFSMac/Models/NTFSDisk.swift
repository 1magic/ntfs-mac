import Foundation

struct DependencyStatus {
    let homebrew: Bool
    let macFUSE: Bool
    let ntfs3g: Bool
    let isAppleSilicon: Bool

    var isReady: Bool { macFUSE && ntfs3g }
}

enum MountStatus: String {
    case mounted = "已挂载"
    case unmounted = "未挂载"
    case mounting = "挂载中..."
    case unmounting = "卸载中..."
    case error = "错误"
}

struct NTFSDisk: Identifiable, Equatable {
    let id: String // BSD name, e.g. "disk2s1"
    let name: String // Volume name
    let devicePath: String // e.g. "/dev/disk2s1"
    let totalSize: UInt64 // bytes
    var mountPoint: String?
    var mountStatus: MountStatus

    var isWritable: Bool {
        mountStatus == .mounted && mountPoint != nil
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
    }

    var displayName: String {
        name.isEmpty ? id : name
    }

    static func == (lhs: NTFSDisk, rhs: NTFSDisk) -> Bool {
        lhs.id == rhs.id && lhs.mountStatus == rhs.mountStatus && lhs.mountPoint == rhs.mountPoint
    }
}
