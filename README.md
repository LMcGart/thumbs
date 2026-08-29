# Thumbs

A social restaurant-logging app for iOS. Friends rate the places they eat, the
app notices where you ate from photo metadata and starts the review for you,
and popular NYC restaurants carry reservation-drop reminders.

**Thumbs** is a placeholder name, and `com.CHANGEME.thumbs` is a placeholder
bundle ID — both get finalized before the first TestFlight upload.

## Layout

- `project.yml` — XcodeGen spec, the only place targets and settings are defined
- `App/` — iOS app target (SwiftUI views + view models, no business logic)
- `Core/` — Swift package with all logic: `Detection`, `Rating`, `Places`
- `Spike/` — macOS command-line tool that runs Detection against the local Photos library
- `docs/` — product notes, detection spec, roadmap; `docs/private/` is gitignored

## Setup

Requires Xcode 26.6 and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
xcodegen generate                       # after any change to project.yml
cd Core && swift build && swift test    # fast loop for all logic
xcodebuild -project Thumbs.xcodeproj -scheme Thumbs \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -project Thumbs.xcodeproj -scheme Spike -destination 'platform=macOS' build
```

The `.xcodeproj` is generated and gitignored — never edit it by hand.

See `CLAUDE.md` for the full rules and `docs/roadmap.md` for the order of work.
