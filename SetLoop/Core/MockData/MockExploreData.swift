import Foundation

enum MockExploreData {
    static let venueHostID = UUID(uuidString: "9A8A0E21-4B40-496B-9032-950BAEA3D6FA")!

    static let lunaProfileID = UUID(uuidString: "7827A22A-38CB-4C02-8D2D-C0828C0D9E3C")!
    static let marcosProfileID = UUID(uuidString: "EE8D95C9-0D0D-45C7-9F33-08281C68FA26")!

    private static let madridVenueID = UUID(uuidString: "BFE14314-26B8-4C68-96D6-737BA6F53C16")!
    private static let barcelonaVenueID = UUID(uuidString: "4D23DD03-081D-4F58-8A68-08E26F1D50C7")!
    private static let valenciaVenueID = UUID(uuidString: "B2DD8F89-BBF6-4C8D-8501-6CB9E3E82C2B")!

    private static let barcelonaHostID = UUID(uuidString: "15E1B845-8F2B-4EA9-8FA4-F54B3C0C7972")!
    private static let valenciaHostID = UUID(uuidString: "B5C7619F-13A4-44B8-B0B8-699D89A21182")!

    static let venues: [Venue] = [
        Venue(
            id: madridVenueID,
            ownerID: venueHostID,
            name: "Sala Norte",
            city: "Madrid",
            address: "Calle Fuencarral 88",
            capacity: 220,
            description: "Club mediano con agenda indie y electronica y equipo técnico estable.",
            genres: ["Indie", "Pop", "House", "Disco"],
            imageURL: nil,
            latitude: nil,
            longitude: nil,
            isVerified: true,
            createdAt: Date(),
            updatedAt: Date()
        ),
        Venue(
            id: barcelonaVenueID,
            ownerID: barcelonaHostID,
            name: "El Taller Live",
            city: "Barcelona",
            address: "Carrer de la Industria 12",
            capacity: 140,
            description: "Formato cercano para jazz, soul y proyectos híbridos.",
            genres: ["Jazz", "Soul", "Acustico"],
            imageURL: nil,
            latitude: nil,
            longitude: nil,
            isVerified: true,
            createdAt: Date(),
            updatedAt: Date()
        ),
        Venue(
            id: valenciaVenueID,
            ownerID: valenciaHostID,
            name: "Club Prisma",
            city: "Valencia",
            address: "Gran Via 14",
            capacity: 320,
            description: "Programación nocturna para DJs open format y house de fin de semana.",
            genres: ["House", "Disco", "Tech House", "Open Format"],
            imageURL: nil,
            latitude: nil,
            longitude: nil,
            isVerified: true,
            createdAt: Date(),
            updatedAt: Date()
        )
    ]

