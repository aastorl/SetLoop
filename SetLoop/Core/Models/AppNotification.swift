import Foundation

enum AppNotificationType: String, Codable, CaseIterable, Identifiable {
    case applicationReceived = "application_received"
    case applicationAccepted = "application_accepted"
    case applicationRejected = "application_rejected"

    var id: String { rawValue }

    var systemImageName: String {
        switch self {
        case .applicationReceived:
            return "tray.and.arrow.down.fill"
        case .applicationAccepted:
            return "checkmark.circle.fill"
        case .applicationRejected:
            return "xmark.circle.fill"
        }
    }
}

struct AppNotification: Identifiable, Codable, Equatable {
    let id: UUID
    var userID: UUID
    var type: AppNotificationType
    var title: String
    var body: String
    var createdAt: Date
    var isRead: Bool
    var relatedGigID: UUID?
    var relatedApplicationID: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case type
        case title
        case body
        case createdAt = "created_at"
        case isRead = "is_read"
        case relatedGigID = "related_gig_id"
        case relatedApplicationID = "related_application_id"
    }
}
