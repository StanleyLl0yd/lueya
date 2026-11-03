import Foundation

public enum OfficialMusicSite {
    public static let home = URL(string: "https://music.yandex.ru/")!

    public static func isTrusted(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return false
        }
        return components.scheme?.lowercased() == "https"
            && components.host?.lowercased() == "music.yandex.ru"
            && components.user == nil
            && components.password == nil
            && components.port == nil
    }
}
