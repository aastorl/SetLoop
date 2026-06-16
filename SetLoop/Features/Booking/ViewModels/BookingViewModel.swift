import Foundation
import Combine

@MainActor
final class BookingViewModel: ObservableObject {
    @Published private(set) var sections: [BookingSectionItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isUpdating = false
    @Published private(set) var errorMessage: String?
    @Published var applicantDisplayMode: BookingDisplayMode = .list
    @Published var visibleMonth: Date
    @Published var selectedDate: Date
    @Published var venueFilter: VenueBookingFilter = .pending {
        didSet {
            reloadItems()
        }
    }

    private let currentProfile: UserProfile
    private let applicationStore: ApplicationStore
    private let gigStore: GigStore
    private let calendar: Calendar
    private var cancellables = Set<AnyCancellable>()

    init(
        applicationStore: ApplicationStore,
        currentProfile: UserProfile,
        gigStore: GigStore,
        calendar: Calendar = .current
    ) {
        self.currentProfile = currentProfile
        self.applicationStore = applicationStore
        self.gigStore = gigStore
        self.calendar = calendar
        let today = calendar.startOfDay(for: Date())
        self.visibleMonth = today
        self.selectedDate = today

        reloadItems()

        applicationStore.$applications
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

    var showsApplicantDisplayModePicker: Bool {
        currentProfile.role != .venue
    }

    var screenTitle: String {
        currentProfile.role == .venue ? "Candidaturas" : "Mis candidaturas"
    }

    var emptyStateTitle: String {
        if currentProfile.role == .venue {
            switch venueFilter {
            case .pending:
                return "Sin candidaturas pendientes"
            case .managed:
                return "Sin candidaturas gestionadas"
            }
        }

        return "Sin candidaturas"
    }

    var emptyStateDescription: String {
        if currentProfile.role == .venue {
            switch venueFilter {
            case .pending:
                return "Las candidaturas pendientes a tus fechas apareceran aqui."
            case .managed:
                return "Las candidaturas aceptadas o rechazadas se guardaran aqui."
            }
        }

        return "Cuando solicites una fecha, aparecera aqui con su estado."
    }

    var hasItems: Bool {
        sections.contains { $0.items.isEmpty == false }
    }

    var calendarMonthTitle: String {
        visibleMonth.formatted(.dateTime.month(.wide).year())
    }

    var selectedDayTitle: String {
        selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    var calendarItems: [BookingEntryItem] {
        sections
            .flatMap(\.items)
            .filter { $0.performanceDate != nil }
            .sorted {
                guard let lhsDate = $0.performanceDate, let rhsDate = $1.performanceDate else {
                    return $0.createdAt > $1.createdAt
                }

                return lhsDate < rhsDate
            }
    }

    var selectedDayCalendarItems: [BookingEntryItem] {
        calendarItems.filter { item in
            guard let performanceDate = item.performanceDate else {
                return false
            }

            return calendar.isDate(performanceDate, inSameDayAs: selectedDate)
        }
    }

    var bookingCalendarWeeks: [BookingCalendarWeek] {
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
                let dayItems = calendarItems.filter { item in
                    guard let performanceDate = item.performanceDate else {
                        return false
                    }

                    return calendar.isDate(performanceDate, inSameDayAs: date)
                }

                return BookingCalendarDay(
                    date: date,
                    dayNumber: calendar.component(.day, from: date),
                    isInDisplayedMonth: calendar.isDate(date, equalTo: monthInterval.start, toGranularity: .month),
                    isToday: calendar.isDateInToday(date),
                    isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                    entriesCount: dayItems.count,
                    hasPendingEntries: dayItems.contains { $0.status == .pending },
                    hasAcceptedEntries: dayItems.contains { $0.status == .accepted },
                    hasInactiveEntries: dayItems.contains { $0.status == .rejected || $0.status == .withdrawn }
                )
            }

            return BookingCalendarWeek(startDate: weekStart, days: days)
        }
    }

    func load() async {
        guard applicationStore.usesRemoteService else {
            reloadItems()
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var loadErrorMessage: String?

        loadErrorMessage = await performBookingLoad {
            try await self.gigStore.loadAll()
        } ?? loadErrorMessage

        loadErrorMessage = await performBookingLoad {
            try await self.applicationStore.loadAll()
        } ?? loadErrorMessage

        errorMessage = loadErrorMessage
        reloadItems()
    }

    func accept(_ item: BookingEntryItem) {
        guard applicationStore.usesRemoteService == false else {
            Task {
                await acceptAsync(item)
            }
            return
        }

        acceptLocally(item)
    }

    func reject(_ item: BookingEntryItem) {
        guard applicationStore.usesRemoteService == false else {
            Task {
                await rejectAsync(item)
            }
            return
        }

        rejectLocally(item)
    }

    func acceptAsync(_ item: BookingEntryItem) async {
        guard applicationStore.usesRemoteService else {
            acceptLocally(item)
            return
        }

        await performRemoteDecision {
            guard self.currentProfile.role == .venue,
                  item.kind == .receivedApplication else {
                return
            }

            _ = try await self.applicationStore.saveStatus(applicationID: item.id, status: .accepted)
        }
    }

    func rejectAsync(_ item: BookingEntryItem) async {
        guard applicationStore.usesRemoteService else {
            rejectLocally(item)
            return
        }

        await performRemoteDecision {
            guard self.currentProfile.role == .venue,
                  item.kind == .receivedApplication else {
                return
            }

            _ = try await self.applicationStore.saveStatus(applicationID: item.id, status: .rejected)
        }
    }

    func select(_ day: BookingCalendarDay) {
        selectedDate = calendar.startOfDay(for: day.date)
        visibleMonth = day.date
    }

    func moveToPreviousMonth() {
        moveVisibleMonth(by: -1)
    }

    func moveToNextMonth() {
        moveVisibleMonth(by: 1)
    }

    private func acceptLocally(_ item: BookingEntryItem) {
        guard currentProfile.role == .venue,
              item.kind == .receivedApplication,
              let updatedApplication = applicationStore.updateStatus(applicationID: item.id, status: .accepted) else {
            return
        }

        closeGigAfterConfirmation(gigID: updatedApplication.gigID, acceptedApplicationID: updatedApplication.id)
    }

    private func rejectLocally(_ item: BookingEntryItem) {
        guard currentProfile.role == .venue,
              item.kind == .receivedApplication else {
            return
        }

        applicationStore.updateStatus(applicationID: item.id, status: .rejected)
    }

    private func closeGigAfterConfirmation(gigID: UUID, acceptedApplicationID: UUID?) {
        _ = gigStore.updateStatus(gigID: gigID, status: .booked)
        applicationStore.rejectPendingApplications(for: gigID, excluding: acceptedApplicationID)
    }

    private func performRemoteDecision(_ operation: () async throws -> Void) async {
        guard isUpdating == false else {
            return
        }

        isUpdating = true
        errorMessage = nil
        defer { isUpdating = false }

        do {
            try await operation()
            try await gigStore.loadAll()
            try await applicationStore.loadAll()
            errorMessage = nil
            reloadItems()
        } catch {
            errorMessage = error.setLoopUserMessage
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

    private func performBookingLoad(_ operation: () async throws -> Void) async -> String? {
        do {
            try await operation()
            return nil
        } catch {
            return error.setLoopUserMessage
        }
    }

    private func reloadItems() {
        if currentProfile.role == .venue {
            let receivedApplications = applicationStore.receivedApplications(for: currentProfile.id)
            let filteredApplications = receivedApplications.filter { application in
                venueFilter.includes(application.status)
            }

            sections = [
                makeApplicationSection(
                    id: "venue.applications",
                    title: "Candidaturas recibidas",
                    applications: filteredApplications,
                    kind: .receivedApplication
                )
            ]
            .filter { $0.items.isEmpty == false }
            return
        }

        let applicationItems = makeApplicationSection(
            id: "applicant.applications",
            title: "Candidaturas enviadas",
            applications: applicationStore.sentApplications(for: currentProfile.id),
            kind: .sentApplication
        )
        .items
        .sorted { $0.createdAt > $1.createdAt }

        sections = ApplicationBookingGroup.allCases.map { group in
            BookingSectionItem(
                id: "applicant.\(group.rawValue)",
                title: group.displayName,
                items: applicationItems.filter { group.includes($0.status) }
            )
        }
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
}

enum BookingDisplayMode: String, CaseIterable, Identifiable {
    case list
    case calendar

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .list:
            return "Lista"
        case .calendar:
            return "Calendario"
        }
    }
}

enum ApplicationBookingGroup: String, CaseIterable, Identifiable {
    case pending
    case confirmed
    case notSelected

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pending:
            return "Pendientes"
        case .confirmed:
            return "Confirmadas"
        case .notSelected:
            return "No seleccionadas"
        }
    }

    func includes(_ status: ApplicationStatus) -> Bool {
        switch self {
        case .pending:
            return status == .pending
        case .confirmed:
            return status == .accepted
        case .notSelected:
            return status == .rejected || status == .withdrawn
        }
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

struct BookingCalendarWeek: Identifiable, Equatable {
    let startDate: Date
    let days: [BookingCalendarDay]

    var id: Date { startDate }
}

struct BookingCalendarDay: Identifiable, Equatable {
    let date: Date
    let dayNumber: Int
    let isInDisplayedMonth: Bool
    let isToday: Bool
    let isSelected: Bool
    let entriesCount: Int
    let hasPendingEntries: Bool
    let hasAcceptedEntries: Bool
    let hasInactiveEntries: Bool

    var id: Date { date }
}

enum BookingEntryKind: String, Equatable {
    case sentApplication
    case receivedApplication

    var isIncoming: Bool {
        self == .receivedApplication
    }

    var displayName: String {
        "Candidatura"
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
