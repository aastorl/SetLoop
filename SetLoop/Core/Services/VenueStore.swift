import Foundation
import Combine

@MainActor
final class VenueStore: ObservableObject {
    private let venuesKey = "setloop.mock.venues"
    private let userDefaults: UserDefaults
    private let remoteService: VenueGigRemoteServicing?
    private let encoder = JSONEncoder.supabase
    private let decoder = JSONDecoder.supabase

    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    @Published private(set) var venues: [Venue] {
        didSet {
            if remoteService == nil {
                persistVenues()
            }
        }
    }

    init(
        userDefaults: UserDefaults = .standard,
        seedVenues: [Venue]? = nil,
        remoteService: VenueGigRemoteServicing? = nil
    ) {
        self.userDefaults = userDefaults
        self.remoteService = remoteService
        let resolvedSeedVenues = seedVenues ?? MockExploreData.venues

        if remoteService != nil {
            self.venues = []
        } else if let persistedVenues = Self.loadPersistedVenues(from: userDefaults, using: decoder) {
            self.venues = persistedVenues
        } else {
            self.venues = resolvedSeedVenues.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
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

        let venue = makeHostedVenue(using: profile, existingVenue: venue(for: profile.id))
        upsert(venue)
        return venue
    }

    @discardableResult
    func saveHostedVenue(using profile: UserProfile) async throws -> Venue? {
        guard profile.role == .venue else {
            return nil
        }

        guard let remoteService else {
            return syncHostedVenue(using: profile)
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let remoteVenue = try await remoteService.fetchVenue(ownerID: profile.id)
            let venue = makeHostedVenue(
                using: profile,
                existingVenue: remoteVenue ?? venue(for: profile.id)
            )
            let savedVenue = try await remoteService.saveVenue(venue)
            errorMessage = nil
            upsert(savedVenue)
            return savedVenue
        } catch {
            errorMessage = error.setLoopUserMessage
            throw error
        }
    }

    func loadAll() async throws {
        guard let remoteService else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            venues = try await remoteService.fetchVenues()
            errorMessage = nil
        } catch {
            errorMessage = error.setLoopUserMessage
            throw error
        }
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

    private func makeHostedVenue(using profile: UserProfile, existingVenue: Venue?) -> Venue {
        let allGenres = Array(Set(profile.venueBandGenres + profile.venueDJGenres)).sorted()
        let now = Date()

        return Venue(
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
