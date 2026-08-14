import Foundation
import Combine
import MapKit

@MainActor
final class VenueAddressSearchViewModel: NSObject, ObservableObject {
    @Published var query = "" {
        didSet {
            updateQueryFragment()
        }
    }

    @Published private(set) var suggestions: [VenueAddressSuggestion] = []
    @Published private(set) var isResolving = false
    @Published var errorMessage: String?

    private let completer = MKLocalSearchCompleter()
    private var completionsByID: [String: MKLocalSearchCompletion] = [:]

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.4168, longitude: -3.7038),
            span: MKCoordinateSpan(latitudeDelta: 14, longitudeDelta: 14)
        )
    }

    func resolve(_ suggestion: VenueAddressSuggestion) async -> VenueAddressSelection? {
        let naturalLanguageQuery: String
        if let completion = completionsByID[suggestion.id] {
            naturalLanguageQuery = [completion.title, completion.subtitle]
                .filter { $0.isEmpty == false }
                .joined(separator: ", ")
        } else {
            naturalLanguageQuery = suggestion.displayAddress
        }

        return await resolve(naturalLanguageQuery: naturalLanguageQuery, fallback: suggestion)
    }

    func resolveExistingSelection(_ selection: VenueAddressSelection) async -> VenueAddressSelection? {
        let naturalLanguageQuery = [
            selection.placeName,
            selection.address,
            selection.city
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: ", ")

        let fallback = VenueAddressSuggestion(
            id: "existing-\(selection.address)",
            title: selection.placeName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? selection.address,
            subtitle: selection.city?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? ""
        )

        return await resolve(naturalLanguageQuery: naturalLanguageQuery, fallback: fallback)
    }

    private func resolve(
        naturalLanguageQuery: String,
        fallback: VenueAddressSuggestion
    ) async -> VenueAddressSelection? {
        let trimmedQuery = naturalLanguageQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedQuery.isEmpty == false else {
            return nil
        }

        isResolving = true
        errorMessage = nil
        defer { isResolving = false }

        do {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = trimmedQuery
            let response = try await MKLocalSearch(request: request).start()
            guard let item = response.mapItems.first else {
                errorMessage = "No encontramos esa direccion."
                return nil
            }

            return VenueAddressSelection(
                placeName: item.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                address: Self.formatAddress(from: item.placemark, fallback: fallback),
                city: item.placemark.locality?.trimmingCharacters(in: .whitespacesAndNewlines),
                latitude: item.placemark.coordinate.latitude,
                longitude: item.placemark.coordinate.longitude
            )
        } catch {
            errorMessage = "No se pudo buscar la direccion. Intentalo de nuevo."
            return nil
        }
    }

    private func updateQueryFragment() {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        completer.queryFragment = trimmedQuery

        if trimmedQuery.isEmpty {
            suggestions = []
            completionsByID = [:]
            errorMessage = nil
        }
    }

    private static func formatAddress(
        from placemark: MKPlacemark,
        fallback: VenueAddressSuggestion
    ) -> String {
        let streetLine = [
            placemark.subThoroughfare,
            placemark.thoroughfare
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: " ")

        let components = [
            streetLine,
            placemark.postalCode,
            placemark.locality,
            placemark.administrativeArea,
            placemark.country
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        if components.isEmpty {
            return fallback.displayAddress
        }

        return Array(NSOrderedSet(array: components)).compactMap { $0 as? String }.joined(separator: ", ")
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

extension VenueAddressSearchViewModel: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let completions = completer.results

        Task { @MainActor [weak self] in
            guard let self else { return }

            var completionsByID: [String: MKLocalSearchCompletion] = [:]

            let suggestions = completions.enumerated().map { index, completion in
                let id = "\(completion.title)|\(completion.subtitle)|\(index)"
                completionsByID[id] = completion
                return VenueAddressSuggestion(
                    id: id,
                    title: completion.title,
                    subtitle: completion.subtitle
                )
            }

            self.completionsByID = completionsByID
            self.suggestions = suggestions
            self.errorMessage = nil
        }
    }

    nonisolated func completer(
        _ completer: MKLocalSearchCompleter,
        didFailWithError error: Error
    ) {
        Task { @MainActor [weak self] in
            self?.suggestions = []
            self?.completionsByID = [:]
            self?.errorMessage = "No se pudo buscar la direccion. Intentalo de nuevo."
        }
    }
}
