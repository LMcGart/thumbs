import CryptoKit
import Media
import Places
import PhotosUI
import Rating
import SwiftUI

/// A photo attached during the flow but not yet uploaded: uploads start only
/// when the review is kept, so cancelling leaves no trace.
private struct StagedPhoto: Identifiable, Sendable {
    let id: String
    let data: Data
    let preview: CGImage?
    let date: Date?
    let suggestionID: String?
}

struct RatingFlowView: View {
    let place: PlaceSummary
    var onSaved: () -> Void
    /// Captured once at presentation: the parent refreshes its rating while
    /// this sheet is up, and a re-evaluated `preset` must not silently turn a
    /// first rating into an "edit".
    @State private var original: RatingService.MyRating?

    @Environment(\.dismiss) private var dismiss
    @AppStorage("bandMateRotation") private var rotation = 0
    @State private var selected: Int?
    @State private var category: PlaceCategory
    @State private var ratedPlaces: [RatedPlace] = []
    @State private var shown: BandMates?
    @State private var savedVisitID: UUID?
    @State private var saveTask: Task<Void, Never>?
    @State private var discarded = false
    @State private var errorMessage: String?
    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var suggestions: [PhotoSuggestion] = []
    @State private var staged: [StagedPhoto] = []
    @State private var visitDate = Date()
    @State private var dateEdited = false
    @State private var dateAutofilled = false
    @State private var dishName = ""
    @State private var dishSuggestions: [String] = []
    @State private var savedDishes: [String] = []

