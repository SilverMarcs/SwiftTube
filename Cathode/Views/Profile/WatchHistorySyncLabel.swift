import SwiftUI

struct WatchHistorySyncLabel: View {
    let status: WatchHistorySyncStatus

    var body: some View {
        switch status {
        case .authenticated:
            Label {
                Text("YouTube history sync")
            } icon: {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            }
        case .unverified:
            Label("YouTube history sync enabled", systemImage: "person.badge.key")
        case .needsSignIn:
            Label("History sync needs sign-in", systemImage: "exclamationmark.triangle")
        case .unavailable:
            Label("History sync temporarily unavailable", systemImage: "exclamationmark.icloud")
        }
    }
}
