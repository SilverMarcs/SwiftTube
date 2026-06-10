import SwiftUI

/// The description section for a video's detail screen. The listing payload
/// often omits the description, so this view fetches it on its own when needed
/// rather than relying on the parent to supply it.
struct VideoDescriptionSection: View {
    let video: Video

    @State private var fetchedDescription: String?
    @State private var isFetching: Bool

    init(video: Video) {
        self.video = video
        let original = video.description?.trimmingCharacters(in: .whitespacesAndNewlines)
        _isFetching = State(initialValue: original?.isEmpty ?? true)
    }

    private var description: String? {
        let original = video.description?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let original, !original.isEmpty { return original }
        return fetchedDescription
    }

    var body: some View {
        Group {
            if let description, !description.isEmpty {
                Section("Description") {
                    ExpandableText(text: description, maxCharacters: 200)
                        .font(.subheadline)
                        #if os(macOS)
                        .listRowSeparator(.hidden, edges: .bottom)
                        #endif
                }
            } else if isFetching {
                Section("Description") {
                    UniversalProgressView()
                }
            }
        }
        .task(id: video.id) {
            let needsFetch = video.description?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
            isFetching = needsFetch
            guard needsFetch else { return }
            defer { isFetching = false }
            do {
                let info = try await InnerTubeAPI.shared.fetchPlayerInfo(videoId: video.id)
                if !Task.isCancelled {
                    fetchedDescription = info.video.description
                }
            } catch {
                print("VideoDescriptionSection description fetch failed: \(error)")
            }
        }
    }
}
