import SwiftUI

struct VenueGigsView: View {
    @StateObject private var viewModel: VenueGigsViewModel

    init(viewModel: VenueGigsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    VenueGigSummaryMetric(title: "Abiertas", value: "\(viewModel.openCount)")
                    VenueGigSummaryMetric(title: "Pendientes", value: "\(viewModel.pendingApplicationCount)")
                }
            }
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)

            if viewModel.items.isEmpty {
                Section {
                    ContentUnavailableView(
                        viewModel.emptyStateTitle,
                        systemImage: "calendar.badge.plus",
                        description: Text(viewModel.emptyStateDescription)
                    )
                    .frame(maxWidth: .infinity, minHeight: 240)
                }
            } else {
                Section("Tus gigs") {
                    ForEach(viewModel.items) { item in
                        VenueGigRow(item: item) {
                            viewModel.edit(item)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Mis fechas")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.startCreating()
                } label: {
                    Label("Nueva fecha", systemImage: "plus")
                }
            }
        }
        .sheet(item: $viewModel.editorContext, onDismiss: {
            viewModel.dismissEditor()
        }) { context in
            GigEditorView(viewModel: viewModel.makeEditorViewModel(for: context.gig))
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
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(item.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Text(item.status.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(item.status.tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(item.status.tint.opacity(0.12))
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
                Label("\(item.pendingApplications) pendientes", systemImage: "tray.full")
                    .font(.caption.weight(.medium))

                Label("\(item.totalApplications) total", systemImage: "person.3")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Editar", action: onEdit)
                .buttonStyle(.bordered)
                .padding(.top, 2)
        }
        .padding(.vertical, 6)
    }
}

private struct GigEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: GigEditorViewModel

    init(viewModel: GigEditorViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos base") {
                    TextField("Titulo de la fecha", text: $viewModel.title)

                    Picker("Busco", selection: $viewModel.roleNeeded) {
                        Text("Musicos").tag(UserRole.musician)
                        Text("DJs").tag(UserRole.dj)
                    }
                    .pickerStyle(.segmented)

                    TextField("Ciudad", text: $viewModel.city)
                        .textInputAutocapitalization(.words)

                    DatePicker(
                        "Fecha",
                        selection: $viewModel.performanceDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                Section("Formato de la gig") {
                    TextField("Duracion en minutos", text: $viewModel.durationText)
                        .keyboardType(.numberPad)

                    HStack(spacing: 12) {
                        TextField("Presupuesto min", text: $viewModel.budgetMinText)
                            .keyboardType(.numberPad)

                        TextField("Presupuesto max", text: $viewModel.budgetMaxText)
                            .keyboardType(.numberPad)
                    }

                    Picker("Estado", selection: $viewModel.status) {
                        ForEach(GigStatus.allCases) { status in
                            Text(status.displayName).tag(status)
                        }
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
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
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
        }
    }

    private func handleSave() {
        Task { @MainActor in
            guard await viewModel.save() != nil else {
                return
            }

            dismiss()
        }
    }
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
