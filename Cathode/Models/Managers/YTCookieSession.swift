import Foundation

/// A login generation is immutable. Renewals change only its revision, never its
/// creation date, so renewing an old login cannot outrank a newer login.
nonisolated struct YTCookieSession: Codable, Equatable, Sendable {
    let id: UUID
    let createdAt: Date
    var revision: UUID
    var revisionNumber: UInt64
    var updatedAt: Date
    var cookies: [YTStoredCookie]
    var signedOut: Bool
    var verified: Bool

    init(cookies: [YTStoredCookie], after previous: YTCookieSession? = nil,
         now: Date = Date(), signedOut: Bool = false, verified: Bool = false) {
        id = UUID()
        createdAt = max(now, previous?.createdAt.addingTimeInterval(0.001) ?? now)
        revision = UUID()
        revisionNumber = 0
        updatedAt = createdAt
        self.cookies = cookies
        self.signedOut = signedOut
        self.verified = verified
    }

    func isNewer(than other: Self) -> Bool {
        if createdAt != other.createdAt { return createdAt > other.createdAt }
        if id != other.id { return id.uuidString > other.id.uuidString }
        if revisionNumber != other.revisionNumber { return revisionNumber > other.revisionNumber }
        if updatedAt != other.updatedAt { return updatedAt > other.updatedAt }
        return revision.uuidString > other.revision.uuidString
    }

    /// A response belongs to one exact snapshot. In-flight replies from an older
    /// login or revision must not restore credentials that have been replaced.
    func acceptsResponse(to snapshot: Self) -> Bool {
        !signedOut && id == snapshot.id && revision == snapshot.revision
    }

    mutating func replaceCookies(_ cookies: [YTStoredCookie], now: Date = Date()) {
        self.cookies = cookies
        revision = UUID()
        revisionNumber += 1
        updatedAt = max(now, updatedAt.addingTimeInterval(0.001))
    }

    /// Returns whether this is a credential renewal worth publishing. A health
    /// check that only confirms old cookies is strictly local, including migration.
    mutating func receive(_ cookies: [YTStoredCookie], verified: Bool) -> Bool {
        let credentialsChanged = cookies.filter(\.isCredential) != self.cookies.filter(\.isCredential)
        if self.cookies != cookies || (verified && !self.verified) {
            replaceCookies(cookies)
            self.verified = self.verified || verified
        }
        return credentialsChanged && self.verified
    }

    static func normalized(_ cookies: [HTTPCookie], at date: Date = Date()) -> [YTStoredCookie] {
        cookies.map(YTStoredCookie.init)
            .filter { YTStoredCookie.isYouTubeDomain($0.domain) && $0.isValid(at: date) }
            .sorted { $0.identity < $1.identity }
    }
}
