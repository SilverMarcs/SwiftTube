import SwiftUI

/// The title row of a video's detail screen: title header, view count / date,
/// and the overflow menu. iOS & visionOS only (gated in the project file).
struct VideoTitleSection: View {
    let video: Video

    var body: some View {
        Section(video.title) {
            HStack(spacing: 5) {
                if let viewCount = video.viewCount {
                    Text("\(viewCount, format: .number.notation(.compactName)) views")
                }

                if video.viewCount != nil, video.publishedAt != nil {
                    Text("•")
                }

                if let date = video.publishedAt {
                    Text(date, style: .date)
                }

                Spacer()

                VideoDetailMenuView(video: video)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .listRowSeparator(.hidden, edges: .bottom)
            .listRowInsets([.vertical], 0)
        }
        .headerProminence(.increased)
        .listRowBackground(Color.clear)
        .listSectionMargins(.all, 0)
    }
}
