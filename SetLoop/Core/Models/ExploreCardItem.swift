import Foundation

enum ExploreItemKind: String, CaseIterable, Identifiable {
    case gig

    var id: String { rawValue }

    var displayName: String {
        "Fechas"
    }
}

struct ExploreFilters: Equatable {
    var city: String = ""
    var date: Date?
}

struct ExploreCardItem: Identifiable, Equatable {
    let id: UUID
    let kind: ExploreItemKind
    let title: String
    let subtitle: String
    let city: String
    let detail: String
    let date: Date?
    let role: UserRole?
    let priceText: String?
    let tags: [String]
    let imageURL: URL?
    let symbolName: String
}
