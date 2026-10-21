import SwiftUI

struct SectionContainer<Content: View, Header: View>: View {
    @ViewBuilder var content: () -> Content
    @ViewBuilder var header: () -> Header

    var body: some View {
        #if os(tvOS)
        Section {
            content()
        } header: {
            header()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .focusSection()
        #else
        VStack(alignment: .leading) {
            header()
                .font(.title3.bold())
                .scenePadding(.horizontal)
            content()
        }
        #endif
    }
}
