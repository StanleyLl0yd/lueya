import Foundation
import XCTest
@testable import LueyaCore

final class MediaSourceRenewalPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    func testNeverRenewsFreshForbiddenOrSessionDenial() {
        let source = sampleSource(at: now)
        XCTAssertFalse(MediaSourceRenewalPolicy.shouldRenew(.forbidden, source: source, now: now))
        XCTAssertFalse(MediaSourceRenewalPolicy.shouldRenew(.unauthorized, source: source, now: now))
        XCTAssertFalse(MediaSourceRenewalPolicy.shouldRenew(.httpStatus(429), source: source, now: now))
        XCTAssertFalse(MediaSourceRenewalPolicy.shouldRenew(.invalidResponse, source: source, now: now))
    }

    func testExpiredSignatureCanRenewButNotAnInfiniteRetry() {
        let source = sampleSource(at: now)
        XCTAssertTrue(MediaSourceRenewalPolicy.shouldRenew(.expiredSource, source: source, now: now))
        XCTAssertTrue(MediaSourceRenewalPolicy.shouldRenew(
            .forbidden, source: source, now: now.addingTimeInterval(46)
        ))
        XCTAssertFalse(MediaSourceRenewalPolicy.shouldRenew(
            .forbidden, source: source, now: now.addingTimeInterval(44)
        ))
        XCTAssertEqual(MediaSourceRenewalPolicy.maximumRenewals, 6)
    }

    func testReplacementRejectsDifferentTrackOrCodecAndUntrustedURL() {
        let original = sampleTrack(id: "123", codec: .aacMP4)
        XCTAssertTrue(MediaSourceRenewalPolicy.accepts(
            original: original, replacement: sampleTrack(id: "123", codec: .aacMP4)
        ))
        XCTAssertFalse(MediaSourceRenewalPolicy.accepts(
            original: original, replacement: sampleTrack(id: "124", codec: .aacMP4)
        ))
        XCTAssertFalse(MediaSourceRenewalPolicy.accepts(
            original: original, replacement: sampleTrack(id: "123", codec: .mp3)
        ))
        XCTAssertFalse(MediaSourceRenewalPolicy.accepts(
            original: original, replacement: sampleTrack(
                id: "123", codec: .aacMP4, url: "https://untrusted.example/audio"
            )
        ))
    }

    private func sampleSource(at date: Date) -> PlayableSource {
        PlayableSource(
            url: URL(string: "https://media.strm.yandex.net/raw?ysign=secret")!,
            quality: .hq, codec: .aacMP4, bitrateKbps: 256, resolvedAt: date
        )
    }

    private func sampleTrack(
        id: String, codec: AudioCodec, url: String = "https://media.strm.yandex.net/audio"
    ) -> ResolvedTrack {
        ResolvedTrack(
            metadata: TrackMetadata(
                id: id, title: "Original fixture", artists: [],
                durationMilliseconds: 2_000, available: true, premiumRequired: false
            ),
            source: PlayableSource(
                url: URL(string: url)!, quality: .hq,
                codec: codec, bitrateKbps: 128, resolvedAt: Date()
            )
        )
    }
}
