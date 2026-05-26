import Foundation

enum APIError: LocalizedError {
    case missingSupabaseConfiguration
    case invalidURL
    case emptyResponse
    case decodingFailed(Error)
    case requestFailed(statusCode: Int, message: String)
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .missingSupabaseConfiguration:
            return "Configura SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY en Info.plist antes de conectar con Supabase."
        case .invalidURL:
            return "La URL de Supabase no es valida."
        case .emptyResponse:
            return "El servidor devolvio una respuesta vacia."
        case .decodingFailed(let error):
            return "No se pudo leer la respuesta del servidor: \(error.localizedDescription)"
        case .requestFailed(let statusCode, let message):
            return "Error \(statusCode): \(message)"
        case .keychain(let status):
            return "Keychain devolvio el estado \(status)."
        }
    }
}
