/// Authentication/reporting health, not a guarantee of server-side persistence.
nonisolated enum WatchHistorySyncStatus {
    case unverified
    case authenticated
    case needsSignIn
    case unavailable
}
