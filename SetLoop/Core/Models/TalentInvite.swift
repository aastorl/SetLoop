import Foundation

struct TalentInvite: Identifiable, Codable, Equatable {
    let id: UUID
    var gigID: UUID
    var hostUserID: UUID // Local o promotora que envian la invitacion.
    var hostDisplayName: String // Snapshot para inbox y avisos mock.
    var talentUserID: UUID // Musico o DJ invitado a una fecha concreta.
    var talentDisplayName: String // Evita lookups externos al renderizar.
    var talentRole: UserRole
    var talentCity: String
    var message: String
    var status: ApplicationStatus
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case gigID = "gig_id"
        case hostUserID = "host_user_id"
        case hostDisplayName = "host_display_name"
        case talentUserID = "talent_user_id"
        case talentDisplayName = "talent_display_name"
        case talentRole = "talent_role"
        case talentCity = "talent_city"
        case message
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
