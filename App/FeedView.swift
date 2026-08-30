import Media
import Places
import SwiftUI

/// Friends' visits, newest first, shown on Home beneath the search bar.
struct FeedView: View {
    @State private var entries: [FeedService.Entry] = []
    @State private var loading = false
    @State private var exhausted = false
    @State private var loadedOnce = false

    var body: some View {
        List {
            if entries.isEmpty && loadedOnce && !loading {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No visits yet").font(.headline)
                    Text("Add friends from your profile to see where they've been eating.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .listRowSeparator(.hidden)
            }
            ForEach(entries) { entry in
                NavigationLink(value: entry) {
                    FeedEntryRow(entry: entry)
                }
                .onAppear {
                    if entry.id == entries.last?.id { Task { await loadMore() } }
                }
            }
            if loading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .refreshable { await reload() }
        .task { await reload() }
    }

    private func reload() async {
        loading = true
        entries = (try? await FeedService.page(before: nil)) ?? []
        exhausted = entries.count < 20
        loading = false
        loadedOnce = true
    }

    private func loadMore() async {
        guard !loading, !exhausted, let last = entries.last else { return }
        loading = true
        let next = (try? await FeedService.page(before: last.visitedAt)) ?? []
        entries.append(contentsOf: next.filter { entry in !entries.contains { $0.id == entry.id } })
        exhausted = next.count < 20
        loading = false
    }
}

private struct FeedEntryRow: View {
    let entry: FeedService.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                AvatarView(path: entry.user.avatar_path)
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.user.shownName).font(.subheadline.bold())
                    Text(entry.visitedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                if let score = entry.score {
                    Text("\(score)").font(.title3.bold())
                }
            }
            Text(entry.placeName).font(.body)
            if !entry.photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(entry.photos) { photo in
                            TierImage(basePath: photo.storage_path, tier: .display)
                                .frame(width: 180, height: 130)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct VisitDetailView: View {
    let entry: FeedService.Entry
    @State private var place: Places.PlaceSummary?
    @State private var dishes: [(name: String, verdict: String)] = []
    @State private var comments: [FeedService.Comment] = []
    @State private var draft = ""
    @State private var replyTo: FeedService.Comment?
    @State private var myID: UUID?

    var body: some View {
        List {
            Section {
                if let place {
                    NavigationLink(value: place) {
                        Text(entry.placeName).font(.headline)
                    }
                } else {
                    Text(entry.placeName).font(.headline)
                }
                HStack {
                    AvatarView(path: entry.user.avatar_path)
                    Text(entry.user.shownName).font(.subheadline.bold())
                    Spacer()
                    if let score = entry.score { Text("\(score)/10").font(.title3.bold()) }
                }
                Text(entry.visitedAt.formatted(date: .long, time: .omitted))
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !entry.photos.isEmpty {
                Section {
                    PhotoGridView(photos: entry.photos)
                }
            }
            if !dishes.isEmpty {
                Section("Dishes") {
                    ForEach(dishes, id: \.name) { dish in
                        HStack {
                            Text(dish.name)
                            Spacer()
                            Text(dish.verdict.capitalized).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section("Comments") {
                ForEach(comments.filter { $0.parent_id == nil }) { comment in
                    commentRow(comment, indented: false)
                    ForEach(comments.filter { $0.parent_id == comment.id }) { reply in
                        commentRow(reply, indented: true)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    if let replyTo {
                        HStack(spacing: 6) {
                            Text("Replying to \(replyTo.profiles.shownName)")
                                .font(.caption).foregroundStyle(.secondary)
                            Button("Cancel") { self.replyTo = nil }.font(.caption)
                        }
                    }
                    HStack {
                        TextField(replyTo == nil ? "Add a comment…" : "Write a reply…", text: $draft, axis: .vertical)
                        Button("Send") { Task { await sendComment() } }
                            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .navigationTitle(entry.placeName)
        .task {
            myID = try? await Supa.signInIfNeeded()
            place = try? await FeedService.place(id: entry.placeID)
            dishes = (try? await FeedService.dishes(visitID: entry.id)) ?? []
            comments = (try? await FeedService.comments(visitID: entry.id)) ?? []
        }
    }

    @ViewBuilder
    private func commentRow(_ comment: FeedService.Comment, indented: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(comment.profiles.shownName).font(.caption.bold())
                Text(comment.created_at.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
                if !indented {
                    Button("Reply") { replyTo = comment }
                        .font(.caption2)
                        .buttonStyle(.borderless)
                }
            }
            Text(comment.body)
        }
        .padding(.leading, indented ? 24 : 0)
        .swipeActions {
            if comment.user_id == myID {
                Button("Delete", role: .destructive) {
                    Task {
                        try? await FeedService.deleteComment(id: comment.id)
                        comments = (try? await FeedService.comments(visitID: entry.id)) ?? []
                    }
                }
            }
        }
    }

    private func sendComment() async {
        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        do {
            try await FeedService.addComment(visitID: entry.id, body: body, parentID: replyTo?.id)
            draft = ""
            replyTo = nil
            comments = (try? await FeedService.comments(visitID: entry.id)) ?? comments
        } catch {}
    }
}

struct AvatarView: View {
    let path: String?
    @State private var url: URL?

    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Circle().fill(.quaternary)
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
        .task(id: path) {
            guard let path else { return }
            url = try? await SocialService.avatarURL(path: path)
        }
    }
}
