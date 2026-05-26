import Foundation
import Security

protocol SessionStoring {
    func save(_ session: AuthSession) throws
    func load() throws -> AuthSession?
    func clear() throws
}

final class KeychainSessionStore: SessionStoring {
    private let service = "com.setloop.supabase.auth"
    private let account = "current_session"
    private let encoder = JSONEncoder.supabase
    private let decoder = JSONDecoder.supabase

    func save(_ session: AuthSession) throws {
        let data = try encoder.encode(session)
        try clear()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw APIError.keychain(status)
        }
    }

    func load() throws -> AuthSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw APIError.keychain(status)
        }

        guard let data = item as? Data else {
            return nil
        }

        return try decoder.decode(AuthSession.self, from: data)
    }

    func clear() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw APIError.keychain(status)
        }
    }
}
