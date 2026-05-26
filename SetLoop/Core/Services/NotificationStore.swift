import Foundation
import Combine

@MainActor
final class NotificationStore: ObservableObject {
    private let notificationsKey = "setloop.mock.notifications"
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder.supabase
    private let decoder = JSONDecoder.supabase

    @Published private(set) var notifications: [AppNotification] {
        didSet {
            persistNotifications()
        }
    }

    init(userDefaults: UserDefaults = .standard) {
        let decoder = JSONDecoder.supabase
        self.userDefaults = userDefaults
        self.notifications = Self.loadPersistedNotifications(
            from: userDefaults,
            using: decoder
        )
    }

    func notifications(for userID: UUID) -> [AppNotification] {
        notifications
            .filter { $0.userID == userID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func unreadCount(for userID: UUID) -> Int {
        notifications.count { $0.userID == userID && !$0.isRead }
    }

    @discardableResult
    func add(
        userID: UUID,
        type: AppNotificationType,
        title: String,
        body: String,
        relatedGigID: UUID? = nil,
        relatedApplicationID: UUID? = nil,
        relatedInviteID: UUID? = nil
    ) -> AppNotification {
        let notification = AppNotification(
            id: UUID(),
            userID: userID,
            type: type,
            title: title,
            body: body,
            createdAt: Date(),
            isRead: false,
            relatedGigID: relatedGigID,
            relatedApplicationID: relatedApplicationID,
            relatedInviteID: relatedInviteID
        )

        notifications.insert(notification, at: 0)
        return notification
    }

    func markAsRead(_ notificationID: UUID) {
        guard let index = notifications.firstIndex(where: { $0.id == notificationID }),
              notifications[index].isRead == false else {
            return
        }

        var updatedNotifications = notifications
        updatedNotifications[index].isRead = true
        notifications = updatedNotifications
    }

    func markAllAsRead(for userID: UUID) {
        var updatedNotifications = notifications
        var didChange = false

        for index in updatedNotifications.indices where updatedNotifications[index].userID == userID && updatedNotifications[index].isRead == false {
            updatedNotifications[index].isRead = true
            didChange = true
        }

        if didChange {
            notifications = updatedNotifications
        }
    }

    private func persistNotifications() {
        guard let data = try? encoder.encode(notifications) else {
            return
        }

        userDefaults.set(data, forKey: notificationsKey)
    }

    private static func loadPersistedNotifications(
        from userDefaults: UserDefaults,
        using decoder: JSONDecoder
    ) -> [AppNotification] {
        guard let data = userDefaults.data(forKey: "setloop.mock.notifications"),
              let notifications = try? decoder.decode([AppNotification].self, from: data) else {
            return []
        }

        return notifications.sorted { $0.createdAt > $1.createdAt }
    }
}
