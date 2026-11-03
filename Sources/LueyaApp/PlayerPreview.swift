import AppKit
import LueyaCore
import SwiftUI

struct PlayerPreview: View {
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

            HStack {
                Text("M0 · feasibility")
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
    }
}
