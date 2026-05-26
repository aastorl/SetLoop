import Foundation
import Combine

@MainActor
final class InviteStore: ObservableObject {
    private let invitesKey = "setloop.mock.invites"
    private let gigStore: GigStore
    private let notificationStore: NotificationStore
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder.supabase
    private let decoder = JSONDecoder.supabase

    @Published private(set) var invites: [TalentInvite] {
        didSet {
            persistInvites()
        }
    }

    init(
        gigStore: GigStore,
        notificationStore: NotificationStore,
        userDefaults: UserDefaults = .standard
    ) {
        self.gigStore = gigStore
        self.notificationStore = notificationStore
        self.userDefaults = userDefaults
        self.invites = Self.loadPersistedInvites(from: userDefaults, using: decoder)
    }

    func createInvite(gigID: UUID, hostProfile: UserProfile, talentProfile: UserProfile, message: String) -> TalentInvite? {
        guard hostProfile.role == .venue,
              talentProfile.role == .musician || talentProfile.role == .dj,
              let gig = gigStore.gig(id: gigID),
              gig.hostUserID == hostProfile.id,
              gig.roleNeeded == talentProfile.role,
              gig.status == .open else {
            return nil
        }

        if let existing = invite(for: gigID, hostUserID: hostProfile.id, talentUserID: talentProfile.id) {
            return existing
        }

        let now = Date()
        let invite = TalentInvite(
            id: UUID(),
            gigID: gigID,
            hostUserID: hostProfile.id,
            hostDisplayName: hostProfile.displayName,
            talentUserID: talentProfile.id,
            talentDisplayName: talentProfile.displayName,
            talentRole: talentProfile.role,
            talentCity: talentProfile.city,
            message: message.trimmingCharacters(in: .whitespacesAndNewlines),
            status: .pending,
            createdAt: now,
            updatedAt: now
        )

        invites.insert(invite, at: 0)
        createReceivedNotification(for: invite, gig: gig)
        return invite
    }

    func sentInvites(for hostUserID: UUID) -> [TalentInvite] {
        invites
            .filter { $0.hostUserID == hostUserID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func receivedInvites(for talentUserID: UUID) -> [TalentInvite] {
        invites
            .filter { $0.talentUserID == talentUserID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func invite(for gigID: UUID, hostUserID: UUID, talentUserID: UUID) -> TalentInvite? {
        invites.first { invite in
            invite.gigID == gigID
                && invite.hostUserID == hostUserID
                && invite.talentUserID == talentUserID
        }
    }

    @discardableResult
    func updateStatus(inviteID: UUID, status: ApplicationStatus) -> TalentInvite? {
        guard let index = invites.firstIndex(where: { $0.id == inviteID }) else {
            return nil
        }

        guard invites[index].status != status else {
            return invites[index]
        }

        var updatedInvites = invites
        updatedInvites[index].status = status
        updatedInvites[index].updatedAt = Date()

        let updatedInvite = updatedInvites[index]
        invites = updatedInvites
        createStatusNotification(for: updatedInvite)
        return updatedInvite
    }

    func rejectPendingInvites(for gigID: UUID, excluding excludedInviteID: UUID? = nil) {
        let pendingIDs = invites
            .filter { $0.gigID == gigID && $0.status == .pending && $0.id != excludedInviteID }
            .map(\.id)

        for inviteID in pendingIDs {
            _ = updateStatus(inviteID: inviteID, status: .rejected)
        }
    }

    private func createReceivedNotification(for invite: TalentInvite, gig: Gig) {
        let venueName = gig.venueName ?? gig.city
        notificationStore.add(
            userID: invite.talentUserID,
            type: .inviteReceived,
            title: "Nueva invitacion para \(gig.title)",
            body: "\(invite.hostDisplayName) quiere contar contigo en \(venueName).",
            relatedGigID: gig.id,
            relatedInviteID: invite.id
        )
    }

    private func createStatusNotification(for invite: TalentInvite) {
        guard let gig = gigStore.gig(id: invite.gigID) else {
            return
        }

        let venueName = gig.venueName ?? gig.city

        switch invite.status {
        case .accepted:
            notificationStore.add(
                userID: invite.hostUserID,
                type: .inviteAccepted,
                title: "Invitacion aceptada",
                body: "\(invite.talentDisplayName) ha aceptado tu invitacion para \(gig.title) en \(venueName).",
                relatedGigID: gig.id,
                relatedInviteID: invite.id
            )
        case .rejected:
            notificationStore.add(
                userID: invite.hostUserID,
                type: .inviteRejected,
                title: "Invitacion rechazada",
                body: "\(invite.talentDisplayName) no seguira adelante con \(gig.title) en \(venueName).",
                relatedGigID: gig.id,
                relatedInviteID: invite.id
            )
        case .pending, .withdrawn:
            break
        }
    }

    private func persistInvites() {
        guard let data = try? encoder.encode(invites) else {
            return
        }

        userDefaults.set(data, forKey: invitesKey)
    }

    private static func loadPersistedInvites(
        from userDefaults: UserDefaults,
        using decoder: JSONDecoder
    ) -> [TalentInvite] {
        guard let data = userDefaults.data(forKey: "setloop.mock.invites"),
              let invites = try? decoder.decode([TalentInvite].self, from: data) else {
            return []
        }

        return invites.sorted { $0.createdAt > $1.createdAt }
    }
}
