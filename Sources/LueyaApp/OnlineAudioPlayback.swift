import AVFoundation
import Foundation
import LueyaCore
import Observation

@MainActor
final class ControlledMediaAssetLoader: NSObject, @preconcurrency AVAssetResourceLoaderDelegate {
    let localURL: URL
    private let source: PlayableSource
    private let reader: SecureMediaRangeClient
    private let reportError: @MainActor (MediaRangeError) -> Void
    private var totalLength: Int64?
    private var requests: [ObjectIdentifier: Task<Void, Never>] = [:]
    private var closed = false

    init(
        source: PlayableSource,
        reader: SecureMediaRangeClient = SecureMediaRangeClient(),
        reportError: @escaping @MainActor (MediaRangeError) -> Void
    ) {
        self.source = source
        self.reader = reader
        self.reportError = reportError
        let suffix = source.codec == .mp3 ? "mp3" : "m4a"
        self.localURL = URL(
            string: "lueya-stream://\(UUID().uuidString.lowercased())/audio.\(suffix)"
        )!
        super.init()
    }

    func resourceLoader(
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

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        didCancel request: AVAssetResourceLoadingRequest
    ) {
        requests.removeValue(forKey: ObjectIdentifier(request))?.cancel()
    }

    func close() {
        closed = true
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
                    let chunk = try await reader.read(
                        from: source.url,
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

    private func knownLength() async throws -> Int64 {
        if let totalLength { return totalLength }
        let sample = try await reader.read(
            from: source.url,
            range: MediaByteRange(offset: 0, length: 1)
        )
        guard sample.totalLength > 0 else { throw MediaRangeError.invalidContentRange }
        totalLength = sample.totalLength
        return sample.totalLength
    }
}

enum PlaybackStatus: Equatable {
    case idle
    case connecting
    case playing
    case paused
    case finished
    case failed(String)
}

@MainActor
@Observable
final class OnlineAudioPlayback {
    private(set) var status: PlaybackStatus = .idle
    private(set) var elapsedSeconds: Double = 0
    private(set) var durationSeconds: Double = 0

    @ObservationIgnored private var player: AVPlayer?
    @ObservationIgnored private var asset: AVURLAsset?
    @ObservationIgnored private var loader: ControlledMediaAssetLoader?
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var endObserver: (any NSObjectProtocol)?
    @ObservationIgnored private var failedObserver: (any NSObjectProtocol)?

    func start(_ track: ResolvedTrack) {
        stop()

        guard track.source.isFresh() else {
            status = .failed("The source link expired. Check the track again.")
            return
        }
        guard MusicCDNPolicy.accepts(track.source.url) else {
            status = .failed("The media source did not pass security checks.")
            return
        }

        durationSeconds = Double(track.metadata.durationMilliseconds ?? 0) / 1000.0
        let handler = ControlledMediaAssetLoader(source: track.source) { [weak self] error in
            self?.resourceFailed(error)
        }
        let asset = AVURLAsset(url: handler.localURL)
        asset.resourceLoader.setDelegate(handler, queue: .main)
        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)
        player.automaticallyWaitsToMinimizeStalling = true

        self.loader = handler
        self.asset = asset
        self.player = player
        status = .connecting

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self, self.player === player else { return }
                let value = CMTimeGetSeconds(time)
                if value.isFinite, value >= 0 { self.elapsedSeconds = value }
                if player.rate > 0, self.status == .connecting { self.status = .playing }
                if let error = player.currentItem?.error {
                    _ = error // Never expose potentially sensitive URLs from system errors.
                    self.status = .failed("The audio decoder could not start this stream.")
                }
            }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.player === player else { return }
                self.status = .finished
            }
        }
        failedObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.player === player else { return }
                self.status = .failed("The stream ended unexpectedly.")
            }
        }
        player.play()
    }

    func toggle() {
        guard let player else { return }
        switch status {
        case .playing, .connecting:
            player.pause()
            status = .paused
        case .paused:
            player.play()
            status = .connecting
        case .finished:
            player.seek(to: .zero)
            elapsedSeconds = 0
            player.play()
            status = .connecting
        case .idle, .failed:
            break
        }
    }

    func seek(to seconds: Double) {
        guard let player, seconds.isFinite,
              seconds >= 0, durationSeconds > 0 else { return }
        let target = min(seconds, durationSeconds)
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
        elapsedSeconds = target
    }

    func stop() {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        if let failedObserver { NotificationCenter.default.removeObserver(failedObserver) }
        endObserver = nil
        failedObserver = nil

        player?.pause()
        player?.replaceCurrentItem(with: nil)
        loader?.close()
        asset?.resourceLoader.setDelegate(nil, queue: nil)
        player = nil
        loader = nil
        asset = nil
        status = .idle
        elapsedSeconds = 0
        durationSeconds = 0
    }

    private func resourceFailed(_ error: MediaRangeError) {
        switch error {
        case .forbidden, .unauthorized, .expiredSource:
            status = .failed("The provider denied this media request. Check the track again.")
        case .rangeUnsupported:
            status = .failed("This media server does not support safe byte-range streaming.")
        default:
            status = .failed("The media server returned an unsupported response.")
        }
        player?.pause()
    }
}
