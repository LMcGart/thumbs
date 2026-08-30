import Places
import SwiftUI

struct SearchHomeView: View {
    @State private var model = SearchModel()
    @State private var query = ""
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if query.isEmpty {
                    FeedView()
                } else {
                    resultsList
                }
            }
            .searchable(text: $query, prompt: "Restaurant, cafe, bar…")
            .task(id: query) {
                // Debounce; .task(id:) cancels the previous search on each keystroke.
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                await model.search(query)
            }
            .navigationTitle("Thumbs")
            .navigationDestination(for: PlaceSummary.self) { RestaurantView(place: $0) }
            .navigationDestination(for: FeedService.Entry.self) { VisitDetailView(entry: $0) }
        }
    }

    private var resultsList: some View {
        List {
                if let message = model.errorMessage {
                    Text(message).foregroundStyle(.red)
                }
                if model.searching && model.hits.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Searching…").foregroundStyle(.secondary)
                    }
                }
                ForEach(model.hits) { hit in
                    switch hit {
                    case .place(let place):
                        NavigationLink(value: place) { PlaceRowView(place: place) }
                    case .apple(let candidate):
                        Button {
                            Task {
                                if let place = try? await model.addApplePlace(candidate) {
                                    path.append(place)
                                }
                            }
                        } label: {
                            AppleRowView(candidate: candidate)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if model.hits.isEmpty && query.count >= 2 && !model.searching {
                    Text("No matches.").foregroundStyle(.secondary)
                }
        }
    }
}

private struct PlaceRowView: View {
    let place: PlaceSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(place.name)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if let subtype = place.subtype { parts.append(subtype.replacingOccurrences(of: "_", with: " ")) }
        if let meters = place.distanceMeters {
            parts.append(meters < 1000 ? "\(Int(meters)) m" : String(format: "%.1f km", meters / 1000))
        }
        return parts.joined(separator: " · ")
    }
}

private struct AppleRowView: View {
    let candidate: AppleCandidate

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(candidate.name)
                Spacer()
                Text("Apple Maps")
                    .font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
            if let address = candidate.address {
                Text(address).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }
}
