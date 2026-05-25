import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject var diskManager: DiskManager
    @Environment(\.openWindow) private var openWindow
    @State private var showQuitConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Dependency warning banner
            if !diskManager.isReady {
                dependencyBanner
            }

            // Toolbar area
            headerView

            Divider()

            // Main content
            if diskManager.disks.isEmpty {
                emptyState
            } else {
                diskListView
            }

            // Error banner
            if let error = diskManager.lastError {
                errorBanner(message: error)
            }

            Divider()

            // Status bar
            statusBar
        }
        .frame(minWidth: 500, minHeight: 350)
    }

    private var dependencyBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("缺少必要依赖，NTFS 读写功能不可用。")
                .font(.caption)
            Spacer()
            Button("安装引导") {
                openWindow(id: "setup-guide")
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.small)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.orange.opacity(0.1))
    }

    private var headerView: some View {
        HStack {
            Text("NTFS Mac")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            Button(action: { diskManager.refreshDisks() }) {
                Label("刷新", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(action: {
                showQuitConfirmation = true
            }) {
                Label("退出", systemImage: "power")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .alert("确认退出", isPresented: $showQuitConfirmation) {
                Button("退出", role: .destructive) {
                    NSApplication.shared.terminate(nil)
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("退出后将无法自动检测和挂载 NTFS 磁盘，确定要退出吗？")
            }
        }
        .padding()
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "externaldrive.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("未检测到 NTFS 磁盘")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("请插入 NTFS 格式的外置硬盘或 U 盘")
                .font(.subheadline)
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var diskListView: some View {
        List {
            ForEach(diskManager.disks) { disk in
                DiskDetailRow(
                    disk: disk,
                    onMount: { diskManager.mount(disk: disk) },
                    onUnmount: { diskManager.unmount(disk: disk) }
                )
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    private func errorBanner(message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.caption)
                .lineLimit(2)
            Spacer()
            Button("关闭") {
                diskManager.lastError = nil
            }
            .buttonStyle(.plain)
            .font(.caption)
        }
        .padding(8)
        .background(.red.opacity(0.1))
    }

    private var statusBar: some View {
        HStack {
            // NTFS-3G status
            HStack(spacing: 4) {
                Circle()
                    .fill(diskManager.isReady ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(diskManager.isReady ? "依赖就绪" : "依赖缺失")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(diskManager.disks.count) 个 NTFS 磁盘")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}

// MARK: - Disk Detail Row

struct DiskDetailRow: View {
    let disk: NTFSDisk
    let onMount: () -> Void
    let onUnmount: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: "externaldrive.fill")
                .font(.title)
                .foregroundStyle(statusColor)
                .frame(width: 40)

            // Info columns
            VStack(alignment: .leading, spacing: 4) {
                Text(disk.displayName)
                    .font(.headline)

                HStack(spacing: 16) {
                    InfoLabel(title: "设备", value: disk.devicePath)
                    InfoLabel(title: "容量", value: disk.formattedSize)
                    InfoLabel(title: "状态", value: disk.mountStatus.rawValue)
                }

                if let mountPoint = disk.mountPoint {
                    InfoLabel(title: "挂载点", value: mountPoint)
                }
            }

            Spacer()

            // Actions
            VStack(spacing: 4) {
                actionButton

                if disk.mountStatus == .mounted, let mountPoint = disk.mountPoint {
                    Button("在 Finder 中打开") {
                        NSWorkspace.shared.open(URL(fileURLWithPath: mountPoint))
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.blue)
                }
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var actionButton: some View {
        switch disk.mountStatus {
        case .unmounted, .error:
            Button("以读写模式挂载") {
                onMount()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

        case .mounted:
            Button("安全卸载") {
                onUnmount()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

        case .mounting, .unmounting:
            ProgressView()
                .controlSize(.small)
        }
    }

    private var statusColor: Color {
        switch disk.mountStatus {
        case .mounted: return .green
        case .unmounted: return .secondary
        case .mounting, .unmounting: return .orange
        case .error: return .red
        }
    }
}

// MARK: - Info Label

struct InfoLabel: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Text(title + ":")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
