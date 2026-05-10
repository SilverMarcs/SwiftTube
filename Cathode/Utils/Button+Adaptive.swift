import SwiftUI

extension View {
    /// `.card` on tvOS, `.plain` on other platforms.
    func adaptiveCardButtonStyle() -> some View {
        #if os(tvOS)
        self.buttonStyle(.card)
        #else
        self.buttonStyle(.plain)
        #endif
    }
}
