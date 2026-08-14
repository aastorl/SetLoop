import SwiftUI

struct BookingView: View {
    @StateObject private var viewModel: BookingViewModel
    @Binding private var targetApplicationID: UUID?
    @State private var focusedApplicationID: UUID?

    init(
        currentProfile: UserProfile,
        applicationStore: ApplicationStore,
        gigStore: GigStore,
        venueStore: VenueStore? = nil,
        targetApplicationID: Binding<UUID?> = .constant(nil)
    ) {
        _targetApplicationID = targetApplicationID
        _viewModel = StateObject(
            wrappedValue: BookingViewModel(
                applicationStore: applicationStore,
                currentProfile: currentProfile,
                gigStore: gigStore,
                venueStore: venueStore
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
                .background(Color(.systemBackground))
            }
            .background(Color(.systemBackground))
            .navigationTitle(viewModel.screenTitle)
            .task {
                await viewModel.load()
            }
            .task(id: targetApplicationID) {
                guard let applicationID = targetApplicationID else {
                    return
                }

                await focusApplication(applicationID)
            }
        }
    }

    @MainActor
    private func focusApplication(_ applicationID: UUID) async {
        if viewModel.item(applicationID: applicationID) == nil {
            await viewModel.load()
        }

        guard let item = viewModel.item(applicationID: applicationID) else {
            viewModel.showUnavailableApplicationMessage()
            targetApplicationID = nil
            return
        }

        viewModel.prepareForPresentation(item)
        focusedApplicationID = applicationID
        targetApplicationID = nil

        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await MainActor.run {
                if focusedApplicationID == applicationID {
                    focusedApplicationID = nil
                }
            }
        }
    }

    private var applicationList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(viewModel.sections) { section in
                    Section(section.title) {
                        ForEach(section.items) { item in
                            bookingRow(item)
                                .padding(14)
                                .background(BookingRowBackground(isFocused: focusedApplicationID == item.id))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .id(item.id)
                                .listRowInsets(EdgeInsets(top: 8, leading: 24, bottom: 8, trailing: 24))
                                .listRowBackground(Color(.systemBackground))
                                .listRowSeparator(.hidden)
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
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground))
            .onChange(of: focusedApplicationID) { _, applicationID in
                guard let applicationID else {
                    return
                }

                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 120_000_000)
                    withAnimation(.snappy) {
                        proxy.scrollTo(applicationID, anchor: .center)
                    }
                }
            }
        }
    }

    private var applicantCalendar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                BookingMonthCalendar(
                    monthTitle: viewModel.calendarMonthTitle,
                    weeks: viewModel.bookingCalendarWeeks,
                    onPreviousMonth: viewModel.moveToPreviousMonth,
                    onNextMonth: viewModel.moveToNextMonth,
                    onSelectDay: viewModel.select
                )
                .padding(18)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 12) {
                    Text(viewModel.selectedDayTitle)
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    if viewModel.selectedDayCalendarItems.isEmpty {
                        BookingEmptyDayView()
                    } else {
                        ForEach(viewModel.selectedDayCalendarItems) { item in
                            VStack(alignment: .leading, spacing: 10) {
                                bookingRow(item)

                                if viewModel.canDelete(item) {
                                    Button(role: .destructive) {
                                        Task {
                                            await viewModel.deleteAsync(item)
                                        }
                                    } label: {
                                        Label("Eliminar candidatura", systemImage: "trash")
                                            .font(.subheadline.weight(.semibold))
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.regular)
                                }
                            }
                            .padding(14)
                            .background(BookingRowBackground(isFocused: focusedApplicationID == item.id))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .background(Color(.systemBackground))
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

private struct BookingEmptyDayView: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 40, height: 40)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text("Sin candidaturas")
                    .font(.subheadline.weight(.semibold))

                Text("No hay fechas vinculadas al dia seleccionado.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
                        .font(.headline)
                        .frame(width: 38, height: 38)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mes anterior")

                Text(monthTitle.capitalized)
                    .font(.headline)
                    .frame(maxWidth: .infinity)

                Button(action: onNextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .frame(width: 38, height: 38)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
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
        HStack(alignment: .top, spacing: 12) {
            BookingEntryImageView(
                imageURL: item.counterpartImageURL,
                symbolName: imageSymbolName
            )

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

                HStack(spacing: 8) {
                    BookingMetaPill(
                        text: item.city,
                        systemImage: "mappin.and.ellipse"
                    )

                    if let performanceDate = item.performanceDate {
                        BookingMetaPill(
                            text: formattedPerformanceDate(performanceDate),
                            systemImage: "calendar"
                        )
                    }
                }

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
        }
        .padding(.vertical, 6)
    }

    private var imageSymbolName: String {
        if item.isIncoming {
            return item.counterpartRole == .dj ? "headphones" : "music.mic"
        }

        return "building.2"
    }

    private func formattedPerformanceDate(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .day()
                .month(.abbreviated)
                .year()
                .hour()
                .minute()
                .locale(Locale(identifier: "es_ES"))
        )
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

private struct BookingRowBackground: View {
    let isFocused: Bool

    init(isFocused: Bool = false) {
        self.isFocused = isFocused
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(isFocused ? Color.accentColor.opacity(0.08) : Color(.secondarySystemBackground))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isFocused ? Color.accentColor.opacity(0.35) : Color(.separator).opacity(0.12),
                        lineWidth: isFocused ? 1.2 : 0.8
                    )
            }
            .shadow(
                color: isFocused ? Color.accentColor.opacity(0.12) : Color.black.opacity(0.035),
                radius: isFocused ? 16 : 12,
                x: 0,
                y: 6
            )
    }
}

private struct BookingMetaPill: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.separator).opacity(0.16), lineWidth: 0.8)
            }
            .shadow(color: Color.black.opacity(0.035), radius: 8, x: 0, y: 4)
    }
}

private struct BookingEntryImageView: View {
    let imageURL: URL?
    let symbolName: String

    var body: some View {
        Group {
            if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty:
                        placeholder(showsProgress: true)
                    case .failure:
                        placeholder(showsProgress: false)
                    @unknown default:
                        placeholder(showsProgress: false)
                    }
                }
            } else {
                placeholder(showsProgress: false)
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func placeholder(showsProgress: Bool) -> some View {
        ZStack {
            Color(.tertiarySystemBackground)

            if showsProgress {
                ProgressView()
            } else {
                Image(systemName: symbolName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
