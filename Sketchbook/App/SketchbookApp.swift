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
    var body: some View {
        TabView {
            GalleryView()
                .tabItem { Label("Sketches", systemImage: "square.grid.2x2.fill") }
            FeedbackView()
                .tabItem { Label("Feedback", systemImage: "bubble.left.and.bubble.right.fill") }
            AboutView()
                .tabItem { Label("About", systemImage: "info.circle.fill") }
        }
        .tint(Theme.primary)
    }
}
