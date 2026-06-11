//
//  YTCookieSignInView.swift
//  Cathode
//
//  Presents YouTube's sign-in flow inside a SwiftUI `WebView`. After the user
//  logs in, the session cookies land in `WKWebsiteDataStore.default()` — the
//  same store YouTubePlayerKit uses — so iframe playback becomes logged-in
//  automatically and `YTCookieAuth` can mint SAPISIDHASH headers for native
//  /player calls.
//
//  A `WKHTTPCookieStoreObserver` watches the data store and dismisses the
//  sheet the moment SAPISID arrives, instead of polling on each navigation.
//

#if !os(tvOS)
import SwiftUI
import WebKit

private let signInURL = URL(string: "https://accounts.google.com/ServiceLogin?service=youtube&continue=https%3A%2F%2Fwww.youtube.com%2F")!

struct YTCookieSignInView: View {
    @Environment(\.dismiss) private var dismiss
    private let auth = YTCookieAuth.shared

    @State private var page: WebPage
    @State private var dataStore: WKWebsiteDataStore
    @State private var observer = YTCookieObserver()

    init() {
        let store = WKWebsiteDataStore.default()
        var config = WebPage.Configuration()
        config.websiteDataStore = store
        _dataStore = State(initialValue: store)
        _page = State(initialValue: WebPage(configuration: config))
    }

    var body: some View {
        NavigationStack {
            WebView(page)
                .navigationTitle("Sign in to YouTube")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
                .task {
                    page.load(URLRequest(url: signInURL))
                    observer.start(cookieStore: dataStore.httpCookieStore) {
                        Task {
                            await auth.refreshSignInState()
                            if auth.isSignedIn { dismiss() }
                        }
                    }
                }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 500)
        #endif
    }
}

// MARK: - Cookie observer

final class YTCookieObserver: NSObject, WKHTTPCookieStoreObserver {
    private weak var cookieStore: WKHTTPCookieStore?
    private var onSignedIn: (() -> Void)?
    private var lastSeenSAPISID: String?

    func start(cookieStore: WKHTTPCookieStore, onSignedIn: @escaping () -> Void) {
        guard self.cookieStore == nil else { return }
        self.cookieStore = cookieStore
        self.onSignedIn = onSignedIn
        cookieStore.add(self)
        check()
    }

    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        check()
    }

    private func check() {
        cookieStore?.getAllCookies { [weak self] cookies in
            guard let self else { return }
            guard let sapis = cookies.first(where: { $0.name == "SAPISID" }) else { return }
            guard sapis.value != self.lastSeenSAPISID else { return }
            self.lastSeenSAPISID = sapis.value
            self.onSignedIn?()
        }
    }

    deinit {
        cookieStore?.remove(self)
    }
}
#endif
