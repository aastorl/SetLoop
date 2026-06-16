import Foundation

@MainActor
protocol SearchServicing {
    func search(
        filters: ExploreFilters,
        profile: UserProfile
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
        self.itemsProvider = itemsProvider ?? { [] }
        self.calendar = calendar
    }

    func search(
        filters: ExploreFilters,
        profile: UserProfile
    ) async throws -> [ExploreCardItem] {
        let items = itemsProvider()
        let cityQuery = filters.city.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedGenres = Set(
            profile.preferredGenres().map { $0.lowercased() }
        )

        return items
            .filter { item in
            let matchesRole = matches(item: item, profile: profile)
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

    private func matches(item: ExploreCardItem, profile: UserProfile) -> Bool {
        switch profile.role {
        case .musician, .dj:
            return item.kind == .gig && item.role == profile.role
        case .venue:
            return false
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

enum ExploreCardFactory {
    static func makeCards(
        gigs: [Gig]
    ) -> [ExploreCardItem] {
        gigs
            .filter { $0.status == .open }
            .map { gig in
                ExploreCardItem(
                    id: gig.id,
                    kind: .gig,
                    title: gig.title,
                    subtitle: gig.venueName ?? "Fecha publicada",
                    city: gig.city,
                    detail: "\(gig.durationMinutes ?? 60) min",
                    date: gig.performanceDate,
                    role: gig.roleNeeded,
                    priceText: budgetText(min: gig.budgetMin, max: gig.budgetMax, currency: gig.currency),
                    tags: gig.requiredGenres,
                    imageURL: gig.imageURL,
                    symbolName: "calendar.badge.clock"
                )
            }
    }

    private static func budgetText(min: Int?, max: Int?, currency: String) -> String? {
        switch (min, max) {
        case (.some(let min), .some(let max)):
            return "\(min)-\(max) \(currency)"
        case (.some(let min), nil):
            return "Desde \(min) \(currency)"
        case (nil, .some(let max)):
            return "Hasta \(max) \(currency)"
        case (nil, nil):
            return nil
        }
    }
}
