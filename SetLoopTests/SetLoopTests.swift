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
    @Test func acceptingAnApplicationClosesGigAndRejectsOtherPendingApplications() {
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
        let acceptedApplicant = UserProfile(
            id: UUID(),
            email: "dj-accepted@setloop.local",
            displayName: "DJ A",
            role: .dj,
            city: "Madrid",
            bio: "Set accepted.",
            genres: [],
            instruments: ["Club Set"]
        )
        let otherApplicant = UserProfile(
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

        let acceptedApplication = applicationStore.createApplication(
            gigID: gig.id,
            applicantProfile: acceptedApplicant,
            message: "Disponible para esta fecha."
        )
        let rejectedApplication = applicationStore.createApplication(
            gigID: gig.id,
            applicantProfile: otherApplicant,
            message: "Me interesa esta fecha."
        )

        let bookingViewModel = BookingViewModel(
            applicationStore: applicationStore,
            currentProfile: hostProfile,
            gigStore: gigStore
        )

        let receivedApplication = bookingViewModel.sections
            .flatMap(\.items)
            .first { $0.id == acceptedApplication.id }!

        bookingViewModel.accept(receivedApplication)

        #expect(gigStore.gig(id: gig.id)?.status == .booked)
        #expect(applicationStore.receivedApplications(for: hostProfile.id).first { $0.id == acceptedApplication.id }?.status == .accepted)
        #expect(applicationStore.receivedApplications(for: hostProfile.id).first { $0.id == rejectedApplication.id }?.status == .rejected)
    }

    @Test func networkErrorsUseUserFacingMessages() {
        #expect(
            APIError.requestFailed(statusCode: 403, message: "{\"message\":\"permission denied\"}").setLoopUserMessage
                == "Tu sesion no tiene permisos para esta accion. Inicia sesion de nuevo si el problema continua."
        )
        #expect(
            URLError(.notConnectedToInternet).setLoopUserMessage
                == "No hay conexion a internet. Revisa la conexion e intentalo de nuevo."
        )
    }

    @MainActor
    @Test func defaultSearchServiceDoesNotExposeMockExploreData() async throws {
        let profile = UserProfile(
            id: UUID(),
            email: "search@setloop.local",
            displayName: "Busqueda Real",
            role: .musician,
            city: "Madrid",
            bio: "Perfil de busqueda.",
            genres: ["Indie"],
            instruments: ["Solista"]
        )

        let results = try await SearchService().search(filters: ExploreFilters(), profile: profile)

        #expect(results.isEmpty)
    }

    @MainActor
    @Test func bookingLoadKeepsLoadedApplicationsWhenGigRefreshFails() async {
        let suiteName = "SetLoopTests.BookingPartialLoad.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)

        let hostProfile = UserProfile(
            id: UUID(),
            email: "venue-partial@setloop.local",
            displayName: "Sala Parcial",
            role: .venue,
            city: "Madrid",
            venueAddress: "Calle Luna 10",
            bio: "Local de pruebas.",
            genres: ["Indie"],
            instruments: ["House"],
            venueCapacity: 150
        )
        let applicantProfile = UserProfile(
            id: UUID(),
            email: "artist-partial@setloop.local",
            displayName: "Artista Parcial",
            role: .musician,
            city: "Madrid",
            bio: "Proyecto en directo.",
            genres: ["Indie"],
            instruments: ["Solista"]
        )
        let gig = Gig(
            id: UUID(),
            venueID: nil,
            hostUserID: hostProfile.id,
            title: "Fecha parcial",
            venueName: hostProfile.displayName,
            city: "Madrid",
            performanceDate: Date(),
            durationMinutes: 60,
            budgetMin: 200,
            budgetMax: 300,
            currency: "EUR",
            roleNeeded: .musician,
            requiredGenres: ["Indie"],
            description: nil,
            status: .open,
            imageURL: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        let application = Application(
            id: UUID(),
            gigID: gig.id,
            applicantUserID: applicantProfile.id,
            applicantDisplayName: applicantProfile.displayName,
            applicantRole: applicantProfile.role,
            applicantCity: applicantProfile.city,
            message: "Me interesa esta fecha.",
            status: .pending,
            createdAt: Date(),
            updatedAt: Date()
        )

        let gigStore = GigStore(
            userDefaults: userDefaults,
            seedGigs: [],
            remoteService: FailingVenueGigRemoteService()
        )
        gigStore.upsert(gig)
        let notificationStore = NotificationStore(userDefaults: userDefaults)
        let bookingService = StubBookingRemoteService(applications: [application])
        let applicationStore = ApplicationStore(
            gigStore: gigStore,
            notificationStore: notificationStore,
            userDefaults: userDefaults,
            remoteService: bookingService
        )
        let viewModel = BookingViewModel(
            applicationStore: applicationStore,
            currentProfile: hostProfile,
            gigStore: gigStore
        )

        await viewModel.load()

        #expect(viewModel.errorMessage == "Carga de prueba fallida.")
        #expect(viewModel.sections.flatMap(\.items).map(\.id).contains(application.id))
    }

}

private enum TestLoadError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Carga de prueba fallida."
        }
    }
}

private final class FailingVenueGigRemoteService: VenueGigRemoteServicing {
    func fetchVenues() async throws -> [Venue] {
        []
    }

    func fetchVenue(ownerID: UUID) async throws -> Venue? {
        nil
    }

    func saveVenue(_ venue: Venue) async throws -> Venue {
        venue
    }

    func fetchGigs() async throws -> [Gig] {
        throw TestLoadError.unavailable
    }

    func fetchGigs(hostUserID: UUID) async throws -> [Gig] {
        throw TestLoadError.unavailable
    }

    func saveGig(_ gig: Gig) async throws -> Gig {
        gig
    }

    func updateGigStatus(gigID: UUID, status: GigStatus) async throws -> Gig {
        throw TestLoadError.unavailable
    }
}

private final class StubBookingRemoteService: BookingRemoteServicing {
    var applications: [Application]

    init(applications: [Application]) {
        self.applications = applications
    }

    func fetchApplications() async throws -> [Application] {
        applications
    }

    func fetchApplication(gigID: UUID, applicantUserID: UUID) async throws -> Application? {
        applications.first { $0.gigID == gigID && $0.applicantUserID == applicantUserID }
    }

    func createApplication(_ application: Application) async throws -> Application {
        applications.append(application)
        return application
    }

    func updateApplicationStatus(applicationID: UUID, status: ApplicationStatus) async throws -> Application {
        guard let index = applications.firstIndex(where: { $0.id == applicationID }) else {
            throw TestLoadError.unavailable
        }

        applications[index].status = status
        return applications[index]
    }
}
