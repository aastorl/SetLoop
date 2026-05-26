import SwiftUI
import PhotosUI

struct ProfileView: View {
    @StateObject private var viewModel: ProfileViewModel
    let onSignOut: () -> Void

    init(
        profile: UserProfile,
        onPersistProfile: @escaping @MainActor (UserProfile) async throws -> UserProfile,
        onProfileSaved: @escaping @MainActor (UserProfile) -> Void,
        onSignOut: @escaping () -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: ProfileViewModel(
                profile: profile,
                mode: .profile,
                onPersistProfile: onPersistProfile
            )
        )
        self.onProfileSaved = onProfileSaved
        self.onSignOut = onSignOut
    }

    private let onProfileSaved: @MainActor (UserProfile) -> Void

    var body: some View {
        NavigationStack {
            ProfileEditorScreen(
                viewModel: viewModel,
                showsSignOutButton: true,
                onProfileSaved: onProfileSaved,
                onSignOut: onSignOut
            )
                .navigationTitle(viewModel.title)
        }
        .accessibilityIdentifier("profile.root")
    }
}

struct ProfileCompletionView: View {
    @StateObject private var viewModel: ProfileViewModel
    let onSignOut: () -> Void

    init(
        profile: UserProfile,
        onPersistProfile: @escaping @MainActor (UserProfile) async throws -> UserProfile,
        onSignOut: @escaping () -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: ProfileViewModel(
                profile: profile,
                mode: .onboarding,
                onPersistProfile: onPersistProfile
            )
        )
        self.onSignOut = onSignOut
    }

    var body: some View {
        NavigationStack {
            ProfileEditorScreen(
                viewModel: viewModel,
                showsSignOutButton: false,
                onProfileSaved: nil,
                onSignOut: onSignOut
            )
                .navigationTitle(viewModel.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Salir") {
                            onSignOut()
                        }
                    }
                }
        }
        .interactiveDismissDisabled()
        .accessibilityIdentifier("profile.completion.root")
    }
}

