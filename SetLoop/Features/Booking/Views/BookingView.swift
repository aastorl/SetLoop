import SwiftUI

struct BookingView: View {
    @StateObject private var viewModel: BookingViewModel

    init(
        currentProfile: UserProfile,
        applicationStore: ApplicationStore,
        inviteStore: InviteStore,
        gigStore: GigStore
    ) {
        _viewModel = StateObject(
            wrappedValue: BookingViewModel(
                applicationStore: applicationStore,
                inviteStore: inviteStore,
                currentProfile: currentProfile,
                gigStore: gigStore
            )
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.showsVenueFilter {
                    Picker("Estado", selection: $viewModel.venueFilter) {
                        ForEach(VenueBookingFilter.allCases) { filter in
                            Text(filter.displayName).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }

                Group {
                    if viewModel.hasItems == false {
                        ContentUnavailableView(
                            viewModel.emptyStateTitle,
                            systemImage: "tray",
                            description: Text(viewModel.emptyStateDescription)
                        )
                    } else {
                        List {
                            ForEach(viewModel.sections) { section in
                                Section(section.title) {
                                    ForEach(section.items) { item in
                                        BookingApplicationRow(
                                            item: item,
                                            onAccept: { viewModel.accept(item) },
                                            onReject: { viewModel.reject(item) }
                                        )
                                    }
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                }
            }
            .navigationTitle("Booking")
        }
    }
}

private struct BookingApplicationRow: View {
    let item: BookingEntryItem
    let onAccept: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.gigTitle)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(item.kind.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Text(item.status.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(item.status.tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(item.status.tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if let counterpartDisplayName = item.counterpartDisplayName {
                VStack(alignment: .leading, spacing: 4) {
                    Text(counterpartDisplayName)
                        .font(.subheadline.weight(.semibold))

                    Text(candidateSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if let venueName = item.venueName {
                Text(venueName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 14) {
                Label(item.city, systemImage: "mappin.and.ellipse")

                if let performanceDate = item.performanceDate {
                    Label(performanceDate.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(item.message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)

            if item.isIncoming && item.status == .pending {
                HStack(spacing: 10) {
                    Button("Rechazar", action: onReject)
                        .buttonStyle(.bordered)

                    Button("Aceptar", action: onAccept)
                        .buttonStyle(.borderedProminent)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 6)
    }

    private var candidateSubtitle: String {
        [
            item.counterpartRole?.displayName,
            item.counterpartCity
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }
}
