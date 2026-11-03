import AppKit
import LueyaCore
import SwiftUI
import WebKit

struct EmbedProbeView: View {
    @State private var userConsentedToLoad = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Official shared-track embed")
                .font(.title3.weight(.semibold))

            Text(
                "A separate technical test using Yandex's documented share embed. " +
                "It is not an authenticated music player."
            )
            .font(.callout)
            .foregroundStyle(.secondary)

            if userConsentedToLoad {
                OfficialTrackWebView()
                    .frame(minHeight: 190)
                    .accessibilityLabel("Official Yandex Music shared-track player")
            } else {
                ContentUnavailableView(
                    "Network access is off",
                    systemImage: "waveform",
                    description: Text(
                        "Nothing is loaded until you explicitly start the test."
                    )
                )
                .frame(maxHeight: .infinity)

                Button("Load official shared track") {
                    userConsentedToLoad = true
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint(
                    "Opens a published sample using ephemeral WebKit storage"
                )
            }

            HStack {
                Text("No login, no token capture, no persistent website data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Quit probe") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(22)
        .frame(minWidth: 520, minHeight: 320)
    }
}

private struct OfficialTrackWebView: NSViewRepresentable {
    func makeCoordinator() -> NavigationGate {
        NavigationGate()
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator

        let target = OfficialSharedEmbed.documentedExample
        if OfficialSharedEmbed.allowsNavigation(to: target) {
            let request = URLRequest(
                url: target,
                cachePolicy: .reloadIgnoringLocalCacheData
            )
            webView.load(request)
        }

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    final class NavigationGate: NSObject, WKNavigationDelegate {
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.targetFrame?.isMainFrame == false {
                decisionHandler(.allow)
                return
            }

            guard let url = navigationAction.request.url,
                  OfficialSharedEmbed.allowsNavigation(to: url) else {
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }
    }
}
