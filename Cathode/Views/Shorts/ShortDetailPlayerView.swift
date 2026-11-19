import AVFoundation
import SwiftUI

/// The Short's feed player, shown small above its details.
struct ShortDetailPlayerView: View {
    let player: AVPlayer?

    var body: some View {
        ShortPlayerLayerView(player: player)
            .frame(maxWidth: .infinity)
            .aspectRatio(16 / 9, contentMode: .fit)
            .background(.black)
            .accessibilityHidden(true)
    }
}
