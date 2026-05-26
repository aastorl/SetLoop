import Foundation

@MainActor
protocol SearchServicing {
    func search(
        filters: ExploreFilters,
        profile: UserProfile,
        venueTalentRole: UserRole?
    ) async throws -> [ExploreCardItem]
}

@MainActor
final class SearchService: SearchServicing {
    private let itemsProvider: () -> [ExploreCardItem]
    private let calendar: Calendar

    init(
        itemsProvider: (() -> [ExploreCardItem])? = nil,
        calendar: Calendar = .current
    ) {
        self.itemsProvider = itemsProvider ?? { MockExploreData.exploreCards }
        self.calendar = calendar
    }

    func search(
        filters: ExploreFilters,
        profile: UserProfile,
        venueTalentRole: UserRole?
    ) async throws -> [ExploreCardItem] {
        let items = itemsProvider()
        let cityQuery = filters.city.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedGenres = Set(
            profile.preferredGenres(for: venueTalentRole).map { $0.lowercased() }
        )

        return items
            .filter { item in
            let matchesRole = matches(item: item, profile: profile, venueTalentRole: venueTalentRole)
            let matchesCity = cityQuery.isEmpty || item.city.localizedCaseInsensitiveContains(cityQuery)
            let matchesDate = filters.date == nil || item.date.map { calendar.isDate($0, inSameDayAs: filters.date!) } == true

            return matchesRole && matchesCity && matchesDate
            }
            .sorted { lhs, rhs in
                let lhsScore = score(item: lhs, profileCity: profile.city, normalizedGenres: normalizedGenres)
                let rhsScore = score(item: rhs, profileCity: profile.city, normalizedGenres: normalizedGenres)

                if lhsScore == rhsScore {
                    switch (lhs.date, rhs.date) {
                    case let (.some(lhsDate), .some(rhsDate)):
                        return lhsDate < rhsDate
                    case (.some, nil):
                        return true
                    case (nil, .some):
                        return false
                    case (nil, nil):
                        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                    }
                }

                return lhsScore > rhsScore
            }
    }

    private func matches(item: ExploreCardItem, profile: UserProfile, venueTalentRole: UserRole?) -> Bool {
        switch profile.role {
        case .musician, .dj:
            return item.kind == .gig && item.role == profile.role
        case .venue:
            let targetRole = venueTalentRole ?? .musician
            return item.kind == .musician && item.role == targetRole
        }
    }

    private func score(item: ExploreCardItem, profileCity: String, normalizedGenres: Set<String>) -> Int {
        var total = 0

        if item.city.caseInsensitiveCompare(profileCity) == .orderedSame {
            total += 3
        }

        let sharedGenres = item.tags.filter { normalizedGenres.contains($0.lowercased()) }.count
        total += sharedGenres * 2

        if let priceText = item.priceText, !priceText.isEmpty {
            total += 1
        }

        return total
    }
}
