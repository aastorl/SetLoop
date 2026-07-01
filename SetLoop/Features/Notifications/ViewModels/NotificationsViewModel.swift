import Foundation
import Combine

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published private(set) var items: [NotificationItem] = []
    @Published private(set) var unreadCount = 0
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

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
            return "Las nuevas candidaturas y cambios clave en tus fechas apareceran aqui."
        case .musician, .dj:
            return "Las respuestas a tus candidaturas y novedades importantes apareceran aqui."
        }
    }

    var canMarkAllAsRead: Bool {
        unreadCount > 0
    }

    func load() async {
        guard notificationStore.usesRemoteService else {
            reload()
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await notificationStore.load(for: currentProfile.id)
            errorMessage = nil
            reload()
        } catch {
            errorMessage = error.setLoopUserMessage
        }
    }

    func markAsRead(_ item: NotificationItem) {
        guard notificationStore.usesRemoteService == false else {
            Task {
                await markAsReadAsync(item)
            }
            return
        }

        notificationStore.markAsRead(item.id)
    }

    func markAllAsRead() {
        guard notificationStore.usesRemoteService == false else {
            Task {
                await markAllAsReadAsync()
            }
            return
        }

        notificationStore.markAllAsRead(for: currentProfile.id)
    }

    func markAsReadAsync(_ item: NotificationItem) async {
        guard item.isRead == false else {
            return
        }

        do {
            try await notificationStore.saveMarkAsRead(item.id)
            errorMessage = nil
            reload()
        } catch {
            errorMessage = error.setLoopUserMessage
        }
    }

    func markAllAsReadAsync() async {
        guard unreadCount > 0 else {
            return
        }

        do {
            try await notificationStore.saveMarkAllAsRead(for: currentProfile.id)
            errorMessage = nil
            reload()
        } catch {
            errorMessage = error.setLoopUserMessage
        }
    }

    func deleteAsync(_ item: NotificationItem) async {
        do {
            try await notificationStore.saveDelete(item.id)
            errorMessage = nil
            reload()
        } catch {
            errorMessage = error.setLoopUserMessage
        }
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
    let relatedApplicationID: UUID?

    init(notification: AppNotification) {
        id = notification.id
        title = notification.title
        body = notification.body
        createdAt = notification.createdAt
        isRead = notification.isRead
        type = notification.type
        relatedApplicationID = notification.relatedApplicationID
    }
}
