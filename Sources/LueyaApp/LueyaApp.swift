import SwiftUI

@main
struct LueyaApp: App {
    var body: some Scene {
        MenuBarExtra("lueya", systemImage: "waveform") {
            PlayerPreview()
        }
        .menuBarExtraStyle(.window)
    }
}
