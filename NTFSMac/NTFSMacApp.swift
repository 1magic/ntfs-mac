import SwiftUI

@MainActor
final class AppState: ObservableObject {
    let diskManager = DiskManager()
    private var observer: NSObjectProtocol?

    init() {
        NotificationManager.shared.setupCategories()

        observer = NotificationCenter.default.addObserver(
            forName: .ntfsMountRequested,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let diskId = notification.userInfo?["diskId"] as? String else { return }
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let disk = self.diskManager.disks.first(where: { $0.id == diskId }) {
                    self.diskManager.mount(disk: disk)
                }
            }
        }
    }

    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

@main
struct NTFSMacApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        // Menu Bar
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState.diskManager)
        } label: {
            Label("NTFS Mac", systemImage: "externaldrive.fill.badge.checkmark")
        }
        .menuBarExtraStyle(.window)

        // Main Window (hidden by default, opened on demand)
        Window("NTFS Mac", id: "main-window") {
            MainWindowView()
                .environmentObject(appState.diskManager)
        }
        .defaultSize(width: 600, height: 400)
        .windowResizability(.contentSize)

        // Setup Guide Window
        Window("安装引导", id: "setup-guide") {
            SetupGuideView()
                .environmentObject(appState.diskManager)
        }
        .defaultSize(width: 520, height: 460)
        .windowResizability(.contentSize)
    }
}
