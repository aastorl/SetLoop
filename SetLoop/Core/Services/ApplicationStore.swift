import Foundation
import Combine

@MainActor
final class ApplicationStore: ObservableObject {
    private let applicationsKey = "setloop.mock.applications"
    private let gigStore: GigStore
    private let notificationStore: NotificationStore
    private let userDefaults: UserDefaults
    private let remoteService: BookingRemoteServicing?
    private let encoder = JSONEncoder.supabase
    private let decoder = JSONDecoder.supabase

    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    @Published private(set) var applications: [Application] {
        didSet {
            if remoteService == nil {
                persistApplications()
            }
        }
    }

    init(
        gigStore: GigStore,
        notificationStore: NotificationStore,
        userDefaults: UserDefaults = .standard,
        remoteService: BookingRemoteServicing? = nil
    ) {
        let decoder = JSONDecoder.supabase
        self.gigStore = gigStore
        self.notificationStore = notificationStore
        self.userDefaults = userDefaults
        self.remoteService = remoteService

        if remoteService != nil {
            self.applications = []
        } else {
            self.applications = Self.loadPersistedApplications(
                from: userDefaults,
                using: decoder
            )
        }
    }

    var usesRemoteService: Bool {
        remoteService != nil
    }

    func createApplication(gigID: UUID, applicantProfile: UserProfile, message: String) -> Application {
        if let existing = application(for: gigID, applicantUserID: applicantProfile.id) {
            return existing
        }

        let application = makeApplication(
            gigID: gigID,
            applicantProfile: applicantProfile,
            message: message
        )

        applications.insert(application, at: 0)
        createReceivedNotification(for: application)
        return application
    }

    @discardableResult
    func submitApplication(gigID: UUID, applicantProfile: UserProfile, message: String) async throws -> Application {
        guard let remoteService else {
            return createApplication(gigID: gigID, applicantProfile: applicantProfile, message: message)
        }

        if let existing = application(for: gigID, applicantUserID: applicantProfile.id) {
            return existing
        }

        isLoading = true
        defer { isLoading = false }

        do {
            if let existing = try await remoteService.fetchApplication(
                gigID: gigID,
                applicantUserID: applicantProfile.id
            ) {
                errorMessage = nil
                upsert(existing)
                return existing
            }

            let savedApplication = try await remoteService.createApplication(
                makeApplication(
                    gigID: gigID,
                    applicantProfile: applicantProfile,
                    message: message
                )
            )
            errorMessage = nil
            upsert(savedApplication)
            return savedApplication
        } catch {
            if let existing = try? await remoteService.fetchApplication(
                gigID: gigID,
                applicantUserID: applicantProfile.id
            ) {
                errorMessage = nil
                upsert(existing)
                return existing
            }

            errorMessage = error.setLoopUserMessage
            throw error
        }
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

    func loadAll() async throws {
        guard let remoteService else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            applications = try await remoteService.fetchApplications()
            errorMessage = nil
        } catch {
            errorMessage = error.setLoopUserMessage
            throw error
        }
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

    @discardableResult
    func saveStatus(applicationID: UUID, status: ApplicationStatus) async throws -> Application? {
        guard let remoteService else {
            return updateStatus(applicationID: applicationID, status: status)
        }

        if let existing = applications.first(where: { $0.id == applicationID }),
           existing.status == status {
            return existing
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let updatedApplication = try await remoteService.updateApplicationStatus(
                applicationID: applicationID,
                status: status
            )
            errorMessage = nil
            upsert(updatedApplication)
            return updatedApplication
        } catch {
            errorMessage = error.setLoopUserMessage
            throw error
        }
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

    func delete(applicationID: UUID) {
        applications.removeAll { $0.id == applicationID }
    }

    func saveDelete(applicationID: UUID) async throws {
        guard let remoteService else {
            delete(applicationID: applicationID)
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await remoteService.deleteApplication(applicationID: applicationID)
            delete(applicationID: applicationID)
            errorMessage = nil
        } catch {
            errorMessage = error.setLoopUserMessage
            throw error
        }
    }

    @discardableResult
    private func upsert(_ application: Application) -> Application {
        if let index = applications.firstIndex(where: { $0.id == application.id }) {
            applications[index] = application
        } else {
            applications.append(application)
        }

        applications.sort { $0.createdAt > $1.createdAt }
        return application
    }

    private func makeApplication(
        gigID: UUID,
        applicantProfile: UserProfile,
        message: String
    ) -> Application {
        let now = Date()
        return Application(
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