private struct ProfileEditorScreen: View {
    @ObservedObject var viewModel: ProfileViewModel
    let showsSignOutButton: Bool
    let onProfileSaved: (@MainActor (UserProfile) -> Void)?
    let onSignOut: () -> Void
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        Form {
            Section {
                HStack(alignment: .center, spacing: 16) {
                    ProfileAvatarPicker(
                        imageData: viewModel.avatarImageData,
                        imageURL: viewModel.avatarDisplayURL,
                        selectedPhotoItem: $selectedPhotoItem
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Text(viewModel.statusTitle)
                            .font(.headline)

                        Text(viewModel.statusDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(viewModel.introText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 6)
            }

            Section("Datos base") {
                TextField(viewModel.displayNameLabel, text: $viewModel.displayName)
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("profile.displayNameField")

                TextField("Ciudad", text: $viewModel.city)
                    .textContentType(.addressCity)
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("profile.cityField")

                if viewModel.profile.role == .venue {
                    TextField("Direccion", text: $viewModel.venueAddress)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("profile.venueAddressField")
                }
            }

            if viewModel.profile.role == .musician {
                Section("Generos") {
                    ForEach(viewModel.genreOptions, id: \.self) { option in
                        ProfileSelectionRow(
                            title: option,
                            isSelected: viewModel.isGenreSelected(option),
                            action: { viewModel.toggleGenre(option) }
                        )
                    }
                    Text("Elige los generos principales de tu perfil.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else if viewModel.profile.role == .venue {
                Section("Generos para bandas") {
                    ForEach(viewModel.genreOptions, id: \.self) { option in
                        ProfileSelectionRow(
                            title: option,
                            isSelected: viewModel.isGenreSelected(option),
                            action: { viewModel.toggleGenre(option) }
                        )
                    }
                    Text("Usamos esta seccion para priorizar bandas y proyectos en directo.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Generos para DJs") {
                    ForEach(viewModel.venueDJGenreOptions, id: \.self) { option in
                        ProfileSelectionRow(
                            title: option,
                            isSelected: viewModel.isVenueDJGenreSelected(option),
                            action: { viewModel.toggleVenueDJGenre(option) }
                        )
                    }
                    Text("Usamos esta seccion para priorizar perfiles DJ y sesiones de club.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if viewModel.profile.role == .musician {
                Section("Formacion") {
                    ForEach(viewModel.musicianFormationOptions, id: \.self) { option in
                        ProfileSelectionRow(
                            title: option,
                            isSelected: viewModel.isFormationSelected(option),
                            action: { viewModel.toggleFormation(option) }
                        )
                    }

                    Text("Elige una sola opcion: solista, duo, trio o banda.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Instrumentos") {
                    ForEach(viewModel.musicianInstrumentOptions, id: \.self) { option in
                        MusicianInstrumentRow(
                            title: option,
                            isSelected: viewModel.isInstrumentSelected(option),
                            count: viewModel.instrumentCount(for: option),
                            onToggle: { viewModel.toggleInstrument(option) },
                            onDecrease: { viewModel.decreaseInstrumentCount(for: option) },
                            onIncrease: { viewModel.increaseInstrumentCount(for: option) }
                        )
                    }
                }
            } else if viewModel.profile.role == .dj {
                Section("Formato / Setup") {
                    ForEach(viewModel.djDetailOptions, id: \.self) { option in
                        ProfileSelectionRow(
                            title: option,
                            isSelected: viewModel.isDetailSelected(option),
                            action: { viewModel.toggleDetail(option) }
                        )
                    }
                }
            } else {
                Section("Aforo") {
                    TextField(viewModel.detailsPlaceholder, text: $viewModel.venueCapacityText)
                        .keyboardType(.numberPad)
                    Text(viewModel.detailsHelperText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Bio") {
                TextField("Describe brevemente tu propuesta", text: $viewModel.bio, axis: .vertical)
                    .lineLimit(4...7)
                    .accessibilityIdentifier("profile.bioField")
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if showsSignOutButton {
                Section {
                    Button(role: .destructive) {
                        onSignOut()
                    } label: {
                        Label("Cerrar sesion", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
        }
        .accessibilityIdentifier("profile.editor")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else {
                return
            }

            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        viewModel.setAvatarImageData(data)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()

                Button {
                    handleSaveTap()
                } label: {
                    HStack {
                        if viewModel.isSaving {
                            ProgressView()
                                .tint(.white)
                        }

                        if viewModel.showsSaveConfirmation {
                            Image(systemName: "checkmark.circle.fill")
                        }

                        Text(viewModel.buttonTitle)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.showsSaveConfirmation ? .green : .accentColor)
                .controlSize(.large)
                .disabled(viewModel.isSaving || !viewModel.canSave)
                .accessibilityIdentifier("profile.saveButton")
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.bar)
            }
        }
    }

    private func handleSaveTap() {
        Task { @MainActor in
            guard let savedProfile = await viewModel.save() else {
                return
            }

            await Task.yield()
            onProfileSaved?(savedProfile)
        }
    }
}

private struct ProfileAvatarPicker: View {
    let imageData: Data?
    let imageURL: URL?
    @Binding var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else if let imageURL {
                        AsyncImage(url: imageURL) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                avatarPlaceholder(showProgress: phase.error == nil)
                            }
                        }
                    } else {
                        avatarPlaceholder(showProgress: false)
                    }
                }
                .frame(width: 88, height: 88)
                .clipShape(Circle())

                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: "camera.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    .offset(x: -2, y: -2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("profile.avatarPicker")
    }

    private func avatarPlaceholder(showProgress: Bool) -> some View {
        Circle()
            .fill(Color(.secondarySystemBackground))
            .overlay {
                if showProgress {
                    ProgressView()
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 46))
                        .foregroundStyle(.secondary)
                }
            }
    }
}

private struct ProfileSelectionRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

                Text(title)
                    .foregroundStyle(.primary)

                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

private struct MusicianInstrumentRow: View {
    let title: String
    let isSelected: Bool
    let count: Int
    let onToggle: () -> Void
    let onDecrease: () -> Void
    let onIncrease: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

                    Text(title)
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            if isSelected {
                HStack(spacing: 10) {
                    Button(action: onDecrease) {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.plain)

                    Text("\(count)")
                        .font(.subheadline.weight(.semibold))
                        .frame(minWidth: 18)

                    Button(action: onIncrease) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(Color.accentColor)
            }
        }
    }
}
