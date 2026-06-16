import SwiftUI
import Combine

@MainActor
struct ExploreView: View {
    @StateObject private var viewModel: ExploreViewModel
    @ObservedObject private var applicationStore: ApplicationStore
    @State private var usesDateFilter = false

    private let currentProfile: UserProfile
    private let detailService: ExploreDetailServicing
    private let gigStore: GigStore
    private let venueStore: VenueStore

    private let columns = [
        GridItem(.adaptive(minimum: 164, maximum: 240), spacing: 16)
    ]
    private let venueMetricColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    init(
        currentProfile: UserProfile,
        detailService: ExploreDetailServicing,
        gigStore: GigStore,
        venueStore: VenueStore,
        applicationStore: ApplicationStore
    ) {
        self.currentProfile = currentProfile
        self.detailService = detailService
        self.gigStore = gigStore
        self.venueStore = venueStore
        _applicationStore = ObservedObject(wrappedValue: applicationStore)
        _viewModel = StateObject(
            wrappedValue: ExploreViewModel(
                currentProfile: currentProfile,
                searchService: SearchService(
                    itemsProvider: {
                        ExploreCardFactory.makeCards(
                            gigs: gigStore.gigs
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
        applicationStore: ApplicationStore
    ) {
        self.currentProfile = currentProfile
        self.detailService = detailService
        self.gigStore = gigStore
        self.venueStore = venueStore
        _applicationStore = ObservedObject(wrappedValue: applicationStore)
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if currentProfile.role == .venue {
                        venueDashboard
                    } else {
                        categoryHeader
                        filters
                        exploreResults
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    if let dataErrorMessage = dataErrorMessage {
                        Text(dataErrorMessage)
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
            .navigationDestination(for: ExploreDetailRoute.self) { route in
                detailDestination(for: route)
            }
        }
    }

    private var venueDashboard: some View {
        VStack(alignment: .leading, spacing: 16) {
            venueDashboardHeader
            venueDashboardSection(
                title: "Proximas fechas",
                systemImage: "calendar",
                gigs: hostActiveUpcomingGigs,
                emptyText: "Sin fechas activas o proximas."
            )
            venueDashboardSection(
                title: "Cerradas y canceladas",
                systemImage: "checkmark.seal",
                gigs: hostClosedOrCancelledGigs,
                emptyText: nil
            )
        }
    }

    private var venueDashboardHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tus fechas")
                        .font(.title3.bold())
                        .foregroundStyle(.primary)

                    Text("Crea fechas y organiza la programacion de tu local desde el calendario.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            LazyVGrid(columns: venueMetricColumns, spacing: 12) {
                VenueMetricPill(title: "Activas", value: "\(hostActiveGigCount)")
                VenueMetricPill(title: "Proximas", value: "\(hostUpcomingGigCount)")
                VenueMetricPill(title: "Cerradas/canceladas", value: "\(hostClosedOrCancelledGigCount)")
            }

            NavigationLink {
                makeVenueGigsView(opensCreatorOnAppear: true)
            } label: {
                Label("Crear fecha", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func venueDashboardSection(
        title: String,
        systemImage: String,
        gigs: [Gig],
        emptyText: String?
    ) -> some View {
        if gigs.isEmpty == false || emptyText != nil {
            VStack(alignment: .leading, spacing: 12) {
                Label(title, systemImage: systemImage)
                    .font(.headline)

                if gigs.isEmpty {
                    if let emptyText {
                        Text(emptyText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    ForEach(Array(gigs.prefix(3))) { gig in
                        NavigationLink {
                            makeVenueGigsView()
                        } label: {
                            VenueDashboardGigRow(
                                gig: gig,
                                pendingApplications: pendingApplications(for: gig.id)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                if gigs.count > 3 {
                    NavigationLink {
                        makeVenueGigsView()
                    } label: {
                            Label("Ver todas", systemImage: "arrow.right")
                                .font(.footnote.weight(.semibold))
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var categoryHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(categoryTitle)
                .font(currentProfile.role == .venue ? .headline : .title3.bold())

            Text(categoryHelperText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var exploreResults: some View {
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
        guard currentProfile.role != .venue else {
            return
        }

        await viewModel.load()
    }

    private func makeVenueGigsView(opensCreatorOnAppear: Bool = false) -> VenueGigsView {
        VenueGigsView(
            viewModel: VenueGigsViewModel(
                currentProfile: currentProfile,
                gigStore: gigStore,
                venueStore: venueStore,
                applicationStore: applicationStore
            ),
            opensCreatorOnAppear: opensCreatorOnAppear
        )
    }

    private var showsDateFilter: Bool {
        currentProfile.role != .venue
    }

    private var categoryTitle: String {
        switch currentProfile.role {
        case .musician:
            return "Fechas para musicos"
        case .venue:
            return "Tus fechas"
        case .dj:
            return "Fechas para DJs"
        }
    }

    private var categoryHelperText: String {
        switch currentProfile.role {
        case .venue:
            return "Gestiona las fechas publicadas de tu local."
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
            return "Tus fechas"
        case .dj:
            return "Fechas DJ"
        }
    }

    private var emptyStateDescription: String {
        switch currentProfile.role {
        case .venue:
            return "Crea una fecha para empezar a recibir candidaturas."
        case .musician, .dj:
            return "Ajusta ciudad o fecha para ampliar el feed."
        }
    }

    private var dataErrorMessage: String? {
        gigStore.errorMessage
            ?? venueStore.errorMessage
            ?? applicationStore.errorMessage
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
        }
    }

    private var hostGigs: [Gig] {
        gigStore.gigs(for: currentProfile.id)
    }

    private var hostActiveGigCount: Int {
        hostGigs.filter { $0.status == .open }.count
    }

    private var hostUpcomingGigCount: Int {
        let now = Date()
        return hostGigs.filter { $0.performanceDate >= now && $0.status != .cancelled }.count
    }

    private var hostClosedOrCancelledGigCount: Int {
        hostGigs.filter { $0.status == .booked || $0.status == .cancelled }.count
    }

    private var hostPendingReviewGigs: [Gig] {
        hostGigs
            .filter { pendingApplications(for: $0.id) > 0 }
            .sorted { lhs, rhs in
                let lhsPending = pendingApplications(for: lhs.id)
                let rhsPending = pendingApplications(for: rhs.id)

                if lhsPending == rhsPending {
                    return lhs.performanceDate < rhs.performanceDate
                }

                return lhsPending > rhsPending
            }
    }

    private var hostActiveUpcomingGigs: [Gig] {
        hostGigs.filter { $0.status == .open }
    }

    private var hostClosedOrCancelledGigs: [Gig] {
        return hostGigs
            .filter { $0.status == .booked || $0.status == .cancelled }
            .sorted { $0.performanceDate > $1.performanceDate }
    }

    private var pendingApplicationCount: Int {
        applicationStore
            .receivedApplications(for: currentProfile.id)
            .filter { $0.status == .pending }
            .count
    }

    private func pendingApplications(for gigID: UUID) -> Int {
        applicationStore
            .receivedApplications(for: currentProfile.id)
            .filter { $0.gigID == gigID && $0.status == .pending }
            .count
    }

}

private enum ExploreDetailRoute: Hashable {
    case gig(UUID)

    init(item: ExploreCardItem) {
        self = .gig(item.id)
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

private struct VenueDashboardGigRow: View {
    let gig: Gig
    let pendingApplications: Int

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                Text(gig.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Label(gig.performanceDate.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                    Label(gig.roleNeeded.shortLabel, systemImage: "person.2")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Label(gig.city, systemImage: "mappin.and.ellipse")
                }
                .font(.caption.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 8) {
                Text(gig.status.homeDisplayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(gig.status.homeTint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(gig.status.homeTint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Label("Abrir", systemImage: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
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

private struct VenueNextGigPreview: View {
    let gig: Gig

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 5) {
                Text("Proxima fecha")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(gig.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(gig.performanceDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(gig.status.homeDisplayName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(gig.status.homeTint)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(gig.status.homeTint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(12)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private extension GigStatus {
    var homeDisplayName: String {
        switch self {
        case .open:
            return "Abierta"
        case .booked:
            return "Cerrada"
        case .cancelled:
            return "Cancelada"
        }
    }

    var homeTint: Color {
        switch self {
        case .open:
            return .green
        case .booked:
            return .blue
        case .cancelled:
            return .red
        }
    }
}

#Preview {
    let detailService = MockExploreDetailService()
    let gigStore = GigStore()
    let venueStore = VenueStore()
    let notificationStore = NotificationStore()
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
        applicationStore: applicationStore
    )
}
