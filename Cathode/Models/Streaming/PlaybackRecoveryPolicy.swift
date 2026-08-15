import Foundation

/// Allows one automatic recovery per instability episode. The budget becomes
/// available again only after two minutes of actual, continuously sampled
/// playback, so a replacement loop cannot replenish itself merely by reaching
/// `readyToPlay`.
struct PlaybackRecoveryPolicy {
    private static let stableResetDuration: TimeInterval = 120
    private static let maximumTickGap: TimeInterval = 2.5

    private(set) var automaticAttempts = 0
    private var itemReachedReady = false
    private var stablePlaybackDuration: TimeInterval = 0
    private var lastStableTickAt: Date?

    mutating func prepareForReplacementItem() {
        itemReachedReady = false
        stablePlaybackDuration = 0
        lastStableTickAt = nil
    }

    mutating func markItemReady() {
        itemReachedReady = true
        lastStableTickAt = nil
    }

    mutating func recordStablePlayback(at date: Date = Date()) {
        guard itemReachedReady else { return }
        if let lastStableTickAt {
            let interval = date.timeIntervalSince(lastStableTickAt)
            if interval >= 0, interval <= Self.maximumTickGap {
                stablePlaybackDuration += interval
            }
        }
        lastStableTickAt = date

        if stablePlaybackDuration >= Self.stableResetDuration {
            automaticAttempts = 0
            stablePlaybackDuration = 0
        }
    }

    mutating func pauseStabilityClock() {
        lastStableTickAt = nil
    }

    mutating func consumeAutomaticRecovery() -> Int? {
        guard itemReachedReady, automaticAttempts < 1 else { return nil }
        automaticAttempts += 1
        prepareForReplacementItem()
        return automaticAttempts
    }

    mutating func reset() {
        automaticAttempts = 0
        itemReachedReady = false
        stablePlaybackDuration = 0
        lastStableTickAt = nil
    }
}
