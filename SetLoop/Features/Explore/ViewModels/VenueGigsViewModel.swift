import Foundation
import Combine

@MainActor
final class VenueGigsViewModel: ObservableObject {
    @Published private(set) var items: [VenueGigItem] = []
    @Published var editorContext: VenueGigEditorContext?

    private let currentProfile: UserProfile
    private let gigStore: GigStore
    private let venueStore: VenueStore
    private let applicationStore: ApplicationStore
    private var cancellables = Set<AnyCancellable>()

    init(
        currentProfile: UserProfile,
        gigStore: GigStore,
        venueStore: VenueStore,
        applicationStore: ApplicationStore
    ) {
        self.currentProfile = currentProfile
        self.gigStore = gigStore
        self.venueStore = venueStore
        self.applicationStore = applicationStore

        reload()

        gigStore.$gigs
            .sink { [weak self] _ in
                self?.reload()
            }
            .store(in: &cancellables)

        applicationStore.$applications
            .sink { [weak self] _ in
                self?.reload()
            }
            .store(in: &cancellables)
    }

    var emptyStateTitle: String {
        "Todavia no has publicado fechas"
    }

    var emptyStateDescription: String {
        "Crea tu primera gig para empezar a recibir candidaturas de musicos o DJs."
    }

    var openCount: Int {
        items.filter { $0.status == .open }.count
    }

    var pendingApplicationCount: Int {
        items.reduce(0) { $0 + $1.pendingApplications }
    }

    func startCreating() {
        editorContext = VenueGigEditorContext(gig: nil)
    }

    func edit(_ item: VenueGigItem) {
        editorContext = VenueGigEditorContext(gig: item.gig)
    }

    func dismissEditor() {
        editorContext = nil
    }

    func makeEditorViewModel(for gig: Gig?) -> GigEditorViewModel {
        GigEditorViewModel(
            currentProfile: currentProfile,
            gigStore: gigStore,
            venueStore: venueStore,
            gig: gig
        )
    }

    private func reload() {
        let hostGigs = gigStore.gigs(for: currentProfile.id)

        items = hostGigs.map { gig in
            let applications = applicationStore
                .receivedApplications(for: currentProfile.id)
                .filter { $0.gigID == gig.id }

            return VenueGigItem(
                gig: gig,
                totalApplications: applications.count,
                pendingApplications: applications.filter { $0.status == .pending }.count
            )
        }
    }
}

struct VenueGigEditorContext: Identifiable {
    let id = UUID()
    let gig: Gig?
}

struct VenueGigItem: Identifiable, Equatable {
    let gig: Gig
    let totalApplications: Int
    let pendingApplications: Int

    var id: UUID { gig.id }
    var title: String { gig.title }
    var city: String { gig.city }
    var performanceDate: Date { gig.performanceDate }
    var status: GigStatus { gig.status }
    var roleNeeded: UserRole { gig.roleNeeded }
    var venueName: String { gig.venueName ?? "Tu local" }
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
}

@MainActor
final class GigEditorViewModel: ObservableObject {
    @Published var title: String
    @Published var city: String
    @Published var performanceDate: Date
    @Published var durationText: String
    @Published var budgetMinText: String
    @Published var budgetMaxText: String
    @Published var roleNeeded: UserRole
    @Published var selectedGenres: [String]
    @Published var gigDescription: String
    @Published var status: GigStatus
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    private let currentProfile: UserProfile
    private let gigStore: GigStore
    private let venueStore: VenueStore
    private let existingGig: Gig?

    init(
        currentProfile: UserProfile,
        gigStore: GigStore,
        venueStore: VenueStore,
        gig: Gig?
    ) {
        self.currentProfile = currentProfile
        self.gigStore = gigStore
        self.venueStore = venueStore
        self.existingGig = gig
        let associatedVenue = venueStore.venue(for: currentProfile.id)

        self.title = gig?.title ?? ""
        self.city = gig?.city ?? associatedVenue?.city ?? currentProfile.city
        self.performanceDate = gig?.performanceDate ?? Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        self.durationText = gig?.durationMinutes.map(String.init) ?? ""
        self.budgetMinText = gig?.budgetMin.map(String.init) ?? ""
        self.budgetMaxText = gig?.budgetMax.map(String.init) ?? ""
        self.roleNeeded = gig?.roleNeeded ?? .musician
        self.selectedGenres = gig?.requiredGenres ?? []
        self.gigDescription = gig?.description ?? ""
        self.status = gig?.status ?? .open
    }

    var screenTitle: String {
        existingGig == nil ? "Nueva fecha" : "Editar fecha"
    }

    var saveButtonTitle: String {
        existingGig == nil ? "Publicar" : "Guardar"
    }

    var canSave: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && selectedGenres.isEmpty == false
    }

    var availableGenreOptions: [String] {
        let baseOptions: [String]

        switch roleNeeded {
        case .musician:
            baseOptions = currentProfile.venueBandGenres.isEmpty
                ? ProfileOptionCatalog.genreOptions
                : currentProfile.venueBandGenres
        case .dj:
            baseOptions = currentProfile.venueDJGenres.isEmpty
                ? ProfileOptionCatalog.venueDJGenreOptions
                : currentProfile.venueDJGenres
        case .venue:
            baseOptions = []
        }

        return baseOptions + selectedGenres.filter { baseOptions.contains($0) == false }
    }

    func isGenreSelected(_ genre: String) -> Bool {
        selectedGenres.contains(genre)
    }

    func toggleGenre(_ genre: String) {
        if let index = selectedGenres.firstIndex(of: genre) {
            selectedGenres.remove(at: index)
        } else {
            selectedGenres.append(genre)
        }
    }

    func save() async -> Gig? {
        guard canSave else {
            return nil
        }

        let minBudget = Int(budgetMinText.trimmingCharacters(in: .whitespacesAndNewlines))
        let maxBudget = Int(budgetMaxText.trimmingCharacters(in: .whitespacesAndNewlines))

        if let minBudget, let maxBudget, maxBudget < minBudget {
            errorMessage = "El presupuesto maximo no puede ser menor que el minimo."
            return nil
        }

        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        let associatedVenue = venueStore.syncHostedVenue(using: currentProfile)
        let now = Date()

        let gig = Gig(
            id: existingGig?.id ?? UUID(),
            venueID: associatedVenue?.id ?? existingGig?.venueID,
            hostUserID: currentProfile.id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            venueName: associatedVenue?.name ?? currentProfile.displayName,
            city: city.trimmingCharacters(in: .whitespacesAndNewlines),
            performanceDate: performanceDate,
            durationMinutes: Int(durationText.trimmingCharacters(in: .whitespacesAndNewlines)),
            budgetMin: minBudget,
            budgetMax: maxBudget,
            currency: existingGig?.currency ?? "EUR",
            roleNeeded: roleNeeded,
            requiredGenres: selectedGenres,
            description: gigDescription.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            status: status,
            imageURL: existingGig?.imageURL,
            createdAt: existingGig?.createdAt ?? now,
            updatedAt: now
        )

        return gigStore.upsert(gig)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
