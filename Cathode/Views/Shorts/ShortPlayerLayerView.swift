import AVFoundation
import SwiftUI

/// An aspect-fit `AVPlayerLayer` that renders a player owned elsewhere.
struct ShortPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer?

    func makeUIView(context: Context) -> ShortPlayerLayerUIView {
        let view = ShortPlayerLayerUIView()
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ view: ShortPlayerLayerUIView, context: Context) {
        if view.playerLayer.player !== player {
            view.playerLayer.player = player
        }
    }

    static func dismantleUIView(_ view: ShortPlayerLayerUIView, coordinator: ()) {
        view.playerLayer.player = nil
    }
}
