import SwiftUI

struct NotificationsView: View {
    @StateObject private var viewModel: NotificationsViewModel

    init(
        currentProfile: UserProfile,
        notificationStore: NotificationStore
    ) {
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
                if viewModel.items.isEmpty {
                    ContentUnavailableView(
                        "Sin avisos",
                        systemImage: "bell",
                        description: Text(viewModel.emptyStateDescription)
                    )
                } else {
                    List(viewModel.items) { item in
                        Button {
                            viewModel.markAsRead(item)
                        } label: {
                            NotificationRow(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Avisos")
            .toolbar {
                if viewModel.canMarkAllAsRead {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Marcar todas") {
                            viewModel.markAllAsRead()
                        }
                    }
                }
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
        }
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
        case .inviteReceived:
            return .blue
        case .inviteAccepted:
            return .green
        case .inviteRejected:
            return .red
        }
    }
}
