import Foundation
import Combine

@MainActor
final class VenueStore: ObservableObject {
    private let venuesKey = "setloop.mock.venues"
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder.supabase
    private let decoder = JSONDecoder.supabase

    @Published private(set) var venues: [Venue] {
        didSet {
            persistVenues()
        }
    }

    init(
        userDefaults: UserDefaults = .standard,
        seedVenues: [Venue] = MockExploreData.venues
    ) {
        self.userDefaults = userDefaults

        if let persistedVenues = Self.loadPersistedVenues(from: userDefaults, using: decoder) {
            self.venues = persistedVenues
        } else {
            self.venues = seedVenues.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    func venue(id: UUID) -> Venue? {
        venues.first { $0.id == id }
    }

    func venue(for ownerID: UUID) -> Venue? {
        venues.first { $0.ownerID == ownerID }
    }

    @discardableResult
    func syncHostedVenue(using profile: UserProfile) -> Venue? {
        guard profile.role == .venue else {
            return nil
        }

        let existingVenue = venue(for: profile.id)
        let allGenres = Array(Set(profile.venueBandGenres + profile.venueDJGenres)).sorted()
        let now = Date()

        let venue = Venue(
            id: existingVenue?.id ?? UUID(),
            ownerID: profile.id,
            name: profile.displayName,
            city: profile.city,
            address: profile.venueAddressText.isEmpty == false
                ? profile.venueAddressText
                : (existingVenue?.address ?? "Direccion por confirmar"),
            capacity: profile.venueCapacity,
            description: profile.bioText.isEmpty ? nil : profile.bioText,
            genres: allGenres,
            imageURL: profile.avatarURL,
            latitude: existingVenue?.latitude,
            longitude: existingVenue?.longitude,
            isVerified: existingVenue?.isVerified ?? false,
            createdAt: existingVenue?.createdAt ?? now,
            updatedAt: now
        )

        upsert(venue)
        return venue
    }

    @discardableResult
    func upsert(_ venue: Venue) -> Venue {
        if let index = venues.firstIndex(where: { $0.id == venue.id }) {
            venues[index] = venue
        } else if let ownerIndex = venues.firstIndex(where: { $0.ownerID == venue.ownerID }) {
            venues[ownerIndex] = venue
        } else {
            venues.append(venue)
        }

        venues.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return venue
    }

    private func persistVenues() {
        guard let data = try? encoder.encode(venues) else {
            return
        }

        userDefaults.set(data, forKey: venuesKey)
    }

    private static func loadPersistedVenues(
        from userDefaults: UserDefaults,
        using decoder: JSONDecoder
    ) -> [Venue]? {
        guard let data = userDefaults.data(forKey: "setloop.mock.venues"),
              let venues = try? decoder.decode([Venue].self, from: data) else {
            return nil
        }

        return venues.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
