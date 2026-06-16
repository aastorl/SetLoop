import Foundation
import Combine

@MainActor
final class VenueGigsViewModel: ObservableObject {
    @Published private(set) var items: [VenueGigItem] = []
    @Published var editorContext: VenueGigEditorContext?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var visibleMonth: Date
    @Published var selectedDate: Date

    private let currentProfile: UserProfile
    private let gigStore: GigStore
    private let venueStore: VenueStore
    private let applicationStore: ApplicationStore
    private let calendar: Calendar
    private var cancellables = Set<AnyCancellable>()

    init(
        currentProfile: UserProfile,
        gigStore: GigStore,
        venueStore: VenueStore,
        applicationStore: ApplicationStore,
        calendar: Calendar = .current
    ) {
        self.currentProfile = currentProfile
        self.gigStore = gigStore
        self.venueStore = venueStore
        self.applicationStore = applicationStore
        self.calendar = calendar
        let today = calendar.startOfDay(for: Date())
        self.visibleMonth = today
        self.selectedDate = today

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
        "Crea tu primera fecha para empezar a recibir candidaturas de musicos o DJs."
    }

    var openCount: Int {
        items.filter { $0.status == .open }.count
    }

    var upcomingCount: Int {
        let now = Date()
        return items.filter { $0.performanceDate >= now && $0.status != .cancelled }.count
    }

    var closedOrCancelledCount: Int {
        items.filter { $0.status == .booked || $0.status == .cancelled }.count
    }

    var pendingApplicationCount: Int {
        items.reduce(0) { $0 + $1.pendingApplications }
    }

    var monthTitle: String {
        visibleMonth.formatted(.dateTime.month(.wide).year())
    }

    var selectedDayTitle: String {
        dayTitle(for: selectedDate)
    }

