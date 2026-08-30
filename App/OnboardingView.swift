import Places
import SwiftUI

/// First run: handle → find friends → home. Detection was cut from onboarding
/// (2026-08-29) — client-side signals can't hit the accuracy bar without the
/// app's own visit data as a prior; see docs/later.md. Guarded by the
/// completion flag so it can't re-trigger.
struct OnboardingView: View {
    @Binding var complete: Bool

    private enum Step { case welcome, profile, friends }
    @State private var step = Step.welcome
    @State private var displayName = ""
    @State private var handle = ""
    @State private var profileStatus: String?
    @State private var friendHandle = ""
    @State private var friendStatus: String?

    var body: some View {
        NavigationStack {
            switch step {
            case .welcome: welcome
            case .profile: profileStep
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
                    .textInputAutocapitalization(.never)
                TextField("handle (for friend requests)", text: $handle)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: handle) { handle = handle.lowercased() }
            }
            if let profileStatus {
                Text(profileStatus).font(.caption).foregroundStyle(.red)
            }
            Button("Continue") {
                Task {
                    do {
                        try await SocialService.updateProfile(handle: handle, displayName: displayName)
                        step = .friends
                    } catch let handleError as SocialService.HandleError {
                        profileStatus = handleError.errorDescription
                    } catch {
                        profileStatus = "Couldn't save: \(error.localizedDescription)"
                    }
                }
            }
            .disabled(handle.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .navigationTitle("Your profile")
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
