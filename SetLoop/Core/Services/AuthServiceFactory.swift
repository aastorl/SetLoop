import Foundation

enum AuthMode {
    case supabase
    case mock

    var displayText: String {
        switch self {
        case .supabase:
            return "Supabase"
        case .mock:
            return "Modo demo local"
        }
    }
}

enum AuthServiceFactory {
    static var currentMode: AuthMode {
        .supabase
    }

    static func make() -> AuthServicing {
        AuthService()
    }
}
