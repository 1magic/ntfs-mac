import Foundation
import UserNotifications

final class NotificationManager: NSObject, @unchecked Sendable {
    static let shared = NotificationManager()

    private override init() {
        super.init()
        requestAuthorization()
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
        UNUserNotificationCenter.current().delegate = self
    }

    func notifyDiskAppeared(disk: NTFSDisk) {
        let content = UNMutableNotificationContent()
        content.title = "检测到 NTFS 磁盘"
        content.body = "「\(disk.displayName)」(\(disk.formattedSize)) 已插入，是否以读写模式挂载？"
        content.sound = .default
        content.categoryIdentifier = "NTFS_DISK_ACTION"
        content.userInfo = ["diskId": disk.id]

        let request = UNNotificationRequest(
            identifier: "disk-appeared-\(disk.id)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func notifyMountSuccess(disk: NTFSDisk) {
        let content = UNMutableNotificationContent()
        content.title = "NTFS 磁盘已挂载"
        content.body = "「\(disk.displayName)」已以读写模式挂载到 \(disk.mountPoint ?? "/Volumes")"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "disk-mounted-\(disk.id)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func notifyError(message: String) {
        let content = UNMutableNotificationContent()
        content.title = "NTFS Mac 错误"
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "error-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func setupCategories() {
        let mountAction = UNNotificationAction(
            identifier: "MOUNT_ACTION",
            title: "以读写模式挂载",
            options: [.authenticationRequired]
        )

        let dismissAction = UNNotificationAction(
            identifier: "DISMISS_ACTION",
            title: "忽略",
            options: [.destructive]
        )

        let category = UNNotificationCategory(
            identifier: "NTFS_DISK_ACTION",
            actions: [mountAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard let diskId = userInfo["diskId"] as? String else { return }

        switch response.actionIdentifier {
        case "MOUNT_ACTION", UNNotificationDefaultActionIdentifier:
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .ntfsMountRequested,
                    object: nil,
                    userInfo: ["diskId": diskId]
                )
            }
        default:
            break
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let ntfsMountRequested = Notification.Name("ntfsMountRequested")
}