    static let gigs: [Gig] = [
        Gig(
            id: UUID(uuidString: "44282C35-233B-4E98-93D5-8E2572DD1451")!,
            venueID: madridVenueID,
            hostUserID: venueHostID,
            title: "Banda indie para viernes noche",
            venueName: "Sala Norte",
            city: "Madrid",
            performanceDate: date(days: 8, hour: 22),
            durationMinutes: 75,
            budgetMin: 450,
            budgetMax: 700,
            currency: "EUR",
            roleNeeded: .musician,
            requiredGenres: ["Indie", "Pop"],
            description: "Buscamos banda con repertorio propio, prueba de sonido simple y actitud profesional.",
            status: .open,
            imageURL: nil,
            createdAt: Date(),
            updatedAt: Date()
        ),
        Gig(
            id: UUID(uuidString: "A7B54C32-3507-4EA4-927E-0A9967A858F1")!,
            venueID: madridVenueID,
            hostUserID: venueHostID,
            title: "DJ selector para warm up de sabado",
            venueName: "Sala Norte",
            city: "Madrid",
            performanceDate: date(days: 15, hour: 0),
            durationMinutes: 90,
            budgetMin: 180,
            budgetMax: 260,
            currency: "EUR",
            roleNeeded: .dj,
            requiredGenres: ["House", "Disco"],
            description: "Buscamos DJ con criterio para warm up elegante y transición a headliner.",
            status: .open,
            imageURL: nil,
            createdAt: Date(),
            updatedAt: Date()
        ),
        Gig(
            id: UUID(uuidString: "C8A0F81D-6E7C-45B3-BDF1-BD1A7309F22B")!,
            venueID: barcelonaVenueID,
            hostUserID: barcelonaHostID,
            title: "Trio soul para afterwork",
            venueName: "El Taller Live",
            city: "Barcelona",
            performanceDate: date(days: 12, hour: 20),
            durationMinutes: 60,
            budgetMin: 320,
            budgetMax: 480,
            currency: "EUR",
            roleNeeded: .musician,
            requiredGenres: ["Soul", "Jazz"],
            description: "Set elegante para formato afterwork con montaje reducido.",
            status: .open,
            imageURL: nil,
            createdAt: Date(),
            updatedAt: Date()
        ),
        Gig(
            id: UUID(uuidString: "F24D0AC4-4F54-44D9-A6C8-9340D1651A7A")!,
            venueID: valenciaVenueID,
            hostUserID: valenciaHostID,
            title: "Open format para noche de club",
            venueName: "Club Prisma",
            city: "Valencia",
            performanceDate: date(days: 18, hour: 1),
            durationMinutes: 120,
            budgetMin: 240,
            budgetMax: 380,
            currency: "EUR",
            roleNeeded: .dj,
            requiredGenres: ["Open Format", "House"],
            description: "Sesión principal con cabina CDJ y técnico de sala durante toda la noche.",
            status: .open,
            imageURL: nil,
            createdAt: Date(),
            updatedAt: Date()
        ),
        Gig(
            id: UUID(uuidString: "70AE1CC7-4D37-4C20-9BB4-6C9A9D13BE38")!,
            venueID: barcelonaVenueID,
            hostUserID: barcelonaHostID,
            title: "Cantautor para ciclo acústico",
            venueName: "El Taller Live",
            city: "Barcelona",
            performanceDate: date(days: 4, hour: 21),
            durationMinutes: 50,
            budgetMin: 150,
            budgetMax: 220,
            currency: "EUR",
            roleNeeded: .musician,
            requiredGenres: ["Acustico", "Pop"],
            description: "Fecha ya cerrada, la mantenemos en datos demo para validar estados.",
            status: .booked,
            imageURL: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    ]

    static let reviews: [Review] = [
        Review(
            id: UUID(),
            reviewerID: venueHostID,
            revieweeID: lunaProfileID,
            gigID: gigs[0].id,
            rating: 5,
            comment: "Llegaron preparados, buen trato y un directo muy sólido.",
            createdAt: Date()
        ),
        Review(
            id: UUID(),
            reviewerID: barcelonaHostID,
            revieweeID: lunaProfileID,
            gigID: nil,
            rating: 4,
            comment: "Comunicación rápida y material promocional bien presentado.",
            createdAt: Date()
        ),
        Review(
            id: UUID(),
            reviewerID: venueHostID,
            revieweeID: marcosProfileID,
            gigID: gigs[1].id,
            rating: 5,
            comment: "Muy buen warm up y lectura de sala impecable.",
            createdAt: Date()
        ),
        Review(
            id: UUID(),
            reviewerID: marcosProfileID,
            revieweeID: venueHostID,
            gigID: gigs[1].id,
            rating: 5,
            comment: "Cabina cuidada, briefing claro y pago resuelto sin fricción.",
            createdAt: Date()
        ),
        Review(
            id: UUID(),
            reviewerID: UUID(),
            revieweeID: barcelonaHostID,
            gigID: gigs[2].id,
            rating: 4,
            comment: "Equipo atento y sala bien organizada para cambios rápidos.",
            createdAt: Date()
        )
    ]

    static var exploreCards: [ExploreCardItem] {
        makeExploreCards(gigs: gigs)
    }

    static func venue(forOwnerID ownerID: UUID) -> Venue? {
        venues.first { $0.ownerID == ownerID }
    }

    static func makeExploreCards(
        gigs: [Gig]
    ) -> [ExploreCardItem] {
        ExploreCardFactory.makeCards(
            gigs: gigs,
            venues: venues
        )
    }

    private static func date(days: Int, hour: Int) -> Date {
        let calendar = Calendar.current
        let baseDate = calendar.date(byAdding: .day, value: days, to: Date()) ?? Date()
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: baseDate) ?? baseDate
    }
}
