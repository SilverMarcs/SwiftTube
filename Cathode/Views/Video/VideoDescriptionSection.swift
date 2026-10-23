import SwiftUI

/// The description section for a video's detail screen.
struct VideoDescriptionSection: View {
    let video: Video

    var body: some View {
        if let description = video.description?.trimmingCharacters(in: .whitespacesAndNewlines),
           !description.isEmpty {
            Section("Description") {
                ExpandableText(text: description, maxCharacters: 200)
                    .font(.subheadline)
                    #if os(macOS)
                    .listRowSeparator(.hidden, edges: .bottom)
                    #endif
            }
        }
    }
}
