// VideoListView.swift
import SwiftUI
import SwiftData

struct FeedView: View {
    @Query(
        filter: #Predicate<Video> { $0.isShort == false },
        sort: \Video.publishedAt,
        order: .reverse
    ) private var videos: [Video]
    
    var body: some View {
        NavigationStack {
            if videos.isEmpty {
                ContentUnavailableView(
                    "No Videos Available",
                    systemImage: "video",
                    description: Text("Videos will appear here once channels are added and loaded")
                )
            } else {
                List(videos) { video in
                    VideoRowView(video: video)
                        .listRowSeparator(.hidden)
                        .listRowInsets(.vertical, 7)
                        .listRowInsets(.horizontal, 10)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Feed")
        .toolbarTitleDisplayMode(.inlineLarge)
    }


}
