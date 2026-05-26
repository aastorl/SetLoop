import Foundation

struct EmptyResponse: Decodable {}

final class SupabaseAPIClient {
    private let config: SupabaseConfig
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        config: SupabaseConfig = .live,
        session: URLSession = .shared,
        decoder: JSONDecoder = .supabase,
        encoder: JSONEncoder = .supabase
    ) {
        self.config = config
        self.session = session
        self.decoder = decoder
        self.encoder = encoder
    }

    func request<Response: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = [],
        method: HTTPMethod = .get,
        authToken: String? = nil,
        additionalHeaders: [String: String] = [:]
    ) async throws -> Response {
        var request = try makeRequest(
            path: path,
            queryItems: queryItems,
            method: method,
            authToken: authToken,
            additionalHeaders: additionalHeaders
        )
        request.httpBody = nil
        return try await perform(request)
    }

    func request<Body: Encodable, Response: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = [],
        method: HTTPMethod,
        body: Body,
        authToken: String? = nil,
        additionalHeaders: [String: String] = [:]
    ) async throws -> Response {
        var request = try makeRequest(
            path: path,
            queryItems: queryItems,
            method: method,
            authToken: authToken,
            additionalHeaders: additionalHeaders
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try await perform(request)
    }

    private func makeRequest(
        path: String,
        queryItems: [URLQueryItem],
        method: HTTPMethod,
        authToken: String?,
        additionalHeaders: [String: String]
    ) throws -> URLRequest {
        guard config.isConfigured else {
            throw APIError.missingSupabaseConfiguration
        }

        guard var components = URLComponents(url: config.projectURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }

        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        additionalHeaders.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        return request
    }

    private func perform<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.emptyResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw APIError.requestFailed(statusCode: httpResponse.statusCode, message: message)
        }

        if Response.self == EmptyResponse.self, data.isEmpty {
            return EmptyResponse() as! Response
        }

        guard !data.isEmpty else {
            throw APIError.emptyResponse
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decodingFailed(error)
        }
    }
}
