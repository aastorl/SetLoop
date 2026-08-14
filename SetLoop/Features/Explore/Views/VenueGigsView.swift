import SwiftUI
import UIKit

struct VenueGigsView: View {
    @StateObject private var viewModel: VenueGigsViewModel
    @State private var didOpenInitialEditor = false
    @State private var showsHistory = false
    @State private var activeSheet: VenueGigsSheet?

    private let opensCreatorOnAppear: Bool

    init(viewModel: VenueGigsViewModel, opensCreatorOnAppear: Bool = false) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.opensCreatorOnAppear = opensCreatorOnAppear
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        VenueGigSummaryMetric(title: "Abiertas", value: "\(viewModel.openCount)")
                        VenueGigSummaryMetric(title: "Proximas", value: "\(viewModel.upcomingCount)")
                    }

                    HStack(spacing: 12) {
                        VenueGigSummaryMetric(title: "Este mes", value: "\(viewModel.monthItems.count)")
                        VenueGigSummaryMetric(title: "Historial", value: "\(viewModel.closedOrCancelledCount)")
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)

            if viewModel.isLoading {
                Section {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 180)
                }
            } else {
                Section {
                    VenueMonthCalendar(
                        monthTitle: viewModel.monthTitle,
                        weeks: viewModel.calendarWeeks,
                        onPreviousMonth: viewModel.moveToPreviousMonth,
                        onNextMonth: viewModel.moveToNextMonth,
                        onSelectDay: { day in
                            viewModel.select(day)
                            activeSheet = .day(VenueGigDayAgendaContext(date: day.date))
                        }
                    )
                    .padding(.vertical, 6)
                } header: {
                    Text("Calendario")
                }

                Section {
                    DisclosureGroup(isExpanded: $showsHistory) {
                        if viewModel.closedOrCancelledItems.isEmpty {
                            Text("Sin fechas pasadas, cerradas o canceladas.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 6)
                        } else {
                            gigRows(viewModel.closedOrCancelledItems)
                        }
                    } label: {
                        Label("Historial", systemImage: "archivebox")
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Fechas")
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .day(let context):
                VenueDayAgendaSheet(
                    title: viewModel.dayTitle(for: context.date),
                    items: viewModel.items(on: context.date),
                    emptyStateTitle: viewModel.items.isEmpty ? viewModel.emptyStateTitle : "Sin fechas este dia",
                    emptyStateDescription: viewModel.items.isEmpty ? viewModel.emptyStateDescription : "No hay fechas creadas para el dia seleccionado.",
                    onCreate: {
                        activeSheet = .editor(viewModel.makeCreateContext(on: context.date))
                    },
                    onEdit: { item in
                        activeSheet = .editor(viewModel.makeEditContext(for: item))
                    },
                    canCancel: viewModel.canCancel,
                    onCancel: { item in
                        await viewModel.cancel(item)
                    }
                )

            case .editor(let context):
                GigEditorView(viewModel: viewModel.makeEditorViewModel(for: context))
            }
        }
        .onAppear {
            guard opensCreatorOnAppear, didOpenInitialEditor == false else {
                return
            }

            didOpenInitialEditor = true
            activeSheet = .editor(viewModel.makeCreateContext(on: viewModel.selectedDate))
        }
        .task {
            await viewModel.load()
        }
    }

    @ViewBuilder
    private func gigRows(_ items: [VenueGigItem]) -> some View {
        ForEach(items) { item in
            VenueGigRow(
                item: item,
                onEdit: {
                    activeSheet = .editor(viewModel.makeEditContext(for: item))
                }
            )
        }
    }
}

private enum VenueGigsSheet: Identifiable {
    case day(VenueGigDayAgendaContext)
    case editor(VenueGigEditorContext)

    var id: String {
        switch self {
        case .day(let context):
            return "day-\(context.id.timeIntervalSince1970)"
        case .editor(let context):
            return "editor-\(context.id.uuidString)"
        }
    }
}

private struct VenueGigDayAgendaContext: Identifiable {
    let date: Date

    var id: Date { Calendar.current.startOfDay(for: date) }
}

