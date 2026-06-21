---
name: ios-feedback-about
description: Add a SwiftUI bottom-tab navigation with Feedback and About tabs to a native iOS app (matching the Tertiary Infotech house style). The Feedback tab has a Title field, a Message field, and a "Send via WhatsApp" button that opens wa.me/6588666375 with the composed text. The About tab shows the app name + description, a Developer card ("Tertiary Infotech Academy Pte Ltd" + tertiaryinfotech.com link), an optional Data-source card with a link, and a Version row (CFBundleShortVersionString/CFBundleVersion). Use when asked to add About/Feedback tabs, a bottom tab bar, a WhatsApp feedback form, or an in-app source attribution/About screen to an iOS/SwiftUI app.
license: MIT
metadata:
  version: "1.0.0"
---

# iOS Feedback + About tabs (SwiftUI)

Add a **bottom tab bar** with **Feedback** and **About** tabs to an existing SwiftUI app,
in the Tertiary Infotech house style. Keep the content screen(s) you already have alongside
them as the first tab. This is the iOS twin of the `android-feedback-about` skill.

- **Feedback tab:** `Title` + `Message` fields and a **Send via WhatsApp** button that opens
  `https://wa.me/6588666375?text=<title + message>` (built with `URLComponents` so the text is
  encoded correctly). The `wa.me` https link works whether or not WhatsApp is installed (web fallback).
- **About tab:** an app card (name + about text), a **Developer** card
  ("Tertiary Infotech Academy Pte Ltd" + `tertiaryinfotech.com` link), an optional **Data source**
  card (link to the official source — required if surfacing government data), and a **Version** row
  read from the bundle.

## Wiring

1. Host the tabs in a root `TabView` and make it the app's root view (`WindowGroup { MainTabView() }`).
   On a **deployment target < iOS 18**, use the classic `.tabItem { Label(...) }` API (the
   `Tab("…", systemImage:)` initializer is iOS 18+). Apply `.tint(Theme.accent)` for the selected
   color and `.preferredColorScheme(.dark)` if the app is dark-themed.
2. Open WhatsApp / links with `UIApplication.shared.open(url)` (and `Link(destination:)` for the
   website row). No URL schemes to allow-list — `wa.me` and `https` need no `LSApplicationQueriesSchemes`.
3. Read the version from `Bundle.main.infoDictionary` — `CFBundleShortVersionString` (e.g. "1.0")
   and `CFBundleVersion` (e.g. "4"). With XcodeGen these come from `MARKETING_VERSION` /
   `CURRENT_PROJECT_VERSION` in `project.yml`.

## Reference implementation

```swift
// MainTabView.swift
struct MainTabView: View {
    var body: some View {
        TabView {
            ContentScreen()                                   // your existing first tab
                .tabItem { Label("Home", systemImage: "house.fill") }
            FeedbackView()
                .tabItem { Label("Feedback", systemImage: "bubble.left.and.bubble.right.fill") }
            AboutView()
                .tabItem { Label("About", systemImage: "info.circle.fill") }
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
    }
}
```

```swift
// FeedbackView.swift — Title + Message -> WhatsApp
struct FeedbackView: View {
    private let whatsAppNumber = "6588666375"        // +65 8866 6375, no "+"/spaces
    @State private var title = ""
    @State private var message = ""

    private var canSend: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Feedback").font(.largeTitle.bold())
                TextField("Title", text: $title)
                ZStack(alignment: .topLeading) {
                    if message.isEmpty { Text("Your message…").foregroundStyle(.secondary) }
                    TextEditor(text: $message).scrollContentBackground(.hidden).frame(minHeight: 160)
                }
                Button(action: send) {
                    Label("Send via WhatsApp", systemImage: "paperplane.fill")
                }
                .disabled(!canSend)
            }
            .padding(22)
        }
    }

    private func send() {
        var body = ""
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let m = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { body += "*\(t)*\n" }
        body += m
        var comps = URLComponents()
        comps.scheme = "https"; comps.host = "wa.me"; comps.path = "/\(whatsAppNumber)"
        comps.queryItems = [URLQueryItem(name: "text", value: body)]
        if let url = comps.url { UIApplication.shared.open(url) }
    }
}
```

```swift
// AboutView.swift — app card, developer + link, version
struct AboutView: View {
    private let developerURL = URL(string: "https://www.tertiaryinfotech.com")!
    private var versionString: String {
        let i = Bundle.main.infoDictionary
        let s = i?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = i?["CFBundleVersion"] as? String ?? "1"
        return "\(s) (\(b))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("About").font(.largeTitle.bold())

                // App card
                VStack(alignment: .leading, spacing: 10) {
                    Text("<App name>").font(.title3.bold())
                    Text("<One-paragraph description of what the app does.>")
                        .foregroundStyle(.secondary)
                }

                // Developer card (label + building row + globe link row)
                Text("DEVELOPER").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 0) {
                    Label("Tertiary Infotech Academy Pte Ltd", systemImage: "building.2.fill")
                        .padding(.vertical, 14)
                    Divider()
                    Link(destination: developerURL) {
                        Label("tertiaryinfotech.com", systemImage: "globe")
                    }
                    .padding(.vertical, 14)
                }

                // Optional Data-source card here (required for government data) — same Link row pattern.

                // Version row
                HStack { Text("Version"); Spacer(); Text(versionString).foregroundStyle(.secondary) }
            }
            .padding(22)
        }
    }
}
```

Wrap each card group in a rounded surface (`.background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))`) to match the grouped-card look in the reference design.

## Conventions

- WhatsApp number is **6588666375** (Singapore, country code included, no `+`/spaces).
- Build the `wa.me` URL with **`URLComponents`/`URLQueryItem`**, never string-concatenation —
  it percent-encodes the title/message (newlines, `*`, emoji) correctly.
- Keep the brand accent (`Theme.accent`) consistent across the tab tint, the Send button, and the
  About links. Reference `Theme` tokens, never raw `Color` literals (see the `mobile-ios-design` skill).
- The About **Data source** card is mandatory when the app shows government/official data
  (LTA DataMall, data.gov.sg, OneMap, etc.) — it doubles as the App Review attribution.
- Below iOS 18 use `TabView { … .tabItem { Label(...) } }`; on iOS 18+ the `Tab(_:systemImage:)`
  initializer is available. `TextEditor` needs `.scrollContentBackground(.hidden)` to show a
  custom background (iOS 16+).
- Verify with `xcodegen generate` (if XcodeGen-based) then a Debug `xcodebuild … build` before shipping.
```
