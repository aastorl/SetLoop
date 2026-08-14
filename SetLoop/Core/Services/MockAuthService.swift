import Foundation

@MainActor
final class MockAuthService: AuthServicing {
    private let accountsKey = "setloop.mock.accounts"
    private let currentUserIDKey = "setloop.mock.current_user_id"
    private let userDefaults: UserDefaults
    private var accounts: [MockAccount]
    private var currentUserID: UUID?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.accounts = Self.loadPersistedAccounts(from: userDefaults)
        self.currentUserID = Self.loadPersistedCurrentUserID(from: userDefaults, key: currentUserIDKey)
    }

    func restoreSession() async throws -> UserProfile? {
        guard let currentUserID else {
            return nil
        }

        return accounts
            .first { $0.profile.id == currentUserID }?
            .profile
    }

    func signUp(email: String, password: String, displayName: String, city: String, role: UserRole) async throws -> UserProfile {
        let normalizedEmail = normalize(email)

        guard accounts.contains(where: { normalize($0.profile.email) == normalizedEmail }) == false else {
            throw MockAuthError.emailAlreadyRegistered
        }

        let profile = UserProfile(
            id: mockProfileID(for: role, existingAccounts: accounts),
            email: email,
            displayName: displayName,
            role: role,
            city: city,
            bio: nil,
            genres: [],
            instruments: [],
            isPremium: false
        )

        accounts.append(MockAccount(profile: profile, password: password))
        try persist(accounts: accounts, currentUserID: profile.id)
        return profile
    }

    func signIn(email: String, password: String) async throws -> UserProfile {
        let normalizedEmail = normalize(email)

        if let existingAccount = accounts.first(where: { normalize($0.profile.email) == normalizedEmail }) {
            guard existingAccount.password == password else {
                throw MockAuthError.invalidCredentials
            }

            persistCurrentUserID(existingAccount.profile.id)
            return existingAccount.profile
        }

        let profile = demoProfile(for: email)

        if let seededAccount = accounts.first(where: { $0.profile.id == profile.id }) {
            persistCurrentUserID(seededAccount.profile.id)
            return seededAccount.profile
        }

        accounts.append(MockAccount(profile: profile, password: password.isEmpty ? "demo1234" : password))

        try persist(accounts: accounts, currentUserID: profile.id)
        return profile
    }

    func requestPasswordReset(email: String) async throws {
        let normalizedEmail = normalize(email)
        guard accounts.contains(where: { normalize($0.profile.email) == normalizedEmail }) else {
            return
        }
    }

    func updatePassword(accessToken: String, newPassword: String) async throws {
        guard let currentUserID,
              let accountIndex = accounts.firstIndex(where: { $0.profile.id == currentUserID }) else {
            throw MockAuthError.profileMissing
        }

        accounts[accountIndex] = MockAccount(
            profile: accounts[accountIndex].profile,
            password: newPassword
        )
        try persist(accounts: accounts, currentUserID: currentUserID)
    }

    func signOut() async throws {
        currentUserID = nil
        userDefaults.removeObject(forKey: currentUserIDKey)
    }

    func updateProfile(_ profile: UserProfile) async throws -> UserProfile {
        let normalizedEmail = normalize(profile.email)

        var resolvedIndex: Int?

        for (index, account) in accounts.enumerated() where account.profile.id == profile.id {
            resolvedIndex = index
            break
        }

        if resolvedIndex == nil, let currentUserID {
            for (index, account) in accounts.enumerated() where account.profile.id == currentUserID {
                resolvedIndex = index
                break
            }
        }

        if resolvedIndex == nil {
            for (index, account) in accounts.enumerated() where normalize(account.profile.email) == normalizedEmail {
                resolvedIndex = index
                break
            }
        }

        guard let resolvedIndex else {
            throw MockAuthError.profileMissing
        }

        let existingPassword = accounts[resolvedIndex].password
        accounts[resolvedIndex] = MockAccount(profile: profile, password: existingPassword)
        try persist(accounts: accounts, currentUserID: profile.id)
        return profile
    }

    private func persist(accounts: [MockAccount], currentUserID: UUID) throws {
        self.accounts = accounts
        let encoder = Self.makeEncoder()
        let data = try encoder.encode(accounts)
        userDefaults.set(data, forKey: accountsKey)
        persistCurrentUserID(currentUserID)
    }

    private func persistCurrentUserID(_ userID: UUID) {
        currentUserID = userID
        userDefaults.set(userID.uuidString, forKey: currentUserIDKey)
    }

    private func normalize(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func mockProfileID(for role: UserRole, existingAccounts: [MockAccount]) -> UUID {
        if role == .venue && existingAccounts.contains(where: { $0.profile.id == MockExploreData.venueHostID }) == false {
            return MockExploreData.venueHostID
        }

        return UUID()
    }

    private func demoProfile(for email: String) -> UserProfile {
        let normalizedEmail = normalize(email)

        if normalizedEmail.contains("venue") || normalizedEmail.contains("local") {
            return UserProfile(
                id: MockExploreData.venueHostID,
                email: email,
                displayName: "Sala Norte Booking",
                role: .venue,
                city: "Madrid",
                venueAddress: "Calle Fuencarral 88",
                bio: "Equipo de booking demo para validar el flujo de candidaturas.",
                genres: ["Indie", "Pop"],
                instruments: ["House", "Disco"],
                venueCapacity: 220,
                isPremium: true
            )
        }

        if normalizedEmail.contains("dj") {
            return UserProfile(
                id: UUID(uuidString: "EE8D95C9-0D0D-45C7-9F33-08281C68FA26")!,
                email: email,
                displayName: "Marcos Vidal DJ Set",
                role: .dj,
                city: "Barcelona",
                bio: "Perfil demo para validar fechas abiertas a DJs.",
                genres: [],
                instruments: ["Open Format", "CDJ", "Controller"],
                isPremium: false
            )
        }

        return UserProfile(
            id: UUID(uuidString: "3F0E4E63-23D1-4076-A5AE-E6E1237FD6AC")!,
            email: email,
            displayName: "Demo SetLoop",
            role: .musician,
            city: "Madrid",
            bio: "Perfil local para probar la app sin Supabase.",
            genres: ["Indie", "Rock"],
            instruments: ["Voz", "Guitarra"],
            isPremium: true
        )
    }

    private static func loadPersistedAccounts(from userDefaults: UserDefaults) -> [MockAccount] {
        let decoder = makeDecoder()
        guard let data = userDefaults.data(forKey: "setloop.mock.accounts"),
              let accounts = try? decoder.decode([MockAccount].self, from: data) else {
            return []
        }

        return accounts
    }

    private static func loadPersistedCurrentUserID(from userDefaults: UserDefaults, key: String) -> UUID? {
        guard let rawValue = userDefaults.string(forKey: key) else {
            return nil
        }

        return UUID(uuidString: rawValue)
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var container = encoder.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            let formatterWithFractionalSeconds = ISO8601DateFormatter()
            formatterWithFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatterWithFractionalSeconds.date(from: value) {
                return date
            }

            let formatterWithoutFractionalSeconds = ISO8601DateFormatter()
            formatterWithoutFractionalSeconds.formatOptions = [.withInternetDateTime]
            if let date = formatterWithoutFractionalSeconds.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Formato de fecha no soportado: \(value)"
            )
        }

        return decoder
    }
}

private struct MockAccount: Codable {
    let profile: UserProfile
    let password: String
}

private enum MockAuthError: LocalizedError {
    case emailAlreadyRegistered
    case invalidCredentials
    case profileMissing

    var errorDescription: String? {
        switch self {
        case .emailAlreadyRegistered:
            return "Ya existe una cuenta demo con ese email."
        case .invalidCredentials:
            return "Email o password incorrectos."
        case .profileMissing:
            return "No se encontro el perfil demo para guardar cambios."
        }
    }
}
