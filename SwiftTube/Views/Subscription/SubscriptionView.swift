//
//  SubscriptionView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 28/09/2025.
//

import SwiftUI
import SwiftData

struct SubscriptionView: View {
    @State private var subscriptions: [Channel] = []
    @State private var isLoading = false
    
    private var authManager = GoogleAuthManager.shared
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(subscriptions) { subscription in
                    HStack {
                        AsyncImage(url: URL(string: subscription.thumbnailURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.gray.opacity(0.3)
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        
                        VStack(alignment: .leading) {
                            Text(subscription.title)
                                .font(.headline)
                            
                            Text(subscription.channelDescription)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .refreshable {
                await loadSubscriptions()
            }
            .navigationTitle("Subscriptions")
            .toolbarTitleDisplayMode(.inlineLarge)
        }
        .task {
            if authManager.isSignedIn {
                await loadSubscriptions()
            }
        }
    }
    
    private func loadSubscriptions() async {
        isLoading = true
        
        do {
            let fetchedSubscriptions = try await YTService.fetchMySubscriptions()
            subscriptions = fetchedSubscriptions
            isLoading = false
        } catch {
            print(error.localizedDescription)
        }
    }
}
