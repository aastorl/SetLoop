import SwiftUI
import PhotosUI
import UIKit

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
    @FocusState private var focusedField: ProfileEditorField?

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
                    .focused($focusedField, equals: .displayName)
                    .accessibilityIdentifier("profile.displayNameField")

                TextField("Ciudad", text: $viewModel.city)
                    .textContentType(.addressCity)
                    .textInputAutocapitalization(.words)
                    .focused($focusedField, equals: .city)
                    .accessibilityIdentifier("profile.cityField")

                if viewModel.profile.role == .venue {
                    TextField("Direccion", text: $viewModel.venueAddress)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .venueAddress)
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
                        .focused($focusedField, equals: .venueCapacity)
                    Text(viewModel.detailsHelperText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Bio") {
                TextField("Describe brevemente tu propuesta", text: $viewModel.bio, axis: .vertical)
                    .lineLimit(4...7)
                    .focused($focusedField, equals: .bio)
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
        .scrollDismissesKeyboard(.interactively)
        .background {
            KeyboardDismissTapRecognizer {
                dismissKeyboard()
            }
        }
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
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
            }
            .background(.bar)
        }
    }

    private func handleSaveTap() {
        dismissKeyboard()

        Task { @MainActor in
            guard let savedProfile = await viewModel.save() else {
                return
            }

            await Task.yield()
            onProfileSaved?(savedProfile)
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

private enum ProfileEditorField: Hashable {
    case displayName
    case city
    case venueAddress
    case venueCapacity
    case bio
}

private struct KeyboardDismissTapRecognizer: UIViewRepresentable {
    let onTapOutsideInput: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTapOutsideInput: onTapOutsideInput)
    }

    func makeUIView(context: Context) -> WindowObserverView {
        let view = WindowObserverView()
        view.onWindowChange = { [weak coordinator = context.coordinator] window in
            coordinator?.attach(to: window)
        }
        return view
    }

    func updateUIView(_ uiView: WindowObserverView, context: Context) {
        context.coordinator.onTapOutsideInput = onTapOutsideInput
    }

    static func dismantleUIView(_ uiView: WindowObserverView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class WindowObserverView: UIView {
        var onWindowChange: ((UIWindow?) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            onWindowChange?(window)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onTapOutsideInput: () -> Void
        private weak var window: UIWindow?
        private weak var recognizer: UITapGestureRecognizer?

        init(onTapOutsideInput: @escaping () -> Void) {
            self.onTapOutsideInput = onTapOutsideInput
        }

        func attach(to window: UIWindow?) {
            guard let window else {
                detach()
                return
            }

            guard self.window !== window else {
                return
            }

            detach()

            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            window.addGestureRecognizer(recognizer)

            self.window = window
            self.recognizer = recognizer
        }

        func detach() {
            if let recognizer, let window {
                window.removeGestureRecognizer(recognizer)
            }

            recognizer = nil
            window = nil
        }

        @objc private func handleTap() {
            onTapOutsideInput()
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            isTextInput(touch.view) == false
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        private func isTextInput(_ view: UIView?) -> Bool {
            var currentView = view

            while let candidate = currentView {
                if candidate is UITextField || candidate is UITextView {
                    return true
                }

                currentView = candidate.superview
            }

            return false
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
