import Foundation
import Combine

@MainActor
final class GigDetailViewModel: ObservableObject {
    let gig: Gig
    let venue: Venue?

    @Published private(set) var application: Application?
    @Published private(set) var isSubmitting = false
    @Published private(set) var errorMessage: String?

    private let currentProfile: UserProfile
    private let applicationStore: ApplicationStore
    private var cancellables = Set<AnyCancellable>()

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

        applicationStore.$applications
            .sink { [weak self] _ in
                self?.reloadApplication()
            }
            .store(in: &cancellables)
    }

    var canRequestContact: Bool {
        gig.isOpenForApplications() && application == nil && isSubmitting == false
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
        if gig.status == .open && gig.isPast() {
            return "Pasada"
        }

        switch gig.status {
        case .open:
            return "Abierta"
        case .booked:
            return "Cerrada"
        case .cancelled:
            return "Cancelada"
        }
    }

    func requestContact(message: String) async {
        guard canRequestContact else {
            return
        }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            application = try await applicationStore.submitApplication(
                gigID: gig.id,
                applicantProfile: currentProfile,
                message: message
            )
            errorMessage = nil
        } catch {
            errorMessage = error.setLoopUserMessage
        }
    }

    private func reloadApplication() {
        application = applicationStore.application(for: gig.id, applicantUserID: currentProfile.id)
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
