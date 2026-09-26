#if canImport(WebKit)
import WebKit

/// Lets YouTube run its normal browser session-maintenance code, including
/// JavaScript/redirect-based renewal that a native HTTP request cannot execute.
@MainActor
final class YTSessionWebRefresher: NSObject, WKNavigationDelegate {
    private let webView: WKWebView
    private var completion: CheckedContinuation<Void, Error>?
    private var timeout: Task<Void, Never>?

    init(dataStore: WKWebsiteDataStore) {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = dataStore
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
    }

    func refresh() async throws {
        guard completion == nil else { throw URLError(.cancelled) }
        guard let url = URL(string: "https://www.youtube.com/feed/history") else { throw URLError(.badURL) }
        try await withCheckedThrowingContinuation { continuation in
            completion = continuation
            timeout = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(20)) } catch { return }
                self?.finish(.failure(URLError(.timedOut)))
            }
            webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData))
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finish(.success(()))
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(.failure(error))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish(.failure(error))
    }

    private func finish(_ result: Result<Void, Error>) {
        guard let completion else { return }
        self.completion = nil
        timeout?.cancel()
        timeout = nil
        if case .failure = result { webView.stopLoading() }
        completion.resume(with: result)
    }
}
#endif
