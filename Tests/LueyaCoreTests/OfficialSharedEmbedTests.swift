import Foundation
import XCTest
@testable import LueyaCore

final class OfficialSharedEmbedTests: XCTestCase {
    func testDocumentedOfficialURL() {
        XCTAssertEqual(
            OfficialSharedEmbed.documentedExample.absoluteString,
            "https://music.yandex.ru/iframe/#track/71263/419460"
        )
        XCTAssertTrue(
            OfficialSharedEmbed.allowsNavigation(
                to: OfficialSharedEmbed.documentedExample
            )
        )
    }

    func testPermitsEmbedFragmentChangesWithoutChangingHost() throws {
        for value in [
            "https://music.yandex.ru/iframe/",
            "https://music.yandex.ru/iframe/#track/1/2",
            "https://music.yandex.ru/iframe"
        ] {
            XCTAssertTrue(
                OfficialSharedEmbed.allowsNavigation(to: try XCTUnwrap(URL(string: value))),
                value
            )
        }
    }

    func testRejectsUnknownDomainsOrPages() throws {
        for value in [
            "http://music.yandex.ru/iframe/#track/1/2",
            "https://music.yandex.ru.evil.example/iframe/",
            "https://music.yandex.ru@evil.example/iframe/",
            "https://evil@music.yandex.ru/iframe/",
            "https://music.yandex.ru:8443/iframe/",
            "https://music.yandex.ru/home",
            "https://music.yandex.ru/iframe/other",
            "https://music.yandex.ru/iframe/?next=https://evil.example",
            "https://music.yandex.com/iframe/"
        ] {
            XCTAssertFalse(
                OfficialSharedEmbed.allowsNavigation(to: try XCTUnwrap(URL(string: value))),
                value
            )
        }
    }
}
