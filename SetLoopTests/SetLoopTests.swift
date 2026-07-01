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
    @Test func profileSaveButtonAppearsOnlyForPendingChanges() async {
        let profile = UserProfile(
            id: UUID(),
            email: "save-button@setloop.local",
            displayName: "Perfil Guardable",
            role: .musician,
            city: "Madrid",
            bio: "Bio inicial.",
            genres: ["Indie"],
            instruments: ["Solista"]
        )

        let viewModel = ProfileViewModel(
            profile: profile,
            mode: .profile,
            onPersistProfile: { $0 }
        )

        #expect(viewModel.showsPrimaryActionButton == false)

        viewModel.bio = "Bio editada."

        #expect(viewModel.showsPrimaryActionButton)
        #expect(viewModel.canSave)

        _ = await viewModel.save()

        #expect(viewModel.showsPrimaryActionButton == false)
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
    @Test func gigEditorConfirmsAndResetsDraftWhenChangingTalentType() {
        let suiteName = "SetLoopTests.GigRoleChange.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)

        let profile = UserProfile(
            id: UUID(),
            email: "venue-editor@setloop.local",
            displayName: "Sala Editor",
            role: .venue,
            city: "Madrid",
            venueAddress: "Calle Test 1",
            bio: "Local de pruebas.",
            genres: ["Rock"],
            instruments: ["House"],
            venueCapacity: 100
        )
        let defaultDate = Date(timeIntervalSince1970: 1_800_000_000)
        let gigStore = GigStore(userDefaults: userDefaults, seedGigs: [])
        let venueStore = VenueStore(userDefaults: userDefaults, seedVenues: [])
        let viewModel = GigEditorViewModel(
            currentProfile: profile,
            gigStore: gigStore,
            venueStore: venueStore,
            gig: nil,
            defaultDate: defaultDate
        )
        let initialPerformanceDate = viewModel.performanceDate

        #expect(viewModel.shouldConfirmRoleChange(to: .dj) == false)
        viewModel.changeRole(to: .dj, resettingDraft: false)

        viewModel.title = "Sesion completa"
        viewModel.durationText = "120"
        viewModel.budgetMinText = "250"
        viewModel.budgetMaxText = "350"
        viewModel.selectedGenres = ["House"]
        viewModel.gigDescription = "Cabina y tecnico incluidos."

        #expect(viewModel.shouldConfirmRoleChange(to: .musician))
        #expect(viewModel.roleNeeded == .dj)
        #expect(viewModel.title == "Sesion completa")

        viewModel.changeRole(to: .musician, resettingDraft: true)

        #expect(viewModel.roleNeeded == .musician)
        #expect(viewModel.title.isEmpty)
        #expect(viewModel.durationText.isEmpty)
        #expect(viewModel.budgetMinText.isEmpty)
        #expect(viewModel.budgetMaxText.isEmpty)
        #expect(viewModel.selectedGenres.isEmpty)
        #expect(viewModel.gigDescription.isEmpty)
        #expect(viewModel.city == profile.city)
        #expect(viewModel.performanceDate == initialPerformanceDate)
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

    @MainActor
    @Test func notificationStoreDeletesNotification() async throws {
        let suiteName = "SetLoopTests.NotificationDelete.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)

        let userID = UUID()
        let notificationStore = NotificationStore(userDefaults: userDefaults)
        let notification = notificationStore.add(
            userID: userID,
            type: .applicationReceived,
            title: "Nueva candidatura",
            body: "Una candidatura acaba de entrar."
        )

        #expect(notificationStore.notifications(for: userID).count == 1)

        try await notificationStore.saveDelete(notification.id)

        #expect(notificationStore.notifications(for: userID).isEmpty)
    }

    @Test func notificationItemKeepsApplicationDestination() {
        let applicationID = UUID()
        let notification = AppNotification(
            id: UUID(),
            userID: UUID(),
            type: .applicationReceived,
            title: "Nueva candidatura",
            body: "Hay una candidatura pendiente.",
            createdAt: Date(),
            isRead: false,
            relatedGigID: UUID(),
            relatedApplicationID: applicationID
        )

        let item = NotificationItem(notification: notification)

        #expect(item.relatedApplicationID == applicationID)
    }

    @MainActor
    @Test func venueManagedApplicationsHidePastEventsAutomatically() {
        let suiteName = "SetLoopTests.BookingDelete.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)

        let hostProfile = UserProfile(
            id: UUID(),
            email: "venue-delete@setloop.local",
            displayName: "Sala Borrado",
            role: .venue,
            city: "Madrid",
            venueAddress: "Calle Norte 8",
            bio: "Prueba de limpieza.",
            genres: ["Indie"],
            instruments: ["House"],
            venueCapacity: 120
        )
        let applicantProfile = UserProfile(
            id: UUID(),
            email: "artist-delete@setloop.local",
            displayName: "Artista Historico",
            role: .musician,
            city: "Madrid",
            bio: "Disponible.",
            genres: ["Indie"],
            instruments: ["Guitarra"]
        )
        let pastGig = Gig(
            id: UUID(),
            venueID: nil,
            hostUserID: hostProfile.id,
            title: "Fecha pasada",
            venueName: hostProfile.displayName,
            city: "Madrid",
            performanceDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
            durationMinutes: 60,
            budgetMin: 150,
            budgetMax: 250,
            currency: "EUR",
            roleNeeded: .musician,
            requiredGenres: ["Indie"],
            description: nil,
            status: .booked,
            imageURL: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        let futureGig = Gig(
            id: UUID(),
            venueID: nil,
            hostUserID: hostProfile.id,
            title: "Fecha futura",
            venueName: hostProfile.displayName,
            city: "Madrid",
            performanceDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date(),
            durationMinutes: 60,
            budgetMin: 150,
            budgetMax: 250,
            currency: "EUR",
            roleNeeded: .musician,
            requiredGenres: ["Indie"],
            description: nil,
            status: .open,
            imageURL: nil,
            createdAt: Date(),
            updatedAt: Date()
        )

        let gigStore = GigStore(userDefaults: userDefaults, seedGigs: [pastGig, futureGig])
        let notificationStore = NotificationStore(userDefaults: userDefaults)
        let applicationStore = ApplicationStore(
            gigStore: gigStore,
            notificationStore: notificationStore,
            userDefaults: userDefaults
        )

        let historicalApplication = applicationStore.createApplication(
            gigID: pastGig.id,
            applicantProfile: applicantProfile,
            message: "Puedo tocar esa fecha."
        )
        _ = applicationStore.updateStatus(applicationID: historicalApplication.id, status: .accepted)

        let activeApplication = applicationStore.createApplication(
            gigID: futureGig.id,
            applicantProfile: applicantProfile,
            message: "Disponible para la fecha futura."
        )
        _ = applicationStore.updateStatus(applicationID: activeApplication.id, status: .accepted)

        let viewModel = BookingViewModel(
            applicationStore: applicationStore,
            currentProfile: hostProfile,
            gigStore: gigStore
        )
        viewModel.venueFilter = .managed

        let managedIDs = viewModel.sections.flatMap(\.items).map(\.id)

        #expect(managedIDs.contains(historicalApplication.id) == false)
        #expect(managedIDs.contains(activeApplication.id))
        #expect(viewModel.item(applicationID: historicalApplication.id) == nil)
        #expect(applicationStore.receivedApplications(for: hostProfile.id).contains { $0.id == historicalApplication.id })
    }

    @MainActor
    @Test func exploreSearchFiltersOpenGigsByApplicantRoleCityAndDate() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let targetDate = setLoopTestDate(year: 2026, month: 9, day: 12, hour: 21, calendar: calendar)
        let otherDate = setLoopTestDate(year: 2026, month: 9, day: 13, hour: 21, calendar: calendar)
        let hostProfile = setLoopTestProfile(role: .venue, city: "Madrid", displayName: "Sala Filtro")
        let musicianProfile = setLoopTestProfile(
            role: .musician,
            city: "Madrid",
            displayName: "Banda Filtro",
            genres: ["Indie"],
            instruments: ["Banda"]
        )
        let djProfile = setLoopTestProfile(
            role: .dj,
            city: "Madrid",
            displayName: "DJ Filtro",
            instruments: ["Club Set"]
        )

        let musicianGig = setLoopTestGig(
            hostProfile: hostProfile,
            title: "Indie Night",
            roleNeeded: .musician,
            city: "Madrid",
            performanceDate: targetDate,
            requiredGenres: ["Indie"],
            status: .open
        )
        let djGig = setLoopTestGig(
            hostProfile: hostProfile,
            title: "Club Night",
            roleNeeded: .dj,
            city: "Madrid",
            performanceDate: targetDate,
            requiredGenres: ["House"],
            status: .open
        )
        let closedMusicianGig = setLoopTestGig(
            hostProfile: hostProfile,
            title: "Fecha cerrada",
            roleNeeded: .musician,
            city: "Madrid",
            performanceDate: targetDate,
            requiredGenres: ["Indie"],
            status: .booked
        )
        let otherDayGig = setLoopTestGig(
            hostProfile: hostProfile,
            title: "Otro dia",
            roleNeeded: .musician,
            city: "Madrid",
            performanceDate: otherDate,
            requiredGenres: ["Indie"],
            status: .open
        )
        let pastOpenGig = setLoopTestGig(
            hostProfile: hostProfile,
            title: "Fecha pasada abierta",
            roleNeeded: .musician,
            city: "Madrid",
            performanceDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            requiredGenres: ["Indie"],
            status: .open
        )
        let service = SearchService(
            itemsProvider: {
                ExploreCardFactory.makeCards(
                    gigs: [pastOpenGig, djGig, closedMusicianGig, otherDayGig, musicianGig]
                )
            },
            calendar: calendar
        )

        let musicianResults = try await service.search(
            filters: ExploreFilters(city: "mad", date: targetDate),
            profile: musicianProfile
        )
        let djResults = try await service.search(filters: ExploreFilters(), profile: djProfile)
        let venueResults = try await service.search(filters: ExploreFilters(), profile: hostProfile)

        #expect(musicianResults.map(\.id) == [musicianGig.id])
        #expect(djResults.map(\.id) == [djGig.id])
        #expect(venueResults.isEmpty)
    }

    @MainActor
    @Test func pastOpenGigIsHistoricalAndNotActionable() throws {
        let suiteName = "SetLoopTests.PastOpenGig.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)

        let hostProfile = setLoopTestProfile(role: .venue, city: "Madrid", displayName: "Sala Pasada")
        let applicantProfile = setLoopTestProfile(role: .musician, city: "Madrid", displayName: "Banda Pasada")
        let pastOpenGig = setLoopTestGig(
            hostProfile: hostProfile,
            title: "Fecha abierta pasada",
            roleNeeded: .musician,
            performanceDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            status: .open
        )
        let gigStore = GigStore(userDefaults: userDefaults, seedGigs: [pastOpenGig])
        let venueStore = VenueStore(userDefaults: userDefaults, seedVenues: [])
        let notificationStore = NotificationStore(userDefaults: userDefaults)
        let applicationStore = ApplicationStore(
            gigStore: gigStore,
            notificationStore: notificationStore,
            userDefaults: userDefaults
        )
        let venueViewModel = VenueGigsViewModel(
            currentProfile: hostProfile,
            gigStore: gigStore,
            venueStore: venueStore,
            applicationStore: applicationStore
        )
        let item = try #require(venueViewModel.items.first { $0.id == pastOpenGig.id })
        let detailViewModel = GigDetailViewModel(
            gig: pastOpenGig,
            currentProfile: applicantProfile,
            applicationStore: applicationStore,
            detailService: MockExploreDetailService(gigs: [pastOpenGig], venues: [])
        )

        #expect(ExploreCardFactory.makeCards(gigs: [pastOpenGig]).isEmpty)
        #expect(gigStore.openGigs(for: .musician).isEmpty)
        #expect(venueViewModel.openCount == 0)
        #expect(venueViewModel.closedOrCancelledCount == 1)
        #expect(venueViewModel.closedOrCancelledItems.map(\.id) == [pastOpenGig.id])
        #expect(venueViewModel.canCancel(item) == false)
        #expect(detailViewModel.statusText == "Pasada")
        #expect(detailViewModel.canRequestContact == false)
    }

    @MainActor
    @Test func venueCalendarGroupsSameDayGigsAndCountsPendingApplications() throws {
        let suiteName = "SetLoopTests.VenueCalendar.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let hostProfile = setLoopTestProfile(role: .venue, city: "Madrid", displayName: "Sala Calendario")
        let firstDate = setLoopTestDate(year: 2026, month: 10, day: 16, hour: 18, calendar: calendar)
        let secondDate = setLoopTestDate(year: 2026, month: 10, day: 16, hour: 23, calendar: calendar)
        let nextDay = setLoopTestDate(year: 2026, month: 10, day: 17, hour: 21, calendar: calendar)
        let openGig = setLoopTestGig(
            hostProfile: hostProfile,
            title: "Apertura",
            roleNeeded: .musician,
            performanceDate: firstDate,
            status: .open
        )
        let bookedGig = setLoopTestGig(
            hostProfile: hostProfile,
            title: "Cierre",
            roleNeeded: .dj,
            performanceDate: secondDate,
            status: .booked
        )
        let nextDayGig = setLoopTestGig(
            hostProfile: hostProfile,
            title: "Otro dia",
            roleNeeded: .musician,
            performanceDate: nextDay,
            status: .open
        )
        let gigStore = GigStore(userDefaults: userDefaults, seedGigs: [nextDayGig, bookedGig, openGig])
        let venueStore = VenueStore(userDefaults: userDefaults, seedVenues: [])
        let notificationStore = NotificationStore(userDefaults: userDefaults)
        let applicationStore = ApplicationStore(
            gigStore: gigStore,
            notificationStore: notificationStore,
            userDefaults: userDefaults
        )
        let pendingApplicant = setLoopTestProfile(role: .musician, city: "Madrid", displayName: "Banda Pendiente")
        let acceptedApplicant = setLoopTestProfile(role: .dj, city: "Madrid", displayName: "DJ Confirmado")

        let pendingApplication = applicationStore.createApplication(
            gigID: openGig.id,
            applicantProfile: pendingApplicant,
            message: "Disponible para abrir."
        )
        let acceptedApplication = applicationStore.createApplication(
            gigID: bookedGig.id,
            applicantProfile: acceptedApplicant,
            message: "Disponible para cerrar."
        )
        _ = applicationStore.updateStatus(applicationID: acceptedApplication.id, status: .accepted)

        let viewModel = VenueGigsViewModel(
            currentProfile: hostProfile,
            gigStore: gigStore,
            venueStore: venueStore,
            applicationStore: applicationStore,
            calendar: calendar
        )
        viewModel.visibleMonth = firstDate
        viewModel.selectedDate = calendar.startOfDay(for: firstDate)

        let selectedItems = viewModel.selectedDayItems
        let openItem = try #require(selectedItems.first { $0.id == openGig.id })
        let bookedItem = try #require(selectedItems.first { $0.id == bookedGig.id })
        let calendarDay = try #require(
            viewModel.calendarWeeks
                .flatMap(\.days)
                .first { calendar.isDate($0.date, inSameDayAs: firstDate) }
        )

        #expect(selectedItems.map(\.id) == [openGig.id, bookedGig.id])
        #expect(openItem.totalApplications == 1)
        #expect(openItem.pendingApplications == 1)
        #expect(bookedItem.totalApplications == 1)
        #expect(bookedItem.pendingApplications == 0)
        #expect(calendarDay.gigsCount == 2)
        #expect(calendarDay.hasOpenGigs)
        #expect(calendarDay.hasClosedOrCancelledGigs)
        #expect(viewModel.pendingApplicationCount == 1)
        #expect(viewModel.pendingReviewItems.map(\.id) == [openGig.id])

        viewModel.startCreating(on: firstDate)
        let editorContext = try #require(viewModel.editorContext)
        let editorViewModel = viewModel.makeEditorViewModel(for: editorContext)
        let editorCalendar = Calendar.current

        #expect(editorCalendar.isDate(editorViewModel.performanceDate, inSameDayAs: firstDate))
        #expect(editorCalendar.component(.hour, from: editorViewModel.performanceDate) == 20)
        #expect(applicationStore.receivedApplications(for: hostProfile.id).map(\.id).contains(pendingApplication.id))
    }

    @MainActor
    @Test func venueCancelsOpenGigAndRejectsPendingApplications() async throws {
        let suiteName = "SetLoopTests.VenueCancelGig.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let hostProfile = setLoopTestProfile(role: .venue, city: "Madrid", displayName: "Sala Cancelacion")
        let applicantProfile = setLoopTestProfile(role: .musician, city: "Madrid", displayName: "Banda Cancelacion")
        let gig = setLoopTestGig(
            hostProfile: hostProfile,
            title: "Fecha a cancelar",
            roleNeeded: .musician,
            performanceDate: setLoopTestDate(year: 2026, month: 12, day: 4, hour: 21, calendar: calendar),
            status: .open
        )
        let gigStore = GigStore(userDefaults: userDefaults, seedGigs: [gig])
        let venueStore = VenueStore(userDefaults: userDefaults, seedVenues: [])
        let notificationStore = NotificationStore(userDefaults: userDefaults)
        let applicationStore = ApplicationStore(
            gigStore: gigStore,
            notificationStore: notificationStore,
            userDefaults: userDefaults
        )
        let application = applicationStore.createApplication(
            gigID: gig.id,
            applicantProfile: applicantProfile,
            message: "Disponible para esta fecha."
        )
        let viewModel = VenueGigsViewModel(
            currentProfile: hostProfile,
            gigStore: gigStore,
            venueStore: venueStore,
            applicationStore: applicationStore,
            calendar: calendar
        )
        let item = try #require(viewModel.items.first { $0.id == gig.id })

        #expect(viewModel.canCancel(item))

        await viewModel.cancel(item)

        let cancelledItem = try #require(viewModel.items.first { $0.id == gig.id })
        let updatedApplication = try #require(applicationStore.applications.first { $0.id == application.id })

        #expect(cancelledItem.status == .cancelled)
        #expect(viewModel.canCancel(cancelledItem) == false)
        #expect(updatedApplication.status == .rejected)
        #expect(viewModel.openCount == 0)
        #expect(viewModel.closedOrCancelledCount == 1)
    }

    @MainActor
    @Test func applicantBookingGroupsApplicationsAndMarksCalendarDays() throws {
        let suiteName = "SetLoopTests.ApplicantBookingCalendar.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let applicantProfile = setLoopTestProfile(
            role: .musician,
            city: "Madrid",
            displayName: "Banda Booking",
            genres: ["Indie"],
            instruments: ["Banda"]
        )
        let hostProfile = setLoopTestProfile(role: .venue, city: "Madrid", displayName: "Sala Booking")
        let pendingDate = setLoopTestDate(year: 2026, month: 11, day: 3, hour: 20, calendar: calendar)
        let acceptedDate = setLoopTestDate(year: 2026, month: 11, day: 9, hour: 21, calendar: calendar)
        let rejectedDate = setLoopTestDate(year: 2026, month: 11, day: 15, hour: 22, calendar: calendar)
        let pendingGig = setLoopTestGig(
            hostProfile: hostProfile,
            title: "Pendiente",
            roleNeeded: .musician,
            performanceDate: pendingDate,
            status: .open
        )
        let acceptedGig = setLoopTestGig(
            hostProfile: hostProfile,
            title: "Aceptada",
            roleNeeded: .musician,
            performanceDate: acceptedDate,
            status: .booked
        )
        let rejectedGig = setLoopTestGig(
            hostProfile: hostProfile,
            title: "Rechazada",
            roleNeeded: .musician,
            performanceDate: rejectedDate,
            status: .open
        )
        let gigStore = GigStore(userDefaults: userDefaults, seedGigs: [pendingGig, acceptedGig, rejectedGig])
        let notificationStore = NotificationStore(userDefaults: userDefaults)
        let applicationStore = ApplicationStore(
            gigStore: gigStore,
            notificationStore: notificationStore,
            userDefaults: userDefaults
        )

        let pendingApplication = applicationStore.createApplication(
            gigID: pendingGig.id,
            applicantProfile: applicantProfile,
            message: "Disponible."
        )
        let acceptedApplication = applicationStore.createApplication(
            gigID: acceptedGig.id,
            applicantProfile: applicantProfile,
            message: "Confirmada."
        )
        _ = applicationStore.updateStatus(applicationID: acceptedApplication.id, status: .accepted)
        let rejectedApplication = applicationStore.createApplication(
            gigID: rejectedGig.id,
            applicantProfile: applicantProfile,
            message: "No seleccionada."
        )
        _ = applicationStore.updateStatus(applicationID: rejectedApplication.id, status: .rejected)

        let viewModel = BookingViewModel(
            applicationStore: applicationStore,
            currentProfile: applicantProfile,
            gigStore: gigStore,
            calendar: calendar
        )
        viewModel.visibleMonth = pendingDate
        viewModel.selectedDate = calendar.startOfDay(for: acceptedDate)

        #expect(viewModel.showsApplicantDisplayModePicker)
        #expect(viewModel.showsVenueFilter == false)
        #expect(viewModel.sections.map(\.title) == ["Pendientes", "Confirmadas", "No seleccionadas"])
        #expect(viewModel.sections[0].items.map(\.id) == [pendingApplication.id])
        #expect(viewModel.sections[1].items.map(\.id) == [acceptedApplication.id])
        #expect(viewModel.sections[2].items.map(\.id) == [rejectedApplication.id])
        #expect(viewModel.selectedDayCalendarItems.map(\.id) == [acceptedApplication.id])

        let days = viewModel.bookingCalendarWeeks.flatMap(\.days)
        let pendingDay = try #require(days.first { calendar.isDate($0.date, inSameDayAs: pendingDate) })
        let acceptedDay = try #require(days.first { calendar.isDate($0.date, inSameDayAs: acceptedDate) })
        let rejectedDay = try #require(days.first { calendar.isDate($0.date, inSameDayAs: rejectedDate) })

        #expect(pendingDay.entriesCount == 1)
        #expect(pendingDay.hasPendingEntries)
        #expect(acceptedDay.entriesCount == 1)
        #expect(acceptedDay.hasAcceptedEntries)
        #expect(rejectedDay.entriesCount == 1)
        #expect(rejectedDay.hasInactiveEntries)
    }

    @MainActor
    @Test func notificationsViewModelTracksReadStateAndDelete() async throws {
        let suiteName = "SetLoopTests.NotificationsViewModel.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)

        let profile = setLoopTestProfile(role: .venue, city: "Madrid", displayName: "Sala Avisos")
        let notificationStore = NotificationStore(userDefaults: userDefaults)
        let applicationID = UUID()
        let unreadNotification = notificationStore.add(
            userID: profile.id,
            type: .applicationReceived,
            title: "Nueva candidatura",
            body: "Tienes una candidatura pendiente.",
            relatedGigID: UUID(),
            relatedApplicationID: applicationID
        )
        let readNotification = notificationStore.add(
            userID: profile.id,
            type: .applicationAccepted,
            title: "Candidatura aceptada",
            body: "La candidatura fue aceptada.",
            relatedGigID: UUID(),
            relatedApplicationID: UUID()
        )
        notificationStore.markAsRead(readNotification.id)

        let viewModel = NotificationsViewModel(
            currentProfile: profile,
            notificationStore: notificationStore
        )
        let unreadItem = try #require(viewModel.items.first { $0.id == unreadNotification.id })
        let readItem = try #require(viewModel.items.first { $0.id == readNotification.id })

        #expect(viewModel.unreadCount == 1)
        #expect(viewModel.canMarkAllAsRead)
        #expect(unreadItem.relatedApplicationID == applicationID)
        #expect(readItem.isRead)

        await viewModel.markAsReadAsync(unreadItem)

        #expect(viewModel.unreadCount == 0)
        #expect(viewModel.canMarkAllAsRead == false)

        await viewModel.deleteAsync(readItem)

        #expect(viewModel.items.contains { $0.id == readNotification.id } == false)
    }

}

