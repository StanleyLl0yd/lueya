import Foundation
import XCTest
@testable import LueyaCore

final class YandexMusicStreamProviderTests: XCTestCase {
    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    func testResolvesTrackWithAuthenticatedMetadataAndRawCDN() async throws {
        let transport = StubTransport(
            fileInfoByQuality: ["lossless": Self.rawInfo()]
        )
        let provider = makeProvider(transport: transport)
        let track = try await provider.resolveTrack(id: "117708948", accessToken: "test-token")

        XCTAssertEqual(track.metadata.id, "117708948")
        XCTAssertEqual(track.metadata.title, "Synthetic track")
        XCTAssertEqual(track.metadata.artists, ["Example artist"])
        XCTAssertEqual(track.metadata.durationMilliseconds, 215_000)
        XCTAssertTrue(track.metadata.premiumRequired)
        XCTAssertEqual(track.source.quality, .hq)
        XCTAssertEqual(track.source.codec, .aacMP4)
        XCTAssertEqual(track.source.bitrateKbps, 320)
        XCTAssertTrue(track.source.isFresh(now: fixedDate.addingTimeInterval(40)))
        XCTAssertFalse(track.source.isFresh(now: fixedDate.addingTimeInterval(46)))
        XCTAssertFalse(track.source.description.contains("ysign"))
        XCTAssertFalse(String(reflecting: track).contains("ysign"))

        let requests = await transport.requests()
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests[0].url?.path, "/tracks")
        XCTAssertEqual(requests[0].httpMethod, "POST")
        XCTAssertEqual(String(data: requests[0].httpBody!, encoding: .utf8), "track-ids=117708948")
        XCTAssertEqual(requests[1].url?.path, "/get-file-info")
        XCTAssertEqual(requests[1].httpMethod, "GET")

