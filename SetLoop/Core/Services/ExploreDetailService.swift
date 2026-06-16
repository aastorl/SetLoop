import Foundation

@MainActor
protocol ExploreDetailServicing {
    func gig(id: UUID) -> Gig?
    func venue(id: UUID) -> Venue?
}

@MainActor
final class MockExploreDetailService: ExploreDetailServicing {
    private let gigsByID: [UUID: Gig]
    private let venuesByID: [UUID: Venue]

    init(
        gigs: [Gig]? = nil,
        venues: [Venue]? = nil
    ) {
        let resolvedGigs = gigs ?? MockExploreData.gigs
        let resolvedVenues = venues ?? MockExploreData.venues

        self.gigsByID = Dictionary(uniqueKeysWithValues: resolvedGigs.map { ($0.id, $0) })
        self.venuesByID = Dictionary(uniqueKeysWithValues: resolvedVenues.map { ($0.id, $0) })
    }

    func gig(id: UUID) -> Gig? {
        gigsByID[id]
    }

    func venue(id: UUID) -> Venue? {
        venuesByID[id]
    }
}

@MainActor
final class StoreBackedExploreDetailService: ExploreDetailServicing {
    private let gigStore: GigStore
    private let venueStore: VenueStore

    init(
        gigStore: GigStore,
        venueStore: VenueStore
    ) {
        self.gigStore = gigStore
        self.venueStore = venueStore
    }

    func gig(id: UUID) -> Gig? {
        gigStore.gig(id: id)
    }

    func venue(id: UUID) -> Venue? {
        venueStore.venue(id: id)
    }
}