private func setLoopTestDate(
    year: Int,
    month: Int,
    day: Int,
    hour: Int,
    minute: Int = 0,
    calendar: Calendar = .current
) -> Date {
    calendar.date(
        from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
    )!
}

private func setLoopTestProfile(
    role: UserRole,
    city: String,
    displayName: String,
    genres: [String] = [],
    instruments: [String] = []
) -> UserProfile {
    UserProfile(
        id: UUID(),
        email: "\(displayName.lowercased().replacingOccurrences(of: " ", with: "-"))@setloop.local",
        displayName: displayName,
        role: role,
        city: city,
        venueAddress: role == .venue ? "Calle Test 1" : nil,
        bio: "Perfil de prueba.",
        genres: genres,
        instruments: instruments,
        venueCapacity: role == .venue ? 120 : nil
    )
}

private func setLoopTestGig(
    hostProfile: UserProfile,
    title: String,
    roleNeeded: UserRole,
    city: String? = nil,
    performanceDate: Date,
    requiredGenres: [String] = ["Indie"],
    status: GigStatus = .open
) -> Gig {
    Gig(
        id: UUID(),
        venueID: nil,
        hostUserID: hostProfile.id,
        title: title,
        venueName: hostProfile.displayName,
        city: city ?? hostProfile.city,
        performanceDate: performanceDate,
        durationMinutes: 90,
        budgetMin: 200,
        budgetMax: 350,
        currency: "EUR",
        roleNeeded: roleNeeded,
        requiredGenres: requiredGenres,
        description: "Fecha de prueba.",
        status: status,
        imageURL: nil,
        createdAt: Date(),
        updatedAt: Date()
    )
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

    func deleteApplication(applicationID: UUID) async throws {
        applications.removeAll { $0.id == applicationID }
    }
}
