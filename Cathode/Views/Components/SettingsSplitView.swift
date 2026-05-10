import SwiftUI

struct SettingsSplitView<InfoPanelContent: View, Content: View>: View {
    @ViewBuilder let content: Content
    @ViewBuilder let infoPanel: InfoPanelContent

    var body: some View {
        #if os(tvOS)
        GeometryReader { proxy in
            HStack(spacing: 70) {
                infoPanel
                    .frame(width: proxy.size.width * 0.5)

                content
                    .safeAreaPadding(.leading)
            }
        }
        #else
        content
        #endif
    }
}
