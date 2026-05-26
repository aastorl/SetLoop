import SwiftUI
import Combine

@MainActor
struct ExploreView: View {
    @StateObject private var viewModel: ExploreViewModel
    @EnvironmentObject private var applicationStore: ApplicationStore
    @State private var usesDateFilter = false
    @State private var selectedVenueTalentRole: UserRole = .musician

    private let currentProfile: UserProfile
    private let detailService: ExploreDetailServicing
    private let gigStore: GigStore
    private let venueStore: VenueStore
    private let reviewStore: ReviewStore
    private let talentDirectory: MockTalentDirectory
    private let inviteStore: InviteStore

    private let columns = [
        GridItem(.adaptive(minimum: 164, maximum: 240), spacing: 16)
    ]

    init(
        currentProfile: UserProfile,
        detailService: ExploreDetailServicing,
        gigStore: GigStore,
        venueStore: VenueStore,
        reviewStore: ReviewStore,
        talentDirectory: MockTalentDirectory,
        inviteStore: InviteStore
    ) {
        self.currentProfile = currentProfile
        self.detailService = detailService
        self.gigStore = gigStore
        self.venueStore = venueStore
        self.reviewStore = reviewStore
        self.talentDirectory = talentDirectory
        self.inviteStore = inviteStore
        _viewModel = StateObject(
            wrappedValue: ExploreViewModel(
                currentProfile: currentProfile,
                searchService: SearchService(
                    itemsProvider: {
                        MockExploreData.makeExploreCards(
                            gigs: gigStore.gigs,
                            venues: venueStore.venues,
                            musicians: talentDirectory.allTalent(excluding: currentProfile.id)
                        )
                    }
                )
            )
        )
    }

    init(
        currentProfile: UserProfile,
        viewModel: ExploreViewModel,
        detailService: ExploreDetailServicing,
        gigStore: GigStore,
        venueStore: VenueStore,
        reviewStore: ReviewStore,
        talentDirectory: MockTalentDirectory,
        inviteStore: InviteStore
    ) {
        self.currentProfile = currentProfile
        self.detailService = detailService
        self.gigStore = gigStore
        self.venueStore = venueStore
        self.reviewStore = reviewStore
        self.talentDirectory = talentDirectory
        self.inviteStore = inviteStore
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if currentProfile.role == .venue {
                        venueManagementSection
                    }

                    categoryHeader
                    filters

                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 180)
                    } else if viewModel.items.isEmpty {
                        ContentUnavailableView("Sin resultados", systemImage: "magnifyingglass", description: Text(emptyStateDescription))
                            .frame(minHeight: 240)
                    } else {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                            ForEach(viewModel.items) { item in
                                NavigationLink(value: ExploreDetailRoute(item: item)) {
                                    ExploreCardView(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(16)
            }
            .navigationTitle(navigationTitle)
            .task {
                await loadExplore()
            }
            .onReceive(gigStore.$gigs.dropFirst()) { _ in
                Task {
                    await loadExplore()
                }
            }
            .onReceive(venueStore.$venues.dropFirst()) { _ in
                Task {
                    await loadExplore()
                }
            }
            .onChange(of: viewModel.filters) {
                Task {
                    await loadExplore()
                }
            }
            .onChange(of: currentProfile.renderIdentity) { _, _ in
                viewModel.apply(profile: currentProfile)
                Task {
                    await loadExplore()
                }
            }
            .onChange(of: usesDateFilter) { _, newValue in
                viewModel.filters.date = newValue ? Date() : nil
            }
            .onChange(of: selectedVenueTalentRole) { _, _ in
                Task {
                    await loadExplore()
                }
            }
            .navigationDestination(for: ExploreDetailRoute.self) { route in
                detailDestination(for: route)
            }
        }
    }

    private var venueManagementSection: some View {
        NavigationLink {
            VenueGigsView(
                viewModel: VenueGigsViewModel(
                    currentProfile: currentProfile,
                    gigStore: gigStore,
                    venueStore: venueStore,
                    applicationStore: applicationStore
                )
            )
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tus fechas")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text("Publica, corrige y revisa el estado de tus gigs desde un solo sitio.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 12)

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    VenueMetricPill(title: "Abiertas", value: "\(hostOpenGigCount)")
                    VenueMetricPill(title: "Pendientes", value: "\(pendingApplicationCount)")
                    VenueMetricPill(title: "Total", value: "\(hostGigCount)")
                }
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var categoryHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(categoryTitle)
                .font(.title3.bold())

            Text(categoryHelperText)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if showsVenueTalentSwitcher {
                Picker("Tipo de talento", selection: $selectedVenueTalentRole) {
                    Text("Musicos").tag(UserRole.musician)
                    Text("DJs").tag(UserRole.dj)
                }
                .pickerStyle(.segmented)
                .padding(.top, 4)
            }
        }
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Ciudad", text: $viewModel.filters.city)
                .textInputAutocapitalization(.words)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            if showsDateFilter {
                Toggle("Fecha concreta", isOn: $usesDateFilter)

                if usesDateFilter {
                    DatePicker("Fecha", selection: Binding(
                        get: { viewModel.filters.date ?? Date() },
                        set: { viewModel.filters.date = $0 }
                    ), displayedComponents: .date)
                    .datePickerStyle(.compact)
                }
            }
        }
    }

    private func loadExplore() async {
        await viewModel.load(venueTalentRole: selectedVenueTalentRole)
    }

    private var showsVenueTalentSwitcher: Bool {
        currentProfile.role == .venue
    }

    private var showsDateFilter: Bool {
        currentProfile.role != .venue
    }

    private var categoryTitle: String {
        switch currentProfile.role {
        case .musician:
            return "Fechas para musicos"
        case .venue:
            return "Talento"
        case .dj:
            return "Fechas para DJs"
        }
    }

    private var categoryHelperText: String {
        switch currentProfile.role {
        case .venue:
            return "Elige si quieres explorar perfiles de musicos o de DJs."
        case .musician:
            return "Explora fechas publicadas que encajan con tu perfil."
        case .dj:
            return "Explora fechas publicadas para DJs y sesiones de club."
        }
    }

    private var navigationTitle: String {
        switch currentProfile.role {
        case .musician:
            return "Fechas"
        case .venue:
            return "Talento"
        case .dj:
            return "Fechas DJ"
        }
    }

    private var emptyStateDescription: String {
        switch currentProfile.role {
        case .venue:
            return "Ajusta ciudad o cambia entre musicos y DJs para ampliar el feed."
        case .musician, .dj:
            return "Ajusta ciudad o fecha para ampliar el feed."
        }
    }

    @ViewBuilder
    private func detailDestination(for route: ExploreDetailRoute) -> some View {
        switch route {
        case .gig(let id):
            if let gig = gigStore.gig(id: id) {
                GigDetailView(
                    viewModel: GigDetailViewModel(
                        gig: gig,
                        currentProfile: currentProfile,
                        applicationStore: applicationStore,
                        detailService: detailService
                    )
                )
            } else {
                MissingDetailView()
            }
        case .venue(let id):
            if let venue = venueStore.venue(id: id) ?? detailService.venue(id: id) {
                VenueDetailView(
                    viewModel: VenueDetailViewModel(
                        venue: venue,
                        reviewStore: reviewStore
                    )
                )
            } else {
                MissingDetailView()
            }
        case .musician(let id):
            if let musician = talentDirectory.musician(id: id) ?? detailService.musician(id: id) {
                MusicianDetailView(
                    viewModel: MusicianDetailViewModel(
                        musician: musician,
                        reviewStore: reviewStore,
                        currentProfile: currentProfile,
                        gigStore: gigStore,
                        inviteStore: inviteStore
                    )
                )
            } else {
                MissingDetailView()
            }
        }
    }

    private var hostGigCount: Int {
        gigStore.gigs(for: currentProfile.id).count
    }

    private var hostOpenGigCount: Int {
        gigStore.gigs(for: currentProfile.id).filter { $0.status == .open }.count
    }

    private var pendingApplicationCount: Int {
        applicationStore
            .receivedApplications(for: currentProfile.id)
            .filter { $0.status == .pending }
            .count
    }
}

