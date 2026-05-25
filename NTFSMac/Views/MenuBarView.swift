import SwiftUI
import AppKit

struct MenuBarView: View {
    @EnvironmentObject var diskManager: DiskManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("NTFS 磁盘")
                    .font(.headline)
                Spacer()
                Button(action: { diskManager.refreshDisks() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Disk list
            if diskManager.disks.isEmpty {
                emptyState
            } else {
                diskList
            }

            Divider()

            // Footer actions
            footerActions
        }
        .frame(width: 320)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "externaldrive.badge.questionmark")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("未检测到 NTFS 磁盘")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var diskList: some View {
        VStack(spacing: 0) {
            ForEach(diskManager.disks) { disk in
                DiskRowView(
                    disk: disk,
                    onMount: { diskManager.mount(disk: disk) },
                    onUnmount: { diskManager.unmount(disk: disk) }
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

                if disk.id != diskManager.disks.last?.id {
                    Divider()
                        .padding(.horizontal, 12)
                }
            }
        }
    }

    private func confirmQuit() {
        let alert = NSAlert()
        alert.messageText = "确认退出"
        alert.informativeText = "退出后将无法自动检测和挂载 NTFS 磁盘，确定要退出吗？"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "退出")
        alert.addButton(withTitle: "取消")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSApplication.shared.terminate(nil)
        }
    }

    private var footerActions: some View {
        VStack(spacing: 0) {
            if !diskManager.isReady {
                Button(action: {
                    openWindow(id: "setup-guide")
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("依赖未就绪，点击查看安装引导")
                            .font(.caption)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(.orange.opacity(0.08))

                Divider()
            }

            HStack {
                Button("打开主窗口") {
                    openWindow(id: "main-window")
                }
                .buttonStyle(.plain)
                .font(.caption)

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(diskManager.isReady ? .green : .red)
                        .frame(width: 6, height: 6)
                    Text(diskManager.isReady ? "就绪" : "依赖缺失")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Divider()
                    .frame(height: 12)

                Button(action: {
                    confirmQuit()
                }) {
                    Image(systemName: "power")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("退出 NTFS Mac")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}
