import Foundation

struct UserProfile: Identifiable, Codable, Equatable {
    let id: UUID
    var email: String
    var displayName: String
    var role: UserRole
    var city: String
    var venueAddress: String? // Direccion publica para la ficha del local o promotora.
    var venuePlaceName: String? // Nombre devuelto por MapKit cuando el local se selecciona desde busqueda.
    var venueLatitude: Double? // Coordenada opcional para ordenar/mostrar locales en mapas.
    var venueLongitude: Double? // Coordenada opcional para abrir el local en mapas.
    var bio: String?
    var avatarURL: URL?
    var genres: [String]
    var instruments: [String]
    var instrumentCounts: [String: Int] // Solo para perfiles musicales cuando un instrumento aparece varias veces.
    var venueCapacity: Int? // Aforo orientativo cuando el perfil representa un local o promotora.
    var isPremium: Bool // Activa ventajas de suscripcion y menor presencia de publicidad.
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case role
        case city
        case venueAddress = "venue_address"
        case venuePlaceName = "venue_place_name"
        case venueLatitude = "venue_latitude"
        case venueLongitude = "venue_longitude"
        case bio
        case avatarURL = "avatar_url"
        case genres
        case instruments
        case instrumentCounts = "instrument_counts"
        case venueCapacity = "venue_capacity"
        case isPremium = "is_premium"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: UUID,
        email: String,
        displayName: String,
        role: UserRole,
        city: String,
        venueAddress: String? = nil,
        venuePlaceName: String? = nil,
        venueLatitude: Double? = nil,
        venueLongitude: Double? = nil,
        bio: String? = nil,
        avatarURL: URL? = nil,
        genres: [String] = [],
        instruments: [String] = [],
        instrumentCounts: [String: Int] = [:],
        venueCapacity: Int? = nil,
        isPremium: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.role = role
        self.city = city
        self.venueAddress = venueAddress
        self.venuePlaceName = venuePlaceName
        self.venueLatitude = venueLatitude
        self.venueLongitude = venueLongitude
        self.bio = bio
        self.avatarURL = avatarURL
        self.genres = genres
        self.instruments = instruments
        self.instrumentCounts = instrumentCounts
        self.venueCapacity = venueCapacity
        self.isPremium = isPremium
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        displayName = try container.decode(String.self, forKey: .displayName)
        role = try container.decode(UserRole.self, forKey: .role)
        city = try container.decode(String.self, forKey: .city)
        venueAddress = try container.decodeIfPresent(String.self, forKey: .venueAddress)
        venuePlaceName = try container.decodeIfPresent(String.self, forKey: .venuePlaceName)
        venueLatitude = try container.decodeIfPresent(Double.self, forKey: .venueLatitude)
        venueLongitude = try container.decodeIfPresent(Double.self, forKey: .venueLongitude)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        avatarURL = try container.decodeIfPresent(URL.self, forKey: .avatarURL)
        genres = try container.decodeIfPresent([String].self, forKey: .genres) ?? []
        instruments = try container.decodeIfPresent([String].self, forKey: .instruments) ?? []
        instrumentCounts = try container.decodeIfPresent([String: Int].self, forKey: .instrumentCounts) ?? [:]
        venueCapacity = try container.decodeIfPresent(Int.self, forKey: .venueCapacity)
        isPremium = try container.decodeIfPresent(Bool.self, forKey: .isPremium) ?? false
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }
}

extension UserProfile {
    var musicianFormations: [String] {
        guard role == .musician else {
            return []
        }

        return instruments.filter { ProfileOptionCatalog.musicianFormationOptions.contains($0) }
    }

    var musicianInstruments: [String] {
        guard role == .musician else {
            return []
        }

        return instruments.filter { ProfileOptionCatalog.musicianFormationOptions.contains($0) == false }
    }

    var venueBandGenres: [String] {
        role == .venue ? genres : []
    }

    var venueDJGenres: [String] {
        role == .venue ? instruments : []
    }

    func preferredGenres(for venueRoleNeeded: UserRole? = nil) -> [String] {
        switch role {
        case .musician:
            return genres
        case .dj:
            return []
        case .venue:
            switch venueRoleNeeded {
            case .dj:
                return venueDJGenres
            case .musician, .venue, .none:
                return venueBandGenres
            }
        }
    }

    var exploreTags: [String] {
        switch role {
        case .musician:
            return genres
        case .dj:
            return formattedInstrumentItems
        case .venue:
            return Array(Set(venueBandGenres + venueDJGenres)).sorted()
        }
    }

    var isProfileComplete: Bool {
        let hasBaseFields = displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && bioText.isEmpty == false

        guard hasBaseFields else {
            return false
        }

        switch role {
        case .musician:
            return genres.isEmpty == false && (musicianFormations.isEmpty == false || musicianInstruments.isEmpty == false)
        case .dj:
            return instruments.isEmpty == false
        case .venue:
            return venueCapacity != nil
                && venueAddressText.isEmpty == false
                && (venueBandGenres.isEmpty == false || venueDJGenres.isEmpty == false)
        }
    }

    var missingProfileRequirements: [String] {
        var requirements: [String] = []

        if displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            requirements.append(role == .venue ? "nombre del local" : "nombre publico")
        }

        if city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            requirements.append("ciudad")
        }

        if bioText.isEmpty {
            requirements.append("bio")
        }

        switch role {
        case .musician:
            if genres.isEmpty {
                requirements.append("generos")
            }
            if instruments.isEmpty {
                requirements.append("instrumentos o formacion")
            }
        case .dj:
            if instruments.isEmpty {
                requirements.append("setup o formato")
            }
        case .venue:
            if venueBandGenres.isEmpty && venueDJGenres.isEmpty {
                requirements.append("generos para bandas o DJs")
            }
            if venueCapacity == nil {
                requirements.append("aforo")
            }
            if venueAddressText.isEmpty {
                requirements.append("direccion")
            }
        }

        return requirements
    }

    var bioText: String {
        bio?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    var venueAddressText: String {
        venueAddress?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    var venuePlaceNameText: String {
        venuePlaceName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    var renderIdentity: String {
        "\(id.uuidString)-\(updatedAt.timeIntervalSince1970)"
    }

    var formattedInstrumentItems: [String] {
        switch role {
        case .musician:
            return musicianInstruments.map { detail in
                guard let count = instrumentCounts[detail], count > 1 else {
                    return detail
                }

                return "\(detail) x\(count)"
            }
        case .dj:
            return instruments
        case .venue:
            return []
        }
    }

    var summaryDetailItems: [String] {
        switch role {
        case .musician:
            return musicianFormations + formattedInstrumentItems
        case .dj:
            return instruments
        case .venue:
            return []
        }
    }
}
