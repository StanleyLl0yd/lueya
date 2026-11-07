import Foundation
import LueyaCore
import Observation

@MainActor
@Observable
final class MusicSignInModel {
    enum Status {
        case restoring
        case signedOut
        case signingOut
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

    enum SearchStatus: Equatable {
        case idle
        case searching
        case ready
        case failed(String)
    }

    enum ExploreStatus: Equatable {
        case idle
        case loading
        case ready
        case failed(String)
    }

    private enum FailedOperation {
        case restore
        case signIn
        case signOut
    }

    private(set) var status: Status = .restoring
    private(set) var sessionNotice: String?
    private(set) var code: OAuthDeviceCode?
    private(set) var sourceProbe: SourceProbeStatus = .idle
    private(set) var searchStatus: SearchStatus = .idle
    private(set) var searchResults: [MusicSearchTrack] = []
    private(set) var artistResults: [MusicSearchArtist] = []
    private(set) var albumResults: [MusicSearchAlbum] = []
    private(set) var artistAlbums: [MusicSearchAlbum] = []
    private(set) var selectedArtist: MusicSearchArtist?
    private(set) var selectedAlbum: MusicSearchAlbum?
    private(set) var hasMoreArtistAlbums = false
    private(set) var isLoadingMoreArtistAlbums = false
    private var artistAlbumPage = 0
    private var previousSearchTracks: [MusicSearchTrack] = []
    private var previousArtistTracks: [MusicSearchTrack] = []
    private var albumLoadTask: Task<Void, Never>?
    private(set) var currentTrack: MusicSearchTrack?
    private(set) var recentTracks: [MusicSearchTrack] = []
    private(set) var exploreStatus: ExploreStatus = .idle
    private(set) var isStartingMyWave = false
    private(set) var isLoadingMyWaveBatch = false
    private(set) var myWaveMessage: String?
    private(set) var isMyWaveActive = false

    var canSkipNext: Bool {
        guard let currentQueueIndex else { return false }
        if currentQueueIndex + 1 < playQueue.count { return true }
        return myWaveSessionID != nil && !myWaveTerminated && !isLoadingMyWaveBatch
    }

    var canSkipPrevious: Bool {
        guard let currentQueueIndex else { return false }
        return currentQueueIndex > 0 || playback.elapsedSeconds > 3
    }
    @ObservationIgnored let playback = OnlineAudioPlayback()

