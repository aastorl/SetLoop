import SwiftUI

struct NotificationsView: View {
    @StateObject private var viewModel: NotificationsViewModel
    private let onOpenApplication: (UUID) -> Void

    init(
        currentProfile: UserProfile,
        notificationStore: NotificationStore,
        onOpenApplication: @escaping (UUID) -> Void = { _ in }
    ) {
        self.onOpenApplication = onOpenApplication
        _viewModel = StateObject(
            wrappedValue: NotificationsViewModel(
                currentProfile: currentProfile,
                notificationStore: notificationStore
            )
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.items.isEmpty {
                    ContentUnavailableView(
                        "Sin avisos",
                        systemImage: "bell",
                        description: Text(viewModel.emptyStateDescription)
                    )
                } else {
                    List(viewModel.items) { item in
                        Button {
                            if let applicationID = item.relatedApplicationID {
                                onOpenApplication(applicationID)
                            }

                            Task {
                                await viewModel.markAsReadAsync(item)
                            }
                        } label: {
                            NotificationRow(item: item)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task {
                                    await viewModel.deleteAsync(item)
                                }
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Avisos")
            .toolbar {
                if viewModel.canMarkAllAsRead {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Marcar todas") {
                            Task {
                                await viewModel.markAllAsReadAsync()
                            }
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.bar)
                }
            }
            .task {
                await viewModel.load()
            }
        }
    }
}

private struct NotificationRow: View {
    let item: NotificationItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.type.systemImageName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(item.tint)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 8)

                    if item.isRead == false {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 8, height: 8)
                    }
                }

                Text(item.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if item.relatedApplicationID != nil {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.vertical, 6)
    }
}

private extension NotificationItem {
    var tint: Color {
        switch type {
        case .applicationReceived:
            return .orange
        case .applicationAccepted:
            return .green
        case .applicationRejected:
            return .red
        }
    }
}
