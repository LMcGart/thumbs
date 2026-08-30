import Places
import Rating
import SwiftUI

struct RatingFlowView: View {
    let place: PlaceSummary
    let presetScore: Int?
    var onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("bandMateRotation") private var rotation = 0
    @State private var selected: Int?
    @State private var category: PlaceCategory
    @State private var ratedPlaces: [RatedPlace] = []
    @State private var shown: BandMates?
    @State private var savedVisitID: UUID?
    @State private var errorMessage: String?
    @State private var dishName = ""
    @State private var dishSuggestions: [String] = []
    @State private var savedDishes: [String] = []

    init(place: PlaceSummary, presetScore: Int? = nil, onSaved: @escaping () -> Void) {
        self.place = place
        self.presetScore = presetScore
        self.onSaved = onSaved
        _selected = State(initialValue: presetScore)
        _category = State(initialValue: place.category)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Menu {
                    ForEach(PlaceCategory.allCases, id: \.self) { option in
                        Button(option.rawValue.capitalized) { category = option }
                    }
                } label: {
                    Text(category.rawValue.capitalized)
                        .font(.caption).padding(.horizontal, 10).padding(.vertical, 4)
                        .background(.quaternary, in: Capsule())
                }

                bandMateArea
                    .frame(minHeight: 96)

                RatingSliderView(
                    selected: $selected,
                    histogram: ratingHistogram(category: category, from: ratedPlaces),
                    enabled: savedVisitID == nil,
                    onCommit: { score in Task { await save(score) } }
                )
                .padding(.horizontal, 4)

                if let errorMessage {
                    Text(errorMessage).font(.caption).foregroundStyle(.red)
                }

                if savedVisitID != nil {
                    dishSection
                }
                Spacer()
            }
            .padding()
            .navigationTitle(place.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(savedVisitID == nil ? "Cancel" : "Done") { dismiss() }
                }
            }
        }
        .task {
            rotation += 1
            ratedPlaces = (try? await RatingService.myRatedPlaces()) ?? []
            dishSuggestions = (try? await RatingService.dishNames(placeID: place.id)) ?? []
        }
        .task(id: selected) {
            // Swap band-mates only after the thumb rests on a stop (~150 ms)
            // so a fast drag doesn't strobe.
            guard let selected else { shown = nil; return }
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                shown = bandMates(at: selected, category: category, from: ratedPlaces.filter { $0.id != place.id }, rotation: rotation)
            }
        }
    }

    @ViewBuilder
    private var bandMateArea: some View {
        if let shown {
            VStack(alignment: .leading, spacing: 6) {
                if let empty = shown.emptyLabel {
                    Text(empty).font(.caption).foregroundStyle(.secondary)
                }
                ForEach(shown.groups, id: \.score) { group in
                    VStack(alignment: .leading, spacing: 4) {
                        if let label = group.label {
                            Text(label).font(.caption2).foregroundStyle(.secondary)
                        }
                        HStack(spacing: 8) {
                            ForEach(group.places.prefix(3)) { mate in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mate.name).font(.caption).lineLimit(2)
                                    Text("\(mate.score)").font(.caption2.bold()).foregroundStyle(.secondary)
                                }
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }
            .transition(.opacity)
        } else {
            Text(selected == nil ? "Slide or tap a number to rate" : "")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 96)
        }
    }

    private var dishSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dishes (optional)").font(.headline)
            TextField("Dish name", text: $dishName)
                .textFieldStyle(.roundedBorder)
            let matches = dishSuggestions.filter {
                !dishName.isEmpty && $0.lowercased().hasPrefix(dishName.lowercased()) && $0.lowercased() != dishName.lowercased()
            }
            ForEach(matches.prefix(3), id: \.self) { suggestion in
                Button(suggestion) { dishName = suggestion }.font(.caption)
            }
            if !dishName.trimmingCharacters(in: .whitespaces).isEmpty {
                HStack {
                    ForEach(["must", "good", "skip"], id: \.self) { verdict in
                        Button(verdict.capitalized) { Task { await addDish(verdict: verdict) } }
                            .buttonStyle(.bordered)
                    }
                }
            }
            ForEach(savedDishes, id: \.self) { line in
                Text(line).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func save(_ score: Int) async {
        guard savedVisitID == nil else { return }
        do {
            savedVisitID = try await RatingService.saveRating(placeID: place.id, score: score, category: category)
            onSaved()
        } catch {
            errorMessage = "Couldn't save: \(error.localizedDescription)"
        }
    }

    private func addDish(verdict: String) async {
        guard let visitID = savedVisitID else { return }
        let name = dishName.trimmingCharacters(in: .whitespaces)
        do {
            try await RatingService.saveDish(visitID: visitID, name: name, verdict: verdict)
            savedDishes.append("\(name) — \(verdict)")
            if !dishSuggestions.contains(where: { $0.lowercased() == name.lowercased() }) {
                dishSuggestions.append(name)
            }
            dishName = ""
        } catch {
            errorMessage = "Couldn't save dish: \(error.localizedDescription)"
        }
    }
}
