import SwiftUI

struct DiskRowView: View {
    let disk: NTFSDisk
    let onMount: () -> Void
    let onUnmount: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Disk icon
            Image(systemName: "externaldrive.fill")
                .font(.title2)
                .foregroundStyle(statusColor)

            // Disk info
            VStack(alignment: .leading, spacing: 2) {
                Text(disk.displayName)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(disk.formattedSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .foregroundStyle(.secondary)

                    Text(disk.mountStatus.rawValue)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                }

                if let mountPoint = disk.mountPoint {
                    Text(mountPoint)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Action button
            actionButton
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var actionButton: some View {
        switch disk.mountStatus {
        case .unmounted, .error:
            Button("挂载") {
                onMount()
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .controlSize(.small)

        case .mounted:
            Button("卸载") {
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
