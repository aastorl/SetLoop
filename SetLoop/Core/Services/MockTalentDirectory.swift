import Foundation

struct MockTalentDirectory {
    private let accountsKey = "setloop.mock.accounts"
    private let userDefaults: UserDefaults
    private let decoder: JSONDecoder
    private let seedProfiles: [UserProfile]

    init(
        userDefaults: UserDefaults = .standard,
        decoder: JSONDecoder = .supabase,
        seedProfiles: [UserProfile] = MockExploreData.musicians
    ) {
        self.userDefaults = userDefaults
        self.decoder = decoder
        self.seedProfiles = seedProfiles
    }

    func allTalent(excluding excludedUserID: UUID? = nil) -> [UserProfile] {
        var profilesByID = Dictionary(
            uniqueKeysWithValues: seedProfiles.map { ($0.id, $0) }
        )

        for profile in persistedTalent() {
            profilesByID[profile.id] = profile
        }

        if let excludedUserID {
            profilesByID.removeValue(forKey: excludedUserID)
        }

        return profilesByID.values.sorted { lhs, rhs in
            if lhs.isPremium != rhs.isPremium {
                return lhs.isPremium && !rhs.isPremium
            }

            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    func musician(id: UUID) -> UserProfile? {
        allTalent().first { $0.id == id }
    }

    private func persistedTalent() -> [UserProfile] {
        guard let data = userDefaults.data(forKey: accountsKey),
              let accounts = try? decoder.decode([MockTalentAccount].self, from: data) else {
            return []
        }

        return accounts
            .map(\.profile)
            .filter { $0.role == .musician || $0.role == .dj }
    }
}

private struct MockTalentAccount: Codable {
    let profile: UserProfile
    let password: String
}
