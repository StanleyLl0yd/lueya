import Foundation
import LueyaCore
import Observation

@MainActor
@Observable
final class MusicSignInModel {
    enum Status {
        case restoring
        case signedOut
        case requestingCode
        case awaitingAuthorization
        case signedIn(String)
        case failed(String)
    }

    enum SourceProbeStatus {
        case idle
        case checking
        case verified(String, String)
        case failed(String)
    }

    private(set) var status: Status = .restoring
    private(set) var code: OAuthDeviceCode?
    private(set) var sourceProbe: SourceProbeStatus = .idle
    @ObservationIgnored let playback = OnlineAudioPlayback()

    @ObservationIgnored private let session = YandexMusicSession()
    @ObservationIgnored private let streamProvider = YandexMusicStreamProvider()
    @ObservationIgnored private var hasRestored = false
    @ObservationIgnored private var signInTask: Task<Void, Never>?
    @ObservationIgnored private var sourceProbeTask: Task<Void, Never>?
    @ObservationIgnored private var replayTask: Task<Void, Never>?
    @ObservationIgnored private var resolvedTrack: ResolvedTrack?
    @ObservationIgnored private var sourceProbeGeneration: UInt64 = 0
    @ObservationIgnored private var playbackOperationGeneration: UInt64 = 0

    func restoreIfNeeded() async {
        guard !hasRestored else { return }
        hasRestored = true

        do {
            if let account = try await session.restoreAccount() {
                status = .signedIn(account.account?.login ?? "Yandex Music account")
            } else {
                status = .signedOut
            }
        } catch {
            status = .failed(Self.message(for: error))
        }
    }

    func signIn() {
        cancelSourceProbe()
        cancelPlayback()
        signInTask?.cancel()
        code = nil
        status = .requestingCode

        signInTask = Task {
            do {
                let received = try await session.beginSignIn()
                try Task.checkCancellation()
                code = received
                status = .awaitingAuthorization

                let account = try await session.completeSignIn(code: received)
                try Task.checkCancellation()
                code = nil
                status = .signedIn(account.account?.login ?? "Yandex Music account")
            } catch is CancellationError {
                code = nil
                status = .signedOut
            } catch {
                code = nil
                status = .failed(Self.message(for: error))
            }
        }
    }

    func cancelSignIn() {
        signInTask?.cancel()
        signInTask = nil
        code = nil
        status = .signedOut
    }

    func signOut() {
        cancelSourceProbe()
        cancelPlayback()
        signInTask?.cancel()
        signInTask = nil
        code = nil

        Task {
            do {
                try await session.signOut()
                status = .signedOut
            } catch {
                status = .failed(Self.message(for: error))
            }
        }
    }

    func checkStreamSource(trackID: String) {
        guard case .signedIn = status else { return }
        cancelSourceProbe()
        cancelPlayback()
        sourceProbe = .checking
        let generation = sourceProbeGeneration

        sourceProbeTask = Task {
            do {
                guard let token = try await session.validAccessToken() else {
                    throw MusicStreamError.invalidToken
                }
                let track = try await streamProvider.resolveTrack(id: trackID, accessToken: token)
                try Task.checkCancellation()
                guard sourceProbeGeneration == generation, case .signedIn = status else { return }

                resolvedTrack = track
                let metadata = track.metadata
                let artist = metadata.artists.joined(separator: ", ")
                let title = artist.isEmpty ? metadata.title : "\(artist) — \(metadata.title)"
                let quality = track.source.quality.rawValue
                let codec = track.source.codec.rawValue
                sourceProbe = .verified(title, "Raw source candidate: \(codec) / \(quality). Audio not yet tested.")
            } catch is CancellationError {
                if sourceProbeGeneration == generation { sourceProbe = .idle }
            } catch {
                guard sourceProbeGeneration == generation, case .signedIn = status else { return }
                sourceProbe = .failed(Self.streamMessage(for: error))
            }
        }
    }

