import Foundation

struct Venue: Identifiable, Codable, Equatable {
    let id: UUID
    var ownerID: UUID // Perfil que administra el local/promotora.
    var name: String
    var city: String
    var address: String
    var capacity: Int?
    var description: String?
    var genres: [String]
    var imageURL: URL?
    var latitude: Double?
    var longitude: Double?
    var isVerified: Bool // Verificacion editorial/manual para confianza del marketplace.
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case ownerID = "owner_id"
        case name
        case city
        case address
        case capacity
        case description
        case genres
        case imageURL = "image_url"
        case latitude
        case longitude
        case isVerified = "is_verified"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
