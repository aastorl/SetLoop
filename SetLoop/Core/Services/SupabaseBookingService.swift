import Foundation

protocol BookingRemoteServicing {
    func fetchApplications() async throws -> [Application]
    func fetchApplication(gigID: UUID, applicantUserID: UUID) async throws -> Application?
    func createApplication(_ application: Application) async throws -> Application
    func updateApplicationStatus(applicationID: UUID, status: ApplicationStatus) async throws -> Application
    func deleteApplication(applicationID: UUID) async throws
}

final class SupabaseBookingService: BookingRemoteServicing {
    private let apiClient: SupabaseAPIClient
    private let sessionStore: SessionStoring

    init(
        apiClient: SupabaseAPIClient = SupabaseAPIClient(),
        sessionStore: SessionStoring = KeychainSessionStore()
    ) {
        self.apiClient = apiClient
        self.sessionStore = sessionStore
    }

    func fetchApplications() async throws -> [Application] {
        try await apiClient.request(
            path: "/rest/v1/applications",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "order", value: "created_at.desc")
            ],
            authToken: try await accessToken()
        )
    }

    func fetchApplication(gigID: UUID, applicantUserID: UUID) async throws -> Application? {
        let applications: [Application] = try await apiClient.request(
            path: "/rest/v1/applications",
            queryItems: [
                URLQueryItem(name: "gig_id", value: "eq.\(gigID.bookingRestID)"),
                URLQueryItem(name: "applicant_user_id", value: "eq.\(applicantUserID.bookingRestID)"),
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "limit", value: "1")
            ],
            authToken: try await accessToken()
        )

        return applications.first
    }

    func createApplication(_ application: Application) async throws -> Application {
        let applications: [Application] = try await apiClient.request(
            path: "/rest/v1/applications",
            method: .post,
            body: [application],
            authToken: try await accessToken(),
            additionalHeaders: ["Prefer": "return=representation"]
        )

        guard let savedApplication = applications.first else {
            throw APIError.emptyResponse
        }

        return savedApplication
    }

    func updateApplicationStatus(applicationID: UUID, status: ApplicationStatus) async throws -> Application {
        let applications: [Application] = try await apiClient.request(
            path: "/rest/v1/applications",
            queryItems: [
                URLQueryItem(name: "id", value: "eq.\(applicationID.bookingRestID)"),
                URLQueryItem(name: "select", value: "*")
            ],
            method: .patch,
            body: BookingStatusUpdateRequest(status: status, updatedAt: Date()),
            authToken: try await accessToken(),
            additionalHeaders: ["Prefer": "return=representation"]
        )

        guard let updatedApplication = applications.first else {
            throw APIError.emptyResponse
        }

        return updatedApplication
    }

    func deleteApplication(applicationID: UUID) async throws {
        let _: EmptyResponse = try await apiClient.request(
            path: "/rest/v1/applications",
            queryItems: [
                URLQueryItem(name: "id", value: "eq.\(applicationID.bookingRestID)")
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

private struct BookingStatusUpdateRequest: Encodable {
    let status: ApplicationStatus
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case status
        case updatedAt = "updated_at"
    }
}

private extension UUID {
    var bookingRestID: String {
        uuidString.lowercased()
    }
}
