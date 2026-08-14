import SwiftUI
import MapKit

struct VenueAddressSearchSheet: View {
    @StateObject private var viewModel = VenueAddressSearchViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSelection: VenueAddressSelection?
    @State private var mapPosition: MapCameraPosition
    @State private var didResolveInitialSelection = false

    let initialQuery: String
    let initialSelection: VenueAddressSelection?
    let onSelect: (VenueAddressSelection) -> Void

    init(
        initialQuery: String,
        initialSelection: VenueAddressSelection? = nil,
        onSelect: @escaping (VenueAddressSelection) -> Void
    ) {
        self.initialQuery = initialQuery
        self.initialSelection = initialSelection
        self.onSelect = onSelect
        _selectedSelection = State(initialValue: initialSelection)
        _mapPosition = State(initialValue: .region(Self.region(for: initialSelection)))
    }

    var body: some View {
        ZStack {
            Map(position: $mapPosition) {
                if let coordinate = selectedCoordinate {
                    Marker(selectedMarkerTitle, coordinate: coordinate)
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topSearchBar

                Spacer(minLength: 0)

                bottomPanel
            }

            if viewModel.isResolving {
                ProgressView()
                    .padding(18)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .onAppear {
            configureInitialState()
        }
    }

    private var topSearchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField(
                    "Buscar direccion",
                    text: Binding(
                        get: { viewModel.query },
                        set: { newValue in
                            if newValue != viewModel.query {
                                selectedSelection = nil
                            }

                            viewModel.query = newValue
                        }
                    )
                )
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)

                if viewModel.query.isEmpty == false {
                    Button {
                        selectedSelection = nil
                        viewModel.query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 13)
            .frame(height: 48)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 48, height: 48)
                    .background(.regularMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cerrar")
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    private var bottomPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let selectedSelection {
                selectedAddressCard(selectedSelection)
            } else if viewModel.suggestions.isEmpty == false {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.suggestions) { suggestion in
                            resultRow(suggestion)
                        }
                    }
                    .padding(.bottom, 2)
                }
                .frame(maxHeight: 310)
            } else if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if selectedSelection == nil {
                Label("Busca el nombre o direccion del local", systemImage: "magnifyingglass")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    private func selectedAddressCard(_ selection: VenueAddressSelection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(Color.accentColor)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    if let placeName = selection.placeName,
                       placeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                        Text(placeName)
                            .font(.subheadline.weight(.semibold))
                    }

                    Text(selection.address)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            Button {
                onSelect(selection)
                dismiss()
            } label: {
                Label("Usar direccion", systemImage: "checkmark")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func resultRow(_ suggestion: VenueAddressSuggestion) -> some View {
        Button {
            preview(suggestion)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.title)
                        .foregroundStyle(.primary)

                    if suggestion.subtitle.isEmpty == false {
                        Text(suggestion.subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding(14)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isResolving)
    }

    private var selectedCoordinate: CLLocationCoordinate2D? {
        Self.coordinate(for: selectedSelection)
    }

    private var selectedMarkerTitle: String {
        guard let selectedSelection else {
            return "Direccion"
        }

        return selectedSelection.placeName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? selectedSelection.address
    }

    private func preview(_ suggestion: VenueAddressSuggestion) {
        Task { @MainActor in
            guard let selection = await viewModel.resolve(suggestion) else {
                return
            }

            selectedSelection = selection
            focusMap(on: selection)
        }
    }

    private func configureInitialState() {
        if viewModel.query.isEmpty {
            viewModel.query = initialQuery
        }

        guard didResolveInitialSelection == false,
              let initialSelection else {
            return
        }

        didResolveInitialSelection = true

        if Self.coordinate(for: initialSelection) != nil {
            focusMap(on: initialSelection)
            return
        }

        Task { @MainActor in
            guard let resolvedSelection = await viewModel.resolveExistingSelection(initialSelection) else {
                return
            }

            selectedSelection = resolvedSelection
            focusMap(on: resolvedSelection)
        }
    }

    private func focusMap(on selection: VenueAddressSelection) {
        guard let coordinate = Self.coordinate(for: selection) else {
            return
        }

        withAnimation(.easeInOut(duration: 0.25)) {
            mapPosition = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.018)
                )
            )
        }
    }

    private static func region(for selection: VenueAddressSelection?) -> MKCoordinateRegion {
        let selectedCoordinate = coordinate(for: selection)
        let coordinate = selectedCoordinate ?? CLLocationCoordinate2D(latitude: 40.4168, longitude: -3.7038)
        let delta = selectedCoordinate == nil ? 10.5 : 0.018

        return MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta)
        )
    }

    private static func coordinate(for selection: VenueAddressSelection?) -> CLLocationCoordinate2D? {
        guard let latitude = selection?.latitude,
              let longitude = selection?.longitude else {
            return nil
        }

        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
