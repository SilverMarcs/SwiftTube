import SwiftUI

struct FeedView: View {
    @State private var selection: Tabs = .videos
    
    var body: some View {
        TabView(selection: $selection) {
            Tab("Feed", systemImage: "video", value: .videos) {
                NavigationStack {
                    VideoFeedTab()
                        .navigationTitle("Feed")
                        .navigationDestination(for: Video.self) { video in
                            VideoPlayerView(video: video)
                        }
                }
            }
            
            Tab("Subscriptions", systemImage: "person.2", value: .subscriptions) {
                NavigationStack {
                       SubscriptionsTab()
                           .navigationTitle("Subscriptions")
                   }
            }
            
            Tab("Settings", systemImage: "gearshape.fill", value: .settings) {
                SettingsView()
            }
            
//            Tab(value: .search, role: .search) {
//                SearchTab()
//            }
                
        }
        .tabViewStyle(.sidebarAdaptable)
        #if !os(macOS)
        .tabBarMinimizeBehavior(.onScrollDown)
        #endif
    }
    
    enum Tabs {
        case videos
        case subscriptions
        case settings
    }
}
