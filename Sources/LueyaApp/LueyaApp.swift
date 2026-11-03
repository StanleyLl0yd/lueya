import SwiftUI

@main
struct LueyaApp: App {
    @State private var signIn = MusicSignInModel()

    var body: some Scene {
        MenuBarExtra("lueya", systemImage: "waveform") {
            PlayerPreview(signIn: signIn)
        }
        .menuBarExtraStyle(.window)
    }
}
