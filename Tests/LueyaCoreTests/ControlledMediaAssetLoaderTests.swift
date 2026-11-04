import AVFoundation
import Foundation
import XCTest
@testable import LueyaCore

/// Generates an original AAC fixture locally; no provider media or secrets.
@MainActor
final class ControlledMediaAssetLoaderTests: XCTestCase {
    private let oldURL = URL(string: "https://media.strm.yandex.net/test/audio?signature=old")!
    private let newURL = URL(string: "https://media.strm.yandex.net/test/audio?signature=new")!

    func testNativeAssetReadsSyntheticAACOverVerified206Ranges() async throws {
        let fixture = try generatedAAC()
        let transport = FixtureRangeTransport(payload: fixture, initial: oldURL)
        let loader = makeLoader(transport: transport)
        let asset = AVURLAsset(url: loader.localURL)
        asset.resourceLoader.setDelegate(loader, queue: .main)
        defer {
            loader.close()
            asset.resourceLoader.setDelegate(nil, queue: nil)
        }

        let duration = try await asset.load(.duration)
        XCTAssertTrue(duration.isValid)
        XCTAssertGreaterThan(CMTimeGetSeconds(duration), 0)
        let seen = await transport.requests()
        XCTAssertFalse(seen.isEmpty)
        XCTAssertTrue(seen.allSatisfy { $0.value(forHTTPHeaderField: "Range") != nil })
        XCTAssertTrue(seen.allSatisfy {
            $0.value(forHTTPHeaderField: "Authorization") == nil &&
            $0.value(forHTTPHeaderField: "Cookie") == nil
        })

        let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        player.seek(to: CMTime(seconds: 0.5, preferredTimescale: 600))
        player.pause()
        player.replaceCurrentItem(with: nil)
    }

    func testExpired410ReResolvesSameTrackAndRetriesOriginalRange() async throws {
        let fixture = try generatedAAC()
        let transport = FixtureRangeTransport(
            payload: fixture, initial: oldURL, expiredOriginal: true
        )
        let attempts = Counter()
        let replacement = track(url: newURL)
        let loader = ControlledMediaAssetLoader(
            track: track(url: oldURL),
            reader: SecureMediaRangeClient(transport: transport),
            renewSource: {
                await attempts.increment()
                return replacement
            },
            reportError: { error in
                XCTFail("Unexpected range error kind: \(type(of: error))")
            }
        )
        let asset = AVURLAsset(url: loader.localURL)
        asset.resourceLoader.setDelegate(loader, queue: .main)
        defer {
            loader.close()
            asset.resourceLoader.setDelegate(nil, queue: nil)
        }

        let duration = try await asset.load(.duration)
        XCTAssertGreaterThan(CMTimeGetSeconds(duration), 0)
        let calls = await attempts.count()
        XCTAssertEqual(calls, 1)
        let requests = await transport.requests()
        XCTAssertTrue(requests.contains { $0.url == oldURL })
        XCTAssertTrue(requests.contains { $0.url == newURL })
    }

    func testRedirected206ResponseFailsClosed() async throws {
        let fixture = try generatedAAC()
        let transport = FixtureRangeTransport(
            payload: fixture,
            initial: oldURL,
            redirectURL: URL(string: "https://untrusted.example/redirect")!
        )
        let expected = expectation(description: "Reject redirected partial response")
        let loader = ControlledMediaAssetLoader(
            track: track(url: oldURL),
            reader: SecureMediaRangeClient(transport: transport),
            renewSource: { XCTFail("Must not renew redirects"); return self.track(url: self.newURL) },
            reportError: { error in
                XCTAssertEqual(error, .invalidResponse)
                expected.fulfill()
            }
        )
        let asset = AVURLAsset(url: loader.localURL)
        asset.resourceLoader.setDelegate(loader, queue: .main)
        defer {
            loader.close()
            asset.resourceLoader.setDelegate(nil, queue: nil)
        }

        do {
            _ = try await asset.load(.duration)
            XCTFail("Redirected 206 must never supply media bytes")
        } catch {
            // The caller sees an AVFoundation failure; its description is never logged.
        }
        await fulfillment(of: [expected], timeout: 5)
    }

