import Foundation
import XCTest
@testable import LueyaCore

final class SecureMediaRangeClientTests: XCTestCase {
    private let url = URL(string:
        "https://media.strm.yandex.net/music-v2/raw/audio?ysign=private"
    )!

    func testExactRangeWithNoAuthenticationOrCookieHeaders() async throws {
        let transport = StubTransport()
        let client = SecureMediaRangeClient(transport: transport)
        let range = try MediaByteRange(offset: 4096, length: 4)
        let response = try await client.read(from: url, range: range)
        XCTAssertEqual(response.bytes, Data([1, 2, 3, 4]))
        XCTAssertEqual(response.offset, 4096)
        XCTAssertEqual(response.end, 4099)
        XCTAssertEqual(response.totalLength, 10_000)
        XCTAssertEqual(response.contentType, "audio/mp4")
        let requests = await transport.captured()
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests[0].value(forHTTPHeaderField: "Range"), "bytes=4096-4099")
        XCTAssertEqual(requests[0].value(forHTTPHeaderField: "Accept-Encoding"), "identity")
        XCTAssertEqual(requests[0].value(forHTTPHeaderField: "Cache-Control"), "no-store")
        XCTAssertNil(requests[0].value(forHTTPHeaderField: "Authorization"))
        XCTAssertNil(requests[0].value(forHTTPHeaderField: "Cookie"))
        XCTAssertEqual(requests[0].httpMethod, "GET")
        XCTAssertEqual(requests[0].cachePolicy, .reloadIgnoringLocalCacheData)
        XCTAssertEqual(await transport.limit(), 4)
    }

    func testRejectsUntrustedHostBeforeNetworkAccess() async {
        let transport = StubTransport()
        await expect(
            .untrustedURL, client: SecureMediaRangeClient(transport: transport),
            url: URL(string: "https://media.strm.yandex.net.evil.example/music")!
        )
        XCTAssertTrue(await transport.captured().isEmpty)
    }

    func testRefusesAllRedirectedResponsesEvenIfStatus206() async {
        let transport = StubTransport(
            responseURL: URL(string: "https://attacker.example/audio")
        )
        await expect(.invalidResponse, client: SecureMediaRangeClient(transport: transport))
    }

    func testRejectsServerIgnoringRange() async {
        let transport = StubTransport(status: 200)
        await expect(.rangeUnsupported, client: SecureMediaRangeClient(transport: transport))
    }

    func testRejectsBadRangeAndOversize() {
        for (offset, length) in [
            (-1, 1), (0, 0), (0, 131_073),
            (Int64.max, 10)
        ] {
            XCTAssertThrowsError(try MediaByteRange(offset: offset, length: length))
        }
        XCTAssertNoThrow(try MediaByteRange(offset: 0, length: 131_072))
    }

    func testRejectsMissingContentRange() async {
        await expect(
            .invalidContentRange,
            client: SecureMediaRangeClient(
                transport: StubTransport(contentRange: nil)
            )
        )
    }

    func testRejectsMismatchedContentRange() async {
        for contentRange in [
            "bytes 0-3/10000",
            "bytes 4096-4100/10000",
            "bytes 4099-4096/10000",
            "bytes 4096-4099/*",
            "bytes 4096-4099/4099",
            "bytes */10000",
            "bytes 4096-4099/9999999999"
        ] {
            await expect(
                .invalidContentRange,
                client: SecureMediaRangeClient(
                    transport: StubTransport(contentRange: contentRange)
                )
            )
        }
    }

    func testRejectsUnexpectedShortPartialResponse() async {
        await expect(
            .inconsistentLength,
            client: SecureMediaRangeClient(
                transport: StubTransport(
                    contentRange: "bytes 4096-4098/10000",
                    data: Data([1, 2, 3])
                )
            )
        )
    }

    func testRejectsTruncatedBytes() async {
        await expect(
            .inconsistentLength,
            client: SecureMediaRangeClient(
                transport: StubTransport(data: Data([1, 2]))
            )
        )
    }

    func testAcceptsShortLastChunkAtEOF() async throws {
        let client = SecureMediaRangeClient(
            transport: StubTransport(
                contentRange: "bytes 4096-4097/4098",
                data: Data([5, 6])
            )
        )
        let chunk = try await client.read(
            from: url, range: MediaByteRange(offset: 4096, length: 4)
        )
        XCTAssertEqual(chunk.totalLength, 4098)
        XCTAssertEqual(chunk.bytes.count, 2)
        XCTAssertEqual(chunk.end, 4097)
    }

    func testRejectsHTMLAndOtherUnexpectedTypes() async {
        for contentType in ["text/html", "application/json", "text/plain"] {
            await expect(
                .invalidContentType,
                client: SecureMediaRangeClient(
                    transport: StubTransport(contentType: contentType)
                )
            )
        }
    }

    func testAcceptsOctetStreamForKnownCodec() async throws {
        let client = SecureMediaRangeClient(
            transport: StubTransport(contentType: "application/octet-stream")
        )
        let result = try await client.read(
            from: url, range: MediaByteRange(offset: 4096, length: 4)
        )
        XCTAssertEqual(result.contentType, "application/octet-stream")
    }

    func testClassifiesForbiddenAndRateLimit() async {
        for (status, expected) in [
            (401, MediaRangeError.unauthorized),
            (403, .forbidden),
            (410, .expiredSource),
            (429, .httpStatus(429)),
            (503, .httpStatus(503))
        ] {
            await expect(
                expected, client: SecureMediaRangeClient(
                    transport: StubTransport(status: status)
                )
            )
        }
    }

    func testGuardsOversizedServerResponse() async {
        let client = SecureMediaRangeClient(
            transport: StubTransport(throwsOversized: true)
        )
        await expect(.oversized, client: client)
    }

    func testNeverPrintsSignedMediaURLInErrors() async {
        let client = SecureMediaRangeClient(
            transport: StubTransport(status: 403)
        )
        do {
            _ = try await client.read(
                from: url, range: MediaByteRange(offset: 4096, length: 4)
            )
            XCTFail("Expected refusal")
        } catch {
            XCTAssertFalse(String(describing: error).contains("ysign"))
            XCTAssertFalse(String(reflecting: error).contains("private"))
        }
    }

    private func expect(
        _ expected: MediaRangeError,
        client: SecureMediaRangeClient,
        url providedURL: URL? = nil
    ) async {
        do {
            _ = try await client.read(
                from: providedURL ?? url,
                range: MediaByteRange(offset: 4096, length: 4)
            )
            XCTFail("Expected \(expected)")
        } catch let error as MediaRangeError {
            XCTAssertEqual(error, expected)
        } catch {
            XCTFail("Wrong failure type: \(type(of: error))")
        }
    }

    private actor StubTransport: MediaHTTPRangeTransport {
        let responseURL: URL?
        let status: Int
        let contentRange: String?
        let contentType: String
        let data: Data
        let throwsOversized: Bool
        private var requests: [URLRequest] = []
        private var lastLimit = 0

        init(
            responseURL: URL? = nil,
            status: Int = 206,
            contentRange: String? = "bytes 4096-4099/10000",
            contentType: String = "audio/mp4; charset=binary",
            data: Data = Data([1, 2, 3, 4]),
            throwsOversized: Bool = false
        ) {
            self.responseURL = responseURL
            self.status = status
            self.contentRange = contentRange
            self.contentType = contentType
            self.data = data
            self.throwsOversized = throwsOversized
        }

        func data(
            for request: URLRequest,
            maximumBytes: Int
        ) async throws -> (Data, HTTPURLResponse) {
            requests.append(request)
            lastLimit = maximumBytes
            if throwsOversized { throw MediaRangeError.oversized }
            var headers: [String: String] = ["Content-Type": contentType]
            if let contentRange {
                headers["Content-Range"] = contentRange
            }
            let response = HTTPURLResponse(
                url: responseURL ?? request.url!,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: headers
            )!
            return (data, response)
        }

        func captured() -> [URLRequest] { requests }
        func limit() -> Int { lastLimit }
    }
}
