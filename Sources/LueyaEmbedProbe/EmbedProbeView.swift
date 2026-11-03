import AppKit
import LueyaCore
import SwiftUI
import WebKit

struct EmbedProbeView: View {
    @State private var userConsentedToLoad = false
    @State private var webErrorMessage: String?

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
                OfficialTrackWebView(errorMessage: $webErrorMessage)
                    .frame(minHeight: 190)
                    .accessibilityLabel("Official Yandex Music shared-track player")

                if let webErrorMessage {
                    Label(webErrorMessage, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
    @Binding var errorMessage: String?

    func makeCoordinator() -> NavigationGate {
        NavigationGate(errorMessage: $errorMessage)
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

    @MainActor
    final class NavigationGate: NSObject, WKNavigationDelegate {
        private let errorMessage: Binding<String?>

        init(errorMessage: Binding<String?>) {
            self.errorMessage = errorMessage
        }

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

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            showLoadFailure(error)
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            showLoadFailure(error)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            errorMessage.wrappedValue =
                "The embedded player stopped unexpectedly. Reopen the probe to retry."
        }

        private func showLoadFailure(_ error: Error) {
            let error = error as NSError
            if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
                return
            }
            errorMessage.wrappedValue =
                "The official track could not be loaded. Check your connection or regional availability."
        }
    }
}