    func testClosingLoaderCancelsInFlightTransport() async throws {
        let fixture = try generatedAAC()
        let transport = FixtureRangeTransport(
            payload: fixture, initial: oldURL, suspendRequests: true
        )
        let loader = makeLoader(transport: transport)
        let asset = AVURLAsset(url: loader.localURL)
        asset.resourceLoader.setDelegate(loader, queue: .main)
        let pending = Task {
            try? await asset.load(.duration)
        }

        for _ in 0..<100 {
            if await transport.started() { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        let started = await transport.started()
        XCTAssertTrue(started)
        loader.close()
        asset.cancelLoading()
        pending.cancel()
        asset.resourceLoader.setDelegate(nil, queue: nil)

        for _ in 0..<100 {
            if await transport.cancelled() { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        let cancelled = await transport.cancelled()
        XCTAssertTrue(cancelled)
    }

    private func makeLoader(transport: FixtureRangeTransport) -> ControlledMediaAssetLoader {
        ControlledMediaAssetLoader(
            track: track(url: oldURL),
            reader: SecureMediaRangeClient(transport: transport),
            renewSource: { XCTFail("Fixture must not need renewal"); return self.track(url: self.newURL) },
            reportError: { error in
                XCTFail("Unexpected synthetic media error kind: \(type(of: error))")
            }
        )
    }

    private func track(url: URL) -> ResolvedTrack {
        ResolvedTrack(
            metadata: TrackMetadata(
                id: "123", title: "Generated sine", artists: [],
                durationMilliseconds: 1_000, available: true, premiumRequired: false
            ),
            source: PlayableSource(
                url: url, quality: .hq, codec: .aacMP4,
                bitrateKbps: 96, resolvedAt: Date()
            )
        )
    }

    private func generatedAAC() throws -> Data {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lueya-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("synthetic.m4a")
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44_100)!
        buffer.frameLength = 44_100
        let samples = buffer.floatChannelData![0]
        for i in 0..<Int(buffer.frameLength) {
            samples[i] = 0.1 * sin(Float(i) * 2 * .pi * 440 / 44_100)
        }
        do {
            let file = try AVAudioFile(forWriting: url, settings: [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 96_000
            ])
            try file.write(from: buffer)
        }
        return try Data(contentsOf: url)
    }

    private actor Counter {
        private var value = 0
        func increment() { value += 1 }
        func count() -> Int { value }
    }

    private actor FixtureRangeTransport: MediaHTTPRangeTransport {
        let payload: Data
        let initial: URL
        let expiredOriginal: Bool
        let redirectURL: URL?
        let suspendRequests: Bool
        private var captured: [URLRequest] = []
        private var hasStarted = false
        private var wasCancelled = false

        init(
            payload: Data, initial: URL,
            expiredOriginal: Bool = false,
            redirectURL: URL? = nil,
            suspendRequests: Bool = false
        ) {
            self.payload = payload
            self.initial = initial
            self.expiredOriginal = expiredOriginal
            self.redirectURL = redirectURL
            self.suspendRequests = suspendRequests
        }

        func data(
            for request: URLRequest,
            maximumBytes: Int
        ) async throws -> (Data, HTTPURLResponse) {
            captured.append(request)
            hasStarted = true
            if suspendRequests {
                do {
                    try await Task.sleep(for: .seconds(20))
                } catch {
                    wasCancelled = true
                    throw error
                }
            }
            guard let url = request.url else { throw MediaRangeError.invalidResponse }
            if expiredOriginal && url == initial {
                return (
                    Data(),
                    HTTPURLResponse(url: url, statusCode: 410, httpVersion: nil, headerFields: [:])!
                )
            }
            guard let raw = request.value(forHTTPHeaderField: "Range"),
                  raw.hasPrefix("bytes=") else { throw MediaRangeError.invalidRange }
            let parts = raw.dropFirst(6).split(separator: "-", omittingEmptySubsequences: false)
            guard parts.count == 2, let offset = Int64(parts[0]),
                  let upper = Int64(parts[1]),
                  offset >= 0, upper >= offset,
                  offset < Int64(payload.count) else { throw MediaRangeError.invalidRange }
            let end = min(upper, Int64(payload.count - 1))
            let chunk = payload.subdata(in: Int(offset)..<Int(end + 1))
            guard chunk.count <= maximumBytes else { throw MediaRangeError.oversized }
            let response = HTTPURLResponse(
                url: redirectURL ?? url, statusCode: 206, httpVersion: "HTTP/1.1",
                headerFields: [
                    "Content-Range": "bytes \(offset)-\(end)/\(payload.count)",
                    "Content-Type": "audio/mp4"
                ]
            )!
            return (chunk, response)
        }

        func requests() -> [URLRequest] { captured }
        func started() -> Bool { hasStarted }
        func cancelled() -> Bool { wasCancelled }
    }
}
