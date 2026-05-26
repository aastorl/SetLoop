import Foundation
import Combine

@MainActor
final class GigDetailViewModel: ObservableObject {
    let gig: Gig
    let venue: Venue?

    @Published private(set) var application: Application?

    private let currentProfile: UserProfile
    private let applicationStore: ApplicationStore

    init(
        gig: Gig,
        currentProfile: UserProfile,
        applicationStore: ApplicationStore,
        detailService: ExploreDetailServicing
    ) {
        self.gig = gig
        self.currentProfile = currentProfile
        self.applicationStore = applicationStore

        if let venueID = gig.venueID {
            self.venue = detailService.venue(id: venueID)
        } else {
            self.venue = nil
        }

        self.application = applicationStore.application(for: gig.id, applicantUserID: currentProfile.id)
    }

    var canRequestContact: Bool {
        gig.status == .open && application == nil
    }

    var venueDisplayName: String {
        venue?.name ?? gig.venueName ?? "Local por confirmar"
    }

    var budgetText: String {
        switch (gig.budgetMin, gig.budgetMax) {
        case (.some(let min), .some(let max)):
            return "\(min)-\(max) \(gig.currency)"
        case (.some(let min), nil):
            return "Desde \(min) \(gig.currency)"
        case (nil, .some(let max)):
            return "Hasta \(max) \(gig.currency)"
        case (nil, nil):
            return "Presupuesto por acordar"
        }
    }

    var durationText: String {
        guard let durationMinutes = gig.durationMinutes else {
            return "Duracion por confirmar"
        }

        return "\(durationMinutes) min"
    }

    var statusText: String {
        switch gig.status {
        case .open:
            return "Abierta"
        case .booked:
            return "Cerrada"
        case .cancelled:
            return "Cancelada"
        }
    }

    func requestContact(message: String) {
        application = applicationStore.createApplication(
            gigID: gig.id,
            applicantProfile: currentProfile,
            message: message
        )
    }
}

@MainActor
final class VenueDetailViewModel: ObservableObject {
    let venue: Venue
    let reviews: [Review]
    let reviewSummary: ReviewSummary

    init(venue: Venue, reviewStore: ReviewStore) {
        self.venue = venue
        self.reviews = reviewStore.reviews(for: venue.ownerID)
        self.reviewSummary = reviewStore.summary(for: venue.ownerID)
    }

    var capacityText: String {
        venue.capacity.map { "\($0) personas" } ?? "Aforo por confirmar"
    }

    var verificationText: String {
        venue.isVerified ? "Local verificado" : "Pendiente de verificacion"
    }
}

@MainActor
final class MusicianDetailViewModel: ObservableObject {
    let musician: UserProfile
    let reviews: [Review]
    let reviewSummary: ReviewSummary
    @Published private(set) var sentInvites: [TalentInvite] = []

    private let currentProfile: UserProfile?
    private let gigStore: GigStore?
    private let inviteStore: InviteStore?
    private var cancellables = Set<AnyCancellable>()

    init(
        musician: UserProfile,
        reviewStore: ReviewStore,
        currentProfile: UserProfile? = nil,
        gigStore: GigStore? = nil,
        inviteStore: InviteStore? = nil
    ) {
        self.musician = musician
        self.reviews = reviewStore.reviews(for: musician.id)
        self.reviewSummary = reviewStore.summary(for: musician.id)
        self.currentProfile = currentProfile
        self.gigStore = gigStore
        self.inviteStore = inviteStore

        reloadInvites()

        inviteStore?.$invites
            .sink { [weak self] _ in
                self?.reloadInvites()
            }
            .store(in: &cancellables)
    }

    var profileTypeText: String {
        musician.role.displayName
    }

    var premiumText: String {
        musician.isPremium ? "Perfil premium" : "Perfil estandar"
    }

    var detailsLabel: String {
        musician.role == .dj ? "Formato / Setup" : "Instrumentos"
    }

    var formationsText: String {
        let formations = musician.musicianFormations
        return formations.isEmpty ? "Por confirmar" : formations.joined(separator: " · ")
    }

    var detailsText: String {
        let items = musician.formattedInstrumentItems
        return items.isEmpty ? "Por confirmar" : items.joined(separator: " · ")
    }

    var tags: [String] {
        musician.exploreTags
    }

    var shouldShowInviteSection: Bool {
        currentProfile?.role == .venue
    }

    var canInviteTalent: Bool {
        shouldShowInviteSection && availableGigs.isEmpty == false
    }

    var inviteHelperText: String {
        if sentInvites.isEmpty == false && availableGigs.isEmpty {
            return "Ya has invitado este perfil a todas tus fechas abiertas compatibles."
        }

        if canInviteTalent {
            return "Invita este perfil a una fecha abierta de tu local."
        }

        let targetLabel = musician.role == .dj ? "DJs" : "musicos"
        return "Publica una fecha abierta para \(targetLabel) antes de invitar este perfil."
    }

    var inviteButtonTitle: String {
        sentInvites.isEmpty ? "Invitar a una fecha" : "Invitar a otra fecha"
    }

    var availableGigs: [Gig] {
        guard let currentProfile,
              currentProfile.role == .venue,
              let gigStore else {
            return []
        }

        let alreadyInvitedGigIDs = Set(sentInvites.map(\.gigID))

        return gigStore.gigs(for: currentProfile.id)
            .filter { $0.status == .open && $0.roleNeeded == musician.role }
            .filter { alreadyInvitedGigIDs.contains($0.id) == false }
    }

    var inviteSummaries: [TalentInviteSummary] {
        sentInvites.map { invite in
            TalentInviteSummary(
                id: invite.id,
                gigTitle: gigStore?.gig(id: invite.gigID)?.title ?? "Fecha no disponible",
                status: invite.status
            )
        }
    }

    func defaultInviteMessage(for gig: Gig?) -> String {
        let performance = gig?.performanceDate.formatted(date: .abbreviated, time: .omitted) ?? "esta fecha"
        return "Hola, nos interesa contar contigo para \(performance). Si te encaja, compartimos briefing y timing."
    }

    func sendInvite(gigID: UUID, message: String) {
        guard let currentProfile,
              currentProfile.role == .venue,
              let inviteStore else {
            return
        }

        _ = inviteStore.createInvite(
            gigID: gigID,
            hostProfile: currentProfile,
            talentProfile: musician,
            message: message
        )
    }

    private func reloadInvites() {
        guard let currentProfile,
              currentProfile.role == .venue,
              let inviteStore else {
            sentInvites = []
            return
        }

        sentInvites = inviteStore
            .sentInvites(for: currentProfile.id)
            .filter { $0.talentUserID == musician.id }
    }
}

struct TalentInviteSummary: Identifiable, Equatable {
    let id: UUID
    let gigTitle: String
    let status: ApplicationStatus
}