    init(place: PlaceSummary, preset: RatingService.MyRating? = nil, onSaved: @escaping () -> Void) {
        self.place = place
        self.onSaved = onSaved
        _original = State(initialValue: preset)
        _selected = State(initialValue: preset?.score)
        _category = State(initialValue: preset?.category ?? place.category)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
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

                    DatePicker("Visited", selection: dateBinding, in: ...Date(), displayedComponents: .date)
                        .font(.subheadline)

                    bandMateArea
                        .frame(minHeight: 96)

                    RatingSliderView(
                        selected: $selected,
                        histogram: ratingHistogram(category: category, from: ratedPlaces),
                        onCommit: { score in saveTask = Task { await save(score) } }
                    )
                    .padding(.horizontal, 4)

                    if let errorMessage {
                        Text(errorMessage).font(.caption).foregroundStyle(.red)
                    }

                    if savedVisitID != nil {
                        photoSection
                        dishSection
                    }
                }
                .padding()
            }
            .navigationTitle(place.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // First rating: X discards the rating and staged photos.
                    // Editing: X reverts score/category and drops staged photos.
                    Button {
                        Task { await cancelOut() }
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                if savedVisitID != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
        .task {
            rotation += 1
            ratedPlaces = (try? await RatingService.myRatedPlaces()) ?? []
            dishSuggestions = (try? await RatingService.dishNames(placeID: place.id)) ?? []
            suggestions = await PhotoSuggestionService.suggestions(
                latitude: place.coordinate.latitude,
                longitude: place.coordinate.longitude
            )
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
        .onChange(of: pickedItems) {
            let items = pickedItems
            pickedItems = []
            Task { await stagePicked(items) }
        }
        .onDisappear {
            // The review was kept: upload staged photos in the background,
            // outliving this sheet. A discarded review uploads nothing.
            guard !discarded, let visitID = savedVisitID, !staged.isEmpty else { return }
            let uploads = staged
            Task.detached(priority: .utility) {
                for photo in uploads {
                    _ = try? await PhotoService.attach(imageData: photo.data, visitID: visitID)
                }
            }
        }
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: { visitDate },
            set: { newDate in
                visitDate = newDate
                dateEdited = true
                if let visitID = savedVisitID {
                    Task { try? await RatingService.setVisitDate(visitID: visitID, date: newDate) }
                }
            }
        )
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

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !suggestions.isEmpty {
                Text("Taken near \(place.name)").font(.caption).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(suggestions) { suggestion in
                            ZStack(alignment: .bottomTrailing) {
                                Image(decorative: suggestion.image, scale: 1)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                if staged.contains(where: { $0.suggestionID == suggestion.id }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.white, .green)
                                        .padding(3)
                                }
                            }
                            .onTapGesture { Task { await toggleSuggestion(suggestion) } }
                        }
                    }
                }
            }
            PhotosPicker(selection: $pickedItems, maxSelectionCount: 6, matching: .images) {
                Label("Add photos", systemImage: "photo.on.rectangle.angled")
            }
            if !staged.isEmpty {
                Text("\(staged.count) photo\(staged.count == 1 ? "" : "s") attached — uploads when you're done (tap to remove)")
                    .font(.caption2).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(staged) { photo in
                            Group {
                                if let preview = photo.preview {
                                    Image(decorative: preview, scale: 1).resizable().scaledToFill()
                                } else {
                                    Rectangle().fill(.quaternary)
                                }
                            }
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .onTapGesture { staged.removeAll { $0.id == photo.id } }
                        }
                    }
                }
            }
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

    private func toggleSuggestion(_ suggestion: PhotoSuggestion) async {
        if let index = staged.firstIndex(where: { $0.suggestionID == suggestion.id }) {
            staged.remove(at: index)
            return
        }
        guard let data = await PhotoSuggestionService.imageData(assetID: suggestion.id) else {
            errorMessage = "Couldn't load that photo"
            return
        }
        stage(data: data, preview: suggestion.image, date: suggestion.date, suggestionID: suggestion.id)
    }

    private func stagePicked(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let preview = downsampledImage(from: data, maxEdge: 240)
            stage(data: data, preview: preview, date: captureDate(from: data), suggestionID: nil)
        }
    }

    private func stage(data: Data, preview: CGImage?, date: Date?, suggestionID: String?) {
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard !staged.contains(where: { $0.id == hash }) else { return }
        staged.append(StagedPhoto(id: hash, data: data, preview: preview, date: date, suggestionID: suggestionID))
        autofillDate(date ?? captureDate(from: data))
    }

    /// First staged photo with a capture date sets the visit date, unless the
    /// user already chose one by hand.
    private func autofillDate(_ date: Date?) {
        guard let date, !dateEdited, !dateAutofilled else { return }
        dateAutofilled = true
        visitDate = date
        if let visitID = savedVisitID {
            Task { try? await RatingService.setVisitDate(visitID: visitID, date: date) }
        }
    }

    // Release = done, but not final: every commit upserts the one rating for
    // this place; the first also ensures a visit exists for attachments.
    private func save(_ score: Int) async {
        do {
            let firstSave = savedVisitID == nil
            savedVisitID = try await RatingService.saveRating(placeID: place.id, score: score, category: category, visitedAt: visitDate)
            if firstSave, dateEdited || dateAutofilled, let visitID = savedVisitID {
                // The visit may predate this flow; make its date match the picker.
                try? await RatingService.setVisitDate(visitID: visitID, date: visitDate)
            }
            onSaved()
        } catch {
            errorMessage = "Couldn't save: \(error.localizedDescription)"
        }
    }

    private func cancelOut() async {
        // A commit fired by the same gesture may still be in flight; settle it
        // first so the undo decision sees the true state.
        await saveTask?.value
        discarded = true
        staged = []
        do {
            if let original {
                if savedVisitID != nil, selected != original.score || category != original.category {
                    _ = try await RatingService.saveRating(placeID: place.id, score: original.score, category: original.category)
                    onSaved()
                }
            } else if savedVisitID != nil {
                try await RatingService.removeRating(placeID: place.id)
                onSaved()
            }
            dismiss()
        } catch {
            errorMessage = "Couldn't undo: \(error.localizedDescription)"
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
