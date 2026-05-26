import Foundation
import Combine

@MainActor
final class ExploreViewModel: ObservableObject {
    @Published var filters = ExploreFilters()
    @Published private(set) var items: [ExploreCardItem] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var currentProfile: UserProfile
    private let searchService: SearchServicing

    init(currentProfile: UserProfile) {
        self.currentProfile = currentProfile
        self.searchService = SearchService()
        self.filters.city = currentProfile.city
    }

    init(currentProfile: UserProfile, searchService: SearchServicing) {
        self.currentProfile = currentProfile
        self.searchService = searchService
        self.filters.city = currentProfile.city
    }

    func load(venueTalentRole: UserRole?) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            items = try await searchService.search(
                filters: filters,
                profile: currentProfile,
                venueTalentRole: venueTalentRole
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func apply(profile: UserProfile) {
        currentProfile = profile
        filters.city = profile.city
    }
}
