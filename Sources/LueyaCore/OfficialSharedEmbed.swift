import Foundation

/// A publicly documented sharing embed, not a Yandex Music API.
public enum OfficialSharedEmbed {
    public static let documentedExample = URL(
        string: "https://music.yandex.ru/iframe/#track/71263/419460"
    )!

    /// Allows top-level navigation only within the official embed path.
    public static func allowsNavigation(to url: URL) -> Bool {
        guard OfficialMusicSite.isTrusted(url),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.query == nil else {
            return false
        }

        return components.path == "/iframe/" || components.path == "/iframe"
    }
}
