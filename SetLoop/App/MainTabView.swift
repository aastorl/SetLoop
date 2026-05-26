import SwiftUI

@MainActor
struct MainTabView: View {
    @State private var currentProfile: UserProfile
    let onPersistProfile: @MainActor (UserProfile) async throws -> UserProfile
    let onSignOut: () -> Void

    @StateObject private var gigStore: GigStore
    @StateObject private var venueStore: VenueStore
    @StateObject private var reviewStore: ReviewStore
    @StateObject private var notificationStore: NotificationStore
    @StateObject private var applicationStore: ApplicationStore
    @StateObject private var inviteStore: InviteStore
    private let detailService: ExploreDetailServicing
    private let talentDirectory: MockTalentDirectory

    init(
        profile: UserProfile,
        onPersistProfile: @escaping @MainActor (UserProfile) async throws -> UserProfile,
        onSignOut: @escaping () -> Void
    ) {
        let gigStore = GigStore()
        let venueStore = VenueStore()
        let reviewStore = ReviewStore()
        let talentDirectory = MockTalentDirectory()
        let detailService = StoreBackedExploreDetailService(
            gigStore: gigStore,
            venueStore: venueStore,
            talentDirectory: talentDirectory
        )
        self._currentProfile = State(initialValue: profile)
        self.onPersistProfile = onPersistProfile
        self.detailService = detailService
        self.talentDirectory = talentDirectory
        self.onSignOut = onSignOut
        _gigStore = StateObject(wrappedValue: gigStore)
        _venueStore = StateObject(wrappedValue: venueStore)
        _reviewStore = StateObject(wrappedValue: reviewStore)
        let notificationStore = NotificationStore()
        _notificationStore = StateObject(wrappedValue: notificationStore)
        _applicationStore = StateObject(
            wrappedValue: ApplicationStore(
                gigStore: gigStore,
                notificationStore: notificationStore
            )
        )
        _inviteStore = StateObject(
            wrappedValue: InviteStore(
                gigStore: gigStore,
                notificationStore: notificationStore
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
        let gigStore = GigStore()
        let venueStore = VenueStore()
        let reviewStore = ReviewStore()
        let talentDirectory = MockTalentDirectory()
        self._currentProfile = State(initialValue: profile)
        self.onPersistProfile = onPersistProfile
        self.detailService = detailService
        self.talentDirectory = talentDirectory
        self.onSignOut = onSignOut
        _gigStore = StateObject(wrappedValue: gigStore)
        _venueStore = StateObject(wrappedValue: venueStore)
        _reviewStore = StateObject(wrappedValue: reviewStore)
        let notificationStore = NotificationStore()
        _notificationStore = StateObject(wrappedValue: notificationStore)
        _applicationStore = StateObject(
            wrappedValue: ApplicationStore(
                gigStore: gigStore,
                notificationStore: notificationStore
            )
        )
        _inviteStore = StateObject(
            wrappedValue: InviteStore(
                gigStore: gigStore,
                notificationStore: notificationStore
            )
        )
    }

    var body: some View {
        TabView {
            ExploreView(
                currentProfile: currentProfile,
                detailService: detailService,
                gigStore: gigStore,
                venueStore: venueStore,
                reviewStore: reviewStore,
                talentDirectory: talentDirectory,
                inviteStore: inviteStore
            )
                .environmentObject(applicationStore)
                .tabItem {
                    Label("Explorar", systemImage: "magnifyingglass")
                }

            BookingView(
                currentProfile: currentProfile,
                applicationStore: applicationStore,
                inviteStore: inviteStore,
                gigStore: gigStore
            )
                .tabItem {
                    Label("Booking", systemImage: "calendar")
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
    }

    @MainActor
    private func updateProfileState(_ profile: UserProfile) {
        currentProfile = profile
        let hostedVenue = venueStore.syncHostedVenue(using: profile)
        gigStore.syncHostedGigMetadata(using: profile, venue: hostedVenue)
    }
}
