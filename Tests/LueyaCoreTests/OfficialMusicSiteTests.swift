import Foundation
import XCTest
@testable import LueyaCore

final class OfficialMusicSiteTests: XCTestCase {
    func testOfficialHomepageIsHTTPSAndTrusted() {
        XCTAssertEqual(OfficialMusicSite.home.absoluteString, "https://music.yandex.ru/")
        XCTAssertTrue(OfficialMusicSite.isTrusted(OfficialMusicSite.home))
    }

    func testRejectsLookalikeHostsAndUnsafeSchemes() throws {
        let unsafe = [
            "http://music.yandex.ru/",
            "https://music.yandex.ru.evil.example/",
            "https://music.yandex.ru@evil.example/",
            "https://evil@music.yandex.ru/",
            "https://music.yandex.ru:8443/",
            "https://music.yandex.com/",
            "file:///etc/passwd"
        ]
        for value in unsafe {
            let url = try XCTUnwrap(URL(string: value))
            XCTAssertFalse(OfficialMusicSite.isTrusted(url), "Unexpectedly trusted: \(value)")
        }
    }

    func testAllowsSubpathsOnTheOfficialHost() {
        let url = URL(string: "https://music.yandex.ru/home")!
        XCTAssertTrue(OfficialMusicSite.isTrusted(url))
    }
}
