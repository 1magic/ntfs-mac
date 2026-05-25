import SwiftUI

struct SetupGuideView: View {
    @EnvironmentObject var diskManager: DiskManager
    @State private var currentStep: SetupStep = .welcome
    @State private var isInstalling = false
    @State private var installLog: String = ""

    enum SetupStep: Int, CaseIterable {
        case welcome
        case homebrew
        case macFUSE
        case ntfs3g
        case done
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            progressBar

            Divider()

            // Content
            ScrollView {
                stepContent
                    .padding(24)
            }

            Divider()

            // Navigation
            navigationBar
        }
        .frame(width: 520, height: 460)
        .onAppear {
            advanceToNextNeeded()
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(SetupStep.allCases, id: \.rawValue) { step in
                RoundedRectangle(cornerRadius: 2)
                    .fill(step.rawValue <= currentStep.rawValue ? Color.accentColor : Color.secondary.opacity(0.2))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .welcome:
            welcomeStep
        case .homebrew:
            homebrewStep
        case .macFUSE:
            macFUSEStep
        case .ntfs3g:
            ntfs3gStep
        case .done:
            doneStep
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "externaldrive.fill.badge.checkmark")
                .font(.system(size: 56))
                .foregroundStyle(.blue)

            Text("欢迎使用 NTFS Mac")
                .font(.title)
                .fontWeight(.bold)

            Text("NTFS Mac 需要安装以下依赖才能正常工作：")
                .font(.body)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Image(systemName: "cpu")
                    .foregroundStyle(.secondary)
                Text("当前 CPU：\(diskManager.cpuArchDescription)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(.quaternary))

            VStack(alignment: .leading, spacing: 12) {
                DependencyRow(
                    name: "Homebrew",
                    description: "macOS 包管理器，用于安装其他依赖",
                    isInstalled: diskManager.isHomebrewInstalled,
                    isRequired: false
                )
                DependencyRow(
                    name: "macFUSE",
                    description: "文件系统扩展框架，提供 NTFS 驱动支持",
                    isInstalled: diskManager.isMacFUSEInstalled,
                    isRequired: true
                )
                DependencyRow(
                    name: "NTFS-3G",
                    description: "开源 NTFS 读写驱动",
                    isInstalled: diskManager.isNTFS3GInstalled,
                    isRequired: true
                )
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
        }
    }

    private var homebrewStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepHeader(
                icon: "cup.and.saucer.fill",
                title: "安装 Homebrew",
                isInstalled: diskManager.isHomebrewInstalled
            )

            if diskManager.isHomebrewInstalled {
                InstalledBanner(name: "Homebrew")
            } else {
                Text("Homebrew 是 macOS 上最流行的包管理器，可以方便地安装 macFUSE 和 NTFS-3G。")
                    .font(.body)
                    .foregroundStyle(.secondary)

                Text("请在终端中执行以下命令：")
                    .font(.subheadline)
                    .fontWeight(.medium)

                CommandBlock(
                    command: #"/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)""#
                )

                InstallTip(text: "安装完成后，请点击下方「重新检测」按钮。")
            }
        }
    }

    private var macFUSEStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepHeader(
                icon: "puzzlepiece.extension.fill",
                title: "安装 macFUSE",
                isInstalled: diskManager.isMacFUSEInstalled
            )

            if diskManager.isMacFUSEInstalled {
                InstalledBanner(name: "macFUSE")
            } else {
                Text("macFUSE 提供了用户空间文件系统支持，是 NTFS-3G 的运行基础。")
                    .font(.body)
                    .foregroundStyle(.secondary)

                // Method 1: Homebrew
                VStack(alignment: .leading, spacing: 8) {
                    Text("方式一：通过 Homebrew 安装（推荐）")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    CommandBlock(command: "brew install --cask macfuse")
                }

                Divider()

                // Method 2: Manual download
                VStack(alignment: .leading, spacing: 8) {
                    Text("方式二：手动下载安装")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Button(action: {
                        NSWorkspace.shared.open(URL(string: "https://osxfuse.github.io/")!)
                    }) {
                        Label("打开 macFUSE 官网下载", systemImage: "safari")
                    }
                    .buttonStyle(.bordered)
                }

                WarningBox(
                    text: "安装 macFUSE 后需要在「系统设置 → 隐私与安全性」中允许系统扩展，然后重启电脑。"
                )
            }
        }
    }

    private var ntfs3gStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepHeader(
                icon: "externaldrive.fill",
                title: "安装 NTFS-3G",
                isInstalled: diskManager.isNTFS3GInstalled
            )

            if diskManager.isNTFS3GInstalled {
                InstalledBanner(name: "NTFS-3G")
            } else {
                Text("NTFS-3G 是开源的 NTFS 文件系统驱动，提供完整的读写支持。")
                    .font(.body)
                    .foregroundStyle(.secondary)

                if diskManager.isHomebrewInstalled {
                    if diskManager.isAppleSilicon {
                        // Apple Silicon: 官方无预编译包，推荐第三方 tap
                        VStack(alignment: .leading, spacing: 8) {
                            Text("通过第三方 Tap 安装（推荐，提供 ARM 预编译版本）")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            CommandBlock(command: "brew install gromgit/fuse/ntfs-3g-mac")
                        }

                        InstallTip(text: "检测到你的 Mac 使用 Apple Silicon 芯片，官方 ntfs-3g 无预编译包，已自动推荐第三方源。")
                    } else {
                        // Intel: 官方有预编译包，可直接安装
                        VStack(alignment: .leading, spacing: 8) {
                            Text("通过 Homebrew 安装（推荐）")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            CommandBlock(command: "brew install ntfs-3g")
                        }

                        InstallTip(text: "检测到你的 Mac 使用 Intel 芯片，可直接使用官方预编译包。")
                    }

                    if !diskManager.isMacFUSEInstalled {
                        WarningBox(text: "请先完成 macFUSE 的安装再安装 NTFS-3G。")
                    }
                } else {
                    InstallTip(text: "推荐先安装 Homebrew，可以更方便地安装 NTFS-3G。")
                }
            }
        }
    }

    private var doneStep: some View {
        VStack(spacing: 20) {
            if diskManager.isReady {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)

                Text("一切就绪！")
                    .font(.title)
                    .fontWeight(.bold)

                Text("所有依赖已安装完成，现在可以使用 NTFS Mac 来读写 NTFS 磁盘了。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.orange)

                Text("部分依赖未安装")
                    .font(.title)
                    .fontWeight(.bold)

                Text("以下依赖仍未检测到，NTFS 读写功能可能无法正常使用。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 8) {
                    if !diskManager.isMacFUSEInstalled {
                        Label("macFUSE 未安装", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                    if !diskManager.isNTFS3GInstalled {
                        Label("NTFS-3G 未安装", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 8).fill(.red.opacity(0.1)))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Navigation

    private var navigationBar: some View {
        HStack {
            if currentStep != .welcome {
                Button("上一步") {
                    withAnimation {
                        if let prev = SetupStep(rawValue: currentStep.rawValue - 1) {
                            currentStep = prev
                        }
                    }
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            Button(action: {
                diskManager.recheckDependencies()
            }) {
                Label("重新检测", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            if currentStep == .done {
                if diskManager.isReady {
                    Button("完成") {
                        NSApp.keyWindow?.close()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Button("下一步") {
                    withAnimation {
                        if let next = SetupStep(rawValue: currentStep.rawValue + 1) {
                            currentStep = next
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    private func advanceToNextNeeded() {
        let status = diskManager.dependencyStatus
        if status.isReady {
            currentStep = .done
        } else if !status.homebrew {
            currentStep = .homebrew
        } else if !status.macFUSE {
            currentStep = .macFUSE
        } else if !status.ntfs3g {
            currentStep = .ntfs3g
        }
    }
}

// MARK: - Subcomponents

struct DependencyRow: View {
    let name: String
    let description: String
    let isInstalled: Bool
    let isRequired: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isInstalled ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isInstalled ? .green : .secondary)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(name).fontWeight(.medium)
                    if isRequired {
                        Text("必需")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(.red.opacity(0.15)))
                            .foregroundStyle(.red)
                    } else {
                        Text("推荐")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(.blue.opacity(0.15)))
                            .foregroundStyle(.blue)
                    }
                }
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

struct StepHeader: View {
    let icon: String
    let title: String
    let isInstalled: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(.blue)
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            Spacer()
            if isInstalled {
                Label("已安装", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline)
            }
        }
    }
}

struct InstalledBanner: View {
    let name: String

    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("\(name) 已安装，可以继续下一步。")
                .font(.body)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(.green.opacity(0.1)))
    }
}

struct CommandBlock: View {
    let command: String

    var body: some View {
        HStack {
            Text(command)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(nil)

            Spacer()

            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command, forType: .string)
            }) {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.plain)
            .help("复制命令")
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.textBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
    }
}

struct WarningBox: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(.orange.opacity(0.1)))
    }
}

struct InstallTip: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.yellow)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(.yellow.opacity(0.08)))
    }
}
