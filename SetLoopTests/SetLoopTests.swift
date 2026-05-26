//
//  SetLoopTests.swift
//  SetLoopTests
//
//  Created by Astor Ludueña  on 08/05/2026.
//

import Foundation
import Testing
@testable import SetLoop

struct SetLoopTests {

    @MainActor
    @Test func mockAuthServiceUpdatesExistingProfile() async throws {
        let suiteName = "SetLoopTests.MockAuthService.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)

        let service = MockAuthService(userDefaults: userDefaults)
        let signedUpProfile = try await service.signUp(
            email: "test@setloop.local",
            password: "demo1234",
            displayName: "Perfil Test",
            city: "Madrid",
            role: .musician
        )

        var updatedProfile = signedUpProfile
        updatedProfile.bio = "Bio actualizada"
        updatedProfile.genres = ["Rock", "Indie"]
        updatedProfile.instruments = ["Voz", "Guitarra"]
        updatedProfile.instrumentCounts = ["Guitarra": 2]
        updatedProfile.updatedAt = Date()

        let savedProfile = try await service.updateProfile(updatedProfile)

        #expect(savedProfile.bio == "Bio actualizada")
        #expect(savedProfile.genres == ["Rock", "Indie"])
        #expect(savedProfile.instrumentCounts["Guitarra"] == 2)

        let restoredProfile = try await service.restoreSession()
        #expect(restoredProfile?.bio == "Bio actualizada")
        #expect(restoredProfile?.genres == ["Rock", "Indie"])
        #expect(restoredProfile?.instrumentCounts["Guitarra"] == 2)
    }

    @Test func supabaseAuthUserBuildsProfileFromMetadata() throws {
        let data = """
        {
            "id": "7827A22A-38CB-4C02-8D2D-C0828C0D9E3C",
            "email": "alta@setloop.local",
            "user_metadata": {
                "display_name": "Alta Real",
                "city": "Madrid",
                "role": "dj"
            }
        }
        """.data(using: .utf8)!

        let authUser = try JSONDecoder().decode(SupabaseAuthUser.self, from: data)
        let profile = authUser.makeProfile(fallbackEmail: "fallback@setloop.local")

        #expect(profile.id == UUID(uuidString: "7827A22A-38CB-4C02-8D2D-C0828C0D9E3C"))
        #expect(profile.email == "alta@setloop.local")
        #expect(profile.displayName == "Alta Real")
        #expect(profile.city == "Madrid")
        #expect(profile.role == .dj)
    }

    @MainActor
    @Test func musicianFormationSelectionIsSingleChoice() {
        let profile = UserProfile(
            id: UUID(),
            email: "formation@setloop.local",
            displayName: "Formato Variable",
            role: .musician,
            city: "Madrid",
            bio: "Disponible en varios formatos.",
            genres: ["Indie"],
            instruments: ["Voz", "Guitarra"],
            instrumentCounts: ["Guitarra": 2]
        )

        let viewModel = ProfileViewModel(
            profile: profile,
            mode: .profile,
            onPersistProfile: { $0 }
        )

        viewModel.toggleFormation("Duo")
        #expect(viewModel.isFormationSelected("Duo"))

        viewModel.toggleFormation("Trio")
        #expect(viewModel.isFormationSelected("Trio"))
        #expect(viewModel.isFormationSelected("Duo") == false)
    }

    @MainActor
    @Test func inviteStoreCreatesInviteAndNotifications() {
        let suiteName = "SetLoopTests.InviteStore.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)

        let hostProfile = UserProfile(
            id: UUID(),
            email: "venue@setloop.local",
            displayName: "Sala Demo",
            role: .venue,
            city: "Madrid",
            bio: "Local demo",
            genres: ["Indie"],
            instruments: ["House"],
            venueCapacity: 180
        )
        let talentProfile = UserProfile(
            id: UUID(),
            email: "artist@setloop.local",
            displayName: "Artista Demo",
            role: .musician,
            city: "Madrid",
            bio: "Proyecto en directo",
            genres: ["Indie"],
            instruments: ["Solista", "Voz"]
        )
        let gig = Gig(
            id: UUID(),
            venueID: nil,
            hostUserID: hostProfile.id,
            title: "Fecha indie",
            venueName: hostProfile.displayName,
            city: "Madrid",
            performanceDate: Date(),
            durationMinutes: 60,
            budgetMin: 250,
            budgetMax: 400,
            currency: "EUR",
            roleNeeded: .musician,
            requiredGenres: ["Indie"],
            description: nil,
            status: .open,
            imageURL: nil,
            createdAt: Date(),
            updatedAt: Date()
        )

        let gigStore = GigStore(userDefaults: userDefaults, seedGigs: [gig])
        let notificationStore = NotificationStore(userDefaults: userDefaults)
        let inviteStore = InviteStore(
            gigStore: gigStore,
            notificationStore: notificationStore,
            userDefaults: userDefaults
        )

        let invite = inviteStore.createInvite(
            gigID: gig.id,
            hostProfile: hostProfile,
            talentProfile: talentProfile,
            message: "Nos interesa tu proyecto para esta fecha."
        )

        #expect(invite != nil)
        #expect(inviteStore.receivedInvites(for: talentProfile.id).count == 1)
        #expect(notificationStore.notifications(for: talentProfile.id).first?.type == .inviteReceived)

        _ = inviteStore.updateStatus(inviteID: invite!.id, status: .accepted)

        #expect(inviteStore.sentInvites(for: hostProfile.id).first?.status == .accepted)
        #expect(notificationStore.notifications(for: hostProfile.id).first?.type == .inviteAccepted)
    }

