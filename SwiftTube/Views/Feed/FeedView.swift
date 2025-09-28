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
            List(videos) { video in
                VideoRowView(video: video)
                    .listRowSeparator(.hidden)
                    .listRowInsets(.vertical, 7)
                    .listRowInsets(.horizontal, 10)
            }
            .listStyle(.plain)
            .navigationTitle("Feed")
            .toolbarTitleDisplayMode(.inlineLarge)
        }
    }
}
