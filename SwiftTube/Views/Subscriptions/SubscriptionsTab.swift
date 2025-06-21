import SwiftUI

struct SubscriptionsTab: View {
    @State private var subscriptions: [Channel] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            List(subscriptions) { channel in
//                ChannelRow(channel: channel)
                ChannelRowContent(channel: channel)
                
                if isLoading {
                    ProgressView()
    //                        .id(UUID())
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .listRowSeparator(.hidden)
                }
            }
            .navigationDestinations()
            .listStyle(.plain)
            .navigationTitle("Subscriptions")
            .toolbarTitleDisplayMode(.inlineLarge)
            .task {
                await loadSubscriptions()
            }
            .refreshable {
                await loadSubscriptions()
            }
        }
    }
    
    private func loadSubscriptions() async {
        isLoading = true
        let channels = await PipedAPI.shared.fetchSubscriptions()
        subscriptions = channels
        isLoading = false
    }
}
