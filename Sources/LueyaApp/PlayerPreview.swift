import AppKit
import ImageIO
import LueyaCore
import SwiftUI

/// The compact menu-bar player. No diagnostic track IDs or external-site buttons.
struct PlayerPreview: View {
    private enum SearchScope: String, CaseIterable {
        case songs = "Songs"
        case albums = "Albums"
        case artists = "Artists"
    }

    private enum Screen: Hashable {
        case explore
        case search
        case player
    }

    let signIn: MusicSignInModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var query = ""
    @State private var navigationPath: [Screen] = [.explore]
    @State private var searchScope: SearchScope = .songs
    @State private var searchDebounceTask: Task<Void, Never>?
    @FocusState private var searchFieldFocused: Bool
    @State private var draftSeekSeconds: Double?
    @State private var contentRevealed = false
    @State private var breathing = false

    private let ink = Color(red: 0.26, green: 0.23, blue: 0.21)
    private let secondary = Color(red: 0.47, green: 0.43, blue: 0.40)
    private let accent = Color(red: 0.62, green: 0.45, blue: 0.29)

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 20)

            Group {
                switch signIn.status {
                case .restoring:
                    statusLine("Restoring your listening space…", symbol: "clock")
                case .signedOut:
                    signedOutContent
                case .signingOut:
                    statusLine("Signing out…", symbol: "hourglass")
                case .requestingCode:
                    statusLine("Preparing a sign-in code…", symbol: "hourglass")
                case .awaitingAuthorization:
                    authorizationContent
                case .signedIn(let account):
                    signedInContent(account: account)
                case .failed(let message):
                    VStack(alignment: .leading, spacing: 13) {
                        statusLine(message, symbol: "info.circle")
                        Button("Retry") { signIn.retryFailure() }
                            .buttonStyle(QuietGlassButtonStyle(surface: .filled))
                        Button("Sign in again") { signIn.signIn() }
                            .buttonStyle(QuietGlassButtonStyle(surface: .text))
                    }
                }
            }
            .id(statusPhase)
            .transition(reduceMotion ? .identity :
                .opacity.combined(with: .scale(scale: 0.985)))
            .opacity(contentRevealed || reduceMotion ? 1 : 0)
            .offset(y: contentRevealed || reduceMotion ? 0 : 5)

            Spacer(minLength: 0)
            footer
                .padding(.top, 18)
        }
        .padding(21)
        // Keep the menu-bar panel's hit-testing bounds stable as search opens.
        .frame(width: 400, height: statusPhase == 3 ? 620 : nil, alignment: .top)
        .foregroundStyle(ink)
        .background { warmGlass }
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.light)
        .tint(accent)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.26), value: statusPhase)
        .task { await signIn.restoreIfNeeded() }
        .onAppear(perform: startMotion)
        .onDisappear {
            searchDebounceTask?.cancel()
            stopMotion()
        }
        .onChange(of: statusPhase) { _, phase in
            if phase != 3 {
                navigationPath = [.explore]
                query = ""
                searchFieldFocused = false
            }
        }
        .onChange(of: reduceMotion) { _, enabled in
            if enabled {
                stopMotion()
                contentRevealed = true
            } else {
                startMotion()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 9) {
            Image(systemName: "waveform.path")
                .font(.system(size: 17))
                .foregroundStyle(accent)
                .accessibilityHidden(true)
            Text("lueya")
                .font(.system(size: 19, weight: .medium, design: .rounded))
                .tracking(0.3)
            Spacer()
            Text("YOUR MUSIC, QUIETLY")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(secondary)
        }
    }

    private var signedOutContent: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(spacing: 17) {
                artwork(isPlaying: false)
                VStack(alignment: .leading, spacing: 6) {
                    Text("a softer way\nto listen.")
                        .font(.system(size: 21, weight: .medium, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Your listening space,\nwithout the noise.")
                        .font(.system(size: 11))
                        .foregroundStyle(secondary)
                }
                Spacer(minLength: 0)
            }
            Button {
                signIn.signIn()
            } label: {
                HStack {
                    Image(systemName: "person.crop.circle")
                    Text("Sign in with Yandex")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 14)
                .frame(height: 42)
            }
            .buttonStyle(QuietGlassButtonStyle(surface: .filled))
            .accessibilityHint("Authorize with your own Yandex account")
        }
    }

    @ViewBuilder
    private var authorizationContent: some View {
        if let code = signIn.code {
            VStack(alignment: .leading, spacing: 12) {
                Text("Enter this code on Yandex's sign-in page")
                    .font(.system(size: 12, weight: .medium))
                HStack(spacing: 10) {
                    Text(code.userCode)
                        .font(.system(size: 19, weight: .semibold, design: .monospaced))
                        .textSelection(.enabled)
                    Spacer()
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(code.userCode, forType: .string)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.system(size: 11, weight: .medium))
                            .padding(8)
                    }
                    .buttonStyle(QuietGlassButtonStyle(surface: .subtle))
                }
                Button {
                    guard YandexOAuthClient.isTrustedVerificationURL(code.verificationURL) else {
                        return
                    }
                    NSWorkspace.shared.open(code.verificationURL)
                } label: {
                    Label("Open sign-in page", systemImage: "arrow.up.right.square")
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                }
                .buttonStyle(QuietGlassButtonStyle(surface: .filled))
                Button("Cancel") { signIn.cancelSignIn() }
                    .font(.system(size: 11))
                    .buttonStyle(QuietGlassButtonStyle(surface: .text))
            }
        }
    }

    private var activeScreen: Screen {
        navigationPath.last ?? .explore
    }

    private func push(_ screen: Screen) {
        navigationPath.append(screen)
    }

    private func goBack() {
        searchFieldFocused = false
        if navigationPath.count > 1 {
            navigationPath.removeLast()
        } else {
            navigationPath = [.explore]
        }
    }

    private func openSearch() {
        push(.search)
    }

    private func signedInContent(account: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Group {
                switch activeScreen {
                case .explore:
                    explorePage
                case .search:
                    searchPage
                case .player:
                    playerPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if activeScreen == .search, signIn.currentTrack != nil {
                miniPlayer
            }

            Spacer(minLength: 5)
            divider
            HStack(spacing: 9) {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(accent)
                Text(account)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Sign out") {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                        signIn.signOut()
                    }
                }
                .buttonStyle(QuietGlassButtonStyle(surface: .text))
                .accessibilityHint("Remove the local Keychain session")
            }
            .font(.system(size: 11))
            .foregroundStyle(secondary)

            if let notice = signIn.sessionNotice {
                statusLine(notice, symbol: "wifi.exclamationmark")
                    .lineLimit(2)
            }
        }
        .frame(height: 478, alignment: .top)
    }

    private var explorePage: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("EXPLORE")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(secondary)
                Spacer()
            }

            Button(action: openSearch) {
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(secondary)
                    Text("Search songs, albums or artists")
                        .foregroundStyle(secondary)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .foregroundStyle(accent)
                }
                .font(.system(size: 12))
                .padding(.horizontal, 13)
                .frame(height: 42)
                .background(.white.opacity(0.58),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.white.opacity(0.76), lineWidth: 1)
                        .allowsHitTesting(false)
                }
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 15) {
                    if let track = signIn.currentTrack ?? signIn.recentTracks.first {
                        featuredTrackCard(track)
                    } else if signIn.exploreStatus == .loading {
                        HStack(spacing: 9) {
                            ProgressView().controlSize(.small)
                            Text("Finding your recent listening…")
                                .font(.system(size: 11))
                                .foregroundStyle(secondary)
                        }
                        .padding(.vertical, 10)
                    } else {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("A little room for music.")
                                .font(.system(size: 17, weight: .medium, design: .rounded))
                            Text("Your recent listening will appear here.")
                                .font(.system(size: 11))
                                .foregroundStyle(secondary)
                        }
                        .padding(.vertical, 5)
                    }

                    myWaveCard

                    if signIn.recentTracks.count > 1 {
                        VStack(alignment: .leading, spacing: 8) {
                            sectionHeading("RECENTLY PLAYED")
                            ForEach(Array(signIn.recentTracks.dropFirst().prefix(6))) { track in
                                recentTrackRow(track)
                            }
                        }
                    }

                    if case .failed(let message) = signIn.exploreStatus {
                        HStack(alignment: .center, spacing: 8) {
                            statusLine(message, symbol: "wifi.exclamationmark")
                            Spacer(minLength: 0)
                            Button {
                                signIn.refreshExplore()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11, weight: .medium))
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(QuietGlassButtonStyle(surface: .subtle))
                            .accessibilityLabel("Refresh Explore")
                        }
                    }
                }
                .padding(.bottom, 5)
            }
            .scrollIndicators(.visible)
        }
    }

    private func featuredTrackCard(_ track: MusicSearchTrack) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionHeading(signIn.currentTrack?.id == track.id &&
                signIn.playback.status == .playing ? "NOW PLAYING" : "LAST LISTENED")
            HStack(spacing: 13) {
                ArtworkThumbnail(url: track.coverURL, size: 82, symbol: "waveform")
                VStack(alignment: .leading, spacing: 5) {
                    Text(track.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .lineLimit(2)
                    Text(track.artistName)
                        .font(.system(size: 11))
                        .foregroundStyle(secondary)
                        .lineLimit(1)
                    if let album = track.album {
                        Text(album.title)
                            .font(.system(size: 10))
                            .foregroundStyle(secondary)
                            .lineLimit(1)
                    }
                    Button {
                        if signIn.currentTrack?.id == track.id {
                            signIn.playOrPause()
                        } else {
                            signIn.playRecent(track)
                        }
                    } label: {
                        Label(
                            signIn.currentTrack?.id == track.id &&
                                (signIn.playback.status == .playing ||
                                 signIn.playback.status == .connecting)
                                ? "Pause" : "Play again",
                            systemImage: signIn.currentTrack?.id == track.id &&
                                (signIn.playback.status == .playing ||
                                 signIn.playback.status == .connecting)
                                ? "pause.fill" : "play.fill"
                        )
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 9)
                        .frame(height: 27)
                    }
                    .buttonStyle(QuietGlassButtonStyle(surface: .filled))
                    .disabled(signIn.currentTrack?.id == track.id && !canPlay)
                }
                Spacer(minLength: 0)
            }
            .padding(11)
            .background(.white.opacity(0.40),
                        in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
    }

    private var myWaveCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 0.90, green: 0.81, blue: 0.70),
                            Color(red: 0.77, green: 0.64, blue: 0.52)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                Image(systemName: "waveform")
                    .font(.system(size: 27, weight: .light))
                    .foregroundStyle(Color(red: 0.36, green: 0.27, blue: 0.22))
            }
            .frame(width: 68, height: 68)

            VStack(alignment: .leading, spacing: 5) {
                Text("My Wave")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Text("Personal recommendations shaped by your listening.")
                    .font(.system(size: 10))
                    .foregroundStyle(secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    signIn.startMyWave()
                } label: {
                    HStack(spacing: 6) {
                        if signIn.isStartingMyWave {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "shuffle")
                        }
                        Text(signIn.isMyWaveActive ? "Start a fresh wave" : "Surprise me")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 9)
                    .frame(height: 27)
                }
                .buttonStyle(QuietGlassButtonStyle(surface: .filled))
                .disabled(signIn.isStartingMyWave)
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .background(.white.opacity(0.48),
                    in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .strokeBorder(.white.opacity(0.72), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottomLeading) {
            if let message = signIn.myWaveMessage {
                Text(message)
                    .font(.system(size: 9))
                    .foregroundStyle(secondary)
                    .padding(.horizontal, 12)
                    .offset(y: 16)
                    .lineLimit(1)
            }
        }
        .padding(.bottom, signIn.myWaveMessage == nil ? 0 : 10)
    }

    private func recentTrackRow(_ track: MusicSearchTrack) -> some View {
        Button {
            signIn.playRecent(track)
        } label: {
            HStack(spacing: 9) {
                ArtworkThumbnail(url: track.coverURL, size: 38, symbol: "music.note")
                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                    Text(track.artistName)
                        .font(.system(size: 10))
                        .foregroundStyle(secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 2)
                Image(systemName: "play.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(accent)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(QuietGlassButtonStyle(surface: .text))
    }

    private var searchPage: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button(action: goBack) {
                    Label("Back", systemImage: "chevron.left")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 8)
                        .frame(height: 27)
                }
                .buttonStyle(QuietGlassButtonStyle(surface: .subtle))
                Text("Search")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Spacer()
                if signIn.searchStatus == .searching {
                    ProgressView().controlSize(.mini)
                        .accessibilityLabel("Searching")
                }
            }

            if signIn.selectedAlbum != nil {
                albumDetail
            } else if signIn.selectedArtist != nil {
                artistDetail
            } else {
                searchField
                HStack(spacing: 7) {
                    ForEach(SearchScope.allCases, id: \.self) { scope in
                        Button(scope.rawValue) {
                            guard searchScope != scope else { return }
                            searchScope = scope
                            signIn.resetSearch()
                            performSearch()
                        }
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 12)
                        .frame(height: 29)
                        .buttonStyle(QuietGlassButtonStyle(
                            surface: searchScope == scope ? .filled : .text
                        ))
                    }
                    Spacer()
                }
                .accessibilityLabel("Search category")

                ScrollView(.vertical) {
                    searchResultsContent
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.vertical, 3)
                }
                .scrollIndicators(.visible)
            }
        }
        .onAppear {
            if signIn.selectedArtist == nil && signIn.selectedAlbum == nil {
                searchFieldFocused = true
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(secondary)
            TextField("Songs, albums, artists…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($searchFieldFocused)
                .onSubmit(performSearch)
                .onChange(of: query) { _, updated in
                    searchDebounceTask?.cancel()
                    signIn.resetSearch()
                    let term = updated.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !term.isEmpty else { return }
                    searchDebounceTask = Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(350))
                        guard !Task.isCancelled else { return }
                        performSearch()
                    }
                }
                .accessibilityLabel("Search songs, albums and artists")
            if !query.isEmpty {
                Button {
                    query = ""
                    searchFieldFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .frame(width: 29, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(secondary)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 7)
        .frame(height: 40)
        .background(.white.opacity(0.58),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.76), lineWidth: 1)
                .allowsHitTesting(false)
        }
    }

    private var searchResultsContent: some View {
        Group {
            switch signIn.searchStatus {
            case .idle:
                statusLine("Find a song, album or artist.", symbol: "sparkle.magnifyingglass")
            case .searching where resultCount == 0:
                statusLine("Searching the music catalog…", symbol: "magnifyingglass")
            case .failed(let message):
                VStack(alignment: .leading, spacing: 8) {
                    statusLine(message, symbol: "info.circle")
                    Button("Try again", action: performSearch)
                        .font(.system(size: 11, weight: .medium))
                        .buttonStyle(QuietGlassButtonStyle(surface: .text))
                }
            case .ready where resultCount == 0:
                statusLine("No matches. Try another search.", symbol: "magnifyingglass")
            default:
                switch searchScope {
                case .songs:
                    VStack(alignment: .leading, spacing: 5) {
                        sectionHeading("SONGS")
                        ForEach(signIn.searchResults) { track in songRow(track) }
                    }
                case .albums:
                    VStack(alignment: .leading, spacing: 7) {
                        sectionHeading("ALBUMS")
                        ForEach(signIn.albumResults) { album in albumRow(album) }
                    }
                case .artists:
                    VStack(alignment: .leading, spacing: 7) {
                        sectionHeading("ARTISTS")
                        ForEach(signIn.artistResults) { artist in artistRow(artist) }
                    }
                }
            }
        }
    }

    private var resultCount: Int {
        switch searchScope {
        case .songs: signIn.searchResults.count
        case .albums: signIn.albumResults.count
        case .artists: signIn.artistResults.count
        }
    }

    private var artistDetail: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 10) {
                navigationBack("Search results") { signIn.returnToArtistResults() }
                if let artist = signIn.selectedArtist {
                    HStack(spacing: 13) {
                        ArtworkThumbnail(url: artist.coverURL, size: 88, symbol: "person.crop.circle")
                        VStack(alignment: .leading, spacing: 5) {
                            Text(artist.name)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .lineLimit(2)
                            Text("Artist")
                                .font(.system(size: 11))
                                .foregroundStyle(secondary)
                        }
                    }
                }
                if !signIn.searchResults.isEmpty {
                    sectionHeading("POPULAR TRACKS")
                    ForEach(signIn.searchResults) { track in songRow(track) }
                }
                if !signIn.artistAlbums.isEmpty {
                    sectionHeading("ALBUMS & SINGLES")
                    ForEach(signIn.artistAlbums) { album in albumRow(album) }
                }
                if signIn.hasMoreArtistAlbums {
                    Button {
                        signIn.loadMoreArtistAlbums()
                    } label: {
                        HStack {
                            if signIn.isLoadingMoreArtistAlbums {
                                ProgressView().controlSize(.mini)
                            }
                            Text(signIn.isLoadingMoreArtistAlbums ? "Loading…" : "More albums")
                            Spacer()
                            Image(systemName: "arrow.down")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 9)
                        .frame(height: 32)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(signIn.isLoadingMoreArtistAlbums)
                }
                if signIn.searchStatus == .searching &&
                    signIn.searchResults.isEmpty && signIn.artistAlbums.isEmpty {
                    statusLine("Loading artist…", symbol: "hourglass")
                } else if case .failed(let message) = signIn.searchStatus {
                    statusLine(message, symbol: "info.circle")
                }
            }
            .padding(.vertical, 3)
        }
        .scrollIndicators(.visible)
    }

    private var albumDetail: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 10) {
                navigationBack(
                    signIn.selectedArtist == nil ? "Search results" : "Artist",
                    action: signIn.returnFromAlbum
                )
                if let album = signIn.selectedAlbum {
                    HStack(spacing: 13) {
                        ArtworkThumbnail(url: album.coverURL, size: 96, symbol: "square.stack")
                        VStack(alignment: .leading, spacing: 5) {
                            Text(album.title)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .lineLimit(3)
                            Text(album.artistName)
                                .font(.system(size: 11))
                                .foregroundStyle(secondary)
                            if let year = album.year {
                                Text(String(year))
                                    .font(.system(size: 10))
                                    .foregroundStyle(secondary)
                            }
                            Button {
                                signIn.playAll(signIn.searchResults)
                            } label: {
                                Label("Play album", systemImage: "play.fill")
                                    .font(.system(size: 10, weight: .medium))
                                    .padding(.horizontal, 9)
                                    .frame(height: 27)
                            }
                            .buttonStyle(QuietGlassButtonStyle(surface: .filled))
                            .disabled(signIn.searchResults.isEmpty)
                        }
                    }
                }
                sectionHeading("TRACKS")
                if signIn.searchStatus == .searching && signIn.searchResults.isEmpty {
                    statusLine("Loading album tracks…", symbol: "hourglass")
                } else if case .failed(let message) = signIn.searchStatus {
                    statusLine(message, symbol: "info.circle")
                } else if signIn.searchResults.isEmpty {
                    statusLine("No tracks are available for this album.", symbol: "music.note")
                } else {
                    ForEach(signIn.searchResults) { track in songRow(track) }
                }
            }
            .padding(.vertical, 3)
        }
        .scrollIndicators(.visible)
    }

    private func songRow(_ track: MusicSearchTrack) -> some View {
        Button {
            signIn.play(track)
        } label: {
            HStack(spacing: 9) {
                ArtworkThumbnail(url: track.coverURL, size: 38, symbol: "music.note")
                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                    Text(track.artistName)
                        .font(.system(size: 10))
                        .foregroundStyle(secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 3)
                Text(formattedMilliseconds(track.durationMilliseconds))
                    .font(.system(size: 10, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(secondary)
            }
            .padding(.horizontal, 7)
            .frame(maxWidth: .infinity, minHeight: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(QuietGlassButtonStyle(surface: .text))
        .accessibilityLabel("Play \(track.title) by \(track.artistName)")
    }

    private func albumRow(_ album: MusicSearchAlbum) -> some View {
        Button {
            signIn.showAlbum(album)
        } label: {
            HStack(spacing: 10) {
                ArtworkThumbnail(url: album.coverURL, size: 58, symbol: "square.stack")
                VStack(alignment: .leading, spacing: 4) {
                    Text(album.title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(2)
                    Text([album.artistName, album.year.map(String.init) ?? ""]
                        .filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.system(size: 10))
                        .foregroundStyle(secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 2)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(secondary)
            }
            .padding(.horizontal, 7)
            .frame(maxWidth: .infinity, minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(QuietGlassButtonStyle(surface: .text))
        .accessibilityLabel("Browse album \(album.title)")
    }

    private func artistRow(_ artist: MusicSearchArtist) -> some View {
        Button {
            signIn.showTracks(for: artist)
        } label: {
            HStack(spacing: 10) {
                ArtworkThumbnail(url: artist.coverURL, size: 58, symbol: "person.crop.circle")
                VStack(alignment: .leading, spacing: 4) {
                    Text(artist.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(2)
                    Text("Artist")
                        .font(.system(size: 10))
                        .foregroundStyle(secondary)
                }
                Spacer(minLength: 2)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(secondary)
            }
            .padding(.horizontal, 7)
            .frame(maxWidth: .infinity, minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(QuietGlassButtonStyle(surface: .text))
        .accessibilityLabel("Browse artist \(artist.name)")
    }

    private var miniPlayer: some View {
        HStack(spacing: 9) {
            Button {
                push(.player)
            } label: {
                HStack(spacing: 9) {
                    ArtworkThumbnail(url: signIn.currentTrack?.coverURL, size: 38, symbol: "waveform")
                    VStack(alignment: .leading, spacing: 3) {
                        Text(signIn.currentTrack?.title ?? "Nothing playing")
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                        Text(signIn.currentTrack?.artistName ?? "Open player")
                            .font(.system(size: 10))
                            .foregroundStyle(secondary)
                            .lineLimit(1)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer(minLength: 2)
            Button(action: signIn.playOrPause) {
                Image(systemName: playIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 31, height: 31)
            }
            .buttonStyle(QuietGlassButtonStyle(surface: .filled))
            .disabled(!canPlay)
            .accessibilityLabel(playLabel)
            Button(action: signIn.skipNext) {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 11))
                    .frame(width: 29, height: 29)
            }
            .buttonStyle(QuietGlassButtonStyle(surface: .subtle))
            .disabled(!signIn.canSkipNext)
            .accessibilityLabel("Next track")
        }
        .padding(8)
        .background(.white.opacity(0.42),
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private var playerPage: some View {
        VStack(alignment: .leading, spacing: 11) {
            Button(action: goBack) {
                Label("Back", systemImage: "chevron.left")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8)
                    .frame(height: 27)
            }
            .buttonStyle(QuietGlassButtonStyle(surface: .subtle))
            ScrollView(.vertical) {
                playerSection
                    .padding(.vertical, 3)
            }
            .scrollIndicators(.visible)
        }
    }

    private func navigationBack(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: "chevron.left")
                .font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 27, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(accent)
    }

    private func sectionHeading(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(secondary)
            .padding(.top, 3)
    }

    private var playerSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 15) {
                ArtworkThumbnail(
                    url: signIn.currentTrack?.coverURL, size: 78, symbol: "waveform"
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(signIn.currentTrack?.title ?? "Nothing playing")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .lineLimit(2)
                        .contentTransition(.opacity)
                    if let track = signIn.currentTrack {
                        Button {
                            if let artist = track.artist {
                                signIn.showTracks(for: artist)
                                openSearch()
                            } else {
                                // Without a trusted artist ID, let the listener
                                // choose a match instead of guessing an identity.
                                query = track.artistName
                                searchScope = .artists
                                openSearch()
                                performSearch()
                            }
                        } label: {
                            Text(track.artistName)
                                .font(.system(size: 11))
                                .foregroundStyle(accent)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Browse music by \(track.artistName)")

                        if let album = track.album {
                            Button {
                                signIn.showAlbum(album)
                                openSearch()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "square.stack")
                                        .font(.system(size: 9))
                                    Text(album.title)
                                        .lineLimit(1)
                                }
                                .font(.system(size: 10))
                                .foregroundStyle(accent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Browse album \(album.title)")
                        }
                    } else {
                        Text("Find something to listen to")
                            .font(.system(size: 11))
                            .foregroundStyle(secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.22),
                       value: signIn.currentTrack?.id)

            HStack(spacing: 7) {
                Text(formattedTime(signIn.playback.elapsedSeconds))
                Slider(
                    value: Binding(
                        get: {
                            draftSeekSeconds ?? min(
                                signIn.playback.elapsedSeconds,
                                max(0, signIn.playback.durationSeconds)
                            )
                        },
                        set: { draftSeekSeconds = $0 }
                    ),
                    in: 0...max(1, signIn.playback.durationSeconds),
                    onEditingChanged: { editing in
                        if !editing {
                            if let draftSeekSeconds {
                                signIn.seekPlayback(to: draftSeekSeconds)
                            }
                            draftSeekSeconds = nil
                        }
                    }
                )
                .controlSize(.small)
                .disabled(signIn.playback.durationSeconds <= 0 || playbackHasError)
                .accessibilityLabel("Playback position")
                Text(formattedTime(signIn.playback.durationSeconds))
            }
            .font(.system(size: 10, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(secondary)

            HStack(spacing: 12) {
                Spacer()
                Button(action: signIn.skipPrevious) {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 14))
                        .frame(width: 33, height: 33)
                }
                .buttonStyle(QuietGlassButtonStyle(surface: .subtle))
                .disabled(!signIn.canSkipPrevious)
                .accessibilityLabel("Previous track or restart")

                Button(action: signIn.playOrPause) {
                    Image(systemName: playIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 48, height: 40)
                }
                .buttonStyle(QuietGlassButtonStyle(surface: .filled))
                .disabled(!canPlay)
                .accessibilityLabel(playLabel)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: playIcon)

                Button(action: signIn.stopPlayback) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 12))
                        .frame(width: 33, height: 33)
                }
                .buttonStyle(QuietGlassButtonStyle(surface: .subtle))
                .disabled(signIn.playback.status == .idle)
                .accessibilityLabel("Stop playback")

                Button(action: signIn.skipNext) {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 14))
                        .frame(width: 33, height: 33)
                }
                .buttonStyle(QuietGlassButtonStyle(surface: .subtle))
                .disabled(!signIn.canSkipNext)
                .accessibilityLabel("Next track")
                Spacer()
            }

            HStack(spacing: 10) {
                Image(systemName: signIn.playback.volume == 0
                    ? "speaker.slash" : "speaker.wave.2")
                    .frame(width: 15)
                    .accessibilityHidden(true)
                Slider(
                    value: Binding(
                        get: { signIn.playback.volume },
                        set: { signIn.playback.setVolume($0) }
                    ),
                    in: 0...1
                )
                .controlSize(.mini)
                .accessibilityLabel("Volume")
            }
            .foregroundStyle(secondary)

            switch signIn.sourceProbe {
            case .checking:
                statusLine("Loading your track…", symbol: "hourglass")
            case .failed(let message):
                statusLine(message, symbol: "info.circle")
            default:
                EmptyView()
            }
            if case .failed(let message) = signIn.playback.status {
                statusLine(message, symbol: "info.circle")
            }
        }
    }

    private func performSearch() {
        searchDebounceTask?.cancel()
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            signIn.resetSearch()
            return
        }
        switch searchScope {
        case .songs: signIn.searchTracks(term)
        case .albums: signIn.searchAlbums(term)
        case .artists: signIn.searchArtists(term)
        }
    }

    private func artwork(isPlaying: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(
                    colors: [
                        .white.opacity(0.88),
                        Color(red: 0.89, green: 0.80, blue: 0.68).opacity(0.55)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(.white.opacity(0.83), lineWidth: 1)
                }
            Circle()
                .fill(accent.opacity(breathing && isPlaying && !reduceMotion ? 0.19 : 0.08))
                .blur(radius: 14)
                .frame(width: 63, height: 63)
            Circle()
                .strokeBorder(accent.opacity(0.20), lineWidth: 1)
                .frame(width: 51, height: 51)
                .scaleEffect(breathing && isPlaying && !reduceMotion ? 1.1 : 1)
            Image(systemName: "waveform")
                .font(.system(size: 23, weight: .ultraLight))
                .foregroundStyle(accent)
        }
        .frame(width: 78, height: 78)
        .accessibilityHidden(true)
    }

    private func statusLine(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 11))
            .foregroundStyle(secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func formattedTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let whole = Int(seconds)
        return "\(whole / 60):\(String(format: "%02d", whole % 60))"
    }

    private func formattedMilliseconds(_ value: Int?) -> String {
        guard let value, value >= 0 else { return "—" }
        return formattedTime(Double(value) / 1_000)
    }

    private var divider: some View {
        Rectangle()
            .fill(accent.opacity(0.15))
            .frame(height: 1)
            .accessibilityHidden(true)
    }

    private var footer: some View {
        HStack {
            Text("lueya v\(version)")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(secondary)
            Spacer()
            Button("Quit lueya") { NSApplication.shared.terminate(nil) }
                .font(.system(size: 10))
                .foregroundStyle(secondary)
                .buttonStyle(QuietGlassButtonStyle(surface: .text))
        }
    }

    /// Opaque warm base fills the native window corners, avoiding dark
    /// system-appearance wedges outside a custom rounded background.
    @ViewBuilder
    private var warmGlass: some View {
        Rectangle()
            .fill(Color(red: 0.965, green: 0.939, blue: 0.901))
            .overlay {
                if !reduceTransparency {
                    Rectangle().fill(.regularMaterial)
                }
            }
            .overlay {
                LinearGradient(
                    colors: [
                        Color(red: 1, green: 0.972, blue: 0.931).opacity(0.72),
                        Color(red: 0.939, green: 0.890, blue: 0.839).opacity(0.43),
                        Color(red: 0.990, green: 0.961, blue: 0.919).opacity(0.54)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(.white.opacity(0.75), lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }

    private func startMotion() {
        guard !reduceMotion else {
            contentRevealed = true
            return
        }
        withAnimation(.easeOut(duration: 0.40)) {
            contentRevealed = true
        }
        withAnimation(.easeInOut(duration: 3.8).repeatForever(autoreverses: true)) {
            breathing = true
        }
    }

    private func stopMotion() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            breathing = false
            contentRevealed = false
        }
    }
}

private struct ArtworkThumbnail: View {
    let url: URL?
    let size: CGFloat
    let symbol: String

    @State private var image: NSImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(LinearGradient(
                    colors: [
                        Color(red: 0.99, green: 0.96, blue: 0.91),
                        Color(red: 0.88, green: 0.80, blue: 0.70).opacity(0.72)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.30, weight: .light))
                    .foregroundStyle(Color(red: 0.62, green: 0.45, blue: 0.29))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .strokeBorder(.white.opacity(0.78), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .task(id: url) {
            image = await SafeArtworkLoader.load(url, maximumPixelSize: Int(size * 2.5))
        }
        .accessibilityHidden(true)
    }
}

@MainActor
private enum SafeArtworkLoader {
    static func load(_ url: URL?, maximumPixelSize: Int) async -> NSImage? {
        guard let url,
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme == "https", parts.host == "avatars.yandex.net",
              parts.port == nil, parts.user == nil, parts.password == nil,
              parts.query == nil, parts.fragment == nil,
              parts.path.hasPrefix("/get-music-content/") else { return nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(
            configuration: configuration, delegate: NoArtworkRedirects(), delegateQueue: nil
        )
        defer { session.invalidateAndCancel() }

        var request = URLRequest(
            url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8
        )
        request.httpMethod = "GET"
        do {
            let (data, response) = try await session.data(for: request)
            guard !Task.isCancelled,
                  let response = response as? HTTPURLResponse,
                  response.url == url, response.statusCode == 200,
                  ["image/jpeg", "image/png", "image/webp"].contains(response.mimeType ?? ""),
                  !data.isEmpty, data.count <= 400_000,
                  let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                    as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? Int,
                  let height = properties[kCGImagePropertyPixelHeight] as? Int,
                  width > 0, height > 0, width <= 1600, height <= 1600,
                  let image = CGImageSourceCreateThumbnailAtIndex(
                    source, 0, [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceThumbnailMaxPixelSize: max(48, maximumPixelSize)
                    ] as CFDictionary
                  ) else { return nil }
            return NSImage(cgImage: image, size: NSSize(width: CGFloat(width), height: CGFloat(height)))
        } catch {
            return nil
        }
    }
}

/// Restores the springy hover/press feedback from v0.4.1 for every button.
private struct QuietGlassButtonStyle: ButtonStyle {
    enum Surface {
        case filled
        case subtle
        case text
    }

    let surface: Surface
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(surfaceColor)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(
                        .white.opacity(surface == .text ? 0 : (hovered ? 0.90 : 0.65)),
                        lineWidth: 1
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            // Only press-feedback changes geometry; hover must not move hit targets.
            .scaleEffect(reduceMotion || !isEnabled ? 1 :
                (configuration.isPressed ? 0.98 : 1))
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.42)
            .shadow(
                color: Color(red: 0.62, green: 0.45, blue: 0.29)
                    .opacity(hovered && isEnabled ? 0.20 : 0),
                radius: hovered ? 9 : 0, x: 0, y: hovered ? 3 : 0
            )
            .animation(
                reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.76),
                value: configuration.isPressed
            )
            .animation(
                reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82),
                value: hovered
            )
            .onHover { hovered = isEnabled && $0 }
    }

    private var surfaceColor: Color {
        switch surface {
        case .filled:
            Color(red: 0.62, green: 0.45, blue: 0.29)
                .opacity(hovered && isEnabled ? 0.24 : 0.14)
        case .subtle:
            .white.opacity(hovered && isEnabled ? 0.88 : 0.47)
        case .text:
            Color(red: 0.62, green: 0.45, blue: 0.29)
                .opacity(hovered && isEnabled ? 0.15 : 0.01)
        }
    }
}

/// Never follow untrusted artwork URL redirects.
private final class NoArtworkRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession, task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        nil
    }
}
