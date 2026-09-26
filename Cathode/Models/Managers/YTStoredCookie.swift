import Foundation

/// Value representation shared by the local snapshot and iCloud. Never log values.
nonisolated struct YTStoredCookie: Codable, Equatable, Sendable {
    let name: String
    let value: String
    let domain: String
    let path: String
    let expires: Date?
    let isSecure: Bool
    let isHTTPOnly: Bool

    init(_ cookie: HTTPCookie) {
        name = cookie.name
        value = cookie.value
        domain = cookie.domain
        path = cookie.path
        expires = cookie.expiresDate
        isSecure = cookie.isSecure
        isHTTPOnly = cookie.isHTTPOnly
    }

    var identity: String { "\(domain.lowercased())\n\(path)\n\(name)" }

    var httpCookie: HTTPCookie? {
        var properties: [HTTPCookiePropertyKey: Any] = [
            .name: name, .value: value, .domain: domain, .path: path,
        ]
        if isSecure { properties[.secure] = "TRUE" }
        if isHTTPOnly { properties[HTTPCookiePropertyKey("HttpOnly")] = "TRUE" }
        if let expires { properties[.expires] = expires }
        return HTTPCookie(properties: properties)
    }

    func isValid(at date: Date) -> Bool { expires.map { $0 > date } ?? true }

    static func isYouTubeDomain(_ domain: String) -> Bool {
        let domain = domain.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
        return domain == "youtube.com" || domain.hasSuffix(".youtube.com")
            || domain == "google.com" || domain.hasSuffix(".google.com")
    }

    func matches(_ url: URL, at date: Date = Date()) -> Bool {
        guard isValid(at: date), let host = url.host?.lowercased(),
              !isSecure || url.scheme == "https" else { return false }
        let bareDomain = domain.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
        let domainMatches = host == bareDomain || (domain.hasPrefix(".") && host.hasSuffix("." + bareDomain))
        let requestPath = url.path.isEmpty ? "/" : url.path
        let pathMatches = requestPath == path
            || requestPath.hasPrefix(path.hasSuffix("/") ? path : path + "/")
        return domainMatches && pathMatches
    }

    /// Only credential changes warrant an iCloud upload; visitor/analytics cookies
    /// may change on every page request and must not flood KVS.
    var isCredential: Bool {
        ["SID", "HSID", "SSID", "APISID", "SAPISID", "SIDCC", "LOGIN_INFO"].contains(name)
            || name.hasPrefix("__Secure-1P") || name.hasPrefix("__Secure-3P")
    }
}
