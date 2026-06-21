import SwiftUI

@main
struct SketchbookApp: App {
    @StateObject private var store = DocumentStore()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(store)
                .tint(Theme.primary)
        }
    }
}

struct MainTabView: View {
    @State private var selection: Int = Int(ProcessInfo.processInfo.environment["SKETCH_TAB"] ?? "0") ?? 0
    var body: some View {
        TabView(selection: $selection) {
            GalleryView()
                .tabItem { Label("Sketches", systemImage: "square.grid.2x2.fill") }
                .tag(0)
            FeedbackView()
                .tabItem { Label("Feedback", systemImage: "bubble.left.and.bubble.right.fill") }
                .tag(1)
            AboutView()
                .tabItem { Label("About", systemImage: "info.circle.fill") }
                .tag(2)
        }
        .tint(Theme.primary)
        .preferredColorScheme(.light) // app uses a fixed warm light theme
    }
}
