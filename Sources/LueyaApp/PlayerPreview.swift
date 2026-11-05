import AppKit
import ImageIO
import LueyaCore
import SwiftUI

/// The compact menu-bar player. No diagnostic track IDs or external-site buttons.
struct PlayerPreview: View {
    private enum SearchScope: String, CaseIterable {
        case all = "All"
        case songs = "Songs"
        case artists = "Artists"
    }

    let signIn: MusicSignInModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var query = ""
    @State private var showingResults = false
    @State private var searchScope: SearchScope = .all
    @State private var coverImage: NSImage?
    @State private var searchDebounceTask: Task<Void, Never>?
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
        .frame(width: 382, height: statusPhase == 3 ? 454 : nil, alignment: .top)
        .foregroundStyle(ink)
        .background { warmGlass }
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.light)
        .tint(accent)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.26), value: statusPhase)
        .task { await signIn.restoreIfNeeded() }
        .task(id: signIn.currentTrack?.id) { await loadArtwork() }
        .onAppear(perform: startMotion)
        .onDisappear {
            searchDebounceTask?.cancel()
            stopMotion()
        }
        .onChange(of: statusPhase) { _, phase in
            if phase != 3 {
                showingResults = false
                query = ""
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

    private func signedInContent(account: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if showingResults {
                searchSection
            } else {
                playerSection
                divider
                searchSection
            }

            Spacer(minLength: 0)
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
        .frame(height: 331, alignment: .top)
    }

    private var playerSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 15) {
                if let coverImage {
                    Image(nsImage: coverImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 78, height: 78)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(.white.opacity(0.78), lineWidth: 1)
                        }
                        .accessibilityLabel("Album artwork")
                } else {
                    artwork(isPlaying: signIn.playback.status == .playing)
                        .frame(width: 78, height: 78)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(signIn.currentTrack?.title ?? "Nothing playing")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .lineLimit(2)
                        .contentTransition(.opacity)
                    Text(signIn.currentTrack?.artistName ?? "Find something to listen to")
                        .font(.system(size: 11))
                        .foregroundStyle(secondary)
                        .lineLimit(2)
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

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: showingResults ? 6 : 10) {
            HStack {
                if showingResults {
                    Button {
                        searchDebounceTask?.cancel()
                        showingResults = false
                    } label: {
                        Label("Player", systemImage: "chevron.left")
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 8)
                            .frame(height: 27)
                    }
                    .buttonStyle(QuietGlassButtonStyle(surface: .subtle))
                    .accessibilityLabel("Back to player")
                } else {
                    Text("EXPLORE")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(secondary)
                }
                Spacer()
                if signIn.searchStatus == .searching {
                    ProgressView().controlSize(.mini)
                        .accessibilityLabel("Searching")
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(secondary)
                TextField("Search music", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .onSubmit(performSearch)
                    .onChange(of: query) { _, updated in
                        searchDebounceTask?.cancel()
                        signIn.resetSearch()
                        let term = updated.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !term.isEmpty else {
                            showingResults = false
                            return
                        }
                        showingResults = true
                        searchDebounceTask = Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(350))
                            guard !Task.isCancelled else { return }
                            performSearch()
                        }
                    }
                    .accessibilityLabel("Search songs and artists")
                if !query.isEmpty {
                    Button {
                        query = ""
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

            if showingResults {
                HStack(spacing: 7) {
                    ForEach(SearchScope.allCases, id: \.self) { scope in
                        Button(scope.rawValue) {
                            guard searchScope != scope else { return }
                            searchScope = scope
                            signIn.resetSearch()
                            performSearch()
                        }
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .buttonStyle(QuietGlassButtonStyle(
                            surface: searchScope == scope ? .filled : .text
                        ))
                    }
                    Spacer()
                }
                .accessibilityLabel("Search category")
                searchResultsPane
            }
        }
    }

    /// A fixed-height scroll viewport keeps the surrounding MenuBarExtra
    /// frame unchanged. Plain, full-width rows do not animate their hit areas.
    private var searchResultsPane: some View {
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: 6) {
                if let artist = signIn.selectedArtist {
                    Button {
                        signIn.returnToArtistResults()
                    } label: {
                        Label("All artists", systemImage: "chevron.left")
                            .font(.system(size: 11, weight: .medium))
                            .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(accent)
                    Text(artist.name)
                        .font(.system(size: 12, weight: .semibold))
                }

                if signIn.searchStatus == .searching && displayedCount == 0 {
                    statusLine("Searching the music catalog…", symbol: "magnifyingglass")
                } else if case .failed(let message) = signIn.searchStatus {
                    statusLine(message, symbol: "info.circle")
                } else if displayedCount == 0 {
                    statusLine("No matches. Try another search.", symbol: "magnifyingglass")
                } else {
                    if shouldShowArtists && !signIn.artistResults.isEmpty {
                        resultHeading("ARTISTS")
                        ForEach(signIn.artistResults.prefix(searchScope == .all ? 3 : 20)) { artist in
                            Button {
                                signIn.showTracks(for: artist)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "person.crop.circle")
                                        .foregroundStyle(accent)
                                        .frame(width: 24)
                                    Text(artist.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .lineLimit(1)
                                    Spacer(minLength: 2)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10))
                                        .foregroundStyle(secondary)
                                }
                                .padding(.horizontal, 10)
                                .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                                .background(.white.opacity(0.44),
                                            in: RoundedRectangle(cornerRadius: 10))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Show tracks by \(artist.name)")
                        }
                    }
                    if shouldShowTracks && !signIn.searchResults.isEmpty {
                        resultHeading(signIn.selectedArtist == nil ? "SONGS" : "TRACKS")
                        ForEach(signIn.searchResults) { track in
                            Button {
                                signIn.play(track)
                                showingResults = false
                            } label: {
                                HStack(spacing: 9) {
                                    Image(systemName: signIn.currentTrack?.id == track.id
                                          ? "waveform" : "music.note")
                                        .font(.system(size: 12))
                                        .foregroundStyle(accent)
                                        .frame(width: 22)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(track.title)
                                            .font(.system(size: 12, weight: .medium))
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
                                .padding(.horizontal, 10)
                                .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                                .background(.white.opacity(0.44),
                                            in: RoundedRectangle(cornerRadius: 10))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Play \(track.title) by \(track.artistName)")
                        }
                    }
                }
            }
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollIndicators(.visible)
        .frame(height: 164)
        .accessibilityLabel("Search results")
    }

    private func resultHeading(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(secondary)
            .padding(.top, 5)
    }

    private var shouldShowArtists: Bool {
        signIn.selectedArtist == nil && searchScope != .songs
    }

    private var shouldShowTracks: Bool {
        signIn.selectedArtist != nil || searchScope != .artists
    }

    private var displayedCount: Int {
        (shouldShowArtists ? signIn.artistResults.count : 0)
            + (shouldShowTracks ? signIn.searchResults.count : 0)
    }

    private var statusPhase: Int {
        switch signIn.status {
        case .restoring: 0
        case .signedOut: 1
        case .requestingCode, .awaitingAuthorization: 2
        case .signedIn: 3
        case .signingOut: 4
        case .failed: 5
        }
    }

    private var playIcon: String {
        switch signIn.playback.status {
        case .playing, .connecting: return "pause.fill"
        default: return "play.fill"
        }
    }

    private var playLabel: String {
        switch signIn.playback.status {
        case .playing, .connecting: return "Pause"
        case .paused: return "Resume"
        case .finished: return "Replay"
        default: return "Play"
        }
    }

    private var canPlay: Bool {
        guard signIn.currentTrack != nil else { return false }
        if case .verified = signIn.sourceProbe { return true }
        return false
    }

    private var playbackHasError: Bool {
        if case .failed = signIn.playback.status { return true }
        return signIn.playback.status == .idle
    }

    private func performSearch() {
        searchDebounceTask?.cancel()
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showingResults = false
            signIn.resetSearch()
            return
        }
        showingResults = true
        switch searchScope {
        case .all: signIn.searchAll(query)
        case .songs: signIn.searchTracks(query)
        case .artists: signIn.searchArtists(query)
        }
    }

    /// Public thumbnail only. Ephemeral session, no redirects, cookies or disk cache.
    private func loadArtwork() async {
        coverImage = nil
        guard let url = signIn.currentTrack?.coverURL else { return }
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
                        kCGImageSourceThumbnailMaxPixelSize: 220
                    ] as CFDictionary
                  ) else { return }
            coverImage = NSImage(cgImage: image, size: NSSize(width: 80, height: 80))
        } catch {
            // Artwork is optional and never prevents track playback.
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
