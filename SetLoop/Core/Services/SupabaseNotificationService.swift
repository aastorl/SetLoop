import Foundation

protocol NotificationRemoteServicing {
    func fetchNotifications(for userID: UUID) async throws -> [AppNotification]
    func markAsRead(notificationID: UUID) async throws -> AppNotification
    func markAllAsRead(for userID: UUID) async throws -> [AppNotification]
    func deleteNotification(notificationID: UUID) async throws
}

final class SupabaseNotificationService: NotificationRemoteServicing {
    private let apiClient: SupabaseAPIClient
    private let sessionStore: SessionStoring

    init(
        apiClient: SupabaseAPIClient = SupabaseAPIClient(),
        sessionStore: SessionStoring = KeychainSessionStore()
    ) {
        self.apiClient = apiClient
        self.sessionStore = sessionStore
    }

    func fetchNotifications(for userID: UUID) async throws -> [AppNotification] {
        try await apiClient.request(
            path: "/rest/v1/notifications",
            queryItems: [
                URLQueryItem(name: "user_id", value: "eq.\(userID.notificationRestID)"),
                URLQueryItem(name: "type", value: "in.(\(AppNotificationType.currentProductRESTFilter))"),
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "order", value: "created_at.desc")
            ],
            authToken: try await accessToken()
        )
    }

    func markAsRead(notificationID: UUID) async throws -> AppNotification {
        let notifications: [AppNotification] = try await apiClient.request(
            path: "/rest/v1/notifications",
            queryItems: [
                URLQueryItem(name: "id", value: "eq.\(notificationID.notificationRestID)"),
                URLQueryItem(name: "select", value: "*")
            ],
            method: .patch,
            body: NotificationReadUpdateRequest(isRead: true),
            authToken: try await accessToken(),
            additionalHeaders: ["Prefer": "return=representation"]
        )

        guard let notification = notifications.first else {
            throw APIError.emptyResponse
        }

        return notification
    }

    func markAllAsRead(for userID: UUID) async throws -> [AppNotification] {
        try await apiClient.request(
            path: "/rest/v1/notifications",
            queryItems: [
                URLQueryItem(name: "user_id", value: "eq.\(userID.notificationRestID)"),
                URLQueryItem(name: "is_read", value: "eq.false"),
                URLQueryItem(name: "type", value: "in.(\(AppNotificationType.currentProductRESTFilter))"),
                URLQueryItem(name: "select", value: "*")
            ],
            method: .patch,
            body: NotificationReadUpdateRequest(isRead: true),
            authToken: try await accessToken(),
            additionalHeaders: ["Prefer": "return=representation"]
        )
    }

    func deleteNotification(notificationID: UUID) async throws {
        let _: EmptyResponse = try await apiClient.request(
            path: "/rest/v1/notifications",
            queryItems: [
                URLQueryItem(name: "id", value: "eq.\(notificationID.notificationRestID)")
            ],
            method: .delete,
            authToken: try await accessToken(),
            additionalHeaders: ["Prefer": "return=minimal"]
        )
    }

    private func accessToken() async throws -> String {
        guard let session = try sessionStore.load() else {
            throw AuthServiceError.missingSession
        }

        if session.needsRefresh {
            return try await refreshSession(session).accessToken
        }

        return session.accessToken
    }

    private func refreshSession(_ session: AuthSession) async throws -> AuthSession {
        let request = RefreshTokenRequest(refreshToken: session.refreshToken)
        let response: SupabaseAuthResponse = try await apiClient.request(
            path: "/auth/v1/token",
            queryItems: [URLQueryItem(name: "grant_type", value: "refresh_token")],
            method: .post,
            body: request
        )

        guard let refreshedSession = response.makeSession(fallbackEmail: session.email) else {
            throw AuthServiceError.missingSession
        }

        try sessionStore.save(refreshedSession)
        return refreshedSession
    }
}

private struct NotificationReadUpdateRequest: Encodable {
    let isRead: Bool

    enum CodingKeys: String, CodingKey {
        case isRead = "is_read"
    }
}

private extension UUID {
    var notificationRestID: String {
        uuidString.lowercased()
    }
}

private extension AppNotificationType {
    static var currentProductRESTFilter: String {
        [
            applicationReceived,
            applicationAccepted,
            applicationRejected
        ]
        .map(\.rawValue)
        .joined(separator: ",")
    }
}
