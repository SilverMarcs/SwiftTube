import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    private static var orientationLock: UIInterfaceOrientationMask = .all

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        Self.orientationLock
    }

    /// Holds iPhone in landscape while the player is full screen, even under
    /// Portrait Orientation Lock. iPad keeps following the device.
    static func setFullScreenLandscape(_ isFullScreen: Bool, in scene: UIWindowScene?) {
        let mask: UIInterfaceOrientationMask = isFullScreen ? .landscape : .all
        guard UIDevice.current.userInterfaceIdiom == .phone,
              orientationLock != mask,
              let scene else { return }
        orientationLock = mask
        scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: isFullScreen ? .landscape : .portrait))
    }
}
