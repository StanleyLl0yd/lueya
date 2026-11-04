import AppKit
import LueyaCore
import SwiftUI

struct PlayerPreview: View {
    let signIn: MusicSignInModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var probeTrackID = ""
    @State private var draftSeekSeconds: Double?
    @State private var openHovered = false
    @State private var checkHovered = false
    @State private var contentRevealed = false
    @State private var heroBreathing = false

    private let ink = Color(red: 0.26, green: 0.23, blue: 0.21)
    private let secondary = Color(red: 0.47, green: 0.43, blue: 0.40)
    private let accent = Color(red: 0.62, green: 0.45, blue: 0.29)
    private let rim = Color.white.opacity(0.78)

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            hero
                .padding(.top, 24)
                .opacity(contentRevealed || reduceMotion ? 1 : 0)
                .offset(y: contentRevealed || reduceMotion ? 0 : 7)

            divider
                .padding(.vertical, 23)

            listeningSection

            divider
                .padding(.vertical, 22)

            accountSection

            footer
                .padding(.top, 23)
        }
        .padding(22)
        .frame(width: 366)
        .foregroundStyle(ink)
        .background { warmGlass }
        .environment(\.colorScheme, .light)
        .tint(accent)
        .task { await signIn.restoreIfNeeded() }
        .onAppear(perform: startMotion)
        .onDisappear(perform: stopMotion)
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
        HStack(alignment: .center, spacing: 9) {
            Image(systemName: "waveform.path")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(accent)
                .accessibilityHidden(true)

            Text("lueya")
                .font(.system(size: 19, weight: .medium, design: .rounded))
                .tracking(0.3)

            Spacer()

            Text("EARLY ACCESS")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var hero: some View {
        HStack(alignment: .center, spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.86),
                                Color(red: 0.89, green: 0.80, blue: 0.68).opacity(0.54)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(rim, lineWidth: 1)
                    }

                Circle()
                    .fill(accent.opacity(heroBreathing && !reduceMotion ? 0.16 : 0.09))
                    .blur(radius: heroBreathing && !reduceMotion ? 19 : 13)
                    .frame(width: 70, height: 70)
                    .scaleEffect(heroBreathing && !reduceMotion ? 1.09 : 0.95)

                Circle()
                    .strokeBorder(accent.opacity(heroBreathing && !reduceMotion ? 0.38 : 0.24), lineWidth: 1)
                    .frame(width: 72, height: 72)
                    .scaleEffect(heroBreathing && !reduceMotion ? 1.06 : 0.96)

                Circle()
                    .fill(.white.opacity(0.42))
                    .frame(width: 51, height: 51)

                Image(systemName: "waveform")
                    .font(.system(size: 24, weight: .ultraLight))
                    .foregroundStyle(accent)
                    .scaleEffect(heroBreathing && !reduceMotion ? 1.06 : 0.96)
            }
            .frame(width: 96, height: 96)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 7) {
                Text("a softer way\nto listen.")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .tracking(-0.4)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Your listening space,\nwithout the noise.")
                    .font(.system(size: 11))
                    .foregroundStyle(secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var listeningSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Online playback is in development", systemImage: "sparkle")
                .font(.system(size: 11))
                .foregroundStyle(secondary)

            Button {
                let destination = OfficialMusicSite.home
                guard OfficialMusicSite.isTrusted(destination) else { return }
                NSWorkspace.shared.open(destination)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .medium))
                    Text("Open Yandex Music")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(secondary)
                }
                .foregroundStyle(ink)
                .padding(.horizontal, 14)
                .frame(height: 43)
                .background(
                    .white.opacity(openHovered ? 0.78 : 0.50),
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(rim.opacity(0.95), lineWidth: 1)
                }
                .scaleEffect(openHovered && !reduceMotion ? 1.016 : 1)
                .offset(y: openHovered && !reduceMotion ? -1 : 0)
            }
            .buttonStyle(.plain)
            .onHover { openHovered = $0 }
            .animation(
                reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.82),
                value: openHovered
            )
            .accessibilityHint("Opens the official Yandex Music website in your default browser")
        }
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR ACCOUNT")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.35)
                .foregroundStyle(secondary)

            accountControls
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.25),
            value: sourcePhase
        )
    }

    @ViewBuilder
    private var accountControls: some View {
        switch signIn.status {
        case .restoring:
            stateLabel("Restoring your session…", icon: "clock")
        case .signedOut:
            Button("Sign in with Yandex") { signIn.signIn() }
                .font(.system(size: 12, weight: .medium))
        case .requestingCode:
            stateLabel("Requesting a sign-in code…", icon: "hourglass")
        case .awaitingAuthorization:
            if let code = signIn.code {
                Text("Enter this code on Yandex's sign-in page:")
                    .font(.system(size: 11))
                    .foregroundStyle(secondary)

                HStack {
                    Text(code.userCode)
                        .font(.system(size: 17, weight: .semibold, design: .monospaced))
                        .textSelection(.enabled)
                    Spacer()
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(code.userCode, forType: .string)
                    }
                    .font(.system(size: 11))
                }

                Button("Open authorization page") {
                    guard YandexOAuthClient.isTrustedVerificationURL(code.verificationURL) else {
                        return
                    }
                    NSWorkspace.shared.open(code.verificationURL)
                }
                .font(.system(size: 11))

                Button("Cancel") { signIn.cancelSignIn() }
                    .font(.system(size: 11))
            }
        case .signedIn(let account):
            VStack(alignment: .leading, spacing: 11) {
                Label("Signed in: \(account)", systemImage: "checkmark.circle")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ink)
                    .lineLimit(2)

                Text("Check an authorized track source (no audio yet)")
                    .font(.system(size: 11))
                    .foregroundStyle(secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 9) {
                    TextField("Numeric track ID", text: $probeTrackID)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .padding(.horizontal, 11)
                        .frame(height: 36)
                        .background(
                            .white.opacity(0.66),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(accent.opacity(0.17), lineWidth: 1)
                        }
                        .accessibilityLabel("Numeric Yandex Music track ID")
                        .onSubmit { signIn.checkStreamSource(trackID: probeTrackID) }

                    Button {
                        signIn.checkStreamSource(trackID: probeTrackID)
                    } label: {
                        Text("Check")
                            .font(.system(size: 12, weight: .medium))
                            .frame(minWidth: 43, minHeight: 36)
                            .padding(.horizontal, 8)
                            .background(
                                accent.opacity(checkHovered ? 0.18 : 0.09),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(probeTrackID.isEmpty)
                    .onHover { checkHovered = $0 }
                    .scaleEffect(checkHovered && !reduceMotion ? 1.035 : 1)
                    .offset(y: checkHovered && !reduceMotion ? -1 : 0)
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.8),
                        value: checkHovered
                    )
                    .accessibilityHint("Checks streaming source availability without playing audio")
                }

                sourceResult
                playbackControls

                Button("Sign out") { signIn.signOut() }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(secondary)
                    .padding(.top, 2)
            }
        case .failed(let message):
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Try sign-in again") { signIn.signIn() }
                .font(.system(size: 11, weight: .medium))
        }
    }

    @ViewBuilder
    private var sourceResult: some View {
        switch signIn.sourceProbe {
        case .idle:
            EmptyView()
        case .checking:
            stateLabel("Checking source…", icon: "hourglass")
        case .verified(let title, let detail):
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(2)
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 1)
        case .failed(let message):
            stateLabel(message, icon: "info.circle")
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var playbackControls: some View {
        if case .verified = signIn.sourceProbe {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 9) {
                    Button {
                        signIn.playOrPause()
                    } label: {
                        Label(playActionLabel, systemImage: playActionIcon)
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(
                                accent.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Experimental online playback with your authorized account")

                    if signIn.playback.status != .idle {
                        Button {
                            signIn.stopPlayback()
                        } label: {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 11))
                                .frame(width: 32, height: 32)
                                .background(
                                    .white.opacity(0.48),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Stop playback")
                    }

                    Spacer()

                    Text("\(formattedTime(signIn.playback.elapsedSeconds)) / \(formattedTime(signIn.playback.durationSeconds))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(secondary)
                        .monospacedDigit()
                }

                if signIn.playback.durationSeconds > 0,
                   signIn.playback.status != .idle {
                    Slider(
                        value: Binding(
                            get: {
                                draftSeekSeconds ?? min(
                                    signIn.playback.elapsedSeconds,
                                    signIn.playback.durationSeconds
                                )
                            },
                            set: { draftSeekSeconds = $0 }
                        ),
                        in: 0...signIn.playback.durationSeconds,
                        onEditingChanged: { editing in
                            if !editing {
                                if let draftSeekSeconds {
                                    signIn.seekPlayback(to: draftSeekSeconds)
                                }
                                draftSeekSeconds = nil
                            }
                        }
                    )
                    .controlSize(.mini)
                    .disabled(playbackHasError)
                    .accessibilityLabel("Playback position")
                }

                if case .failed(let message) = signIn.playback.status {
                    stateLabel(message, icon: "info.circle")
                }
                Text("Online playback is experimental; full-track delivery is not yet verified.")
                    .font(.system(size: 10))
                    .foregroundStyle(secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
        }
    }

    private var playbackHasError: Bool {
        if case .failed = signIn.playback.status { return true }
        return false
    }

    private var playActionLabel: String {
        switch signIn.playback.status {
        case .connecting, .playing: "Pause"
        case .paused: "Resume"
        case .finished: "Replay"
        case .failed: "Try again"
        case .idle: "Play"
        }
    }

    private var playActionIcon: String {
        switch signIn.playback.status {
        case .connecting, .playing: "pause.fill"
        default: "play.fill"
        }
    }

    private func formattedTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let rounded = Int(seconds)
        return "\(rounded / 60):\(String(format: "%02d", rounded % 60))"
    }

    private var sourcePhase: Int {
        switch signIn.sourceProbe {
        case .idle: 0
        case .checking: 1
        case .verified: 2
        case .failed: 3
        }
    }

    private func startMotion() {
        guard !reduceMotion else {
            contentRevealed = true
            return
        }

        // One entrance, then a quiet, low-frequency pulse while the panel is visible.
        withAnimation(.easeOut(duration: 0.46)) {
            contentRevealed = true
        }
        withAnimation(.easeInOut(duration: 3.7).repeatForever(autoreverses: true)) {
            heroBreathing = true
        }
    }

    private func stopMotion() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            heroBreathing = false
            contentRevealed = false
        }
    }

    private func stateLabel(_ value: String, icon: String) -> some View {
        Label(value, systemImage: icon)
            .font(.system(size: 11))
            .foregroundStyle(secondary)
            .labelStyle(.titleAndIcon)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var divider: some View {
        Rectangle()
            .fill(accent.opacity(0.16))
            .frame(height: 1)
            .accessibilityHidden(true)
    }

    private var footer: some View {
        HStack(spacing: 7) {
            Text("lueya v\(version)")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(secondary)

            Spacer()

            Button("Quit lueya") { NSApplication.shared.terminate(nil) }
                .font(.system(size: 10))
                .foregroundStyle(secondary)
                .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var warmGlass: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

        ZStack {
            if reduceTransparency {
                shape.fill(Color(red: 0.965, green: 0.939, blue: 0.901))
            } else {
                shape.fill(.regularMaterial)
            }

            shape.fill(
                LinearGradient(
                    colors: [
                        Color(red: 1, green: 0.972, blue: 0.931).opacity(0.72),
                        Color(red: 0.939, green: 0.890, blue: 0.839).opacity(0.43),
                        Color(red: 0.990, green: 0.961, blue: 0.919).opacity(0.54)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            shape.strokeBorder(.white.opacity(0.75), lineWidth: 1)
        }
        .clipShape(shape)
        .shadow(color: accent.opacity(0.11), radius: 25, x: 0, y: 12)
    }
}
