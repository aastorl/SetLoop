import Foundation
import Combine

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published private(set) var items: [NotificationItem] = []
    @Published private(set) var unreadCount = 0

    private let currentProfile: UserProfile
    private let notificationStore: NotificationStore
    private var cancellables = Set<AnyCancellable>()

    init(
        currentProfile: UserProfile,
        notificationStore: NotificationStore
    ) {
        self.currentProfile = currentProfile
        self.notificationStore = notificationStore

        reload()

        notificationStore.$notifications
            .sink { [weak self] _ in
                self?.reload()
            }
            .store(in: &cancellables)
    }

    var emptyStateDescription: String {
        switch currentProfile.role {
        case .venue:
            return "Las nuevas candidaturas, invitaciones y cambios clave en tus fechas apareceran aqui."
        case .musician, .dj:
            return "Las respuestas a tus solicitudes, invitaciones y novedades importantes apareceran aqui."
        }
    }

    var canMarkAllAsRead: Bool {
        unreadCount > 0
    }

    func markAsRead(_ item: NotificationItem) {
        notificationStore.markAsRead(item.id)
    }

    func markAllAsRead() {
        notificationStore.markAllAsRead(for: currentProfile.id)
    }

    private func reload() {
        let notifications = notificationStore.notifications(for: currentProfile.id)
        items = notifications.map(NotificationItem.init)
        unreadCount = notifications.count { $0.isRead == false }
    }
}

struct NotificationItem: Identifiable, Equatable {
    let id: UUID
    let title: String
    let body: String
    let createdAt: Date
    let isRead: Bool
    let type: AppNotificationType

    init(notification: AppNotification) {
        id = notification.id
        title = notification.title
        body = notification.body
        createdAt = notification.createdAt
        isRead = notification.isRead
        type = notification.type
    }
}
