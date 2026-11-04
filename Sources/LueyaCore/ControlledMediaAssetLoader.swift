import AVFoundation
import Foundation

@MainActor
public final class ControlledMediaAssetLoader: NSObject, @preconcurrency AVAssetResourceLoaderDelegate {
    public let localURL: URL
    private let original: ResolvedTrack
    private var source: PlayableSource
    private let renewSource: @MainActor () async throws -> ResolvedTrack
    private var renewalTask: Task<PlayableSource, Error>?
    private var renewalCount = 0
    private let reader: SecureMediaRangeClient
    private let reportError: @MainActor (MediaRangeError) -> Void
    private var totalLength: Int64?
    private var requests: [ObjectIdentifier: Task<Void, Never>] = [:]
    private var closed = false

    public init(
        track: ResolvedTrack,
        reader: SecureMediaRangeClient = SecureMediaRangeClient(),
        renewSource: @escaping @MainActor () async throws -> ResolvedTrack,
        reportError: @escaping @MainActor (MediaRangeError) -> Void
    ) {
        self.original = track
        self.source = track.source
        self.reader = reader
        self.renewSource = renewSource
        self.reportError = reportError
        let suffix = track.source.codec == .mp3 ? "mp3" : "m4a"
        self.localURL = URL(
            string: "lueya-stream://\(UUID().uuidString.lowercased())/audio.\(suffix)"
        )!
        super.init()
    }

    public func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource request: AVAssetResourceLoadingRequest
    ) -> Bool {
        guard !closed, request.request.url == localURL else { return false }

        let key = ObjectIdentifier(request)
        requests[key]?.cancel()
        requests[key] = Task { [weak self] in
            await self?.serve(request, key: key)
        }
        return true
    }

    public func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        didCancel request: AVAssetResourceLoadingRequest
    ) {
        requests.removeValue(forKey: ObjectIdentifier(request))?.cancel()
    }

    public func close() {
        closed = true
        renewalTask?.cancel()
        renewalTask = nil
        for task in requests.values { task.cancel() }
        requests.removeAll()
    }

    private func serve(
        _ request: AVAssetResourceLoadingRequest,
        key: ObjectIdentifier
    ) async {
        defer { requests.removeValue(forKey: key) }
        do {
            try Task.checkCancellation()
            // First probe one byte to establish a trusted resource length.
            // This is not a full media download or a persisted cache.
            let length = try await knownLength()
            try Task.checkCancellation()
            guard !closed, requests[key] != nil, !request.isFinished else { return }

            if let content = request.contentInformationRequest {
                let type = source.codec == .mp3 ? "public.mp3" : "public.mpeg-4-audio"
                if content.allowedContentTypes?.contains(type) ?? true {
                    content.contentType = type
                }
                content.contentLength = length
                content.isByteRangeAccessSupported = true
                content.isEntireLengthAvailableOnDemand = false
            }

            if let data = request.dataRequest {
                var cursor = max(data.currentOffset, data.requestedOffset)
                let needsAll = data.requestsAllDataToEndOfResource
                let requestedEnd: Int64
                if needsAll {
                    requestedEnd = length
                } else {
                    let end = data.requestedOffset.addingReportingOverflow(Int64(data.requestedLength))
                    guard !end.overflow, data.requestedLength >= 0 else {
                        throw MediaRangeError.invalidRange
                    }
                    requestedEnd = min(length, end.partialValue)
                }

                while cursor < requestedEnd {
                    try Task.checkCancellation()
                    guard !closed, requests[key] != nil, !request.isFinished else { return }
                    let count = Int(min(
                        Int64(MediaByteRange.maximumChunkLength), requestedEnd - cursor
                    ))
                    let chunk = try await read(
                        range: MediaByteRange(offset: cursor, length: count)
                    )
                    try Task.checkCancellation()
                    guard !closed, requests[key] != nil, !request.isFinished else { return }
                    guard chunk.totalLength == length else {
                        throw MediaRangeError.inconsistentLength
                    }
                    data.respond(with: chunk.bytes)
                    cursor += Int64(chunk.bytes.count)
                }
            }

            guard !closed, requests[key] != nil, !request.isFinished else { return }
            request.finishLoading()
        } catch is CancellationError {
            // Cancellation is expected on seek, track change, sign-out or close.
        } catch let error as MediaRangeError {
            guard !closed, requests[key] != nil, !request.isFinished else { return }
            reportError(error)
            request.finishLoading(with: error)
        } catch {
            guard !closed, requests[key] != nil, !request.isFinished else { return }
            reportError(.invalidResponse)
            request.finishLoading(with: MediaRangeError.invalidResponse)
        }
    }

    private func read(range: MediaByteRange) async throws -> MediaRangeResponse {
        let selected = source
        do {
            return try await reader.read(from: selected.url, range: range)
        } catch let error as MediaRangeError {
            guard !closed, MediaSourceRenewalPolicy.shouldRenew(error, source: selected) else {
                throw error
            }
            let replacement = try await replacementSource(after: selected)
            try Task.checkCancellation()
            guard !closed else { throw CancellationError() }
            // Exactly one retry for this byte range; no retry loop for access denials.
            return try await reader.read(from: replacement.url, range: range)
        }
    }

    private func replacementSource(after previous: PlayableSource) async throws -> PlayableSource {
        if source.url != previous.url { return source }
        if let renewalTask { return try await renewalTask.value }
        guard renewalCount < MediaSourceRenewalPolicy.maximumRenewals else {
            throw MediaRangeError.expiredSource
        }

        renewalCount += 1
        let task = Task { [original, renewSource] () throws -> PlayableSource in
            // Back off between provider calls and avoid immediate denial loops.
            try await Task.sleep(for: .milliseconds(300))
            let refreshed = try await renewSource()
            try Task.checkCancellation()
            guard MediaSourceRenewalPolicy.accepts(original: original, replacement: refreshed),
                  refreshed.source.url != previous.url else {
                throw MediaRangeError.invalidResponse
            }
            return refreshed.source
        }
        renewalTask = task
        defer { renewalTask = nil }
        let updated = try await task.value
        try Task.checkCancellation()
        guard !closed else { throw CancellationError() }
        source = updated
        return updated
    }

    private func knownLength() async throws -> Int64 {
        if let totalLength { return totalLength }
        let sample = try await read(
            range: MediaByteRange(offset: 0, length: 1)
        )
        guard sample.totalLength > 0 else { throw MediaRangeError.invalidContentRange }
        totalLength = sample.totalLength
        return sample.totalLength
    }
}