private struct VenueDayAgendaSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let items: [VenueGigItem]
    let emptyStateTitle: String
    let emptyStateDescription: String
    let onCreate: () -> Void
    let onEdit: (VenueGigItem) -> Void
    let canCancel: (VenueGigItem) -> Bool
    let onCancel: (VenueGigItem) async -> Void

    @State private var itemPendingCancellation: VenueGigItem?
    @State private var isCancelling = false

    var body: some View {
        NavigationStack {
            List {
                Section("Gestionar fechas creadas") {
                    if items.isEmpty {
                        ContentUnavailableView(
                            emptyStateTitle,
                            systemImage: "calendar",
                            description: Text(emptyStateDescription)
                        )
                        .frame(maxWidth: .infinity, minHeight: 150)
                    } else {
                        ForEach(items) { item in
                            VenueGigRow(
                                item: item,
                                canCancel: canCancel(item),
                                isCancelDisabled: isCancelling,
                                onEdit: {
                                    onEdit(item)
                                },
                                onCancel: {
                                    itemPendingCancellation = item
                                }
                            )
                        }
                    }
                }
            }
            .alert("Cancelar fecha", isPresented: showsCancellationAlert) {
                Button("Volver", role: .cancel) {
                    itemPendingCancellation = nil
                }

                Button("Cancelar fecha", role: .destructive) {
                    guard let item = itemPendingCancellation else {
                        return
                    }

                    isCancelling = true
                    Task { @MainActor in
                        await onCancel(item)
                        isCancelling = false
                        itemPendingCancellation = nil
                    }
                }
            } message: {
                Text("La fecha dejara de aparecer en Explore y sus candidaturas pendientes pasaran a no seleccionadas.")
            }
            .listStyle(.insetGrouped)
            .navigationTitle(title.capitalized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(action: onCreate) {
                        Label("Crear nueva", systemImage: "plus")
                    }
                }
            }
        }
        .presentationDetents([preferredDetent])
        .presentationDragIndicator(.hidden)
    }

    private var showsCancellationAlert: Binding<Bool> {
        Binding(
            get: { itemPendingCancellation != nil },
            set: { isPresented in
                if isPresented == false {
                    itemPendingCancellation = nil
                }
            }
        )
    }

    private var preferredDetent: PresentationDetent {
        switch items.count {
        case 0:
            return .height(320)
        case 1...2:
            return .medium
        default:
            return .large
        }
    }
}

private struct VenueMonthCalendar: View {
    let monthTitle: String
    let weeks: [VenueGigCalendarWeek]
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    let onSelectDay: (VenueGigCalendarDay) -> Void

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
                        VenueCalendarDayButton(day: day) {
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

private struct VenueCalendarDayButton: View {
    let day: VenueGigCalendarDay
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text("\(day.dayNumber)")
                    .font(.subheadline.weight(day.isSelected ? .bold : .regular))
                    .foregroundStyle(foregroundStyle)
                    .frame(height: 18)

                HStack(spacing: 3) {
                    if day.hasOpenGigs {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 5, height: 5)
                    }

                    if day.hasClosedOrCancelledGigs {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 5, height: 5)
                    }

                    if day.gigsCount > 2 {
                        Text("\(day.gigsCount)")
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
        } else if day.gigsCount > 0 {
            Color(.tertiarySystemBackground)
        } else {
            Color.clear
        }
    }
}

