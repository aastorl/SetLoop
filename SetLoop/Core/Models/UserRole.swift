import Foundation

enum UserRole: String, Codable, CaseIterable, Identifiable {
    case musician
    case venue
    case dj

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .musician:
            return "Musico"
        case .venue:
            return "Local"
        case .dj:
            return "DJ"
        }
    }

    var shortLabel: String {
        switch self {
        case .musician:
            return "Musico"
        case .venue:
            return "Local"
        case .dj:
            return "DJ"
        }
    }
}
