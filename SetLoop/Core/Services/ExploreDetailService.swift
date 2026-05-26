import Foundation

@MainActor
protocol ExploreDetailServicing {
    func gig(id: UUID) -> Gig?
    func venue(id: UUID) -> Venue?
    func musician(id: UUID) -> UserProfile?
}

@MainActor
final class MockExploreDetailService: ExploreDetailServicing {
    private let gigsByID: [UUID: Gig]
    private let venuesByID: [UUID: Venue]
    private let musiciansByID: [UUID: UserProfile]

    init(
        gigs: [Gig] = MockExploreData.gigs,
        venues: [Venue] = MockExploreData.venues,
        musicians: [UserProfile] = MockExploreData.musicians
    ) {
        self.gigsByID = Dictionary(uniqueKeysWithValues: gigs.map { ($0.id, $0) })
        self.venuesByID = Dictionary(uniqueKeysWithValues: venues.map { ($0.id, $0) })
        self.musiciansByID = Dictionary(uniqueKeysWithValues: musicians.map { ($0.id, $0) })
    }

    func gig(id: UUID) -> Gig? {
        gigsByID[id]
    }

    func venue(id: UUID) -> Venue? {
        venuesByID[id]
    }

    func musician(id: UUID) -> UserProfile? {
        musiciansByID[id]
    }
}

@MainActor
final class StoreBackedExploreDetailService: ExploreDetailServicing {
    private let gigStore: GigStore
    private let venueStore: VenueStore
    private let talentDirectory: MockTalentDirectory

    init(
        gigStore: GigStore,
        venueStore: VenueStore,
        talentDirectory: MockTalentDirectory
    ) {
        self.gigStore = gigStore
        self.venueStore = venueStore
        self.talentDirectory = talentDirectory
    }

    func gig(id: UUID) -> Gig? {
        gigStore.gig(id: id)
    }

    func venue(id: UUID) -> Venue? {
        venueStore.venue(id: id)
    }

    func musician(id: UUID) -> UserProfile? {
        talentDirectory.musician(id: id)
    }
}
