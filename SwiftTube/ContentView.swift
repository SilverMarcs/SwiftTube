//////

//  ContentView.swift

//  SwiftTube//  ContentView.swift//  MainView.swift

//

//  Created by Zabir Raihan on 27/09/2025.//  SwiftTube//  SwiftTube

//

////

import SwiftUI

//  Created by Zabir Raihan on 27/09/2025.//  Created by Zabir Raihan on 27/09/2025.

struct ContentView: View {
    @State private var rssLinks: [String] = ["https://www.youtube.com/feeds/videos.xml?channel_id=UCNvzD7Z-g64bPXxGzaQaa4g"]////

    var body: some View {
        TabView {
            VideosList(rssLinks: rssLinks)
                .tabItem {
                    Label("Videos", systemImage: "video")
                }
            
            RSSView(rssLinks: $rssLinks)
                .tabItem {
                    Label("RSS", systemImage: "link")
                }
        }
    }
}