    var monthItems: [VenueGigItem] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: visibleMonth) else {
            return []
        }

        return items.filter { monthInterval.contains($0.performanceDate) }
    }

    var selectedDayItems: [VenueGigItem] {
        items(on: selectedDate)
    }

    func dayTitle(for date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    func items(on date: Date) -> [VenueGigItem] {
        items
            .filter { calendar.isDate($0.performanceDate, inSameDayAs: date) }
            .sorted { $0.performanceDate < $1.performanceDate }
    }

    var calendarWeeks: [VenueGigCalendarWeek] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: visibleMonth) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingDays = (firstWeekday - calendar.firstWeekday + 7) % 7
        let gridStart = calendar.date(byAdding: .day, value: -leadingDays, to: monthInterval.start) ?? monthInterval.start

        return (0..<6).map { weekIndex in
            let weekStart = calendar.date(byAdding: .day, value: weekIndex * 7, to: gridStart) ?? gridStart
            let days = (0..<7).map { dayOffset in
                let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) ?? weekStart
                let dayItems = items.filter { calendar.isDate($0.performanceDate, inSameDayAs: date) }

                return VenueGigCalendarDay(
                    date: date,
                    dayNumber: calendar.component(.day, from: date),
                    isInDisplayedMonth: calendar.isDate(date, equalTo: monthInterval.start, toGranularity: .month),
                    isToday: calendar.isDateInToday(date),
                    isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                    gigsCount: dayItems.count,
                    hasOpenGigs: dayItems.contains { $0.status == .open },
                    hasClosedOrCancelledGigs: dayItems.contains { $0.status == .booked || $0.status == .cancelled }
                )
            }

            return VenueGigCalendarWeek(startDate: weekStart, days: days)
        }
    }

    var pendingReviewItems: [VenueGigItem] {
        items
            .filter { $0.pendingApplications > 0 }
            .sorted { lhs, rhs in
                if lhs.pendingApplications == rhs.pendingApplications {
                    return lhs.performanceDate < rhs.performanceDate
                }

                return lhs.pendingApplications > rhs.pendingApplications
            }
    }

    var activeUpcomingItems: [VenueGigItem] {
        items.filter { $0.status == .open }
    }

    var closedOrCancelledItems: [VenueGigItem] {
        return items
            .filter { $0.status == .booked || $0.status == .cancelled }
            .sorted { $0.performanceDate > $1.performanceDate }
    }

    func startCreating(on date: Date? = nil) {
        editorContext = makeCreateContext(on: date)
    }

    func edit(_ item: VenueGigItem) {
        editorContext = makeEditContext(for: item)
    }

    func dismissEditor() {
        editorContext = nil
    }

    func select(_ day: VenueGigCalendarDay) {
        selectedDate = calendar.startOfDay(for: day.date)
        visibleMonth = day.date
    }

    func makeCreateContext(on date: Date? = nil) -> VenueGigEditorContext {
        VenueGigEditorContext(gig: nil, defaultDate: date)
    }

    func makeEditContext(for item: VenueGigItem) -> VenueGigEditorContext {
        VenueGigEditorContext(gig: item.gig, defaultDate: nil)
    }

    func moveToPreviousMonth() {
        moveVisibleMonth(by: -1)
    }

    func moveToNextMonth() {
        moveVisibleMonth(by: 1)
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var loadErrorMessage: String?

        if currentProfile.role == .venue {
            loadErrorMessage = await performVenueGigLoad {
                _ = try await self.venueStore.saveHostedVenue(using: self.currentProfile)
            } ?? loadErrorMessage
        }

        loadErrorMessage = await performVenueGigLoad {
            try await venueStore.loadAll()
        } ?? loadErrorMessage

        loadErrorMessage = await performVenueGigLoad {
            try await gigStore.loadAll()
        } ?? loadErrorMessage

        loadErrorMessage = await performVenueGigLoad {
            try await applicationStore.loadAll()
        } ?? loadErrorMessage

        errorMessage = loadErrorMessage
        reload()
    }

    func makeEditorViewModel(for context: VenueGigEditorContext) -> GigEditorViewModel {
        GigEditorViewModel(
            currentProfile: currentProfile,
            gigStore: gigStore,
            venueStore: venueStore,
            gig: context.gig,
            defaultDate: context.defaultDate
        )
    }

    private func reload() {
        let hostGigs = gigStore.gigs(for: currentProfile.id)
        let hostApplications = applicationStore.receivedApplications(for: currentProfile.id)

        items = hostGigs.map { gig in
            let applications = hostApplications
                .filter { $0.gigID == gig.id }

            return VenueGigItem(
                gig: gig,
                totalApplications: applications.count,
                pendingApplications: applications.filter { $0.status == .pending }.count
            )
        }
    }

    private func moveVisibleMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: visibleMonth) else {
            return
        }

        visibleMonth = newMonth

        if calendar.isDate(selectedDate, equalTo: newMonth, toGranularity: .month) == false,
           let monthInterval = calendar.dateInterval(of: .month, for: newMonth) {
            selectedDate = monthInterval.start
        }
    }

    private func performVenueGigLoad(_ operation: () async throws -> Void) async -> String? {
        do {
            try await operation()
            return nil
        } catch {
            return error.setLoopUserMessage
        }
    }
}

struct VenueGigEditorContext: Identifiable {
    let id = UUID()
    let gig: Gig?
    let defaultDate: Date?
}

struct VenueGigCalendarWeek: Identifiable, Equatable {
    let startDate: Date
    let days: [VenueGigCalendarDay]

    var id: Date { startDate }
}

struct VenueGigCalendarDay: Identifiable, Equatable {
    let date: Date
    let dayNumber: Int
    let isInDisplayedMonth: Bool
    let isToday: Bool
    let isSelected: Bool
    let gigsCount: Int
    let hasOpenGigs: Bool
    let hasClosedOrCancelledGigs: Bool

    var id: Date { date }
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
        gig: Gig?,
        defaultDate: Date? = nil
    ) {
        self.currentProfile = currentProfile
        self.gigStore = gigStore
        self.venueStore = venueStore
        self.existingGig = gig
        let associatedVenue = venueStore.venue(for: currentProfile.id)
        let creationDate = defaultDate.flatMap {
            Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: $0)
        }

        self.title = gig?.title ?? ""
        self.city = gig?.city ?? associatedVenue?.city ?? currentProfile.city
        self.performanceDate = gig?.performanceDate ?? creationDate ?? Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
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

        do {
            let associatedVenue = try await venueStore.saveHostedVenue(using: currentProfile)
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

            return try await gigStore.save(gig)
        } catch {
            errorMessage = error.setLoopUserMessage
            return nil
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