private struct VenueGigSummaryMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title3.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct VenueGigRow: View {
    let item: VenueGigItem
    var canCancel = false
    var isCancelDisabled = false
    let onEdit: () -> Void
    var onCancel: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(item.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Text(statusDisplayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusTint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(statusTint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack(spacing: 14) {
                Label(item.roleNeeded.shortLabel, systemImage: "person.2")
                Label(item.city, systemImage: "mappin.and.ellipse")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: 14) {
                Label(item.performanceDate.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                Label(item.budgetText, systemImage: "eurosign")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Label("\(item.totalApplications) candidaturas", systemImage: "person.3")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                VenueGigInlineActionButton(
                    title: "Gestionar",
                    systemImage: "slider.horizontal.3",
                    tint: .accentColor,
                    action: onEdit
                )

                if canCancel {
                    VenueGigInlineActionButton(
                        title: "Cancelar",
                        systemImage: "xmark.circle",
                        tint: .red,
                        action: {
                            onCancel?()
                        }
                    )
                    .disabled(isCancelDisabled)
                }
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 6)
    }

    private var statusDisplayName: String {
        if item.status == .open && item.isPast {
            return "Pasada"
        }

        return item.status.displayName
    }

    private var statusTint: Color {
        if item.status == .open && item.isPast {
            return .secondary
        }

        return item.status.tint
    }
}

private struct VenueGigInlineActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 34)
                .padding(.horizontal, 10)
                .foregroundStyle(tint)
                .background(tint.opacity(0.1))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(tint.opacity(0.22), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

private struct GigEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: GigEditorViewModel
    @FocusState private var focusedField: GigEditorField?
    @State private var pendingRole: UserRole?
    @State private var showsRoleChangeConfirmation = false

    init(viewModel: GigEditorViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos base") {
                    TextField("Titulo de la fecha", text: $viewModel.title)
                        .focused($focusedField, equals: .title)

                    Picker("Busco", selection: roleSelection) {
                        Text("Musicos").tag(UserRole.musician)
                        Text("DJs").tag(UserRole.dj)
                    }
                    .pickerStyle(.segmented)

                    DatePicker(
                        "Fecha",
                        selection: $viewModel.performanceDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                Section("Formato de la gig") {
                    TextField("Duracion en minutos", text: $viewModel.durationText)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .duration)

                    HStack(spacing: 12) {
                        TextField("Presupuesto min", text: $viewModel.budgetMinText)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .budgetMin)

                        TextField("Presupuesto max", text: $viewModel.budgetMaxText)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .budgetMax)
                    }
                }

                Section(viewModel.roleNeeded == .dj ? "Estilos / enfoque del set" : "Generos requeridos") {
                    ForEach(viewModel.availableGenreOptions, id: \.self) { option in
                        Button {
                            viewModel.toggleGenre(option)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: viewModel.isGenreSelected(option) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(viewModel.isGenreSelected(option) ? Color.accentColor : Color.secondary)

                                Text(option)
                                    .foregroundStyle(.primary)

                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("Descripcion") {
                    TextField(
                        "Brief de la fecha, necesidades tecnicas y contexto",
                        text: $viewModel.gigDescription,
                        axis: .vertical
                    )
                    .lineLimit(4...7)
                    .focused($focusedField, equals: .description)
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .background {
                KeyboardDismissTapRecognizer {
                    dismissKeyboard()
                }
            }
            .navigationTitle(viewModel.screenTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        handleSave()
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text(viewModel.saveButtonTitle)
                        }
                    }
                    .disabled(viewModel.isSaving || !viewModel.canSave)
                }
            }
            .alert("Cambiar tipo de fecha", isPresented: $showsRoleChangeConfirmation) {
                Button("Cancelar", role: .cancel) {
                    pendingRole = nil
                }

                Button("Aceptar", role: .destructive) {
                    guard let pendingRole else {
                        return
                    }

                    viewModel.changeRole(to: pendingRole, resettingDraft: true)
                    self.pendingRole = nil
                }
            } message: {
                Text("Al cambiar entre Musicos y DJs se reiniciaran los datos cargados en esta fecha.")
            }
        }
    }

    private var roleSelection: Binding<UserRole> {
        Binding(
            get: { viewModel.roleNeeded },
            set: requestRoleChange
        )
    }

    private func requestRoleChange(_ newRole: UserRole) {
        dismissKeyboard()

        guard viewModel.shouldConfirmRoleChange(to: newRole) else {
            viewModel.changeRole(to: newRole, resettingDraft: false)
            return
        }

        pendingRole = newRole
        showsRoleChangeConfirmation = true
    }

    private func handleSave() {
        dismissKeyboard()

        Task { @MainActor in
            guard await viewModel.save() != nil else {
                return
            }

            dismiss()
        }
    }

    private func dismissKeyboard() {
        focusedField = nil
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

private enum GigEditorField: Hashable {
    case title
    case duration
    case budgetMin
    case budgetMax
    case description
}

private extension GigStatus {
    var displayName: String {
        switch self {
        case .open:
            return "Abierta"
        case .booked:
            return "Cerrada"
        case .cancelled:
            return "Cancelada"
        }
    }

    var tint: Color {
        switch self {
        case .open:
            return .green
        case .booked:
            return .blue
        case .cancelled:
            return .red
        }
    }
}