        for request in requests {
            XCTAssertEqual(request.url?.host, "api.music.yandex.net")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "OAuth test-token")
        }
        XCTAssertEqual(
            requests[1].value(forHTTPHeaderField: "X-Yandex-Music-Client"),
            "YandexMusicDesktopAppWindows/5.95.0"
        )
        let query = URLComponents(url: requests[1].url!, resolvingAgainstBaseURL: false)!.queryItems!
        func parameter(_ name: String) -> String? {
            query.first(where: { $0.name == name })?.value
        }
        XCTAssertEqual(parameter("trackId"), "117708948")
        XCTAssertEqual(parameter("quality"), "lossless")
        XCTAssertEqual(parameter("transports"), "raw")
        XCTAssertEqual(parameter("codecs"), "flac-mp4,aac-mp4,mp3")
        XCTAssertEqual(parameter("ts"), "1700000000")
        XCTAssertEqual(parameter("sign"), "j5VIKo+CcIQ//tK10808aAsOFJof7+J4CDdZc4tBBzo")
    }

    func testFallsBackFromEncryptedOrUnsupportedCodecToRawAAC() async throws {
        let transport = StubTransport(fileInfoByQuality: [
            "lossless": Self.info(codec: "flac", transport: "encraw"),
            "hq": Self.info(codec: "flac-mp4", transport: "raw"),
            "nq": Self.rawInfo()
        ])
        let track = try await makeProvider(transport: transport)
            .resolveTrack(id: "117708948", accessToken: "test-token")
        XCTAssertEqual(track.source.codec, .aacMP4)

        let requests = await transport.requests()
        let qualities = requests.dropFirst().compactMap { request -> String? in
            URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "quality" })?.value
        }
        XCTAssertEqual(qualities, ["lossless", "hq", "nq"])
    }

    func testRefusesAllEncryptedResponses() async {
        let transport = StubTransport(fileInfoByQuality: [
            "lossless": Self.info(codec: "flac", transport: "encraw"),
            "hq": Self.info(codec: "mp3", transport: "encraw"),
            "nq": Self.info(codec: "aac-mp4", transport: "encraw")
        ])
        await expect(.unsupportedEncryptedTransport, provider: makeProvider(transport: transport))
    }

    func testRejectsUntrustedMediaURLs() async {
        let transport = StubTransport(fileInfoByQuality: [
            "lossless": Self.rawInfo(url: "https://strm.yandex.net.evil.example/audio"),
            "hq": Self.rawInfo(url: "http://media.strm.yandex.net/audio"),
            "nq": Self.rawInfo(url: "https://example.org/audio")
        ])
        await expect(.untrustedMediaURL, provider: makeProvider(transport: transport))
    }

    func testRejectsUnavailableTrackWithoutFetchingMedia() async {
        let transport = StubTransport(
            metadata: #"{"result":[{"id":117708948,"available":false}]}"#
        )
        await expect(.metadataUnavailable, provider: makeProvider(transport: transport))
        let requests = await transport.requests()
        XCTAssertEqual(requests.count, 1)
    }

    func testRejectsBadIdentifiersAndTokensBeforeAnyRequest() async {
        let invalidIDs = ["", "0", "-1", "id:album", "117708948/evil", "117708948?x=1", "１２３", "99999999999999999999"]
        for id in invalidIDs {
            let transport = StubTransport()
            do {
                _ = try await makeProvider(transport: transport).resolveTrack(id: id, accessToken: "test-token")
                XCTFail("Expected invalid track ID")
            } catch let error as MusicStreamError {
                XCTAssertEqual(error, .invalidTrackID)
            } catch {
                XCTFail("Unexpected error type")
            }
            let requests = await transport.requests()
            XCTAssertTrue(requests.isEmpty)
        }
        for token in ["", "space in token", "bad\nheader"] {
            let transport = StubTransport()
            do {
                _ = try await makeProvider(transport: transport)
                    .resolveTrack(id: "117708948", accessToken: token)
                XCTFail("Expected invalid token")
            } catch let error as MusicStreamError {
                XCTAssertEqual(error, .invalidToken)
            } catch {
                XCTFail("Unexpected error type")
            }
            let requests = await transport.requests()
            XCTAssertTrue(requests.isEmpty)
        }
    }

    func testRejectsUntrustedAPIResponseOriginEvenWhenStatusIs200() async {
        let transport = StubTransport(responseURL: URL(string: "https://evil.example/tracks"))
        await expect(.invalidResponse, provider: makeProvider(transport: transport))
    }

    func testClassifiesAccessAndRateLimitFailures() async {
        for (status, error) in [
            (401, MusicStreamError.unauthorized(.trackMetadata)),
            (403, .forbidden(.trackMetadata)),
            (429, .rateLimited(.trackMetadata)),
            (502, .httpStatus(.trackMetadata, 502))
        ] {
            await expect(error, provider: makeProvider(transport: StubTransport(status: status)))
        }
    }

    func test403AtMetadataIsNotConfusedWithSourceFailure() async {
        let transport = StubTransport(status: 403)
        await expect(.forbidden(.trackMetadata), provider: makeProvider(transport: transport))
        let requests = await transport.requests()
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.url?.path, "/tracks")
    }

    func test403AtAudioSourceCarriesRequestedQuality() async {
        let transport = StubTransport(statusForSource: 403)
        await expect(
            .forbidden(.rawAudioSource(.lossless)),
            provider: makeProvider(transport: transport)
        )
        let requests = await transport.requests()
        XCTAssertEqual(requests.map { $0.url?.path }, ["/tracks", "/get-file-info"])
        XCTAssertEqual(MusicRequestStage.rawAudioSource(.lossless).label, "audio source (lossless)")
        XCTAssertEqual(MusicRequestStage.trackMetadata.label, "track metadata")
        XCTAssertFalse(MusicRequestStage.rawAudioSource(.lossless).label.contains("sign="))
    }

    func test401AtAudioSourceIsStageSpecific() async {
        let transport = StubTransport(statusForSource: 401)
        await expect(
            .unauthorized(.rawAudioSource(.lossless)),
            provider: makeProvider(transport: transport)
        )
    }

    func testRejectsMalformedMetadata() async {
        let transport = StubTransport(metadata: #"{"result":[{"id":123,"title":"other"}]}"#)
        await expect(.invalidPayload, provider: makeProvider(transport: transport))
    }

    func testCDNAllowlistAndSignedURLRedaction() {
        let valid = [
            "https://media.strm.yandex.net/music-v2/raw/a?ysign=secret",
            "https://strm-mar-126.strm.yandex.net/music-v2/raw/a",
            "https://abc.storage.yandex.net/get-mp3/audio"
        ]
        for candidate in valid {
            XCTAssertTrue(MusicCDNPolicy.accepts(URL(string: candidate)!), candidate)
        }

        let invalid = [
            "http://media.strm.yandex.net/audio",
            "https://strm.yandex.net.evil.example/audio",
            "https://strm.yandex.net/audio",
            "https://strm.yandex.net@evil.example/audio",
            "https://user:password@media.strm.yandex.net/audio",
            "https://media.strm.yandex.net:8443/audio",
            "https://media.strm.yandex.net/audio#fragment",
            "https://example.com/audio",
            "https://127.0.0.1/audio"
        ]
        for candidate in invalid {
            XCTAssertFalse(MusicCDNPolicy.accepts(URL(string: candidate)!), candidate)
        }
    }

    private func makeProvider(transport: StubTransport) -> YandexMusicStreamProvider {
        YandexMusicStreamProvider(transport: transport, now: { Date(timeIntervalSince1970: 1_700_000_000) })
    }

    private func expect(
        _ expected: MusicStreamError,
        provider: YandexMusicStreamProvider
    ) async {
        do {
            _ = try await provider.resolveTrack(id: "117708948", accessToken: "test-token")
            XCTFail("Expected \(expected)")
        } catch let error as MusicStreamError {
            XCTAssertEqual(error, expected)
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    private static func rawInfo(
        url: String = "https://media.strm.yandex.net/music-v2/raw/file?ysign=secret"
    ) -> String {
        info(codec: "aac-mp4", transport: "raw", url: url)
    }

    private static func info(
        codec: String, transport: String, url: String = "https://media.strm.yandex.net/music-v2/raw/file"
    ) -> String {
        """
        {"result":{"downloadInfo":{"quality":"hq","codec":"\(codec)",
        "bitrate":320,"transport":"\(transport)","urls":["\(url)"]}}}
        """
    }

    private actor StubTransport: MusicHTTPTransport {
        private let metadata: String
        private let fileInfoByQuality: [String: String]
        private let status: Int
        private let statusForSource: Int?
        private let responseURL: URL?
        private var captured: [URLRequest] = []

        init(
            metadata: String = #"{"result":[{"id":117708948,"title":"Synthetic track","durationMs":215000,"available":true,"availableForPremiumUsers":true,"artists":[{"name":"Example artist"}]}]}"#,
            fileInfoByQuality: [String: String] = [:],
            status: Int = 200,
            statusForSource: Int? = nil,
            responseURL: URL? = nil
        ) {
            self.metadata = metadata
            self.fileInfoByQuality = fileInfoByQuality
            self.status = status
            self.statusForSource = statusForSource
            self.responseURL = responseURL
        }

        func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
            captured.append(request)
            let url = request.url!
            let body: String
            if url.path == "/tracks" {
                body = metadata
            } else {
                let quality = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "quality" })?.value ?? ""
                body = fileInfoByQuality[quality] ?? #"{"result":null}"#
            }
            let response = HTTPURLResponse(
                url: responseURL ?? url,
                statusCode: url.path == "/get-file-info" ? (statusForSource ?? status) : status,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(body.utf8), response)
        }

        func requests() -> [URLRequest] { captured }
    }
}
