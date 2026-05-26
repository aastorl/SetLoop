import Foundation

protocol AuthServicing {
    func restoreSession() async throws -> UserProfile?
    func signUp(email: String, password: String, displayName: String, city: String, role: UserRole) async throws -> UserProfile
    func signIn(email: String, password: String) async throws -> UserProfile
    func updateProfile(_ profile: UserProfile) async throws -> UserProfile
    func signOut() async throws
}

final class AuthService: AuthServicing {
    private let apiClient: SupabaseAPIClient
    private let sessionStore: SessionStoring

    init(
        apiClient: SupabaseAPIClient = SupabaseAPIClient(),
        sessionStore: SessionStoring = KeychainSessionStore()
    ) {
        self.apiClient = apiClient
        self.sessionStore = sessionStore
    }

    func restoreSession() async throws -> UserProfile? {
        guard let savedSession = try sessionStore.load() else {
            return nil
        }

        let session = savedSession.needsRefresh ? try await refreshSession(savedSession) : savedSession
        return try await fetchOrCreateProfile(session: session)
    }

    func signUp(email: String, password: String, displayName: String, city: String, role: UserRole) async throws -> UserProfile {
        let request = SignUpRequest(
            email: email,
            password: password,
            data: [
                "display_name": displayName,
                "city": city,
                "role": role.rawValue
            ]
        )

        let response: SupabaseAuthResponse = try await apiClient.request(
            path: "/auth/v1/signup",
            method: .post,
            body: request
        )

        guard let session = response.makeSession(fallbackEmail: email) else {
            throw AuthServiceError.emailConfirmationRequired
        }

        try sessionStore.save(session)

        let profile = UserProfile(
            id: session.userID,
            email: email,
            displayName: displayName,
            role: role,
            city: city
        )

        return try await upsertProfile(profile, accessToken: session.accessToken)
    }

    func signIn(email: String, password: String) async throws -> UserProfile {
        let request = SignInRequest(email: email, password: password)
        let response: SupabaseAuthResponse = try await apiClient.request(
            path: "/auth/v1/token",
            queryItems: [URLQueryItem(name: "grant_type", value: "password")],
            method: .post,
            body: request
        )

        guard let session = response.makeSession(fallbackEmail: email) else {
            throw AuthServiceError.missingSession
        }

        try sessionStore.save(session)
        return try await fetchOrCreateProfile(session: session, authUser: response.user)
    }

    func signOut() async throws {
        let session = try sessionStore.load()

        if let accessToken = session?.accessToken {
            let _: EmptyResponse = try await apiClient.request(
                path: "/auth/v1/logout",
                method: .post,
                authToken: accessToken
            )
        }

        try sessionStore.clear()
    }

    func updateProfile(_ profile: UserProfile) async throws -> UserProfile {
        guard let session = try sessionStore.load() else {
            throw AuthServiceError.missingSession
        }

        guard profile.id == session.userID else {
            throw AuthServiceError.profileSessionMismatch
        }

        var profileToSave = profile
        profileToSave.email = session.email
        profileToSave.updatedAt = Date()

        return try await upsertProfile(profileToSave, accessToken: session.accessToken)
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

    private func fetchOrCreateProfile(session: AuthSession, authUser: SupabaseAuthUser? = nil) async throws -> UserProfile {
        do {
            return try await fetchProfile(userID: session.userID, accessToken: session.accessToken)
        } catch AuthServiceError.profileMissing {
            let resolvedUser: SupabaseAuthUser
            if let authUser {
                resolvedUser = authUser
            } else {
                resolvedUser = try await fetchAuthUser(accessToken: session.accessToken)
            }

            let profile = resolvedUser.makeProfile(fallbackEmail: session.email)
            return try await upsertProfile(profile, accessToken: session.accessToken)
        }
    }

    private func fetchAuthUser(accessToken: String) async throws -> SupabaseAuthUser {
        try await apiClient.request(
            path: "/auth/v1/user",
            authToken: accessToken
        )
    }

    private func fetchProfile(userID: UUID, accessToken: String) async throws -> UserProfile {
        let profiles: [UserProfile] = try await apiClient.request(
            path: "/rest/v1/profiles",
            queryItems: [
                URLQueryItem(name: "id", value: "eq.\(userID.uuidString.lowercased())"),
                URLQueryItem(name: "select", value: "*")
            ],
            authToken: accessToken
        )

        guard let profile = profiles.first else {
            throw AuthServiceError.profileMissing
        }

        return profile
    }

    private func upsertProfile(_ profile: UserProfile, accessToken: String) async throws -> UserProfile {
        let profiles: [UserProfile] = try await apiClient.request(
            path: "/rest/v1/profiles",
            queryItems: [URLQueryItem(name: "on_conflict", value: "id")],
            method: .post,
            body: [profile],
            authToken: accessToken,
            additionalHeaders: ["Prefer": "resolution=merge-duplicates,return=representation"]
        )

        guard let savedProfile = profiles.first else {
            throw AuthServiceError.profileMissing
        }

        return savedProfile
    }
}
