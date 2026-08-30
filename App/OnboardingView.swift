import Places
import SwiftUI

/// First-run calibration: handle → photo access → rate your last places →
/// find friends. Guarded by the completion flag so it can't re-trigger.
struct OnboardingView: View {
    @Binding var complete: Bool

    private enum Step { case welcome, profile, photos, cards, friends }
    @State private var step = Step.welcome
    @State private var displayName = ""
    @State private var handle = ""
    @State private var profileStatus: String?
    @State private var detecting = false
    @State private var detected: [DetectedPlace] = []
    @State private var rated: Set<UUID> = []
    @State private var ratingTarget: DetectedPlace?
    @State private var friendHandle = ""
    @State private var friendStatus: String?

    var body: some View {
        NavigationStack {
            switch step {
            case .welcome: welcome
            case .profile: profileStep
            case .photos: photosStep
            case .cards: cardsStep
            case .friends: friendsStep
            }
        }
        .interactiveDismissDisabled()
    }

    private var welcome: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("Thumbs").font(.largeTitle.bold())
            Text("Rate the places you eat, see where your friends actually go.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Get started") { step = .profile }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var profileStep: some View {
        Form {
            Section("What should friends see?") {
                TextField("Display name", text: $displayName)
                TextField("handle (for friend requests)", text: $handle)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            if let profileStatus {
                Text(profileStatus).font(.caption).foregroundStyle(.red)
            }
            Button("Continue") {
                Task {
                    do {
                        try await SocialService.updateProfile(handle: handle, displayName: displayName)
                        step = .photos
                    } catch {
                        profileStatus = "Handles are 3–20 lowercase letters, numbers or _ and must be unique."
                    }
                }
            }
            .disabled(handle.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .navigationTitle("Your profile")
    }

    private var photosStep: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "photo.stack").font(.system(size: 44)).foregroundStyle(.secondary)
            Text("Find the places you've already been")
                .font(.title3.bold())
                .multilineTextAlignment(.center)
            Text("We use the location and time on your photos to spot restaurants you've visited, so reviewing takes one tap. Nothing is uploaded until you choose to share it.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            if detecting {
                ProgressView("Looking through your recent photos…")
            } else {
                Button("Find my recent places") {
                    Task {
                        detecting = true
                        detected = await OnboardingService.recentPlaces()
                        detecting = false
                        step = detected.isEmpty ? .friends : .cards
                    }
                }
                .buttonStyle(.borderedProminent)
                Button("Skip") { step = .friends }
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private var cardsStep: some View {
        List {
            Section {
                Text("Rate the ones you remember — skip anything that's wrong or fuzzy.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach($detected) { $item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        if item.candidates.count > 1 {
                            Picker("", selection: $item.chosen) {
                                ForEach(0..<item.candidates.count, id: \.self) { index in
                                    Text(item.candidates[index].place.name).tag(index)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        } else {
                            Text(item.chosenPlace.name)
                        }
                        Text("\(item.visitedAt.formatted(date: .abbreviated, time: .omitted)) · \(item.photoCount) photo\(item.photoCount == 1 ? "" : "s")")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if rated.contains(item.id) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Button("Rate") { ratingTarget = item }
                            .buttonStyle(.bordered)
                    }
                }
            }
            Button("Done") { step = .friends }
        }
        .navigationTitle("Your recent places")
        .sheet(item: $ratingTarget) { target in
            RatingFlowView(place: target.chosenPlace, initialDate: target.visitedAt) {
                rated.insert(target.id)
            }
        }
    }

    private var friendsStep: some View {
        Form {
            Section("Find a friend by handle") {
                HStack {
                    TextField("their handle", text: $friendHandle)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Request") {
                        Task {
                            guard let target = try? await SocialService.findProfile(handle: friendHandle) else {
                                friendStatus = "No one with that handle yet"
                                return
                            }
                            try? await SocialService.sendRequest(to: target.id)
                            friendStatus = "Request sent to \(target.shownName)"
                            friendHandle = ""
                        }
                    }
                    .disabled(friendHandle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if let friendStatus {
                    Text(friendStatus).font(.caption).foregroundStyle(.secondary)
                }
            }
            Button("Finish") { complete = true }
        }
        .navigationTitle("Find friends")
    }
}
