import SwiftUI

struct SubscriptionsTab: View {
    @StateObject private var accountManager = AccountManager.shared
    @State private var subscriptions: [Channel] = []
    @State private var isLoadingSubscriptions = false
    
    var body: some View {
        Group {
            if isLoadingSubscriptions {
                VStack {
                    Spacer()
                    ProgressView("Loading subscriptions...")
                    Spacer()
                }
            } else if subscriptions.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary)
                    Text("No subscriptions")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Subscribe to channels to see them here")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding()
            } else {
                List(subscriptions) { channel in
                    ChannelRow(channel: channel)
                }
                .listStyle(.plain)
            }
        }
        .task {
            await loadSubscriptions()
        }
        .refreshable {
            await loadSubscriptions()
        }
    }
    
    private func loadSubscriptions() async {
        guard accountManager.currentAccount != nil else { return }
        
        isLoadingSubscriptions = true
        let channels = await PipedAPI.shared.fetchSubscriptions()
        subscriptions = channels
        isLoadingSubscriptions = false
    }
}
