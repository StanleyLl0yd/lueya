import AVFoundation
import Foundation
import LueyaCore
import Observation

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
    private(set) var volume: Double = 1

    @ObservationIgnored private var player: AVPlayer?
    @ObservationIgnored private var asset: AVURLAsset?
    @ObservationIgnored private var loader: ControlledMediaAssetLoader?
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var endObserver: (any NSObjectProtocol)?
    @ObservationIgnored private var failedObserver: (any NSObjectProtocol)?
    @ObservationIgnored private var itemStatusObservation: NSKeyValueObservation?
    @ObservationIgnored private var playerControlObservation: NSKeyValueObservation?
    @ObservationIgnored private var startupWatchdog: Task<Void, Never>?
    @ObservationIgnored private var playbackGeneration: UInt64 = 0

    func start(
        _ track: ResolvedTrack,
        onFinished: @escaping @MainActor () -> Void,
        renewSource: @escaping @MainActor () async throws -> ResolvedTrack
    ) {
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
        let generation = playbackGeneration
        let handler = ControlledMediaAssetLoader(track: track, renewSource: renewSource) { [weak self] error in
            guard let self, self.playbackGeneration == generation else { return }
            self.resourceFailed(error)
        }
        let asset = AVURLAsset(url: handler.localURL)
        asset.resourceLoader.setDelegate(handler, queue: .main)
        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)
        player.automaticallyWaitsToMinimizeStalling = true
        player.volume = Float(volume)

        self.loader = handler
        self.asset = asset
        self.player = player
        status = .connecting
        itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            let rawStatus = item.status.rawValue
            Task { @MainActor [weak self] in
                self?.handleItemStatus(rawStatus, generation: generation)
            }
        }
        playerControlObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) {
            [weak self] player, _ in
            let rawStatus = player.timeControlStatus.rawValue
            Task { @MainActor [weak self] in
                self?.handleControlStatus(rawStatus, generation: generation)
            }
        }
        beginStartupWatchdog(generation: generation)

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self, self.player === player else { return }
                let value = CMTimeGetSeconds(time)
                if value.isFinite, value >= 0 { self.elapsedSeconds = value }
                if player.currentItem?.status == .failed {
                    // System NSError may contain a signed CDN URL: never display it.
                    self.fail("The audio decoder could not open this stream.")
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
                if case .failed = self.status { return }
                self.startupWatchdog?.cancel()
                self.startupWatchdog = nil
                self.status = .finished
                onFinished()
            }
        }
        failedObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.player === player else { return }
                self.fail("The stream ended unexpectedly.")
            }
        }
        player.play()
    }

    func toggle() {
        guard let player else { return }
        switch status {
        case .playing, .connecting:
            startupWatchdog?.cancel()
            startupWatchdog = nil
            player.pause()
            status = .paused
        case .paused:
            status = .connecting
            beginStartupWatchdog(generation: playbackGeneration)
            player.play()
        case .finished:
            player.seek(to: .zero)
            elapsedSeconds = 0
            status = .connecting
            beginStartupWatchdog(generation: playbackGeneration)
            player.play()
        case .idle, .failed:
            break
        }
    }

    func setVolume(_ value: Double) {
        guard value.isFinite else { return }
        volume = min(1, max(0, value))
        player?.volume = Float(volume)
    }

    func seek(to seconds: Double) {
        guard let player, seconds.isFinite,
              seconds >= 0, durationSeconds > 0 else { return }
        let target = min(seconds, durationSeconds)
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
        elapsedSeconds = target
    }

    func stop() {
        playbackGeneration &+= 1
        startupWatchdog?.cancel()
        startupWatchdog = nil
        itemStatusObservation?.invalidate()
        playerControlObservation?.invalidate()
        itemStatusObservation = nil
        playerControlObservation = nil
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

    private func handleItemStatus(_ raw: Int, generation: UInt64) {
        guard generation == playbackGeneration else { return }
        if raw == AVPlayerItem.Status.failed.rawValue {
            fail("The audio decoder could not load this stream.")
        }
    }

    private func handleControlStatus(_ raw: Int, generation: UInt64) {
        guard generation == playbackGeneration else { return }
        if case .failed = status { return }
        guard raw == AVPlayer.TimeControlStatus.playing.rawValue else { return }
        if status == .connecting {
            startupWatchdog?.cancel()
            startupWatchdog = nil
            status = .playing
        }
    }

    private func beginStartupWatchdog(generation: UInt64) {
        startupWatchdog?.cancel()
        startupWatchdog = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(15))
                try Task.checkCancellation()
            } catch {
                return
            }
            self?.startupTimedOut(generation: generation)
        }
    }

    private func startupTimedOut(generation: UInt64) {
        guard generation == playbackGeneration, status == .connecting else { return }
        fail("Audio did not become ready. Check the source or connection.")
    }

    private func fail(_ message: String) {
        guard status != .idle, status != .finished else { return }
        startupWatchdog?.cancel()
        startupWatchdog = nil
        status = .failed(message)
        player?.pause()
    }

    private func resourceFailed(_ error: MediaRangeError) {
        switch error {
        case .forbidden, .unauthorized, .expiredSource:
            fail("The provider denied this media request. Check the track again.")
        case .rangeUnsupported:
            fail("This media server does not support safe byte-range streaming.")
        default:
            fail("The media server returned an unsupported response.")
        }
    }
}
