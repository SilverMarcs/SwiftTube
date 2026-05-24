import AVFoundation
import Foundation

/// Tracks SponsorBlock segments for the currently-playing video and exposes the
/// segment the playhead is currently inside (or nil). Observed by SwiftUI views
/// like `SponsorSkipOverlay` for the "Skip Sponsor" affordance.
@Observable
final class SponsorTracker {
    private(set) var segments: [SponsorSegment] = []
    private(set) var currentSegment: SponsorSegment? = nil

    func update(segments: [SponsorSegment]) {
        self.segments = segments
    }

    func reset() {
        segments = []
        currentSegment = nil
    }

    /// Recomputes `currentSegment` against the given playhead. Call from the
    /// player's periodic time observer.
    func refresh(playerSeconds: TimeInterval) {
        let next = segments.first { playerSeconds >= $0.start && playerSeconds < $0.end }
        if next != currentSegment {
            currentSegment = next
        }
    }

    /// Consumes the active segment (clears optimistically so UI hides
    /// immediately) and returns its `end` time so the caller can seek the
    /// player. Returns nil if no segment is active.
    func consumeActiveSegmentEnd() -> TimeInterval? {
        guard let segment = currentSegment else { return nil }
        currentSegment = nil
        return segment.end
    }
}
