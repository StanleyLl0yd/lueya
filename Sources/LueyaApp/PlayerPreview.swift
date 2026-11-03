import AppKit
import LueyaCore
import SwiftUI

struct PlayerPreview: View {
    let signIn: MusicSignInModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var probeTrackID = ""
    @State private var openHovered = false
    @State private var checkHovered = false

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
                    .fill(accent.opacity(0.09))
                    .blur(radius: 15)
                    .frame(width: 70, height: 70)

                Circle()
                    .strokeBorder(accent.opacity(0.28), lineWidth: 1)
                    .frame(width: 72, height: 72)

                Circle()
                    .fill(.white.opacity(0.42))
                    .frame(width: 51, height: 51)

                Image(systemName: "waveform")
                    .font(.system(size: 24, weight: .ultraLight))
                    .foregroundStyle(accent)
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
                .scaleEffect(openHovered && !reduceMotion ? 1.008 : 1)
            }
            .buttonStyle(.plain)
            .onHover { openHovered = $0 }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: openHovered)
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
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: checkHovered)
                    .accessibilityHint("Checks streaming source availability without playing audio")
                }

                sourceResult

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
