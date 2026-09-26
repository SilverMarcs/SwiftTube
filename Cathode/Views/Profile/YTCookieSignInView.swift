#if !os(tvOS)
import SwiftUI
import WebKit

struct YTCookieSignInView: View {
    @Environment(\.dismiss) private var dismiss
    private let auth = YTCookieAuth.shared
    @State private var page: WebPage
    @State private var checking = false
    @State private var ready = false
    @State private var verificationFailed = false
    @State private var checkTask: Task<Void, Never>?

    init() {
        var configuration = WebPage.Configuration()
        configuration.websiteDataStore = .default()
        _page = State(initialValue: WebPage(configuration: configuration))
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
                    ToolbarItem(placement: .confirmationAction) {
                        Button(checking ? "Checking…" : "Finish Sign-In") {
                            checkSignIn(showFailure: true)
                        }
                        .disabled(checking || !ready || page.isLoading)
                    }
                }
                .task {
                    await auth.prepareInteractiveSignIn()
                    guard !Task.isCancelled,
                          let url = URL(string: "https://accounts.google.com/ServiceLogin?service=youtube&continue=https%3A%2F%2Fwww.youtube.com%2F") else { return }
                    ready = true
                    page.load(URLRequest(url: url))
                }
                .onChange(of: page.isLoading) { _, loading in
                    guard ready, !loading, !checking,
                          let host = page.url?.host(), host == "youtube.com" || host.hasSuffix(".youtube.com") else { return }
                    checkSignIn(showFailure: false)
                }
                .alert("Couldn’t verify history sync", isPresented: $verificationFailed) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text("Finish signing in to YouTube, then try again. If you’re already signed in, check your connection.")
                }
                .onDisappear {
                    checkTask?.cancel()
                    auth.endInteractiveSignIn()
                }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 500)
        #endif
    }

    private func checkSignIn(showFailure: Bool) {
        guard !checking else { return }
        checking = true
        checkTask = Task {
            let verified = await auth.completeInteractiveSignIn()
            guard !Task.isCancelled else { return }
            checking = false
            if verified { dismiss() }
            else if showFailure { verificationFailed = true }
        }
    }
}
#endif
