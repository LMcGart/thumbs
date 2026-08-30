import Places
import PhotosUI
import SwiftUI

struct ProfileView: View {
    @State private var profile: SocialService.Profile?
    @State private var handle = ""
    @State private var displayName = ""
    @State private var avatarItem: PhotosPickerItem?
    @State private var friendHandle = ""
    @State private var incoming: [SocialService.Profile] = []
    @State private var friends: [SocialService.Profile] = []
    @State private var myEntries: [FeedService.Entry] = []
    @State private var myLikes: [UUID: FeedService.LikeState] = [:]
    @State private var status: String?

    var body: some View {
        NavigationStack {
            List {
                Section("You") {
                    HStack {
                        PhotosPicker(selection: $avatarItem, matching: .images) {
                            AvatarView(path: profile?.avatar_path)
                        }
                        VStack(alignment: .leading) {
                            TextField("Display name", text: $displayName)
                            TextField("handle", text: $handle)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.caption)
                        }
                    }
                    Button("Save") { Task { await saveProfile() } }
                    if let status {
                        Text(status).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section("Your reviews — \(myEntries.count)") {
                    if myEntries.isEmpty {
                        Text("Nothing rated yet").foregroundStyle(.secondary)
                    }
                    ForEach(myEntries) { entry in
                        NavigationLink(value: entry) {
                            FeedEntryRow(
                                entry: entry,
                                like: myLikes[entry.id] ?? FeedService.LikeState(count: 0, liked: false),
                                onToggleLike: { toggleMyLike(entry.id) }
                            )
                        }
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                    }
                }
                Section("Add friend") {
                    HStack {
                        TextField("friend's handle", text: $friendHandle)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button("Request") { Task { await sendRequest() } }
                            .disabled(friendHandle.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                if !incoming.isEmpty {
                    Section("Requests") {
                        ForEach(incoming) { requester in
                            HStack {
                                Text(requester.shownName)
                                Spacer()
                                Button("Accept") { Task { await accept(requester) } }
                            }
                        }
                    }
                }
                Section("Friends") {
                    if friends.isEmpty {
                        Text("No friends yet").foregroundStyle(.secondary)
                    }
                    ForEach(friends) { friend in
                        HStack {
                            AvatarView(path: friend.avatar_path)
                            Text(friend.shownName)
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationDestination(for: PlaceSummary.self) { RestaurantView(place: $0) }
            .navigationDestination(for: FeedService.Entry.self) { VisitDetailView(entry: $0) }
        }
        .task { await reload() }
        .onChange(of: avatarItem) {
            guard let item = avatarItem else { return }
            avatarItem = nil
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    try? await SocialService.uploadAvatar(imageData: data)
                    await reload()
                }
            }
        }
    }

    private func toggleMyLike(_ visitID: UUID) {
        var state = myLikes[visitID] ?? FeedService.LikeState(count: 0, liked: false)
        state.liked.toggle()
        state.count += state.liked ? 1 : -1
        myLikes[visitID] = state
        let liked = state.liked
        Task { try? await FeedService.setVisitLike(visitID: visitID, liked: liked) }
    }

    private func reload() async {
        profile = try? await SocialService.myProfile()
        if let uid = try? await Supa.signInIfNeeded() {
            myEntries = (try? await FeedService.page(before: nil, limit: 100, userID: uid)) ?? []
            myLikes = (try? await FeedService.visitLikes(visitIDs: myEntries.map(\.id))) ?? [:]
        }
        handle = profile?.handle ?? ""
        displayName = profile?.display_name ?? ""
        guard let uid = try? await Supa.signInIfNeeded(),
              let rows = try? await SocialService.friendships()
        else { return }
        let incomingIDs = rows.filter { $0.addressee == uid && $0.status == "requested" }.map(\.requester)
        let friendIDs = rows.filter { $0.status == "accepted" }
            .map { $0.requester == uid ? $0.addressee : $0.requester }
        incoming = (try? await SocialService.profiles(ids: incomingIDs)) ?? []
        friends = (try? await SocialService.profiles(ids: friendIDs)) ?? []
    }

    private func saveProfile() async {
        do {
            try await SocialService.updateProfile(handle: handle, displayName: displayName)
            status = "Saved"
            await reload()
        } catch {
            status = "Couldn't save — handles are 3–20 lowercase letters, numbers, _ and must be unique"
        }
    }

    private func sendRequest() async {
        do {
            guard let target = try await SocialService.findProfile(handle: friendHandle) else {
                status = "No one with that handle"
                return
            }
            try await SocialService.sendRequest(to: target.id)
            status = "Request sent to \(target.shownName)"
            friendHandle = ""
        } catch {
            status = "Couldn't send request: \(error.localizedDescription)"
        }
    }

    private func accept(_ requester: SocialService.Profile) async {
        try? await SocialService.accept(requester: requester.id)
        await reload()
    }
}
