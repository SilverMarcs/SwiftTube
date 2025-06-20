import SwiftUI

struct FeedView: View {
    @StateObject private var accountManager = AccountManager.shared
    
    var body: some View {
        TabView {
            NavigationStack {
                VideoFeedTab()
                    .navigationTitle("Feed")
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Menu {
                                Button("Switch Account") {
                                    // Implementation for account switching
                                }
                                
                                Button("Logout") {
                                    if let currentAccount = accountManager.currentAccount {
                                        accountManager.removeAccount(currentAccount)
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                    }
            }
            .tabItem {
                Image(systemName: "video")
                Text("Feed")
            }
            
            NavigationStack {
                SubscriptionsTab()
                    .navigationTitle("Subscriptions")
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Menu {
                                Button("Switch Account") {
                                    // Implementation for account switching
                                }
                                
                                Button("Logout") {
                                    if let currentAccount = accountManager.currentAccount {
                                        accountManager.removeAccount(currentAccount)
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                    }
            }
            .tabItem {
                Image(systemName: "person.2")
                Text("Subscriptions")
            }
        }
    }
}
