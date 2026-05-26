import Foundation

struct Review: Identifiable, Codable, Equatable {
    let id: UUID
    var reviewerID: UUID
    var revieweeID: UUID
    var gigID: UUID? // Nulo cuando la review viene de una relacion fuera de una fecha publicada.
    var rating: Int
    var comment: String
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case reviewerID = "reviewer_id"
        case revieweeID = "reviewee_id"
        case gigID = "gig_id"
        case rating
        case comment
        case createdAt = "created_at"
    }
}
