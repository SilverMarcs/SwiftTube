import AVFoundation
import UIKit

final class ShortPlayerLayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    // `layerClass` guarantees the cast.
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        playerLayer.videoGravity = .resizeAspect
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
