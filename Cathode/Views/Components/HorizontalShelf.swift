import SwiftUI

/// A horizontal scrolling row primitive: a `ScrollView(.horizontal)` + `LazyHStack`
/// with edge scene padding and hidden indicators. `.scrollClipDisabled()` on tvOS
/// so focus-scaled cards aren't clipped.
///
/// Adapted from the FinStream project's section paradigm.
struct HorizontalShelf<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: spacing) {
                content()
            }
            .scenePadding(.horizontal)
        }
        .scrollIndicators(.hidden)
        #if os(tvOS)
        .scrollClipDisabled()
        #endif
    }
}
