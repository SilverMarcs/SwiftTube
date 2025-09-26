//
//  VideosList.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 27/09/2025.
//

import SwiftUI

struct VideosList: View {
    let rssLinks: [String]

    @State private var videos: [Entry] = []

    var body: some View {
        NavigationStack {
            List(videos) { video in
                VideoRow(entry: video)
            }
            .navigationTitle("Videos")
            .toolbarTitleDisplayMode(.inlineLarge)
            .task {
                await fetchVideos()
            }
        }
    }

    private func fetchVideos() async {
        videos = []
        for url in rssLinks {
            if let feed = await fetchFeed(from: url) {
                videos.append(contentsOf: feed.entries)
            }
        }
        videos.sort { $0.published > $1.published }
    }

    private func fetchFeed(from urlString: String) async -> Feed? {
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            // Parse XML data into Feed
            return parseFeed(from: data)
        } catch {
            print("Error fetching: \(error)")
            return nil
        }
    }

    private func parseFeed(from data: Data) -> Feed? {
        // Simple XML parsing using XMLParser
        // This is a basic implementation; in a real app, consider using a library like SWXMLHash
        let parser = FeedParser()
        parser.parse(data: data)
        return parser.feed
    }
}
