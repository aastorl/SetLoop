import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    enum Mode {
        case onboarding
        case profile
    }

    @Published private(set) var profile: UserProfile
    @Published var displayName: String
    @Published var city: String
    @Published var venueAddress: String
    @Published var selectedGenres: [String]
    @Published var selectedVenueDJGenres: [String]
    @Published var selectedMusicianFormations: [String]
    @Published var selectedMusicianInstruments: [String]
    @Published var musicianInstrumentCounts: [String: Int]
    @Published var selectedDJDetails: [String]
    @Published var venueCapacityText: String
    @Published var bio: String
    @Published var avatarImageData: Data?
    @Published private(set) var isSaving = false
    @Published private(set) var lastSavedAt: Date?
    @Published var errorMessage: String?

    let mode: Mode

    private let onPersistProfile: @MainActor (UserProfile) async throws -> UserProfile
    private let avatarStorage: AvatarStoring
    private var persistedAvatarImageData: Data?

    init(
        profile: UserProfile,
        mode: Mode,
        onPersistProfile: @escaping @MainActor (UserProfile) async throws -> UserProfile,
        avatarStorage: AvatarStoring? = nil
    ) {
        let resolvedAvatarStorage = avatarStorage ?? AvatarStorageFactory.make()
        self.profile = profile
        self.mode = mode
        self.onPersistProfile = onPersistProfile
        self.avatarStorage = resolvedAvatarStorage
        self.displayName = profile.displayName
        self.city = profile.city
        self.venueAddress = profile.venueAddressText
        self.selectedGenres = profile.genres
        self.selectedVenueDJGenres = profile.role == .venue ? profile.instruments : []
        self.selectedMusicianFormations = profile.instruments.filter { ProfileOptionCatalog.musicianFormationOptions.contains($0) }
        self.selectedMusicianInstruments = profile.instruments.filter { ProfileOptionCatalog.musicianInstrumentOptions.contains($0) }
        self.musicianInstrumentCounts = profile.instrumentCounts
        self.selectedDJDetails = profile.instruments
        self.venueCapacityText = profile.venueCapacity.map(String.init) ?? ""
        self.bio = profile.bioText
        let persistedAvatarData = resolvedAvatarStorage.loadImageData(from: profile.avatarURL)
        self.avatarImageData = persistedAvatarData
        self.persistedAvatarImageData = persistedAvatarData
    }

    var title: String {
        switch mode {
        case .onboarding:
            return "Completa tu perfil"
        case .profile:
            return "Perfil"
        }
    }

    var primaryActionTitle: String {
        switch mode {
        case .onboarding:
            return "Continuar"
        case .profile:
            return "Guardar cambios"
        }
    }

    var buttonTitle: String {
        guard mode == .profile, showsSaveConfirmation else {
            return primaryActionTitle
        }

        return "Guardado"
    }

    var showsSaveConfirmation: Bool {
        mode == .profile && lastSavedAt != nil && hasPendingChanges == false
    }

    var avatarDisplayURL: URL? {
        avatarImageData == nil ? profile.avatarURL : nil
    }

    var introText: String {
        switch mode {
        case .onboarding:
            return "La home y los resultados se ajustan a tu ciudad, generos y datos clave."
        case .profile:
            return "Tu home usa este perfil para priorizar fechas y avisos relevantes."
        }
    }

    var statusTitle: String {
        draftProfile.isProfileComplete ? "Perfil completo" : "Perfil incompleto"
    }

    var statusDescription: String {
        if draftProfile.isProfileComplete {
            return "Tu cuenta ya tiene la informacion minima para personalizar Explore."
        }

        return "Faltan: \(draftProfile.missingProfileRequirements.joined(separator: ", "))."
    }

    var displayNameLabel: String {
        profile.role == .venue ? "Nombre del local o promotora" : "Nombre publico"
    }

    var detailsLabel: String {
        switch profile.role {
        case .musician:
            return "Instrumentos o formacion"
        case .dj:
            return "Setup o formato"
        case .venue:
            return "Aforo"
        }
    }

    var detailsPlaceholder: String {
        switch profile.role {
        case .musician:
            return "Selecciona una o varias opciones"
        case .dj:
            return "Selecciona una o varias opciones"
        case .venue:
            return "220"
        }
    }

    var detailsHelperText: String {
        switch profile.role {
        case .musician:
            return "Marca la formacion o instrumentos principales."
        case .dj:
            return "Marca el formato de set o el setup principal."
        case .venue:
            return "Indica el aforo aproximado en personas."
        }
    }

    var genreOptions: [String] {
        mergedOptions(base: ProfileOptionCatalog.genreOptions, selected: selectedGenres)
    }

    var venueDJGenreOptions: [String] {
        mergedOptions(base: ProfileOptionCatalog.venueDJGenreOptions, selected: selectedVenueDJGenres)
    }

    var musicianFormationOptions: [String] {
        mergedOptions(base: ProfileOptionCatalog.musicianFormationOptions, selected: selectedMusicianFormations)
    }

    var musicianInstrumentOptions: [String] {
        mergedOptions(base: ProfileOptionCatalog.musicianInstrumentOptions, selected: selectedMusicianInstruments)
    }

    var djDetailOptions: [String] {
        mergedOptions(base: ProfileOptionCatalog.djDetailOptions, selected: selectedDJDetails)
    }

    var canSave: Bool {
        draftProfile.isProfileComplete && (mode == .onboarding || hasPendingChanges)
    }

    func save() async -> UserProfile? {
        guard canSave else {
            return nil
        }

        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        do {
            var profileToSave = draftProfile
            let avatarDataToPersist = avatarImageData != persistedAvatarImageData ? avatarImageData : nil
            profileToSave.avatarURL = try await avatarStorage.persistImageData(
                avatarDataToPersist,
                for: profile.id,
                existingURL: profile.avatarURL
            )

            let savedProfile = try await onPersistProfile(profileToSave)
            profile = savedProfile
            displayName = savedProfile.displayName
            city = savedProfile.city
            venueAddress = savedProfile.venueAddressText
            selectedGenres = savedProfile.genres
            selectedVenueDJGenres = savedProfile.role == .venue ? savedProfile.instruments : []
            selectedMusicianFormations = savedProfile.instruments.filter { ProfileOptionCatalog.musicianFormationOptions.contains($0) }
            selectedMusicianInstruments = savedProfile.instruments.filter { ProfileOptionCatalog.musicianInstrumentOptions.contains($0) }
            musicianInstrumentCounts = savedProfile.instrumentCounts
            selectedDJDetails = savedProfile.instruments
            venueCapacityText = savedProfile.venueCapacity.map(String.init) ?? ""
            bio = savedProfile.bioText
            persistedAvatarImageData = avatarImageData
            lastSavedAt = Date()
            return savedProfile
        } catch {
            errorMessage = error.setLoopUserMessage
            return nil
        }
    }

    func apply(profile: UserProfile) {
        self.profile = profile
        displayName = profile.displayName
        city = profile.city
        venueAddress = profile.venueAddressText
        selectedGenres = profile.genres
        selectedVenueDJGenres = profile.role == .venue ? profile.instruments : []
        selectedMusicianFormations = profile.instruments.filter { ProfileOptionCatalog.musicianFormationOptions.contains($0) }
        selectedMusicianInstruments = profile.instruments.filter { ProfileOptionCatalog.musicianInstrumentOptions.contains($0) }
        musicianInstrumentCounts = profile.instrumentCounts
        selectedDJDetails = profile.instruments
        venueCapacityText = profile.venueCapacity.map(String.init) ?? ""
        bio = profile.bioText
        let persistedAvatarData = avatarStorage.loadImageData(from: profile.avatarURL)
        avatarImageData = persistedAvatarData
        persistedAvatarImageData = persistedAvatarData
        lastSavedAt = nil
        errorMessage = nil
    }

    func toggleGenre(_ genre: String) {
        toggle(genre, in: &selectedGenres)
    }

    func toggleVenueDJGenre(_ genre: String) {
        toggle(genre, in: &selectedVenueDJGenres)
    }

    func toggleDetail(_ detail: String) {
        toggle(detail, in: &selectedDJDetails)
    }

    func isGenreSelected(_ genre: String) -> Bool {
        selectedGenres.contains(genre)
    }

    func isVenueDJGenreSelected(_ genre: String) -> Bool {
        selectedVenueDJGenres.contains(genre)
    }

    func isDetailSelected(_ detail: String) -> Bool {
        selectedDJDetails.contains(detail)
    }

    func setAvatarImageData(_ data: Data?) {
        avatarImageData = data
        lastSavedAt = nil
    }

    func toggleFormation(_ formation: String) {
        if selectedMusicianFormations == [formation] {
            selectedMusicianFormations = []
        } else {
            selectedMusicianFormations = [formation]
        }
    }

    func isFormationSelected(_ formation: String) -> Bool {
        selectedMusicianFormations.contains(formation)
    }

    func toggleInstrument(_ instrument: String) {
        if selectedMusicianInstruments.contains(instrument) {
            selectedMusicianInstruments.removeAll { $0 == instrument }
            musicianInstrumentCounts[instrument] = nil
        } else {
            selectedMusicianInstruments.append(instrument)
            musicianInstrumentCounts[instrument] = max(1, musicianInstrumentCounts[instrument] ?? 1)
        }
    }

    func isInstrumentSelected(_ instrument: String) -> Bool {
        selectedMusicianInstruments.contains(instrument)
    }

    func instrumentCount(for instrument: String) -> Int {
        max(1, musicianInstrumentCounts[instrument] ?? 1)
    }

    func increaseInstrumentCount(for instrument: String) {
        guard isInstrumentSelected(instrument) else { return }
        musicianInstrumentCounts[instrument] = instrumentCount(for: instrument) + 1
    }

    func decreaseInstrumentCount(for instrument: String) {
        guard isInstrumentSelected(instrument) else { return }
        let nextValue = max(1, instrumentCount(for: instrument) - 1)
        musicianInstrumentCounts[instrument] = nextValue
    }

    private var parsedVenueCapacity: Int? {
        Int(venueCapacityText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var hasPendingChanges: Bool {
        normalizedDraftProfile != normalizedPersistedProfile || avatarImageData != persistedAvatarImageData
    }

    private var draftProfile: UserProfile {
        var updatedProfile = profile
        updatedProfile.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedProfile.city = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedVenueAddress = venueAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedProfile.venueAddress = trimmedVenueAddress.isEmpty ? nil : trimmedVenueAddress
        updatedProfile.bio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedProfile.genres = selectedGenres

        switch updatedProfile.role {
        case .musician:
            updatedProfile.instruments = selectedMusicianFormations + selectedMusicianInstruments
            updatedProfile.instrumentCounts = musicianInstrumentCounts.filter { selectedMusicianInstruments.contains($0.key) }
            updatedProfile.venueCapacity = nil
        case .dj:
            updatedProfile.genres = []
            updatedProfile.instruments = selectedDJDetails
            updatedProfile.instrumentCounts = [:]
            updatedProfile.venueCapacity = nil
        case .venue:
            updatedProfile.instruments = selectedVenueDJGenres
            updatedProfile.instrumentCounts = [:]
            updatedProfile.venueCapacity = parsedVenueCapacity
        }

        updatedProfile.updatedAt = Date()
        return updatedProfile
    }

    private var normalizedDraftProfile: ProfileSnapshot {
        ProfileSnapshot(profile: draftProfile)
    }

    private var normalizedPersistedProfile: ProfileSnapshot {
        ProfileSnapshot(profile: profile)
    }

    private func mergedOptions(base: [String], selected: [String]) -> [String] {
        base + selected.filter { base.contains($0) == false }
    }

    private func toggle(_ value: String, in values: inout [String]) {
        if let index = values.firstIndex(of: value) {
            values.remove(at: index)
        } else {
            values.append(value)
        }
    }
}

private struct ProfileSnapshot: Equatable {
    let displayName: String
    let city: String
    let venueAddress: String
    let bio: String
    let genres: [String]
    let instruments: [String]
    let instrumentCounts: [String: Int]
    let venueCapacity: Int?

    init(profile: UserProfile) {
        displayName = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        city = profile.city.trimmingCharacters(in: .whitespacesAndNewlines)
        venueAddress = profile.venueAddressText
        bio = profile.bioText
        genres = profile.genres
        instruments = profile.instruments
        instrumentCounts = profile.instrumentCounts
        venueCapacity = profile.venueCapacity
    }
}
