import Foundation

nonisolated enum YTSessionValidation {
    /// Missing authentication evidence is an unknown response, not a logout.
    static func authenticated(in data: Data) -> Bool? {
        guard let html = String(data: data, encoding: .utf8),
              let expression = try? NSRegularExpression(pattern: #""LOGGED_IN"\s*:\s*(true|false)"#),
              let match = expression.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else { return nil }
        return html[range] == "true"
    }
}
