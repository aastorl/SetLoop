import SwiftUI

@MainActor
struct MainTabView: View {
    @State private var currentProfile: UserProfile
    let onPersistProfile: @MainActor (UserProfile) async throws -> UserProfile
    let onSignOut: () -> Void

    @StateObject private var gigStore: GigStore
    @StateObject private var venueStore: VenueStore
    @StateObject private var notificationStore: NotificationStore
    @StateObject private var applicationStore: ApplicationStore
    private let detailService: ExploreDetailServicing

    init(
        profile: UserProfile,
        onPersistProfile: @escaping @MainActor (UserProfile) async throws -> UserProfile,
        onSignOut: @escaping () -> Void
    ) {
        let venueGigService = SupabaseVenueGigService()
        let bookingService = SupabaseBookingService()
        let notificationService = SupabaseNotificationService()
        let gigStore = GigStore(seedGigs: [], remoteService: venueGigService)
        let venueStore = VenueStore(seedVenues: [], remoteService: venueGigService)
        let detailService = StoreBackedExploreDetailService(
            gigStore: gigStore,
            venueStore: venueStore
        )
        self._currentProfile = State(initialValue: profile)
        self.onPersistProfile = onPersistProfile
        self.detailService = detailService
        self.onSignOut = onSignOut
        _gigStore = StateObject(wrappedValue: gigStore)
        _venueStore = StateObject(wrappedValue: venueStore)
        let notificationStore = NotificationStore(remoteService: notificationService)
        _notificationStore = StateObject(wrappedValue: notificationStore)
        _applicationStore = StateObject(
            wrappedValue: ApplicationStore(
                gigStore: gigStore,
                notificationStore: notificationStore,
                remoteService: bookingService
            )
        )
        let hostedVenue = venueStore.syncHostedVenue(using: profile)
        gigStore.syncHostedGigMetadata(using: profile, venue: hostedVenue)
    }

    init(
        profile: UserProfile,
        detailService: ExploreDetailServicing,
        onPersistProfile: @escaping @MainActor (UserProfile) async throws -> UserProfile,
        onSignOut: @escaping () -> Void
    ) {
        let venueGigService = SupabaseVenueGigService()
        let bookingService = SupabaseBookingService()
        let notificationService = SupabaseNotificationService()
        let gigStore = GigStore(seedGigs: [], remoteService: venueGigService)
        let venueStore = VenueStore(seedVenues: [], remoteService: venueGigService)
        self._currentProfile = State(initialValue: profile)
        self.onPersistProfile = onPersistProfile
        self.detailService = detailService
        self.onSignOut = onSignOut
        _gigStore = StateObject(wrappedValue: gigStore)
        _venueStore = StateObject(wrappedValue: venueStore)
        let notificationStore = NotificationStore(remoteService: notificationService)
        _notificationStore = StateObject(wrappedValue: notificationStore)
        _applicationStore = StateObject(
            wrappedValue: ApplicationStore(
                gigStore: gigStore,
                notificationStore: notificationStore,
                remoteService: bookingService
            )
        )
    }

    var body: some View {
        TabView {
            primaryTab
                .tabItem {
                    Label(primaryTabTitle, systemImage: primaryTabSystemImage)
                }

            BookingView(
                currentProfile: currentProfile,
                applicationStore: applicationStore,
                gigStore: gigStore
            )
                .tabItem {
                    Label("Candidaturas", systemImage: "tray.full")
                }

            NotificationsView(
                currentProfile: currentProfile,
                notificationStore: notificationStore
            )
                .tabItem {
                    Label("Avisos", systemImage: "bell")
                }
                .badge(notificationStore.unreadCount(for: currentProfile.id))

            ProfileView(
                profile: currentProfile,
                onPersistProfile: onPersistProfile,
                onProfileSaved: updateProfileState,
                onSignOut: onSignOut
            )
                .tabItem {
                    Label("Perfil", systemImage: "person.crop.circle")
                }
        }
        .accessibilityIdentifier("main.tabView")
        .task(id: currentProfile.renderIdentity) {
            await loadVenueGigData()
        }
    }

    @MainActor
    private func updateProfileState(_ profile: UserProfile) {
        currentProfile = profile
        let hostedVenue = venueStore.syncHostedVenue(using: profile)
        gigStore.syncHostedGigMetadata(using: profile, venue: hostedVenue)
    }

    private func loadVenueGigData() async {
        let profile = currentProfile

        if profile.role == .venue {
            await performDataLoad {
                _ = try await venueStore.saveHostedVenue(using: profile)
            }
        }

        await performDataLoad {
            try await venueStore.loadAll()
        }

        await performDataLoad {
            try await gigStore.loadAll()
        }

        await performDataLoad {
            try await applicationStore.loadAll()
        }

        await performDataLoad {
            try await notificationStore.load(for: profile.id)
        }
    }

    private func performDataLoad(_ operation: () async throws -> Void) async {
        do {
            try await operation()
        } catch {
            // Store-level errorMessage drives the visible error state in each tab.
        }
    }

    @ViewBuilder
    private var primaryTab: some View {
        if currentProfile.role == .venue {
            NavigationStack {
                VenueGigsView(
                    viewModel: VenueGigsViewModel(
                        currentProfile: currentProfile,
                        gigStore: gigStore,
                        venueStore: venueStore,
                        applicationStore: applicationStore
                    )
                )
            }
        } else {
            ExploreView(
                currentProfile: currentProfile,
                detailService: detailService,
                gigStore: gigStore,
                venueStore: venueStore,
                applicationStore: applicationStore
            )
        }
    }

    private var primaryTabTitle: String {
        currentProfile.role == .venue ? "Fechas" : "Explorar"
    }

    private var primaryTabSystemImage: String {
        currentProfile.role == .venue ? "calendar.badge.clock" : "magnifyingglass"
    }
}
