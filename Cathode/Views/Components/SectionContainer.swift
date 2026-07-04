import SwiftUI

/// A section wrapper with a consistent header treatment across platforms.
/// If `isVisible` is `false`, nothing is rendered.
/// - tvOS: wraps the content in a `Section` (optional header), inside a `.focusSection()`.
/// - other platforms: a `VStack` with a bold `title3` header and horizontal scene padding.
///
/// Adapted from the FinStream project's section paradigm.
struct SectionContainer<RowContent: View, HeaderContent: View>: View {
    @ViewBuilder let header: () -> HeaderContent

    let isVisible: Bool
    let showHeader: Bool
    @ViewBuilder let content: () -> RowContent

    init(
        isVisible: Bool = true,
        showHeader: Bool = true,
        @ViewBuilder content: @escaping () -> RowContent,
        @ViewBuilder header: @escaping () -> HeaderContent
    ) {
        self.header = header
        self.isVisible = isVisible
        self.showHeader = showHeader
        self.content = content
    }

    var body: some View {
        if isVisible {
#if os(tvOS)
            Group {
                if showHeader {
                    Section {
                        content()
                    } header: {
                        header()
                    }
                } else {
                    content()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .focusSection()
#else
            VStack(alignment: .leading) {
                if showHeader {
                    header()
                        .font(.title3.bold())
                        .scenePadding(.horizontal)
                }

                content()
            }
#endif
        }
    }
}
