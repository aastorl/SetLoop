import Foundation
import Combine

@MainActor
final class GigStore: ObservableObject {
    private let gigsKey = "setloop.mock.gigs"
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder.supabase
    private let decoder = JSONDecoder.supabase

    @Published private(set) var gigs: [Gig] {
        didSet {
            persistGigs()
        }
    }

    init(
        userDefaults: UserDefaults = .standard,
        seedGigs: [Gig]? = nil
    ) {
        self.userDefaults = userDefaults
        let resolvedSeedGigs = seedGigs ?? MockExploreData.gigs

        if let persistedGigs = Self.loadPersistedGigs(from: userDefaults, using: decoder) {
            self.gigs = persistedGigs
        } else {
            self.gigs = resolvedSeedGigs.sorted { $0.performanceDate < $1.performanceDate }
        }
    }

    func gig(id: UUID) -> Gig? {
        gigs.first { $0.id == id }
    }

    func gigs(for hostUserID: UUID) -> [Gig] {
        gigs
            .filter { $0.hostUserID == hostUserID }
            .sorted { $0.performanceDate < $1.performanceDate }
    }

    func openGigs(for role: UserRole) -> [Gig] {
        gigs
            .filter { $0.status == .open && $0.roleNeeded == role }
            .sorted { $0.performanceDate < $1.performanceDate }
    }

    @discardableResult
    func upsert(_ gig: Gig) -> Gig {
        if let existingIndex = gigs.firstIndex(where: { $0.id == gig.id }) {
            gigs[existingIndex] = gig
        } else {
            gigs.append(gig)
        }

        gigs.sort { $0.performanceDate < $1.performanceDate }
        return gig
    }

    @discardableResult
    func updateStatus(gigID: UUID, status: GigStatus) -> Gig? {
        guard let index = gigs.firstIndex(where: { $0.id == gigID }) else {
            return nil
        }

        guard gigs[index].status != status else {
            return gigs[index]
        }

        gigs[index].status = status
        gigs[index].updatedAt = Date()
        gigs.sort { $0.performanceDate < $1.performanceDate }
        return gigs.first { $0.id == gigID }
    }

    func syncHostedGigMetadata(using profile: UserProfile, venue: Venue?) {
        guard profile.role == .venue else {
            return
        }

        let expectedVenueID = venue?.id
        let expectedVenueName = venue?.name ?? profile.displayName
        let expectedCity = venue?.city ?? profile.city

        var didChange = false

        for index in gigs.indices where gigs[index].hostUserID == profile.id {
            var itemDidChange = false

            if gigs[index].venueID != expectedVenueID {
                gigs[index].venueID = expectedVenueID
                itemDidChange = true
            }

            if gigs[index].venueName != expectedVenueName {
                gigs[index].venueName = expectedVenueName
                itemDidChange = true
            }

            if gigs[index].city != expectedCity {
                gigs[index].city = expectedCity
                itemDidChange = true
            }

            if itemDidChange {
                gigs[index].updatedAt = Date()
                didChange = true
            }
        }

        if didChange {
            gigs.sort { $0.performanceDate < $1.performanceDate }
        }
    }

    private func persistGigs() {
        guard let data = try? encoder.encode(gigs) else {
            return
        }

        userDefaults.set(data, forKey: gigsKey)
    }

    private static func loadPersistedGigs(from userDefaults: UserDefaults, using decoder: JSONDecoder) -> [Gig]? {
        guard let data = userDefaults.data(forKey: "setloop.mock.gigs"),
              let gigs = try? decoder.decode([Gig].self, from: data) else {
            return nil
        }

        return gigs.sorted { $0.performanceDate < $1.performanceDate }
    }
}
