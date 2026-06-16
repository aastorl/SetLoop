import Foundation
import Combine

@MainActor
final class NotificationStore: ObservableObject {
    private let notificationsKey = "setloop.mock.notifications"
    private let userDefaults: UserDefaults
    private let remoteService: NotificationRemoteServicing?
    private let encoder = JSONEncoder.supabase
    private let decoder = JSONDecoder.supabase

    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    @Published private(set) var notifications: [AppNotification] {
        didSet {
            if remoteService == nil {
                persistNotifications()
            }
        }
    }

    init(
        userDefaults: UserDefaults = .standard,
        remoteService: NotificationRemoteServicing? = nil
    ) {
        let decoder = JSONDecoder.supabase
        self.userDefaults = userDefaults
        self.remoteService = remoteService
        self.notifications = remoteService == nil
            ? Self.loadPersistedNotifications(
                from: userDefaults,
                using: decoder
            )
            : []
    }

    var usesRemoteService: Bool {
        remoteService != nil
    }

    func notifications(for userID: UUID) -> [AppNotification] {
        notifications
            .filter { $0.userID == userID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func unreadCount(for userID: UUID) -> Int {
        notifications.count { $0.userID == userID && !$0.isRead }
    }

    func load(for userID: UUID) async throws {
        guard let remoteService else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            notifications = try await remoteService.fetchNotifications(for: userID)
            errorMessage = nil
        } catch {
            errorMessage = error.setLoopUserMessage
            throw error
        }
    }

    @discardableResult
    func add(
        userID: UUID,
        type: AppNotificationType,
        title: String,
        body: String,
        relatedGigID: UUID? = nil,
        relatedApplicationID: UUID? = nil
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
            relatedApplicationID: relatedApplicationID
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

    func saveMarkAsRead(_ notificationID: UUID) async throws {
        guard let remoteService else {
            markAsRead(notificationID)
            return
        }

        do {
            let notification = try await remoteService.markAsRead(notificationID: notificationID)
            upsert(notification)
            errorMessage = nil
        } catch {
            errorMessage = error.setLoopUserMessage
            throw error
        }
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

    func saveMarkAllAsRead(for userID: UUID) async throws {
        guard let remoteService else {
            markAllAsRead(for: userID)
            return
        }

        do {
            let updatedNotifications = try await remoteService.markAllAsRead(for: userID)

            if updatedNotifications.isEmpty {
                markAllAsRead(for: userID)
            } else {
                for notification in updatedNotifications {
                    upsert(notification)
                }
            }

            errorMessage = nil
        } catch {
            errorMessage = error.setLoopUserMessage
            throw error
        }
    }

    @discardableResult
    private func upsert(_ notification: AppNotification) -> AppNotification {
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[index] = notification
        } else {
            notifications.append(notification)
        }

        notifications.sort { $0.createdAt > $1.createdAt }
        return notification
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
