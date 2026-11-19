import Observation

/// Shares the Shorts tab's feed with the tab bar accessory and its detail view.
@MainActor
@Observable
final class ShortsSession {
    var feed: ShortsFeed?
    var isShowingDetail = false
}
