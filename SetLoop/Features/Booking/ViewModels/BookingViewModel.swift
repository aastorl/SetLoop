import Foundation
import Combine

@MainActor
final class BookingViewModel: ObservableObject {
    @Published private(set) var sections: [BookingSectionItem] = []
    @Published var venueFilter: VenueBookingFilter = .pending {
        didSet {
            reloadItems()
        }
    }

    private let currentProfile: UserProfile
    private let applicationStore: ApplicationStore
    private let inviteStore: InviteStore
    private let gigStore: GigStore
    private var cancellables = Set<AnyCancellable>()

    init(
        applicationStore: ApplicationStore,
        inviteStore: InviteStore,
        currentProfile: UserProfile,
        gigStore: GigStore
    ) {
        self.currentProfile = currentProfile
        self.applicationStore = applicationStore
        self.inviteStore = inviteStore
        self.gigStore = gigStore

        reloadItems()

        applicationStore.$applications
            .sink { [weak self] _ in
                self?.reloadItems()
            }
            .store(in: &cancellables)

        inviteStore.$invites
            .sink { [weak self] _ in
                self?.reloadItems()
            }
            .store(in: &cancellables)

        gigStore.$gigs
            .sink { [weak self] _ in
                self?.reloadItems()
            }
            .store(in: &cancellables)
    }

    var showsVenueFilter: Bool {
        currentProfile.role == .venue
    }

    var emptyStateTitle: String {
        if currentProfile.role == .venue {
            switch venueFilter {
            case .pending:
                return "Sin actividad pendiente"
            case .managed:
                return "Sin actividad gestionada"
            }
        }

        return "Sin actividad de booking"
    }

    var emptyStateDescription: String {
        if currentProfile.role == .venue {
            switch venueFilter {
            case .pending:
                return "Las candidaturas pendientes y tus invitaciones abiertas apareceran aqui."
            case .managed:
                return "Las respuestas aceptadas o rechazadas se guardaran aqui."
            }
        }

        return "Cuando solicites una fecha o recibas una invitacion, aparecera aqui con su estado."
    }

    var hasItems: Bool {
        sections.contains { $0.items.isEmpty == false }
    }

    func accept(_ item: BookingEntryItem) {
        switch item.kind {
        case .receivedApplication:
            guard currentProfile.role == .venue else { return }
            guard let updatedApplication = applicationStore.updateStatus(applicationID: item.id, status: .accepted) else {
                return
            }
            closeGigAfterConfirmation(gigID: updatedApplication.gigID, acceptedApplicationID: updatedApplication.id, acceptedInviteID: nil)
        case .receivedInvite:
            guard currentProfile.role == .musician || currentProfile.role == .dj else { return }
            guard let updatedInvite = inviteStore.updateStatus(inviteID: item.id, status: .accepted) else {
                return
            }
            closeGigAfterConfirmation(gigID: updatedInvite.gigID, acceptedApplicationID: nil, acceptedInviteID: updatedInvite.id)
        case .sentApplication, .sentInvite:
            break
        }
    }

    func reject(_ item: BookingEntryItem) {
        switch item.kind {
        case .receivedApplication:
            guard currentProfile.role == .venue else { return }
            applicationStore.updateStatus(applicationID: item.id, status: .rejected)
        case .receivedInvite:
            guard currentProfile.role == .musician || currentProfile.role == .dj else { return }
            inviteStore.updateStatus(inviteID: item.id, status: .rejected)
        case .sentApplication, .sentInvite:
            break
        }
    }

    private func closeGigAfterConfirmation(
        gigID: UUID,
        acceptedApplicationID: UUID?,
        acceptedInviteID: UUID?
    ) {
        _ = gigStore.updateStatus(gigID: gigID, status: .booked)
        applicationStore.rejectPendingApplications(for: gigID, excluding: acceptedApplicationID)
        inviteStore.rejectPendingInvites(for: gigID, excluding: acceptedInviteID)
    }

