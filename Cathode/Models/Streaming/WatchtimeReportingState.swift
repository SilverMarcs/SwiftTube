/// Shared by queued reports for one tracking configuration. Once delivery
/// fails, skip its queued reports and let playback obtain fresh configuration.
@MainActor
final class WatchtimeReportingState {
    var failed = false
}
