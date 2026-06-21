import SwiftUI

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
                Text("About").font(.largeTitle.bold()).foregroundStyle(Theme.ink)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Sketchbook").font(.title3.bold()).foregroundStyle(Theme.ink)
                    Text("A natural drawing studio for iPad. Sketch with pressure-sensitive brushes and Apple Pencil, work in layers, trace reference photos, use symmetry and rulers, fill with color, apply filter effects, and bring your art into the real world with AR. Everything syncs to your personal iCloud.")
                        .foregroundStyle(Theme.mutedInk)
                }
                .appCard()

                Text("DEVELOPER").font(.caption.weight(.semibold)).foregroundStyle(Theme.mutedInk)
                VStack(alignment: .leading, spacing: 0) {
                    Label("Tertiary Infotech Academy Pte Ltd", systemImage: "building.2.fill")
                        .foregroundStyle(Theme.ink)
                        .padding(.vertical, 14)
                    Divider()
                    Link(destination: developerURL) {
                        Label("tertiaryinfotech.com", systemImage: "globe").foregroundStyle(Theme.primary)
                    }
                    .padding(.vertical, 14)
                }
                .appCard()

                HStack {
                    Text("Version").foregroundStyle(Theme.ink)
                    Spacer()
                    Text(versionString).foregroundStyle(Theme.mutedInk)
                }
                .appCard()
            }
            .padding(22)
        }
        .background(Theme.background.ignoresSafeArea())
    }
}
