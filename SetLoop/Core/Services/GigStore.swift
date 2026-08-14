import Foundation
import Combine

@MainActor
final class GigStore: ObservableObject {
    private let gigsKey = "setloop.mock.gigs"
    private let userDefaults: UserDefaults
    private let remoteService: VenueGigRemoteServicing?
    private let encoder = JSONEncoder.supabase
    private let decoder = JSONDecoder.supabase

    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    @Published private(set) var gigs: [Gig] {
        didSet {
            if remoteService == nil {
                persistGigs()
            }
        }
    }

    init(
        userDefaults: UserDefaults = .standard,
        seedGigs: [Gig]? = nil,
        remoteService: VenueGigRemoteServicing? = nil
    ) {
        self.userDefaults = userDefaults
        self.remoteService = remoteService
        let resolvedSeedGigs = seedGigs ?? MockExploreData.gigs

        if remoteService != nil {
            self.gigs = []
        } else if let persistedGigs = Self.loadPersistedGigs(from: userDefaults, using: decoder) {
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
            .filter { $0.isOpenForApplications() && $0.roleNeeded == role }
            .sorted { $0.performanceDate < $1.performanceDate }
    }

    func loadAll() async throws {
        guard let remoteService else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            gigs = try await remoteService.fetchGigs()
            errorMessage = nil
        } catch {
            errorMessage = error.setLoopUserMessage
            throw error
        }
    }

    func loadGigs(for hostUserID: UUID) async throws {
        guard let remoteService else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let hostGigs = try await remoteService.fetchGigs(hostUserID: hostUserID)
            let hostGigIDs = Set(hostGigs.map(\.id))
            gigs.removeAll { $0.hostUserID == hostUserID && hostGigIDs.contains($0.id) == false }

            for gig in hostGigs {
                upsert(gig)
            }

            errorMessage = nil
        } catch {
            errorMessage = error.setLoopUserMessage
            throw error
        }
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
    func save(_ gig: Gig) async throws -> Gig {
        guard let remoteService else {
            return upsert(gig)
        }

        do {
            let savedGig = try await remoteService.saveGig(gig)
            errorMessage = nil
            upsert(savedGig)
            return savedGig
        } catch {
            errorMessage = error.setLoopUserMessage
            throw error
        }
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

    @discardableResult
    func saveStatus(gigID: UUID, status: GigStatus) async throws -> Gig? {
        guard let remoteService else {
            return updateStatus(gigID: gigID, status: status)
        }

        do {
            let updatedGig = try await remoteService.updateGigStatus(gigID: gigID, status: status)
            errorMessage = nil
            upsert(updatedGig)
            return updatedGig
        } catch {
            errorMessage = error.setLoopUserMessage
            throw error
        }
    }

    func syncHostedGigMetadata(using profile: UserProfile, venue: Venue?) {
        guard profile.role == .venue else {
            return
        }

        let expectedVenueID = venue?.id
        let expectedVenueName = venue?.name ?? profile.displayName
        let expectedCity = venue?.city ?? profile.city
        let expectedImageURL = venue?.imageURL ?? profile.avatarURL

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

            if gigs[index].imageURL != expectedImageURL {
                gigs[index].imageURL = expectedImageURL
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