private enum ExploreDetailRoute: Hashable {
    case gig(UUID)
    case venue(UUID)
    case musician(UUID)

    init(item: ExploreCardItem) {
        switch item.kind {
        case .gig:
            self = .gig(item.id)
        case .venue:
            self = .venue(item.id)
        case .musician:
            self = .musician(item.id)
        }
    }
}

private struct ExploreCardView: View {
    let item: ExploreCardItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.secondarySystemBackground))
                    .aspectRatio(1.18, contentMode: .fit)

                Image(systemName: item.symbolName)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Text(item.kind.displayName)
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(8)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)

                Text(item.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                    Text(item.city)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let date = item.date {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                if let priceText = item.priceText {
                    Text(priceText)
                        .font(.subheadline.bold())
                }

                if !item.tags.isEmpty {
                    Text(item.tags.prefix(3).joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct VenueMetricPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    let detailService = MockExploreDetailService()
    let gigStore = GigStore()
    let venueStore = VenueStore()
    let reviewStore = ReviewStore()
    let notificationStore = NotificationStore()
    let inviteStore = InviteStore(
        gigStore: gigStore,
        notificationStore: notificationStore
    )
    let talentDirectory = MockTalentDirectory()
    let applicationStore = ApplicationStore(
        gigStore: gigStore,
        notificationStore: notificationStore
    )

    ExploreView(
        currentProfile: UserProfile(
            id: UUID(),
            email: "demo@setloop.local",
            displayName: "Demo SetLoop",
            role: .musician,
            city: "Madrid"
        ),
        detailService: detailService,
        gigStore: gigStore,
        venueStore: venueStore,
        reviewStore: reviewStore,
        talentDirectory: talentDirectory,
        inviteStore: inviteStore
    )
    .environmentObject(applicationStore)
}
