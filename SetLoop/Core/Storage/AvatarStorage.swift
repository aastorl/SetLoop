import Foundation

protocol AvatarStoring {
    func loadImageData(from url: URL?) -> Data?
    func persistImageData(_ data: Data?, for profileID: UUID, existingURL: URL?) async throws -> URL?
}

enum AvatarStorageFactory {
    static func make() -> AvatarStoring {
        SupabaseConfig.live.isConfigured ? SupabaseAvatarStorage() : LocalAvatarStorage()
    }
}

struct LocalAvatarStorage: AvatarStoring {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func loadImageData(from url: URL?) -> Data? {
        guard let url else {
            return nil
        }

        guard url.isFileURL else {
            return nil
        }

        return try? Data(contentsOf: url)
    }

    func persistImageData(_ data: Data?, for profileID: UUID, existingURL: URL?) async throws -> URL? {
        guard let data else {
            return existingURL
        }

        let directoryURL = try avatarsDirectoryURL()
        let fileURL = directoryURL.appendingPathComponent("\(profileID.uuidString.lowercased()).jpg")

        try data.write(to: fileURL, options: [.atomic])
        return fileURL
    }

    private func avatarsDirectoryURL() throws -> URL {
        let baseURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let directoryURL = baseURL.appendingPathComponent("SetLoop/Avatars", isDirectory: true)

        if fileManager.fileExists(atPath: directoryURL.path) == false {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        return directoryURL
    }
}

struct SupabaseAvatarStorage: AvatarStoring {
    private let bucketName = "avatars"
    private let client: SupabaseStorageClient
    private let sessionStore: SessionStoring

    init(
        client: SupabaseStorageClient = SupabaseStorageClient(),
        sessionStore: SessionStoring = KeychainSessionStore()
    ) {
        self.client = client
        self.sessionStore = sessionStore
    }

    func loadImageData(from url: URL?) -> Data? {
        nil
    }

    func persistImageData(_ data: Data?, for profileID: UUID, existingURL: URL?) async throws -> URL? {
        guard let data else {
            return existingURL
        }

        guard let session = try sessionStore.load() else {
            throw AvatarStorageError.missingSession
        }

        let image = AvatarImagePayload(data: data)
        let objectPath = [
            "profiles",
            profileID.uuidString.lowercased(),
            "\(UUID().uuidString.lowercased()).\(image.fileExtension)"
        ].joined(separator: "/")

        try await client.upload(
            data: data,
            bucketName: bucketName,
            objectPath: objectPath,
            contentType: image.contentType,
            accessToken: session.accessToken
        )

        return try client.publicURL(bucketName: bucketName, objectPath: objectPath)
    }
}

struct SupabaseStorageClient {
    private let config: SupabaseConfig
    private let session: URLSession

    init(config: SupabaseConfig = .live, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    func upload(
        data: Data,
        bucketName: String,
        objectPath: String,
        contentType: String,
        accessToken: String
    ) async throws {
        guard config.isConfigured else {
            throw APIError.missingSupabaseConfiguration
        }

        var request = URLRequest(url: try storageURL(path: "/storage/v1/object/\(bucketName)/\(objectPath)"))
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        let (responseData, response) = try await session.upload(for: request, from: data)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.emptyResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: responseData, encoding: .utf8)
                ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw APIError.requestFailed(statusCode: httpResponse.statusCode, message: message)
        }
    }

    func publicURL(bucketName: String, objectPath: String) throws -> URL {
        try storageURL(path: "/storage/v1/object/public/\(bucketName)/\(objectPath)")
    }

    private func storageURL(path: String) throws -> URL {
        guard var components = URLComponents(url: config.projectURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }

        components.path = path

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        return url
    }
}

private struct AvatarImagePayload {
    let contentType: String
    let fileExtension: String

    init(data: Data) {
        if data.starts(with: [0xFF, 0xD8, 0xFF]) {
            contentType = "image/jpeg"
            fileExtension = "jpg"
        } else if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            contentType = "image/png"
            fileExtension = "png"
        } else if data.starts(with: [0x47, 0x49, 0x46, 0x38]) {
            contentType = "image/gif"
            fileExtension = "gif"
        } else if Self.hasWebPHeader(data) {
            contentType = "image/webp"
            fileExtension = "webp"
        } else if Self.hasISOBrand("heic", in: data) || Self.hasISOBrand("heix", in: data) || Self.hasISOBrand("hevc", in: data) || Self.hasISOBrand("hevx", in: data) {
            contentType = "image/heic"
            fileExtension = "heic"
        } else if Self.hasISOBrand("mif1", in: data) || Self.hasISOBrand("msf1", in: data) {
            contentType = "image/heif"
            fileExtension = "heif"
        } else {
            contentType = "image/jpeg"
            fileExtension = "jpg"
        }
    }

    private static func hasWebPHeader(_ data: Data) -> Bool {
        let header = Data(data.prefix(12))
        return header.starts(with: [0x52, 0x49, 0x46, 0x46]) && header.dropFirst(8).starts(with: [0x57, 0x45, 0x42, 0x50])
    }

    private static func hasISOBrand(_ brand: String, in data: Data) -> Bool {
        guard data.count >= 12 else {
            return false
        }

        let header = Data(data.prefix(32))
        return header.range(of: Data(brand.utf8)) != nil
    }
}

private enum AvatarStorageError: LocalizedError {
    case missingSession

    var errorDescription: String? {
        switch self {
        case .missingSession:
            return "Inicia sesion de nuevo para subir tu avatar."
        }
    }
}
