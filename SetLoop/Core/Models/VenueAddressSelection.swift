import Foundation

struct VenueAddressSuggestion: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String

    var displayAddress: String {
        [title, subtitle]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: ", ")
    }
}

struct VenueAddressSelection: Equatable {
    var placeName: String?
    var address: String
    var city: String?
    var latitude: Double? // Coordenada usada luego para ordenar/mostrar fechas por ubicacion.
    var longitude: Double? // Coordenada usada luego para abrir mapas externos o vistas de mapa.
}
