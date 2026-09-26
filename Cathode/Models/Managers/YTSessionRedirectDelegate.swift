import Foundation

nonisolated final class YTSessionRedirectDelegate: NSObject, URLSessionTaskDelegate {
    private let jar: HTTPCookieStorage

    init(jar: HTTPCookieStorage) { self.jar = jar }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        YTSessionTransport.receiveCookies(from: response, into: jar)
        guard let url = request.url, url.scheme == "https",
              let host = url.host, YTStoredCookie.isYouTubeDomain(host) else {
            completionHandler(nil)
            return
        }
        var request = request
        request.httpShouldHandleCookies = false
        request.setValue(YTSessionTransport.cookieHeader(in: jar, for: url), forHTTPHeaderField: "Cookie")
        if response.url?.host != url.host {
            request.setValue(nil, forHTTPHeaderField: "Authorization")
        }
        completionHandler(request)
    }
}
