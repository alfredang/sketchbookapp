import SwiftUI

struct FeedbackView: View {
    private let whatsAppNumber = "6588666375"
    @State private var title = ""
    @State private var message = ""

    private var canSend: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Feedback").font(.largeTitle.bold()).foregroundStyle(Theme.ink)
                Text("Tell us what brushes, templates or effects you'd love to see next.")
                    .foregroundStyle(Theme.mutedInk)

                VStack(alignment: .leading, spacing: 14) {
                    TextField("Title", text: $title)
                        .textFieldStyle(.roundedBorder)
                    ZStack(alignment: .topLeading) {
                        if message.isEmpty {
                            Text("Your message…").foregroundStyle(Theme.mutedInk)
                                .padding(.top, 8).padding(.leading, 5)
                        }
                        TextEditor(text: $message)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 160)
                    }
                    .padding(8)
                    .background(Theme.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .appCard()

                Button(action: send) {
                    Label("Send via WhatsApp", systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.white)
                        .padding(.vertical, 14)
                        .background(canSend ? Theme.primary : Theme.mutedInk, in: Capsule())
                }
                .disabled(!canSend)
            }
            .padding(22)
        }
        .background(Theme.background.ignoresSafeArea())
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
