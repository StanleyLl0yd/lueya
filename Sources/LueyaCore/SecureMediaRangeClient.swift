import Foundation

public struct MediaByteRange: Sendable, Equatable {
    public static let maximumChunkLength = 128 * 1024
    public let offset: Int64
    public let length: Int

    public init(offset: Int64, length: Int) throws {
        guard offset >= 0, (1...Self.maximumChunkLength).contains(length),
              offset <= Int64.max - Int64(length) else {
            throw MediaRangeError.invalidRange
        }
        self.offset = offset
        self.length = length
    }

    public var end: Int64 { offset + Int64(length) - 1 }
}

public struct MediaRangeResponse: Sendable {
    public let bytes: Data
    public let offset: Int64
    public let end: Int64
    public let totalLength: Int64
    public let contentType: String
}

public enum MediaRangeError: Error, Equatable, Sendable {
    case invalidRange
    case untrustedURL
    case invalidResponse
    case rangeUnsupported
    case invalidContentRange
    case inconsistentLength
    case oversized
    case invalidContentType
    case unauthorized
    case forbidden
    case expiredSource
    case httpStatus(Int)
}

public protocol MediaHTTPRangeTransport: Sendable {
    func data(
        for request: URLRequest,
        maximumBytes: Int
    ) async throws -> (Data, HTTPURLResponse)
}

/// Each request has a strict in-memory byte cap. There is no cache, cookie store,
/// background transfer, disk file or redirect-following path.
public struct BoundedEphemeralMediaTransport: MediaHTTPRangeTransport {
    private let session: URLSession

    public init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpMaximumConnectionsPerHost = 3
        session = URLSession(
            configuration: configuration,
            delegate: RejectRedirects(),
            delegateQueue: nil
        )
    }

    public func data(
        for request: URLRequest,
        maximumBytes: Int
    ) async throws -> (Data, HTTPURLResponse) {
        guard (1...MediaByteRange.maximumChunkLength).contains(maximumBytes) else {
            throw MediaRangeError.invalidRange
        }
        let (stream, rawResponse) = try await session.bytes(for: request)
        guard let response = rawResponse as? HTTPURLResponse else {
            throw MediaRangeError.invalidResponse
        }
        // Error pages are not media. Inspect only their HTTP status and URL;
        // a 403/410 HTML body can exceed a one-byte range probe.
        // Never buffer or expose denial bodies, cookies or signed URLs.
        guard response.statusCode == 206 else {
            return (Data(), response)
        }
        if rawResponse.expectedContentLength > Int64(maximumBytes) {
            throw MediaRangeError.oversized
        }

        var data = Data()
        data.reserveCapacity(min(maximumBytes, 8192))
        for try await byte in stream {
            try Task.checkCancellation()
            guard data.count < maximumBytes else { throw MediaRangeError.oversized }
            data.append(byte)
        }
        return (data, response)
    }

    private final class RejectRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest request: URLRequest
        ) async -> URLRequest? {
            nil
        }
    }
}

/// A narrow byte-range boundary for signed, *already authorized* raw media.
/// Neither the provider's OAuth token nor a media URL is ever logged or persisted.
public struct SecureMediaRangeClient: Sendable {
    private let transport: any MediaHTTPRangeTransport

    public init(
        transport: any MediaHTTPRangeTransport = BoundedEphemeralMediaTransport()
    ) {
        self.transport = transport
    }

    public func read(from sourceURL: URL, range: MediaByteRange) async throws -> MediaRangeResponse {
        guard MusicCDNPolicy.accepts(sourceURL) else {
            throw MediaRangeError.untrustedURL
        }
        try Task.checkCancellation()

        var request = URLRequest(
            url: sourceURL,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 20
        )
        request.httpMethod = "GET"
        request.setValue("bytes=\(range.offset)-\(range.end)", forHTTPHeaderField: "Range")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        // Never send an OAuth header, a custom client secret or browser cookies.
        let (data, response) = try await transport.data(
            for: request,
            maximumBytes: range.length
        )
        try Task.checkCancellation()
        guard let responseURL = response.url, responseURL == sourceURL,
              MusicCDNPolicy.accepts(responseURL) else {
            throw MediaRangeError.invalidResponse
        }
        switch response.statusCode {
        case 206: break
        case 200: throw MediaRangeError.rangeUnsupported
        case 401: throw MediaRangeError.unauthorized
        case 403: throw MediaRangeError.forbidden
        case 410: throw MediaRangeError.expiredSource
        default: throw MediaRangeError.httpStatus(response.statusCode)
        }

        guard let header = response.value(forHTTPHeaderField: "Content-Range"),
              let parsed = Self.parseContentRange(header) else {
            throw MediaRangeError.invalidContentRange
        }
        let (lower, upper, total) = parsed
        guard lower == range.offset, upper <= range.end,
              upper >= lower, upper < total else {
            throw MediaRangeError.invalidContentRange
        }
        // Short responses are acceptable *only* at actual end-of-file.
        guard upper == range.end || upper == total - 1 else {
            throw MediaRangeError.inconsistentLength
        }
        let expectedCount = upper - lower + 1
        guard expectedCount == Int64(data.count) else {
            throw MediaRangeError.inconsistentLength
        }

        let mediaType = (response.value(forHTTPHeaderField: "Content-Type") ?? "")
            .split(separator: ";", maxSplits: 1)
            .first.map { $0.trimmingCharacters(in: .whitespaces).lowercased() } ?? ""
        guard Self.acceptedTypes.contains(mediaType) else {
            throw MediaRangeError.invalidContentType
        }

        return MediaRangeResponse(
            bytes: data,
            offset: lower,
            end: upper,
            totalLength: total,
            contentType: mediaType
        )
    }

    private static let acceptedTypes: Set<String> = [
        "application/octet-stream", "binary/octet-stream",
        "audio/mp4", "audio/mpeg", "audio/mpeg3",
        "audio/aac", "audio/x-aac", "audio/x-m4a",
        "video/mp4", "application/mp4"
    ]

    private static func parseContentRange(_ raw: String) -> (Int64, Int64, Int64)? {
        guard raw.hasPrefix("bytes ") else { return nil }
        let parts = raw.dropFirst(6).split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let total = Int64(parts[1]), total > 0, total <= 2_147_483_647 else {
            return nil
        }
        let bounds = parts[0].split(separator: "-", omittingEmptySubsequences: false)
        guard bounds.count == 2,
              let lower = Int64(bounds[0]), let upper = Int64(bounds[1]),
              lower >= 0, upper >= lower, upper < total else {
            return nil
        }
        return (lower, upper, total)
    }
}
