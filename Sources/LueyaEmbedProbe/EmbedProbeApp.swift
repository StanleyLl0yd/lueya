import SwiftUI

@main
struct LueyaEmbedProbeApp: App {
    var body: some Scene {
        WindowGroup("lueya · shared-track probe") {
            EmbedProbeView()
        }
        .defaultSize(width: 610, height: 365)
    }
}
