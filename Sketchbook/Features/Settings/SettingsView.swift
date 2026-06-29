import SwiftUI

/// Persisted user preferences. Keys are shared with `NewSketchSheet`,
/// `EditorViewModel`, `Haptics` and the app root.
enum SettingsKey {
    static let defaultTemplate = "defaultTemplate"
    static let defaultLandscape = "defaultLandscape"
    static let defaultBrush = "defaultBrush"
    static let defaultPencilGrade = "defaultPencilGrade"
    static let defaultEraseSize = "defaultEraseSize"
    static let fingerDrawing = "fingerDrawing"   // default false → Pencil only
    static let haptics = "haptics"               // default true
    static let theme = "theme"                   // light | dark | system (default light)
}

enum AppTheme: String, CaseIterable, Identifiable {
    case light, dark, system
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: DocumentStore
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKey.theme) private var theme = AppTheme.light.rawValue
    @AppStorage(SettingsKey.fingerDrawing) private var fingerDrawing = true
    @AppStorage(SettingsKey.haptics) private var haptics = true
    @AppStorage(SettingsKey.defaultTemplate) private var defaultTemplate = TemplateKind.blank.rawValue
    @AppStorage(SettingsKey.defaultLandscape) private var defaultLandscape = true
    @AppStorage(SettingsKey.defaultBrush) private var defaultBrush = BrushType.pen.rawValue
    @AppStorage(SettingsKey.defaultPencilGrade) private var defaultPencilGrade = PencilGrade.hb.rawValue
    @AppStorage(SettingsKey.defaultEraseSize) private var defaultEraseSize = 24.0

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
                Section("Appearance") {
                    Picker("Theme", selection: $theme) {
                        ForEach(AppTheme.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                }

                Section("Drawing") {
                    Toggle("Finger Drawing", isOn: $fingerDrawing)
                    HStack {
                        Label("Palm Rejection", systemImage: "hand.raised.fill")
                        Spacer()
                        Text("Always On").foregroundStyle(Theme.mutedInk)
                    }
                    Toggle("Haptic Feedback", isOn: $haptics)
                }

                Section("Tool Defaults") {
                    Picker("Brush", selection: $defaultBrush) {
                        ForEach(BrushType.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                    Picker("Pencil Grade", selection: $defaultPencilGrade) {
                        ForEach(PencilGrade.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                    VStack(alignment: .leading) {
                        Text("Eraser Size: \(Int(defaultEraseSize)) pt")
                            .font(.caption).foregroundStyle(Theme.mutedInk)
                        Slider(value: $defaultEraseSize, in: 6...80)
                    }
                }

                Section("New Sketch Defaults") {
                    Picker("Template", selection: $defaultTemplate) {
                        ForEach(TemplateKind.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                    Toggle("Landscape", isOn: $defaultLandscape)
                }

                Section("Storage") {
                    HStack {
                        Label(store.usingICloud ? "iCloud" : "On this device",
                              systemImage: store.usingICloud ? "icloud.fill" : "internaldrive")
                        Spacer()
                        Text(store.usingICloud ? "Synced" : "Local").foregroundStyle(Theme.mutedInk)
                    }
                }

                Section("About") {
                    Link(destination: developerURL) {
                        Label("Tertiary Infotech Academy", systemImage: "globe")
                    }
                    HStack { Text("Version"); Spacer(); Text(versionString).foregroundStyle(Theme.mutedInk) }
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
