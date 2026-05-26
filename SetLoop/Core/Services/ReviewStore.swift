import Foundation
import Combine

@MainActor
final class ReviewStore: ObservableObject {
    @Published private(set) var reviews: [Review]

    init(seedReviews: [Review]? = nil) {
        let resolvedSeedReviews = seedReviews ?? MockExploreData.reviews
        self.reviews = resolvedSeedReviews.sorted { $0.createdAt > $1.createdAt }
    }

    func reviews(for revieweeID: UUID) -> [Review] {
        reviews
            .filter { $0.revieweeID == revieweeID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func summary(for revieweeID: UUID) -> ReviewSummary {
        let targetReviews = reviews(for: revieweeID)
        guard targetReviews.isEmpty == false else {
            return ReviewSummary(averageRating: 0, count: 0)
        }

        let total = targetReviews.reduce(0) { $0 + $1.rating }
        return ReviewSummary(
            averageRating: Double(total) / Double(targetReviews.count),
            count: targetReviews.count
        )
    }
}

struct ReviewSummary: Equatable {
    let averageRating: Double
    let count: Int

    var formattedAverage: String {
        averageRating.formatted(.number.precision(.fractionLength(count == 0 ? 0 : 1)))
    }
}