    @ObservationIgnored private let session = YandexMusicSession()
    @ObservationIgnored private let streamProvider = YandexMusicStreamProvider()
    @ObservationIgnored private let searchProvider = YandexMusicSearchProvider()
    @ObservationIgnored private let exploreProvider = YandexMusicExploreProvider()
    @ObservationIgnored private var exploreTask: Task<Void, Never>?
    @ObservationIgnored private var exploreGeneration: UInt64 = 0
    @ObservationIgnored private var myWaveTask: Task<Void, Never>?
    @ObservationIgnored private var myWaveFeedbackTask: Task<Void, Never>?
    @ObservationIgnored private var myWaveGeneration: UInt64 = 0
    @ObservationIgnored private var myWaveSessionID: String?
    @ObservationIgnored private var myWaveBatchByTrackID: [String: String] = [:]
    @ObservationIgnored private var myWaveQueueIdentifiers: [String] = []
    @ObservationIgnored private var myWaveFeedbackStarted = false
    @ObservationIgnored private var myWaveTerminated = false
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var searchGeneration: UInt64 = 0
    @ObservationIgnored private var playQueue: [MusicSearchTrack] = []
    @ObservationIgnored private var currentQueueIndex: Int?
    @ObservationIgnored private var hasRestored = false
    @ObservationIgnored private var failedOperation: FailedOperation = .restore
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
                sessionNotice = account.account == nil
                    ? "Saved session loaded. Account verification is temporarily unavailable."
                    : nil
                status = .signedIn(account.account?.login ?? "Yandex Music account")
                loadExplore()
            } else {
                sessionNotice = nil
                status = .signedOut
            }
        } catch {
            failedOperation = .restore
            status = .failed(Self.message(for: error))
        }
    }

    func retryFailure() {
        switch failedOperation {
        case .restore:
            hasRestored = false
            status = .restoring
            Task { await restoreIfNeeded() }
        case .signIn:
            signIn()
        case .signOut:
            signOut()
        }
    }

    func signIn() {
        sessionNotice = nil
        clearCatalog()
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
                failedOperation = .signIn
                status = .signedIn(account.account?.login ?? "Yandex Music account")
                loadExplore()
            } catch is CancellationError {
                code = nil
                status = .signedOut
            } catch {
                code = nil
                failedOperation = .signIn
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
        sessionNotice = nil
        clearCatalog()
        cancelSourceProbe()
        cancelPlayback()
        signInTask?.cancel()
        signInTask = nil
        code = nil
        status = .signingOut

        Task {
            do {
                try await session.signOut()
                status = .signedOut
            } catch {
                failedOperation = .signOut
                status = .failed(Self.message(for: error))
            }
        }
    }

    func refreshExplore() {
        loadExplore()
    }

    private func loadExplore() {
        guard case .signedIn = status else { return }
        exploreTask?.cancel()
        exploreGeneration &+= 1
        let generation = exploreGeneration
        exploreStatus = .loading
        exploreTask = Task {
            do {
                guard let token = try await session.validAccessToken() else {
                    throw MusicExploreError.invalidToken
                }
                let tracks = try await exploreProvider.recentTracks(
                    accessToken: token, limit: 8
                )
                try Task.checkCancellation()
                guard generation == exploreGeneration, case .signedIn = status else { return }
                recentTracks = tracks
                exploreStatus = .ready
            } catch is CancellationError {
            } catch {
                guard generation == exploreGeneration, case .signedIn = status else { return }
                exploreStatus = .failed(Self.exploreMessage(for: error))
            }
        }
    }

    func startMyWave() {
        guard case .signedIn = status, !isStartingMyWave else { return }
        resetMyWaveSession()
        let generation = myWaveGeneration
        isStartingMyWave = true
        myWaveMessage = nil
        myWaveTask = Task {
            defer {
                if generation == myWaveGeneration { isStartingMyWave = false }
            }
            do {
                guard let token = try await session.validAccessToken() else {
                    throw MusicExploreError.invalidToken
                }
                let radio = try await exploreProvider.startMyWave(accessToken: token)
                try Task.checkCancellation()
                guard generation == myWaveGeneration, case .signedIn = status else { return }
                guard !radio.tracks.isEmpty else {
                    myWaveTerminated = radio.terminated
                    myWaveMessage = "Yandex Music has no recommendations available right now."
                    return
                }
                myWaveSessionID = radio.id
                myWaveTerminated = radio.terminated
                myWaveQueueIdentifiers = radio.queueIdentifiers
                if let batchID = radio.batchID {
                    for track in radio.tracks { myWaveBatchByTrackID[track.id] = batchID }
                }
                myWaveFeedbackStarted = false
                isMyWaveActive = true
                playQueue = radio.tracks
                currentQueueIndex = 0
                loadTrack(radio.tracks[0])
            } catch is CancellationError {
            } catch {
                guard generation == myWaveGeneration, case .signedIn = status else { return }
                myWaveMessage = Self.exploreMessage(for: error)
            }
        }
    }

    func playRecent(_ selected: MusicSearchTrack) {
        guard case .signedIn = status else { return }
        resetMyWaveSession()
        playQueue = [selected]
        currentQueueIndex = 0
        loadTrack(selected)
    }

    func playAll(_ tracks: [MusicSearchTrack]) {
        guard case .signedIn = status, let first = tracks.first else { return }
        resetMyWaveSession()
        playQueue = tracks
        currentQueueIndex = 0
        loadTrack(first)
    }

    private func resetMyWaveSession() {
        myWaveGeneration &+= 1
        myWaveTask?.cancel()
        myWaveTask = nil
        myWaveFeedbackTask?.cancel()
        myWaveFeedbackTask = nil
        myWaveSessionID = nil
        myWaveBatchByTrackID = [:]
        myWaveQueueIdentifiers = []
        myWaveFeedbackStarted = false
        myWaveTerminated = false
        isStartingMyWave = false
        isLoadingMyWaveBatch = false
        isMyWaveActive = false
        myWaveMessage = nil
    }

    private func loadMoreMyWaveBatch(playImmediately: Bool) {
        guard case .signedIn = status, let sessionID = myWaveSessionID,
              !myWaveTerminated, !isLoadingMyWaveBatch else { return }
        isLoadingMyWaveBatch = true
        let generation = myWaveGeneration
        let queue = myWaveQueueIdentifiers
        let pendingFeedback = myWaveFeedbackTask
        myWaveTask = Task {
            defer {
                if generation == myWaveGeneration { isLoadingMyWaveBatch = false }
            }
            do {
                await pendingFeedback?.value
                try Task.checkCancellation()
                guard let token = try await session.validAccessToken() else {
                    throw MusicExploreError.invalidToken
                }
                let batch = try await exploreProvider.nextMyWaveBatch(
                    sessionID: sessionID, queue: queue, accessToken: token
                )
                try Task.checkCancellation()
                guard generation == myWaveGeneration, myWaveSessionID == sessionID,
                      case .signedIn = status else { return }
                let known = Set(playQueue.map(\.id))
                let newTracks = batch.tracks.filter { !known.contains($0.id) }
                var seenQueueIDs = Set<String>()
                myWaveQueueIdentifiers = Array(
                    (myWaveQueueIdentifiers + batch.queueIdentifiers).filter {
                        seenQueueIDs.insert($0).inserted
                    }.suffix(100)
                )
                if let batchID = batch.batchID {
                    for track in newTracks { myWaveBatchByTrackID[track.id] = batchID }
                }
                myWaveTerminated = batch.terminated
                guard !newTracks.isEmpty else {
                    if playImmediately && batch.terminated {
                        myWaveMessage = "You've reached the end of this My Wave session."
                    }
                    return
                }
                let nextIndex = playQueue.count
                let currentTrackFinishedWhilePrefetching =
                    playback.status == .finished && currentQueueIndex == nextIndex - 1
                playQueue.append(contentsOf: newTracks)
                if playImmediately || currentTrackFinishedWhilePrefetching {
                    currentQueueIndex = nextIndex
                    loadTrack(playQueue[nextIndex])
                }
            } catch is CancellationError {
            } catch {
                guard generation == myWaveGeneration else { return }
                myWaveMessage = Self.exploreMessage(for: error)
            }
        }
    }

    private func sendMyWaveFeedback(
        _ event: MusicWaveFeedbackEvent,
        track: MusicSearchTrack? = nil,
        totalPlayedSeconds: Double? = nil
    ) {
        guard let sessionID = myWaveSessionID else { return }
        let generation = myWaveGeneration
        let batchID = track.flatMap { myWaveBatchByTrackID[$0.id] }
        let identifier = track?.radioQueueIdentifier
        let previousFeedback = myWaveFeedbackTask
        myWaveFeedbackTask = Task { [weak self] in
            await previousFeedback?.value
            guard let self, generation == self.myWaveGeneration,
                  self.myWaveSessionID == sessionID else { return }
            do {
                guard let token = try await self.session.validAccessToken() else { return }
                guard generation == self.myWaveGeneration,
                      self.myWaveSessionID == sessionID else { return }
                try await self.exploreProvider.sendFeedback(
                    sessionID: sessionID, event: event,
                    trackIdentifier: identifier, totalPlayedSeconds: totalPlayedSeconds,
                    batchID: batchID, accessToken: token
                )
            } catch {
                // Feedback is best-effort; playback must never depend on it.
            }
        }
    }

    private func myWaveTrackDidStart(_ track: MusicSearchTrack) {
        guard isMyWaveActive, myWaveSessionID != nil else { return }
        if !myWaveFeedbackStarted {
            sendMyWaveFeedback(.radioStarted)
            myWaveFeedbackStarted = true
        }
        sendMyWaveFeedback(.trackStarted, track: track)
    }

    private func advanceAfterWaveTrackFinished(_ track: MusicSearchTrack) {
        guard isMyWaveActive, myWaveSessionID != nil else {
            skipNext()
            return
        }
        sendMyWaveFeedback(
            .trackFinished, track: track,
            totalPlayedSeconds: max(playback.elapsedSeconds, playback.durationSeconds)
        )
        advanceQueueOrFetchWave()
    }

    private func advanceQueueOrFetchWave() {
        guard let index = currentQueueIndex else { return }
        if playQueue.indices.contains(index + 1) {
            currentQueueIndex = index + 1
            trimMyWaveQueueIfNeeded()
            guard let nextIndex = currentQueueIndex else { return }
            loadTrack(playQueue[nextIndex])
            if myWaveSessionID != nil && playQueue.count - nextIndex <= 3 {
                loadMoreMyWaveBatch(playImmediately: false)
            }
        } else if myWaveSessionID != nil && !myWaveTerminated {
            loadMoreMyWaveBatch(playImmediately: true)
        }
    }

    func resetSearch() {
        cancelSearch()
        previousSearchTracks = []
        previousArtistTracks = []
        searchResults = []
        artistResults = []
        albumResults = []
        artistAlbums = []
        selectedArtist = nil
        selectedAlbum = nil
        hasMoreArtistAlbums = false
        artistAlbumPage = 0
        searchStatus = .idle
    }

    func searchTracks(_ text: String) {
        guard case .signedIn = status else { return }
        cancelSearch()
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchResults = []
            searchStatus = .idle
            return
        }

        previousSearchTracks = []
        previousArtistTracks = []
        searchResults = []
        artistResults = []
        albumResults = []
        artistAlbums = []
        selectedArtist = nil
        selectedAlbum = nil
        searchStatus = .searching
        let generation = searchGeneration
        searchTask = Task {
            do {
                guard let token = try await session.validAccessToken() else {
                    throw MusicSearchError.invalidToken
                }
                let matches = try await searchProvider.tracks(matching: query, accessToken: token)
                try Task.checkCancellation()
                guard generation == searchGeneration, case .signedIn = status else { return }
                searchResults = matches
                searchStatus = .ready
            } catch is CancellationError {
                // A newer query or sign-out owns the visible search state.
            } catch {
                guard generation == searchGeneration, case .signedIn = status else { return }
                searchStatus = .failed(Self.searchMessage(for: error))
            }
        }
    }

    /// Unified read-only catalog search: artist, album and track matches.
    func searchAll(_ text: String) {
        guard case .signedIn = status else { return }
        resetSearch()
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        searchStatus = .searching
        let generation = searchGeneration
        searchTask = Task {
            do {
                guard let token = try await session.validAccessToken() else {
                    throw MusicSearchError.invalidToken
                }
                async let matchedArtists = searchProvider.artists(
                    matching: query, accessToken: token
                )
                async let matchedTracks = searchProvider.tracks(
                    matching: query, accessToken: token
                )
                async let matchedAlbums = searchProvider.albums(
                    matching: query, accessToken: token
                )
                let (artists, tracks, albums) = try await (
                    matchedArtists, matchedTracks, matchedAlbums
                )
                try Task.checkCancellation()
                guard generation == searchGeneration,
                      case .signedIn = status else { return }
                artistResults = artists
                albumResults = albums
                searchResults = tracks
                searchStatus = .ready
            } catch is CancellationError {
                // Superseded queries must never replace current results.
            } catch {
                guard generation == searchGeneration,
                      case .signedIn = status else { return }
                searchStatus = .failed(Self.searchMessage(for: error))
            }
        }
    }

    func searchArtists(_ text: String) {
        guard case .signedIn = status else { return }
        resetSearch()
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        searchStatus = .searching
        let generation = searchGeneration
        searchTask = Task {
            do {
                guard let token = try await session.validAccessToken() else {
                    throw MusicSearchError.invalidToken
                }
                let artists = try await searchProvider.artists(
                    matching: query, accessToken: token
                )
                try Task.checkCancellation()
                guard generation == searchGeneration,
                      case .signedIn = status else { return }
                artistResults = artists
                searchStatus = .ready
            } catch is CancellationError {
                // Superseded queries never overwrite the results.
            } catch {
                guard generation == searchGeneration,
                      case .signedIn = status else { return }
                searchStatus = .failed(Self.searchMessage(for: error))
            }
        }
    }

    func searchAlbums(_ text: String) {
        guard case .signedIn = status else { return }
        resetSearch()
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        searchStatus = .searching
        let generation = searchGeneration
        searchTask = Task {
            do {
                guard let token = try await session.validAccessToken() else {
                    throw MusicSearchError.invalidToken
                }
                let albums = try await searchProvider.albums(
                    matching: query, accessToken: token
                )
                try Task.checkCancellation()
                guard generation == searchGeneration,
                      case .signedIn = status else { return }
                albumResults = albums
                searchStatus = .ready
            } catch is CancellationError {
            } catch {
                guard generation == searchGeneration,
                      case .signedIn = status else { return }
                searchStatus = .failed(Self.searchMessage(for: error))
            }
        }
    }

    /// Artist page shows a short track selection AND its separate discography.
    func showTracks(for artist: MusicSearchArtist) {
        guard case .signedIn = status else { return }
        cancelSearch()
        if selectedArtist == nil && selectedAlbum == nil {
            previousSearchTracks = searchResults
        }
        previousArtistTracks = []
        searchResults = []
        artistAlbums = []
        hasMoreArtistAlbums = false
        artistAlbumPage = 0
        selectedAlbum = nil
        selectedArtist = artist
        searchStatus = .searching
        let generation = searchGeneration
        searchTask = Task {
            do {
                guard let token = try await session.validAccessToken() else {
                    throw MusicSearchError.invalidToken
                }
                async let popular = searchProvider.tracks(
                    forArtistID: artist.id, accessToken: token
                )
                async let discography = searchProvider.albums(
                    forArtistID: artist.id, accessToken: token
                )
                let (tracks, albums) = try await (popular, discography)
                try Task.checkCancellation()
                guard generation == searchGeneration,
                      selectedArtist?.id == artist.id,
                      selectedAlbum == nil,
                      case .signedIn = status else { return }
                searchResults = tracks
                artistAlbums = albums.albums
                hasMoreArtistAlbums = albums.hasMore
                searchStatus = .ready
            } catch is CancellationError {
            } catch {
                guard generation == searchGeneration,
                      selectedArtist?.id == artist.id,
                      selectedAlbum == nil,
                      case .signedIn = status else { return }
                searchStatus = .failed(Self.searchMessage(for: error))
            }
        }
    }

    func loadMoreArtistAlbums() {
        guard case .signedIn = status,
              let artist = selectedArtist,
              selectedAlbum == nil,
              hasMoreArtistAlbums,
              !isLoadingMoreArtistAlbums,
              artistAlbumPage < 100 else { return }
        isLoadingMoreArtistAlbums = true
        let nextPage = artistAlbumPage + 1
        let generation = searchGeneration
        albumLoadTask = Task {
            defer {
                if generation == searchGeneration { isLoadingMoreArtistAlbums = false }
            }
            do {
                guard let token = try await session.validAccessToken() else {
                    throw MusicSearchError.invalidToken
                }
                let page = try await searchProvider.albums(
                    forArtistID: artist.id, page: nextPage, accessToken: token
                )
                try Task.checkCancellation()
                guard generation == searchGeneration,
                      selectedArtist?.id == artist.id, selectedAlbum == nil else { return }
                let known = Set(artistAlbums.map(\.id))
                artistAlbums += page.albums.filter { !known.contains($0.id) }
                artistAlbumPage = nextPage
                hasMoreArtistAlbums = page.hasMore && !page.albums.isEmpty
            } catch {
                // Keep prior albums and allow an explicit retry.
            }
        }
    }

    func showAlbum(_ album: MusicSearchAlbum) {
        guard case .signedIn = status else { return }
        cancelSearch()
        if selectedArtist == nil && selectedAlbum == nil {
            previousSearchTracks = searchResults
        }
        if selectedArtist != nil && selectedAlbum == nil {
            previousArtistTracks = searchResults
        }
        searchResults = []
        selectedAlbum = album
        searchStatus = .searching
        let generation = searchGeneration
        searchTask = Task {
            do {
                guard let token = try await session.validAccessToken() else {
                    throw MusicSearchError.invalidToken
                }
                let tracks = try await searchProvider.tracks(
                    forAlbum: album, accessToken: token
                )
                try Task.checkCancellation()
                guard generation == searchGeneration,
                      selectedAlbum?.id == album.id,
                      case .signedIn = status else { return }
                searchResults = tracks
                searchStatus = .ready
            } catch is CancellationError {
            } catch {
                guard generation == searchGeneration,
                      selectedAlbum?.id == album.id,
                      case .signedIn = status else { return }
                searchStatus = .failed(Self.searchMessage(for: error))
            }
        }
    }

    func returnFromAlbum() {
        cancelSearch()
        selectedAlbum = nil
        if selectedArtist != nil {
            searchResults = previousArtistTracks
            previousArtistTracks = []
        } else {
            searchResults = previousSearchTracks
            previousSearchTracks = []
        }
        searchStatus = .ready
    }

    func returnToArtistResults() {
        if selectedAlbum != nil {
            returnFromAlbum()
            return
        }
        cancelSearch()
        selectedArtist = nil
        artistAlbums = []
        hasMoreArtistAlbums = false
        searchResults = previousSearchTracks
        previousSearchTracks = []
        searchStatus = .ready
    }

    private func trimMyWaveQueueIfNeeded() {
        guard isMyWaveActive, let index = currentQueueIndex, index > 50 else { return }
        let dropCount = index - 25
        guard dropCount > 0 else { return }
        playQueue.removeFirst(dropCount)
        currentQueueIndex = index - dropCount
        let retainedTrackIDs = Set(playQueue.map(\.id))
        myWaveBatchByTrackID = myWaveBatchByTrackID.filter {
            retainedTrackIDs.contains($0.key)
        }
    }

    func play(_ selected: MusicSearchTrack) {
        guard case .signedIn = status else { return }
        resetMyWaveSession()
        let results = searchResults
        playQueue = results.contains(where: { $0.id == selected.id }) ? results : [selected]
        currentQueueIndex = playQueue.firstIndex(where: { $0.id == selected.id })
        loadTrack(selected)
    }

    func skipNext() {
        guard case .signedIn = status, currentQueueIndex != nil else { return }
        if isMyWaveActive, let currentTrack {
            sendMyWaveFeedback(
                .skip, track: currentTrack,
                totalPlayedSeconds: playback.elapsedSeconds
            )
        }
        advanceQueueOrFetchWave()
    }

    func skipPrevious() {
        guard case .signedIn = status else { return }
        if playback.elapsedSeconds > 3 {
            playback.seek(to: 0)
            return
        }
        guard let index = currentQueueIndex,
              playQueue.indices.contains(index - 1) else { return }
        currentQueueIndex = index - 1
        loadTrack(playQueue[index - 1])
    }

    private func loadTrack(_ selected: MusicSearchTrack) {
        cancelSourceProbe()
        cancelPlayback()
        currentTrack = selected
        sourceProbe = .checking
        let generation = sourceProbeGeneration
        sourceProbeTask = Task {
            do {
                guard let token = try await session.validAccessToken() else {
                    throw MusicStreamError.invalidToken
                }
                let resolved = try await streamProvider.resolveTrack(
                    id: selected.id, accessToken: token
                )
                try Task.checkCancellation()
                guard sourceProbeGeneration == generation,
                      case .signedIn = status else { return }
                resolvedTrack = resolved
                sourceProbe = .verified(
                    resolved.metadata.title,
                    resolved.metadata.artists.joined(separator: ", ")
                )
                startPlayback(resolved)
            } catch is CancellationError {
                // A superseding selection owns the playback state.
            } catch {
                guard sourceProbeGeneration == generation,
                      case .signedIn = status else { return }
                sourceProbe = .failed(Self.streamMessage(for: error))
            }
        }
    }

    private func clearCatalog() {
        exploreTask?.cancel()
        exploreGeneration &+= 1
        recentTracks = []
        exploreStatus = .idle
        resetMyWaveSession()
        resetSearch()
        previousSearchTracks = []
        previousArtistTracks = []
        searchResults = []
        artistResults = []
        albumResults = []
        artistAlbums = []
        selectedArtist = nil
        selectedAlbum = nil
        searchStatus = .idle
        playQueue = []
        currentQueueIndex = nil
        currentTrack = nil
    }

    private func cancelSearch() {
        searchGeneration &+= 1
        searchTask?.cancel()
        searchTask = nil
        albumLoadTask?.cancel()
        albumLoadTask = nil
        isLoadingMoreArtistAlbums = false
    }

    private static func exploreMessage(for error: Error) -> String {
        guard let failure = error as? MusicExploreError else {
            return "Personal recommendations are temporarily unavailable."
        }
        switch failure {
        case .invalidToken, .unauthorized:
            return "Your Yandex Music session expired. Sign in again."
        case .forbidden:
            return "This account cannot access personal recommendations."
        case .rateLimited:
            return "Yandex Music is receiving too many requests. Try again later."
        case .invalidSession:
            return "The recommendation session expired. Start My Wave again."
        case .invalidResponse, .invalidPayload:
            return "Yandex Music returned an unexpected Explore response."
        case .httpStatus:
            return "Explore is temporarily unavailable. Check your connection."
        }
    }

    private static func searchMessage(for error: Error) -> String {
        guard let failure = error as? MusicSearchError else {
            return "Search is unavailable. Check your connection."
        }
        switch failure {
        case .invalidQuery: return "Enter a song or artist (up to 120 characters)."
        case .invalidToken, .unauthorized: return "Your session expired. Sign in again."
        case .forbidden: return "This account cannot search the music catalog."
        case .rateLimited: return "Too many searches. Try again later."
        case .invalidResponse, .invalidPayload: return "Search returned an unexpected response."
        case .httpStatus: return "Search is temporarily unavailable."
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
        playback.start(track, onStarted: { [weak self] in
            guard let self,
                  self.playbackOperationGeneration == operation,
                  self.sourceProbeGeneration == probe,
                  self.currentTrack?.id == trackID else { return }
            self.myWaveTrackDidStart(self.currentTrack ?? MusicSearchTrack(
                id: trackID, title: track.metadata.title,
                artists: track.metadata.artists,
                durationMilliseconds: track.metadata.durationMilliseconds
            ))
        }, onFinished: { [weak self] in
            guard let self,
                  self.playbackOperationGeneration == operation,
                  self.sourceProbeGeneration == probe,
                  self.currentTrack?.id == trackID,
                  let selected = self.currentTrack else { return }
            self.advanceAfterWaveTrackFinished(selected)
        }) { [weak self] in
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
            switch stage {
            case .trackMetadata:
                return "This recording is unavailable from the music catalog."
            case .rawAudioSource:
                return "This recording's audio is not available through the permitted raw stream. Try another recording."
            }
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
        if let keychain = error as? TokenStorageError {
            switch keychain {
            case .invalidStoredData:
                return "Saved Keychain session is unreadable. Sign in again if retry fails."
            case .keychainStatus:
                return "macOS denied access to your saved session. Retry and choose Always Allow in Keychain."
            }
        }
        return "Could not connect. Retry will keep your saved session; there is no need to sign in again."
    }
}
