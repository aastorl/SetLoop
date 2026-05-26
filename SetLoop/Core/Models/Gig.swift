import Foundation

enum GigStatus: String, Codable, CaseIterable, Identifiable {
    case open
    case booked
    case cancelled

    var id: String { rawValue }
}

struct Gig: Identifiable, Codable, Equatable {
    let id: UUID
    var venueID: UUID?
    var hostUserID: UUID // Usuario que publica y gestiona la fecha.
    var title: String
    var venueName: String?
    var city: String
    var performanceDate: Date
    var durationMinutes: Int?
    var budgetMin: Int?
    var budgetMax: Int?
    var currency: String
    var roleNeeded: UserRole // Tipo de perfil que encaja con la fecha.
    var requiredGenres: [String]
    var description: String?
    var status: GigStatus
    var imageURL: URL?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case venueID = "venue_id"
        case hostUserID = "host_user_id"
        case title
        case venueName = "venue_name"
        case city
        case performanceDate = "performance_date"
        case durationMinutes = "duration_minutes"
        case budgetMin = "budget_min"
        case budgetMax = "budget_max"
        case currency
        case roleNeeded = "role_needed"
        case requiredGenres = "required_genres"
        case description
        case status
        case imageURL = "image_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