    private func reloadItems() {
        if currentProfile.role == .venue {
            let receivedApplications = applicationStore.receivedApplications(for: currentProfile.id)
            let filteredApplications = receivedApplications.filter { application in
                venueFilter.includes(application.status)
            }
            let sentInvites = inviteStore.sentInvites(for: currentProfile.id).filter { invite in
                venueFilter.includes(invite.status)
            }

            sections = [
                makeApplicationSection(
                    id: "venue.applications",
                    title: "Candidaturas recibidas",
                    applications: filteredApplications,
                    kind: .receivedApplication
                ),
                makeInviteSection(
                    id: "venue.invites",
                    title: "Invitaciones enviadas",
                    invites: sentInvites,
                    kind: .sentInvite
                )
            ]
            .filter { $0.items.isEmpty == false }
            return
        }

        sections = [
            makeApplicationSection(
                id: "talent.applications",
                title: "Solicitudes enviadas",
                applications: applicationStore.sentApplications(for: currentProfile.id),
                kind: .sentApplication
            ),
            makeInviteSection(
                id: "talent.invites",
                title: "Invitaciones recibidas",
                invites: inviteStore.receivedInvites(for: currentProfile.id),
                kind: .receivedInvite
            )
        ]
        .filter { $0.items.isEmpty == false }
    }

    private func makeApplicationSection(
        id: String,
        title: String,
        applications: [Application],
        kind: BookingEntryKind
    ) -> BookingSectionItem {
        let items = applications.map { application in
            let gig = gigStore.gig(id: application.gigID)

            return BookingEntryItem(
                id: application.id,
                kind: kind,
                gigTitle: gig?.title ?? "Fecha no disponible",
                venueName: gig?.venueName,
                city: gig?.city ?? "Ciudad por confirmar",
                performanceDate: gig?.performanceDate,
                counterpartDisplayName: kind == .receivedApplication ? application.applicantDisplayName : nil,
                counterpartRole: kind == .receivedApplication ? application.applicantRole : nil,
                counterpartCity: kind == .receivedApplication ? application.applicantCity : nil,
                message: application.message,
                status: application.status,
                createdAt: application.createdAt
            )
        }

        return BookingSectionItem(id: id, title: title, items: items)
    }

    private func makeInviteSection(
        id: String,
        title: String,
        invites: [TalentInvite],
        kind: BookingEntryKind
    ) -> BookingSectionItem {
        let items = invites.map { invite in
            let gig = gigStore.gig(id: invite.gigID)

            return BookingEntryItem(
                id: invite.id,
                kind: kind,
                gigTitle: gig?.title ?? "Fecha no disponible",
                venueName: gig?.venueName ?? invite.hostDisplayName,
                city: gig?.city ?? invite.talentCity,
                performanceDate: gig?.performanceDate,
                counterpartDisplayName: kind == .sentInvite ? invite.talentDisplayName : invite.hostDisplayName,
                counterpartRole: kind == .sentInvite ? invite.talentRole : .venue,
                counterpartCity: kind == .sentInvite ? invite.talentCity : gig?.city,
                message: invite.message,
                status: invite.status,
                createdAt: invite.createdAt
            )
        }

        return BookingSectionItem(id: id, title: title, items: items)
    }
}

enum VenueBookingFilter: String, CaseIterable, Identifiable {
    case pending
    case managed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pending:
            return "Pendientes"
        case .managed:
            return "Gestionadas"
        }
    }

    func includes(_ status: ApplicationStatus) -> Bool {
        switch self {
        case .pending:
            return status == .pending
        case .managed:
            return status != .pending
        }
    }
}

struct BookingSectionItem: Identifiable, Equatable {
    let id: String
    let title: String
    let items: [BookingEntryItem]
}

enum BookingEntryKind: String, Equatable {
    case sentApplication
    case receivedApplication
    case sentInvite
    case receivedInvite

    var isIncoming: Bool {
        switch self {
        case .receivedApplication, .receivedInvite:
            return true
        case .sentApplication, .sentInvite:
            return false
        }
    }

    var displayName: String {
        switch self {
        case .sentApplication, .receivedApplication:
            return "Solicitud"
        case .sentInvite, .receivedInvite:
            return "Invitacion"
        }
    }
}

struct BookingEntryItem: Identifiable, Equatable {
    let id: UUID
    let kind: BookingEntryKind
    let gigTitle: String
    let venueName: String?
    let city: String
    let performanceDate: Date?
    let counterpartDisplayName: String?
    let counterpartRole: UserRole?
    let counterpartCity: String?
    let message: String
    let status: ApplicationStatus
    let createdAt: Date

    var isIncoming: Bool {
        kind.isIncoming
    }
}
