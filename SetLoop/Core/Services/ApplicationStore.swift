import Foundation
import Combine

@MainActor
final class ApplicationStore: ObservableObject {
    private let applicationsKey = "setloop.mock.applications"
    private let gigStore: GigStore
    private let notificationStore: NotificationStore
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder.supabase
    private let decoder = JSONDecoder.supabase

    @Published private(set) var applications: [Application] {
        didSet {
            persistApplications()
        }
    }

    init(
        gigStore: GigStore,
        notificationStore: NotificationStore,
        userDefaults: UserDefaults = .standard
    ) {
        let decoder = JSONDecoder.supabase
        self.gigStore = gigStore
        self.notificationStore = notificationStore
        self.userDefaults = userDefaults
        self.applications = Self.loadPersistedApplications(
            from: userDefaults,
            using: decoder
        )
    }

    func createApplication(gigID: UUID, applicantProfile: UserProfile, message: String) -> Application {
        if let existing = application(for: gigID, applicantUserID: applicantProfile.id) {
            return existing
        }

        let now = Date()
        let application = Application(
            id: UUID(),
            gigID: gigID,
            applicantUserID: applicantProfile.id,
            applicantDisplayName: applicantProfile.displayName,
            applicantRole: applicantProfile.role,
            applicantCity: applicantProfile.city,
            message: message.trimmingCharacters(in: .whitespacesAndNewlines),
            status: .pending,
            createdAt: now,
            updatedAt: now
        )

        applications.insert(application, at: 0)
        createReceivedNotification(for: application)
        return application
    }

    func sentApplications(for applicantUserID: UUID) -> [Application] {
        applications
            .filter { $0.applicantUserID == applicantUserID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func receivedApplications(for hostUserID: UUID) -> [Application] {
        applications
            .filter { application in
                gigStore.gig(id: application.gigID)?.hostUserID == hostUserID
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    func updateStatus(applicationID: UUID, status: ApplicationStatus) -> Application? {
        guard let index = applications.firstIndex(where: { $0.id == applicationID }) else {
            return nil
        }

        guard applications[index].status != status else {
            return applications[index]
        }

        var updatedApplications = applications
        updatedApplications[index].status = status
        updatedApplications[index].updatedAt = Date()

        let updatedApplication = updatedApplications[index]
        applications = updatedApplications
        createStatusNotification(for: updatedApplication)
        return updatedApplication
    }

    func rejectPendingApplications(for gigID: UUID, excluding excludedApplicationID: UUID? = nil) {
        let pendingIDs = applications
            .filter { $0.gigID == gigID && $0.status == .pending && $0.id != excludedApplicationID }
            .map(\.id)

        for applicationID in pendingIDs {
            _ = updateStatus(applicationID: applicationID, status: .rejected)
        }
    }

    func application(for gigID: UUID, applicantUserID: UUID) -> Application? {
        applications.first { application in
            application.gigID == gigID && application.applicantUserID == applicantUserID
        }
    }

    private func createReceivedNotification(for application: Application) {
        guard let gig = gigStore.gig(id: application.gigID),
              gig.hostUserID != application.applicantUserID else {
            return
        }

        let venueName = gig.venueName ?? "tu local"
        notificationStore.add(
            userID: gig.hostUserID,
            type: .applicationReceived,
            title: "Nueva candidatura para \(gig.title)",
            body: "\(application.applicantDisplayName) quiere actuar en \(venueName).",
            relatedGigID: gig.id,
            relatedApplicationID: application.id
        )
    }

    private func createStatusNotification(for application: Application) {
        guard let gig = gigStore.gig(id: application.gigID) else {
            return
        }

        let venueName = gig.venueName ?? gig.city

        switch application.status {
        case .accepted:
            notificationStore.add(
                userID: application.applicantUserID,
                type: .applicationAccepted,
                title: "Solicitud aceptada",
                body: "Tu candidatura para \(gig.title) en \(venueName) ha sido aceptada.",
                relatedGigID: gig.id,
                relatedApplicationID: application.id
            )
        case .rejected:
            notificationStore.add(
                userID: application.applicantUserID,
                type: .applicationRejected,
                title: "Solicitud rechazada",
                body: "Tu candidatura para \(gig.title) en \(venueName) no ha seguido adelante.",
                relatedGigID: gig.id,
                relatedApplicationID: application.id
            )
        case .pending, .withdrawn:
            break
        }
    }

    private func persistApplications() {
        guard let data = try? encoder.encode(applications) else {
            return
        }

        userDefaults.set(data, forKey: applicationsKey)
    }

    private static func loadPersistedApplications(
        from userDefaults: UserDefaults,
        using decoder: JSONDecoder
    ) -> [Application] {
        guard let data = userDefaults.data(forKey: "setloop.mock.applications"),
              let applications = try? decoder.decode([Application].self, from: data) else {
            return []
        }

        return applications.sorted { $0.createdAt > $1.createdAt }
    }
}
