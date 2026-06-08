import SwiftUI

struct VideoDetailsList: View {
    let video: Video
    let description: String?
    let fetchedChannel: Channel?

    var body: some View {
        List {
            VideoDetailsListSection(
                video: video,
                description: description,
                fetchedChannel: fetchedChannel
            )
        }
    }
}
