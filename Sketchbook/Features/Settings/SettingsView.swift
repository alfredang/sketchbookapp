import SwiftUI

/// Persisted user preferences. Keys are shared with `NewSketchSheet` and
/// `EditorViewModel` so the chosen defaults apply to new sketches.
enum SettingsKey {
    static let defaultTemplate = "defaultTemplate"
    static let defaultLandscape = "defaultLandscape"
    static let defaultBrush = "defaultBrush"
    static let defaultPencilOnly = "defaultPencilOnly"
}

struct SettingsView: View {
    @EnvironmentObject private var store: DocumentStore
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKey.defaultTemplate) private var defaultTemplate = TemplateKind.blank.rawValue
    @AppStorage(SettingsKey.defaultLandscape) private var defaultLandscape = true
    @AppStorage(SettingsKey.defaultBrush) private var defaultBrush = BrushType.pen.rawValue
    @AppStorage(SettingsKey.defaultPencilOnly) private var defaultPencilOnly = false

    private let developerURL = URL(string: "https://www.tertiaryinfotech.com")!
    private var versionString: String {
        let i = Bundle.main.infoDictionary
        let s = i?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = i?["CFBundleVersion"] as? String ?? "1"
        return "\(s) (\(b))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Storage") {
                    HStack {
                        Label(store.usingICloud ? "iCloud" : "On this device",
                              systemImage: store.usingICloud ? "icloud.fill" : "internaldrive")
                        Spacer()
                        Text(store.usingICloud ? "Synced" : "Local").foregroundStyle(Theme.mutedInk)
                    }
                    Text(store.usingICloud
                         ? "Sketches sync to your personal iCloud across your devices."
                         : "Sketches are saved on this device. Sign in to iCloud to sync.")
                        .font(.caption).foregroundStyle(Theme.mutedInk)
                }

                Section("New Sketch Defaults") {
                    Picker("Template", selection: $defaultTemplate) {
                        ForEach(TemplateKind.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                    Toggle("Landscape", isOn: $defaultLandscape)
                }

                Section("Drawing Defaults") {
                    Picker("Brush", selection: $defaultBrush) {
                        ForEach(BrushType.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                    Toggle(isOn: $defaultPencilOnly) {
                        Label("Palm rejection (Pencil only)", systemImage: "hand.raised")
                    }
                }

                Section("About") {
                    Link(destination: developerURL) {
                        Label("Tertiary Infotech Academy", systemImage: "globe")
                    }
                    HStack {
                        Text("Version"); Spacer()
                        Text(versionString).foregroundStyle(Theme.mutedInk)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
