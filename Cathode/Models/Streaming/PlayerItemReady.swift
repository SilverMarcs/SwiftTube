import AVFoundation

/// Awaits AVPlayerItem reaching `.readyToPlay` or `.failed`.
/// Returns true on ready, false on failure.
func awaitPlayerItemReady(_ item: AVPlayerItem) async -> Bool {
    if item.status == .readyToPlay { return true }
    if item.status == .failed { return false }
    return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
        var resumed = false
        var observation: NSKeyValueObservation?
        observation = item.observe(\.status, options: [.new, .initial]) { item, _ in
            guard !resumed else { return }
            switch item.status {
            case .readyToPlay:
                resumed = true
                observation?.invalidate()
                cont.resume(returning: true)
            case .failed:
                resumed = true
                observation?.invalidate()
                cont.resume(returning: false)
            default:
                break
            }
        }
    }
}
