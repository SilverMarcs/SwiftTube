import SwiftUI

#if !os(tvOS)
struct CommentRepliesView: View {
    @State private var model: CommentRepliesModel
    @State private var isExpanded = false

    init(comment: Comment) {
        _model = State(initialValue: CommentRepliesModel(comment: comment))
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button {
                    isExpanded.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                        Text(isExpanded ? "Hide replies" : "View replies")
                    }
                }
                .font(.subheadline)

                if model.isLoading {
                    ProgressView()
                        .controlSize(.mini)
                }
            }

            if isExpanded {
                VStack(alignment: .leading) {
                    ForEach(model.replies) { reply in
                        CommentRowView(comment: reply)
                    }

                }
                .task {
                    if !model.hasLoaded {
                        await model.loadMore()
                    }
                }
            }
        }
        .buttonStyle(.borderless)
    }

    private func requestLoad() {
        Task { await model.loadMore() }
    }
}
#endif
