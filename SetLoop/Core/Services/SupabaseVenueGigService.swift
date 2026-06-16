import Foundation

protocol VenueGigRemoteServicing {
    func fetchVenues() async throws -> [Venue]
    func fetchVenue(ownerID: UUID) async throws -> Venue?
    func saveVenue(_ venue: Venue) async throws -> Venue
    func fetchGigs() async throws -> [Gig]
    func fetchGigs(hostUserID: UUID) async throws -> [Gig]
    func saveGig(_ gig: Gig) async throws -> Gig
    func updateGigStatus(gigID: UUID, status: GigStatus) async throws -> Gig
}

final class SupabaseVenueGigService: VenueGigRemoteServicing {
    private let apiClient: SupabaseAPIClient
    private let sessionStore: SessionStoring

    init(
        apiClient: SupabaseAPIClient = SupabaseAPIClient(),
        sessionStore: SessionStoring = KeychainSessionStore()
    ) {
        self.apiClient = apiClient
        self.sessionStore = sessionStore
    }

    func fetchVenues() async throws -> [Venue] {
        try await apiClient.request(
            path: "/rest/v1/venues",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "order", value: "name.asc")
            ],
            authToken: try await accessToken()
        )
    }

    func fetchVenue(ownerID: UUID) async throws -> Venue? {
        let venues: [Venue] = try await apiClient.request(
            path: "/rest/v1/venues",
            queryItems: [
                URLQueryItem(name: "owner_id", value: "eq.\(ownerID.supabaseID)"),
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "limit", value: "1")
            ],
            authToken: try await accessToken()
        )

        return venues.first
    }

    func saveVenue(_ venue: Venue) async throws -> Venue {
        let venues: [Venue] = try await apiClient.request(
            path: "/rest/v1/venues",
            queryItems: [URLQueryItem(name: "on_conflict", value: "owner_id")],
            method: .post,
            body: [venue],
            authToken: try await accessToken(),
            additionalHeaders: ["Prefer": "resolution=merge-duplicates,return=representation"]
        )

        guard let savedVenue = venues.first else {
            throw APIError.emptyResponse
        }

        return savedVenue
    }

    func fetchGigs() async throws -> [Gig] {
        try await apiClient.request(
            path: "/rest/v1/gigs",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "order", value: "performance_date.asc")
            ],
            authToken: try await accessToken()
        )
    }

    func fetchGigs(hostUserID: UUID) async throws -> [Gig] {
        try await apiClient.request(
            path: "/rest/v1/gigs",
            queryItems: [
                URLQueryItem(name: "host_user_id", value: "eq.\(hostUserID.supabaseID)"),
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "order", value: "performance_date.asc")
            ],
            authToken: try await accessToken()
        )
    }

    func saveGig(_ gig: Gig) async throws -> Gig {
        let gigs: [Gig] = try await apiClient.request(
            path: "/rest/v1/gigs",
            queryItems: [URLQueryItem(name: "on_conflict", value: "id")],
            method: .post,
            body: [gig],
            authToken: try await accessToken(),
            additionalHeaders: ["Prefer": "resolution=merge-duplicates,return=representation"]
        )

        guard let savedGig = gigs.first else {
            throw APIError.emptyResponse
        }

        return savedGig
    }

    func updateGigStatus(gigID: UUID, status: GigStatus) async throws -> Gig {
        let gigs: [Gig] = try await apiClient.request(
            path: "/rest/v1/gigs",
            queryItems: [
                URLQueryItem(name: "id", value: "eq.\(gigID.supabaseID)"),
                URLQueryItem(name: "select", value: "*")
            ],
            method: .patch,
            body: GigStatusUpdateRequest(status: status, updatedAt: Date()),
            authToken: try await accessToken(),
            additionalHeaders: ["Prefer": "return=representation"]
        )

        guard let updatedGig = gigs.first else {
            throw APIError.emptyResponse
        }

        return updatedGig
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

private struct GigStatusUpdateRequest: Encodable {
    let status: GigStatus
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case status
        case updatedAt = "updated_at"
    }
}

private extension UUID {
    var supabaseID: String {
        uuidString.lowercased()
    }
}