    func playOrPause() {
        guard case .signedIn = status, let resolvedTrack else { return }
        switch playback.status {
        case .connecting, .playing, .paused:
            playback.toggle()
        case .idle, .failed, .finished:
            replayTask?.cancel()
            guard !resolvedTrack.source.isFresh() else {
                startPlayback(resolvedTrack)
                return
            }

            // Refresh a stale signed source only through the user's session.
            playback.stop()
            let generation = sourceProbeGeneration
            let trackID = resolvedTrack.metadata.id
            sourceProbe = .checking
            replayTask = Task {
                do {
                    guard let token = try await session.validAccessToken() else {
                        throw MusicStreamError.invalidToken
                    }
                    let refreshed = try await streamProvider.resolveTrack(
                        id: trackID,
                        accessToken: token
                    )
                    try Task.checkCancellation()
                    guard generation == sourceProbeGeneration,
                          case .signedIn = status else { return }
                    self.resolvedTrack = refreshed
                    let artist = refreshed.metadata.artists.joined(separator: ", ")
                    let name = artist.isEmpty
                        ? refreshed.metadata.title
                        : "\(artist) — \(refreshed.metadata.title)"
                    sourceProbe = .verified(
                        name,
                        "Raw source: \(refreshed.source.codec.rawValue) / \(refreshed.source.quality.rawValue)"
                    )
                    startPlayback(refreshed)
                } catch is CancellationError {
                    // A superseding request or logout must not restart playback.
                } catch {
                    guard generation == sourceProbeGeneration,
                          case .signedIn = status else { return }
                    sourceProbe = .failed(Self.streamMessage(for: error))
                }
            }
        }
    }

    func stopPlayback() {
        playbackOperationGeneration &+= 1
        replayTask?.cancel()
        replayTask = nil
        playback.stop()
    }

    func seekPlayback(to seconds: Double) {
        playback.seek(to: seconds)
    }

    private func cancelPlayback() {
        playbackOperationGeneration &+= 1
        replayTask?.cancel()
        replayTask = nil
        resolvedTrack = nil
        playback.stop()
    }

    private func startPlayback(_ track: ResolvedTrack) {
        playbackOperationGeneration &+= 1
        let operation = playbackOperationGeneration
        let probe = sourceProbeGeneration
        let trackID = track.metadata.id
        playback.start(track) { [weak self] in
            guard let self,
                  self.playbackOperationGeneration == operation,
                  self.sourceProbeGeneration == probe,
                  case .signedIn = self.status else { throw CancellationError() }

            guard let token = try await self.session.validAccessToken() else {
                throw MusicStreamError.invalidToken
            }
            let refreshed = try await self.streamProvider.resolveTrack(
                id: trackID, accessToken: token
            )
            try Task.checkCancellation()
            guard self.playbackOperationGeneration == operation,
                  self.sourceProbeGeneration == probe,
                  case .signedIn = self.status else { throw CancellationError() }
            // Only the loader may accept a replacement after format checks.
            // Do not overwrite the UI's cached candidate before that decision.
            return refreshed
        }
    }

    private func cancelSourceProbe() {
        sourceProbeGeneration &+= 1
        sourceProbeTask?.cancel()
        sourceProbeTask = nil
        sourceProbe = .idle
    }

    private static func streamMessage(for error: Error) -> String {
        guard let stream = error as? MusicStreamError else {
            return "Could not reach the music service. Check your network."
        }
        switch stream {
        case .invalidTrackID:
            return "Enter a numeric Yandex Music track ID."
        case .invalidToken:
            return "Music session is missing or invalid. Please sign in again."
        case .unauthorized(let stage):
            return "HTTP 401: \(stage.label) request was unauthorized. Sign-in may need renewal."
        case .metadataUnavailable:
            return "The provider marks this track unavailable in its metadata."
        case .forbidden(let stage):
            return "HTTP 403: \(stage.label) request denied. This does not prove a region block."
        case .unavailable:
            return "No compatible raw audio source was returned for this track."
        case .unsupportedEncryptedTransport:
            return "The service supplied only unsupported encrypted media."
        case .unsupportedCodec:
            return "No supported AAC/MP3 media format was supplied."
        case .untrustedMediaURL:
            return "The media source was outside the trusted CDN allowlist."
        case .rateLimited(let stage):
            return "HTTP 429: \(stage.label) rate-limited. Try again later."
        case .httpStatus(let stage, let status):
            return "HTTP \(status): \(stage.label) request failed."
        case .invalidResponse, .invalidPayload:
            return "The service returned an unexpected media response."
        }
    }

    private static func message(for error: Error) -> String {
        if let oauth = error as? YandexOAuthError {
            switch oauth {
            case .authorizationDenied:
                return "Authorization was declined."
            case .expired:
                return "Authorization expired. Please try again."
            case .invalidClient, .invalidCredentials:
                return "Yandex rejected the login session."
            case .rateLimited:
                return "Too many requests. Please try later."
            case .invalidResponse, .invalidVerificationURL, .httpStatus:
                return "Yandex authorization is currently unavailable."
            }
        }
        if let api = error as? MusicAPIError {
            switch api {
            case .unauthorized, .forbidden:
                return "This account cannot access Yandex Music."
            default:
                return "Could not verify the Yandex Music account."
            }
        }
        if error is TokenStorageError {
            return "Unable to access the local Keychain session."
        }
        return "Could not connect. Check your network and try again."
    }
}
