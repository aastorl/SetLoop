import SwiftUI

struct BookingView: View {
    @StateObject private var viewModel: BookingViewModel
    @Binding private var targetApplicationID: UUID?
    @State private var presentedApplication: BookingApplicationRoute?

    init(
        currentProfile: UserProfile,
        applicationStore: ApplicationStore,
        gigStore: GigStore,
        targetApplicationID: Binding<UUID?> = .constant(nil)
    ) {
        _targetApplicationID = targetApplicationID
        _viewModel = StateObject(
            wrappedValue: BookingViewModel(
                applicationStore: applicationStore,
                currentProfile: currentProfile,
                gigStore: gigStore
            )
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.showsVenueFilter {
                    Picker("Estado", selection: $viewModel.venueFilter) {
                        ForEach(VenueBookingFilter.allCases) { filter in
                            Text(filter.displayName).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }

                if viewModel.showsApplicantDisplayModePicker {
                    Picker("Vista", selection: $viewModel.applicantDisplayMode) {
                        ForEach(BookingDisplayMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }

                Group {
                    if viewModel.isLoading && viewModel.hasItems == false {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.hasItems == false {
                        ContentUnavailableView(
                            viewModel.emptyStateTitle,
                            systemImage: "tray",
                            description: Text(viewModel.emptyStateDescription)
                        )
                    } else if viewModel.applicantDisplayMode == .calendar && viewModel.showsApplicantDisplayModePicker {
                        applicantCalendar
                    } else {
                        applicationList
                    }
                }
            }
            .navigationTitle(viewModel.screenTitle)
            .task {
                await viewModel.load()
            }
            .task(id: targetApplicationID) {
                guard let applicationID = targetApplicationID else {
                    return
                }

                await openApplication(applicationID)
            }
            .sheet(item: $presentedApplication, onDismiss: {
                targetApplicationID = nil
            }) { route in
                BookingApplicationDetailView(
                    viewModel: viewModel,
                    applicationID: route.id
                )
            }
        }
    }

    @MainActor
    private func openApplication(_ applicationID: UUID) async {
        if viewModel.item(applicationID: applicationID) == nil {
            await viewModel.load()
        }

        guard let item = viewModel.item(applicationID: applicationID) else {
            viewModel.showUnavailableApplicationMessage()
            targetApplicationID = nil
            return
        }

        viewModel.prepareForPresentation(item)
        presentedApplication = BookingApplicationRoute(id: applicationID)
    }

    private var applicationList: some View {
        List {
            ForEach(viewModel.sections) { section in
                Section(section.title) {
                    ForEach(section.items) { item in
                        bookingRow(item)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if viewModel.canDelete(item) {
                                    Button(role: .destructive) {
                                        Task {
                                            await viewModel.deleteAsync(item)
                                        }
                                    } label: {
                                        Label("Eliminar", systemImage: "trash")
                                    }
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var applicantCalendar: some View {
        List {
            Section {
                BookingMonthCalendar(
                    monthTitle: viewModel.calendarMonthTitle,
                    weeks: viewModel.bookingCalendarWeeks,
                    onPreviousMonth: viewModel.moveToPreviousMonth,
                    onNextMonth: viewModel.moveToNextMonth,
                    onSelectDay: viewModel.select
                )
                .padding(.vertical, 6)
            } header: {
                Text("Calendario")
            }

            Section(viewModel.selectedDayTitle) {
                if viewModel.selectedDayCalendarItems.isEmpty {
                    ContentUnavailableView(
                        "Sin candidaturas este dia",
                        systemImage: "calendar",
                        description: Text("No hay candidaturas vinculadas al dia seleccionado.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 150)
                } else {
                    ForEach(viewModel.selectedDayCalendarItems) { item in
                        bookingRow(item)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if viewModel.canDelete(item) {
                                    Button(role: .destructive) {
                                        Task {
                                            await viewModel.deleteAsync(item)
                                        }
                                    } label: {
                                        Label("Eliminar", systemImage: "trash")
                                    }
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func bookingRow(_ item: BookingEntryItem) -> some View {
        BookingApplicationRow(
            item: item,
            isUpdating: viewModel.isUpdating,
            onAccept: {
                Task {
                    await viewModel.acceptAsync(item)
                }
            },
            onReject: {
                Task {
                    await viewModel.rejectAsync(item)
                }
            }
        )
    }
}

private struct BookingApplicationRoute: Identifiable {
    let id: UUID
}

private struct BookingApplicationDetailView: View {
    @ObservedObject var viewModel: BookingViewModel
    let applicationID: UUID
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let item = viewModel.item(applicationID: applicationID) {
                    ScrollView {
                        BookingApplicationRow(
                            item: item,
                            isUpdating: viewModel.isUpdating,
                            onAccept: {
                                Task {
                                    await viewModel.acceptAsync(item)
                                }
                            },
                            onReject: {
                                Task {
                                    await viewModel.rejectAsync(item)
                                }
                            }
                        )
                        .padding(20)
                    }
                } else {
                    ContentUnavailableView(
                        "Candidatura no disponible",
                        systemImage: "tray",
                        description: Text("Puede haber sido eliminada o ya no estar disponible.")
                    )
                }
            }
            .navigationTitle("Candidatura")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct BookingMonthCalendar: View {
    let monthTitle: String
    let weeks: [BookingCalendarWeek]
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    let onSelectDay: (BookingCalendarDay) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private let weekdaySymbols = Self.makeWeekdaySymbols()

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Button(action: onPreviousMonth) {
                    Image(systemName: "chevron.left")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Mes anterior")

                Text(monthTitle.capitalized)
                    .font(.headline)
                    .frame(maxWidth: .infinity)

                Button(action: onNextMonth) {
                    Image(systemName: "chevron.right")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Mes siguiente")
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(weeks) { week in
                    ForEach(week.days) { day in
                        BookingCalendarDayButton(day: day) {
                            onSelectDay(day)
                        }
                    }
                }
            }
        }
    }

    private static func makeWeekdaySymbols() -> [String] {
        let formatter = DateFormatter()
        let symbols = formatter.veryShortWeekdaySymbols ?? ["D", "L", "M", "X", "J", "V", "S"]
        let firstWeekday = Calendar.current.firstWeekday - 1
        return Array(symbols[firstWeekday...]) + Array(symbols[..<firstWeekday])
    }
}

private struct BookingCalendarDayButton: View {
    let day: BookingCalendarDay
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text("\(day.dayNumber)")
                    .font(.subheadline.weight(day.isSelected ? .bold : .regular))
                    .foregroundStyle(foregroundStyle)
                    .frame(height: 18)

                HStack(spacing: 3) {
                    if day.hasPendingEntries {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 5, height: 5)
                    }

                    if day.hasAcceptedEntries {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 5, height: 5)
                    }

                    if day.hasInactiveEntries {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 5, height: 5)
                    }

                    if day.entriesCount > 3 {
                        Text("\(day.entriesCount)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(day.isSelected ? Color.white : Color.secondary)
                    }
                }
                .frame(height: 8)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(background)
            .overlay {
                if day.isToday && day.isSelected == false {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(0.55), lineWidth: 1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(day.isInDisplayedMonth ? 1 : 0.35)
        }
        .buttonStyle(.plain)
    }

    private var foregroundStyle: Color {
        if day.isSelected {
            return .white
        }

        return day.isInDisplayedMonth ? .primary : .secondary
    }

    @ViewBuilder
    private var background: some View {
        if day.isSelected {
            Color.accentColor
        } else if day.entriesCount > 0 {
            Color(.tertiarySystemBackground)
        } else {
            Color.clear
        }
    }
}

private struct BookingApplicationRow: View {
    let item: BookingEntryItem
    let isUpdating: Bool
    let onAccept: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.gigTitle)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(item.kind.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Text(item.status.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(item.status.tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(item.status.tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if let counterpartDisplayName = item.counterpartDisplayName {
                VStack(alignment: .leading, spacing: 4) {
                    Text(counterpartDisplayName)
                        .font(.subheadline.weight(.semibold))

                    Text(candidateSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if let venueName = item.venueName {
                Text(venueName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 14) {
                Label(item.city, systemImage: "mappin.and.ellipse")

                if let performanceDate = item.performanceDate {
                    Label(performanceDate.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(item.message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)

            if item.isIncoming && item.status == .pending {
                HStack(spacing: 10) {
                    Button("Rechazar", action: onReject)
                        .buttonStyle(.bordered)
                        .disabled(isUpdating)

                    Button("Aceptar", action: onAccept)
                        .buttonStyle(.borderedProminent)
                        .disabled(isUpdating)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 6)
    }

    private var candidateSubtitle: String {
        [
            item.counterpartRole?.displayName,
            item.counterpartCity
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }
}
