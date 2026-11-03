import AppKit
import LueyaCore
import SwiftUI

struct PlayerPreview: View {
    let signIn: MusicSignInModel
    @State private var probeTrackID = ""

    private let ivory = Color(red: 0.96, green: 0.91, blue: 0.85)
    private let muted = Color(red: 0.74, green: 0.70, blue: 0.70)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 9) {
                Image(systemName: "waveform.path")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(ivory)
                    .accessibilityHidden(true)
                Text("lueya")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(.white)
                Spacer()
                Text("PREVIEW")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(muted)
            }

            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.white.opacity(0.08))
                    Circle()
                        .stroke(ivory.opacity(0.32), lineWidth: 1)
                        .padding(14)
                    Circle()
                        .fill(ivory.opacity(0.12))
                        .padding(25)
                    Image(systemName: "waveform")
                        .font(.system(size: 26, weight: .ultraLight))
                        .foregroundStyle(ivory)
                }
                .frame(width: 100, height: 100)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 7) {
                    Text("a softer way\nto listen.")
                        .font(.system(size: 19, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Your listening space,\nwithout the noise.")
                        .font(.system(size: 11))
                        .foregroundStyle(muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Rectangle()
                .fill(.white.opacity(0.14))
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 12) {
                Label("Playback integration is being evaluated", systemImage: "sparkle")
                    .font(.system(size: 11))
                    .foregroundStyle(muted)

                Button {
                    let destination = OfficialMusicSite.home
                    guard OfficialMusicSite.isTrusted(destination) else { return }
                    NSWorkspace.shared.open(destination)
                } label: {
                    HStack {
                        Image(systemName: "arrow.up.right")
                        Text("Open official Yandex Music")
                        Spacer()
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ivory)
                    .padding(12)
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the official website in your default browser")
            }

            Rectangle()
                .fill(.white.opacity(0.14))
                .frame(height: 1)

            signInControls

            HStack {
                Text("M0 · authenticated API research")
                    .font(.system(size: 10))
                    .foregroundStyle(muted.opacity(0.85))
                Spacer()
                Button("Quit lueya") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.system(size: 10))
                .foregroundStyle(muted)
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(width: 328)
        .background {
            ZStack {
                Color(red: 0.14, green: 0.15, blue: 0.19)
                LinearGradient(
                    colors: [ivory.opacity(0.12), .clear, Color.purple.opacity(0.09)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Rectangle().fill(.ultraThinMaterial).opacity(0.17)
            }
        }
        .task {
            await signIn.restoreIfNeeded()
        }
    }

    @ViewBuilder
    private var signInControls: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Yandex Music account")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ivory)

            switch signIn.status {
            case .restoring:
                Label("Checking local session…", systemImage: "clock")
                    .font(.system(size: 11))
                    .foregroundStyle(muted)
            case .signedOut:
                Button("Sign in with Yandex") { signIn.signIn() }
                    .font(.system(size: 12))
            case .requestingCode:
                Label("Requesting a sign-in code…", systemImage: "hourglass")
                    .font(.system(size: 11))
                    .foregroundStyle(muted)
            case .awaitingAuthorization:
                if let code = signIn.code {
                    Text("Enter this code on Yandex's sign-in page:")
                        .font(.system(size: 11))
                        .foregroundStyle(muted)
                    HStack {
                        Text(code.userCode)
                            .font(.system(size: 17, weight: .semibold, design: .monospaced))
                            .textSelection(.enabled)
                            .foregroundStyle(ivory)
                        Spacer()
                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(code.userCode, forType: .string)
                        }
                        .font(.system(size: 11))
                    }
                    Button("Open Yandex authorization page") {
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
                Label("Signed in: \(account)", systemImage: "checkmark.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(ivory)
                Text("Check a track's authorized raw source (no audio yet):")
                    .font(.system(size: 10))
                    .foregroundStyle(muted)
                HStack(spacing: 8) {
                    TextField("Numeric track ID", text: $probeTrackID)
                        .font(.system(size: 11))
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Numeric Yandex Music track ID")
                        .onSubmit { signIn.checkStreamSource(trackID: probeTrackID) }
                    Button("Check") {
                        signIn.checkStreamSource(trackID: probeTrackID)
                    }
                    .font(.system(size: 11))
                    .disabled(probeTrackID.isEmpty)
                    .accessibilityHint("Checks a raw streaming source without playing audio")
                }

                switch signIn.sourceProbe {
                case .idle:
                    EmptyView()
                case .checking:
                    Label("Checking source…", systemImage: "hourglass")
                        .font(.system(size: 10))
                        .foregroundStyle(muted)
                case .verified(let title, let detail):
                    Text(title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ivory)
                        .lineLimit(2)
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundStyle(muted)
                        .fixedSize(horizontal: false, vertical: true)
                case .failed(let message):
                    Label(message, systemImage: "exclamationmark.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button("Sign out") { signIn.signOut() }
                    .font(.system(size: 11))
            case .failed(let message):
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(muted)
                Button("Try sign-in again") { signIn.signIn() }
                    .font(.system(size: 11))
            }
        }
        .buttonStyle(.plain)
    }
}