    @MainActor
    @Test func venueStoreSyncsVenueFromProfile() {
        let suiteName = "SetLoopTests.VenueStore.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)

        let profile = UserProfile(
            id: UUID(),
            email: "venue-sync@setloop.local",
            displayName: "Sala Prisma",
            role: .venue,
            city: "Sevilla",
            venueAddress: "Calle Feria 12",
            bio: "Programacion de club y directos.",
            genres: ["Indie", "Rock"],
            instruments: ["House", "Disco"],
            venueCapacity: 260
        )

        let venueStore = VenueStore(userDefaults: userDefaults, seedVenues: [])
        let venue = venueStore.syncHostedVenue(using: profile)

        #expect(venue?.name == "Sala Prisma")
        #expect(venue?.city == "Sevilla")
        #expect(venue?.address == "Calle Feria 12")
        #expect(venue?.capacity == 260)
        #expect(venue?.genres == ["Disco", "House", "Indie", "Rock"])
        #expect(venueStore.venue(for: profile.id)?.description == "Programacion de club y directos.")
    }

    @MainActor
    @Test func acceptingAnInviteClosesGigAndRejectsOtherPendingItems() {
        let suiteName = "SetLoopTests.BookingClosure.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)

        let hostProfile = UserProfile(
            id: UUID(),
            email: "venue-closure@setloop.local",
            displayName: "Sala Centro",
            role: .venue,
            city: "Madrid",
            venueAddress: "Gran Via 20",
            bio: "Local de pruebas.",
            genres: ["Pop"],
            instruments: ["House"],
            venueCapacity: 180
        )
        let invitedTalent = UserProfile(
            id: UUID(),
            email: "dj-accepted@setloop.local",
            displayName: "DJ A",
            role: .dj,
            city: "Madrid",
            bio: "Set accepted.",
            genres: [],
            instruments: ["Club Set"]
        )
        let otherTalent = UserProfile(
            id: UUID(),
            email: "dj-rejected@setloop.local",
            displayName: "DJ B",
            role: .dj,
            city: "Madrid",
            bio: "Set pendiente.",
            genres: [],
            instruments: ["Open Format"]
        )
        let gig = Gig(
            id: UUID(),
            venueID: nil,
            hostUserID: hostProfile.id,
            title: "Club Friday",
            venueName: hostProfile.displayName,
            city: "Madrid",
            performanceDate: Date(),
            durationMinutes: 90,
            budgetMin: 200,
            budgetMax: 300,
            currency: "EUR",
            roleNeeded: .dj,
            requiredGenres: ["House"],
            description: nil,
            status: .open,
            imageURL: nil,
            createdAt: Date(),
            updatedAt: Date()
        )

        let gigStore = GigStore(userDefaults: userDefaults, seedGigs: [gig])
        let notificationStore = NotificationStore(userDefaults: userDefaults)
        let applicationStore = ApplicationStore(
            gigStore: gigStore,
            notificationStore: notificationStore,
            userDefaults: userDefaults
        )
        let inviteStore = InviteStore(
            gigStore: gigStore,
            notificationStore: notificationStore,
            userDefaults: userDefaults
        )

        let pendingApplication = applicationStore.createApplication(
            gigID: gig.id,
            applicantProfile: otherTalent,
            message: "Me interesa esta fecha."
        )
        let invite = inviteStore.createInvite(
            gigID: gig.id,
            hostProfile: hostProfile,
            talentProfile: invitedTalent,
            message: "Queremos contar contigo."
        )!

        let bookingViewModel = BookingViewModel(
            applicationStore: applicationStore,
            inviteStore: inviteStore,
            currentProfile: invitedTalent,
            gigStore: gigStore
        )

        let receivedInvite = bookingViewModel.sections
            .flatMap(\.items)
            .first { $0.id == invite.id }!

        bookingViewModel.accept(receivedInvite)

        #expect(gigStore.gig(id: gig.id)?.status == .booked)
        #expect(inviteStore.receivedInvites(for: invitedTalent.id).first?.status == .accepted)
        #expect(applicationStore.receivedApplications(for: hostProfile.id).first { $0.id == pendingApplication.id }?.status == .rejected)
    }

}
