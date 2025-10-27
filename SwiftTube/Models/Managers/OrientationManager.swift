import SwiftUI
import UIKit

// Centralized orientation control. Not Observable to avoid accidental SwiftUI refreshes.
class OrientationManager {
    static let shared = OrientationManager()
    var lockedOrientation: UIInterfaceOrientationMask = .all

    /// Locks supported orientations for the app window and optionally requests a rotation.
    /// - Parameters:
    ///   - orientation: The mask to advertise via `supportedInterfaceOrientationsFor`.
    ///   - rotateTo: Optional concrete orientation to request. On iOS 16+, we use `UIWindowScene.requestGeometryUpdate`.
    func lockOrientation(_ orientation: UIInterfaceOrientationMask, rotateTo: UIInterfaceOrientation? = nil) {
        lockedOrientation = orientation

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first else { return }

        // Inform view controllers to re-evaluate supported orientations
        windowScene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()

        // Optionally request rotation
        guard let rotateTo = rotateTo else { return }

        let orientations = UIInterfaceOrientationMask(from: rotateTo)
        let preferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: orientations)
        windowScene.requestGeometryUpdate(preferences, errorHandler: nil)
    }
}

private extension UIInterfaceOrientationMask {
    init(from orientation: UIInterfaceOrientation) {
        switch orientation {
        case .portrait: self = .portrait
        case .portraitUpsideDown: self = .portraitUpsideDown
        case .landscapeLeft: self = .landscapeLeft
        case .landscapeRight: self = .landscapeRight
        default: self = .all
        }
    }
}
