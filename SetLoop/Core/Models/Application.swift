import Foundation

enum ApplicationStatus: String, Codable, CaseIterable, Identifiable {
    case pending
    case accepted
    case rejected
    case withdrawn

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pending:
            return "Pendiente"
        case .accepted:
            return "Aceptada"
        case .rejected:
            return "Rechazada"
        case .withdrawn:
            return "Retirada"
        }
    }
}

struct Application: Identifiable, Codable, Equatable {
    let id: UUID
    var gigID: UUID
    var applicantUserID: UUID // Musico, banda o DJ que solicita el contacto.
    var applicantDisplayName: String // Snapshot del perfil para inbox y avisos mock.
    var applicantRole: UserRole // Evita depender de lookups externos en modo demo.
    var applicantCity: String // Mantiene contexto minimo del candidato.
    var message: String
    var status: ApplicationStatus
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case gigID = "gig_id"
        case applicantUserID = "applicant_user_id"
        case applicantDisplayName = "applicant_display_name"
        case applicantRole = "applicant_role"
        case applicantCity = "applicant_city"
        case message
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
