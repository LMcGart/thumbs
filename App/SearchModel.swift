import CoreLocation
import Foundation
import MapKit
import Observation
import Places
import Supabase

@MainActor @Observable
final class SearchModel {
    var hits: [SearchHit] = []
    var searching = false
    var errorMessage: String?

    // NYC bias per the item 5 spec; becomes the user's location when the app
    // gains location permission in a later item.
    private let bias = Coordinate(latitude: 40.7291, longitude: -73.9965)

    private struct SearchParams: Encodable {
        let query: String
        let near_lat: Double
        let near_lon: Double
    }

    private struct ServerRow: Decodable {
        let id: Int64
        let name: String
        let category: String
        let subtype: String?
        let address: String?
        let lat: Double
        let lon: Double
        let distance_meters: Double
    }

    func search(_ rawQuery: String) async {
        let query = rawQuery.trimmingCharacters(in: .whitespaces)
        guard query.count >= 2 else { hits = []; return }
        searching = true
        defer { searching = false }
        do {
            _ = try await Supa.signInIfNeeded()
            // Both suppliers race in parallel on every query: Apple for the
            // finding, our rows for the knowing; the blend dedupes.
            async let appleResults = appleSearch(query)
            let rows: [ServerRow] = try await Supa.client
                .rpc("search_places", params: SearchParams(query: query, near_lat: bias.latitude, near_lon: bias.longitude))
                .execute().value
            let server = rows.map { row in
                PlaceSummary(
                    id: row.id, name: row.name,
                    category: PlaceCategory(rawValue: row.category) ?? .restaurant,
                    subtype: row.subtype, address: row.address,
                    coordinate: Coordinate(latitude: row.lat, longitude: row.lon),
                    distanceMeters: row.distance_meters
                )
            }
            let apple = await appleResults
            guard !Task.isCancelled else { return }
            hits = blendSearchResults(server: server, apple: apple)
            errorMessage = nil
        } catch is CancellationError {
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
        }
    }

    private func appleSearch(_ query: String) async -> [AppleCandidate] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .pointOfInterest
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [
            .restaurant, .cafe, .bakery, .brewery, .winery, .nightlife, .foodMarket,
        ])
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: bias.latitude, longitude: bias.longitude),
            latitudinalMeters: 60_000, longitudinalMeters: 60_000
        )
        guard let response = try? await MKLocalSearch(request: request).start() else { return [] }
        return response.mapItems.compactMap { item in
            guard let name = item.name, let location = item.placemark.location else { return nil }
            return AppleCandidate(
                mapKitID: item.identifier?.rawValue,
                name: name,
                category: Self.reviewCategory(item.pointOfInterestCategory),
                address: item.placemark.title,
                coordinate: Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            )
        }
    }

    private static func reviewCategory(_ poi: MKPointOfInterestCategory?) -> PlaceCategory {
        switch poi {
        case .some(.cafe), .some(.bakery): .cafe
        case .some(.nightlife), .some(.brewery), .some(.winery): .bar
        default: .restaurant
        }
    }

    private struct PlaceInsert: Encodable {
        let name: String
        let mapkit_id: String?
        let location: String
        let category: String
        let address: String?
    }

    private struct InsertedRow: Decodable {
        let id: Int64
        let name: String
        let category: String
        let subtype: String?
        let address: String?
    }

    /// Saves a picked Apple result into places (idempotent on mapkit_id) and
    /// returns the row, whether new or already present.
    func addApplePlace(_ candidate: AppleCandidate) async throws -> PlaceSummary {
        _ = try await Supa.signInIfNeeded()
        let insert = PlaceInsert(
            name: candidate.name,
            mapkit_id: candidate.mapKitID,
            location: "POINT(\(candidate.coordinate.longitude) \(candidate.coordinate.latitude))",
            category: candidate.category.rawValue,
            address: candidate.address
        )
        let row: InsertedRow
        if candidate.mapKitID != nil {
            try await Supa.client.from("places")
                .upsert(insert, onConflict: "mapkit_id", ignoreDuplicates: true)
                .execute()
            let rows: [InsertedRow] = try await Supa.client.from("places")
                .select("id,name,category,subtype,address")
                .eq("mapkit_id", value: candidate.mapKitID!)
                .limit(1).execute().value
            guard let existing = rows.first else { throw URLError(.badServerResponse) }
            row = existing
        } else {
            row = try await Supa.client.from("places")
                .insert(insert).select("id,name,category,subtype,address")
                .single().execute().value
        }
        return PlaceSummary(
            id: row.id, name: row.name,
            category: PlaceCategory(rawValue: row.category) ?? .restaurant,
            subtype: row.subtype, address: row.address ?? candidate.address,
            coordinate: candidate.coordinate, distanceMeters: nil
        )
    }
}
