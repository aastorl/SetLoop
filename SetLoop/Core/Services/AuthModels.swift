import Foundation

struct AuthSession: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresAt: Date
    let userID: UUID
    let email: String

    var needsRefresh: Bool {
        Date() >= expiresAt.addingTimeInterval(-60)
    }

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresAt = "expires_at"
        case userID = "user_id"
        case email
    }
}

struct SupabaseAuthUser: Decodable {
    let id: UUID
    let email: String?
    let userMetadata: AuthUserMetadata?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case userMetadata = "user_metadata"
    }
}

struct AuthUserMetadata: Decodable, Equatable {
    let displayName: String?
    let city: String?
    let role: UserRole?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case displayNameCamel = "displayName"
        case city
        case role
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        displayName = try container.decodeTrimmedString(forKeys: [.displayName, .displayNameCamel])
        city = try container.decodeTrimmedString(forKeys: [.city])

        if let rawRole = try container.decodeTrimmedString(forKeys: [.role]) {
            role = UserRole(rawValue: rawRole)
        } else {
            role = nil
        }
    }
}

struct SupabaseAuthResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: TimeInterval?
    let expiresAt: TimeInterval?
    let tokenType: String?
    let user: SupabaseAuthUser?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case expiresAt = "expires_at"
        case tokenType = "token_type"
        case user
    }

    func makeSession(fallbackEmail: String? = nil) -> AuthSession? {
        guard
            let accessToken,
            let refreshToken,
            let tokenType,
            let user
        else {
            return nil
        }

        guard let email = user.email ?? fallbackEmail else {
            return nil
        }

        let expirationDate: Date
        if let expiresAt {
            expirationDate = Date(timeIntervalSince1970: expiresAt)
        } else if let expiresIn {
            expirationDate = Date().addingTimeInterval(expiresIn)
        } else {
            expirationDate = Date().addingTimeInterval(3600)
        }

        return AuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenType: tokenType,
            expiresAt: expirationDate,
            userID: user.id,
            email: email
        )
    }
}

struct SignUpRequest: Encodable {
    let email: String
    let password: String
    let data: [String: String]
}

struct SignInRequest: Encodable {
    let email: String
    let password: String
}

struct RefreshTokenRequest: Encodable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

enum AuthServiceError: LocalizedError {
    case emailConfirmationRequired
    case missingSession
    case profileMissing
    case profileSessionMismatch

    var errorDescription: String? {
        switch self {
        case .emailConfirmationRequired:
            return "Cuenta creada. Confirma tu email y despues inicia sesion."
        case .missingSession:
            return "No se recibio una sesion valida desde Supabase."
        case .profileMissing:
            return "No existe perfil asociado a este usuario."
        case .profileSessionMismatch:
            return "El perfil no pertenece a la sesion activa."
        }
    }
}

extension SupabaseAuthUser {
    func makeProfile(
        fallbackEmail: String,
        fallbackDisplayName: String? = nil,
        fallbackCity: String? = nil,
        fallbackRole: UserRole? = nil
    ) -> UserProfile {
        let resolvedEmail = (email ?? fallbackEmail).trimmed
        let resolvedDisplayName = userMetadata?.displayName
            ?? fallbackDisplayName?.trimmedNonEmpty
            ?? resolvedEmail.emailNameFallback
        let resolvedCity = userMetadata?.city
            ?? fallbackCity?.trimmedNonEmpty
            ?? ""

        return UserProfile(
            id: id,
            email: resolvedEmail,
            displayName: resolvedDisplayName,
            role: userMetadata?.role ?? fallbackRole ?? .musician,
            city: resolvedCity
        )
    }
}

private extension KeyedDecodingContainer {
    func decodeTrimmedString(forKeys keys: [Key]) throws -> String? {
        for key in keys {
            if let value = try decodeIfPresent(String.self, forKey: key)?.trimmedNonEmpty {
                return value
            }
        }

        return nil
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedNonEmpty: String? {
        let value = trimmed
        return value.isEmpty ? nil : value
    }

    var emailNameFallback: String {
        let name = split(separator: "@", maxSplits: 1).first.map(String.init) ?? self
        return name.trimmedNonEmpty ?? "SetLoop"
    }
}
