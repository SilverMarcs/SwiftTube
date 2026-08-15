import Foundation

/// The last position reported while the current item was healthy. Genuine
/// time-jump notifications replace the value, including backwards user seeks;
/// failed-item rollbacks are ignored because failed items are never recorded.
struct PlaybackPositionState {
    private(set) var seconds: Double?

    mutating func recordStablePosition(_ value: Double) {
        guard value.isFinite, value >= 0 else { return }
        seconds = value
    }

    mutating func reset() {
        seconds = nil
    }
}
