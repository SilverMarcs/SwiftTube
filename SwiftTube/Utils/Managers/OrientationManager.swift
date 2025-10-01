import SwiftUI

// TODO: see if need to be observable or not
class OrientationManager {
    static let shared = OrientationManager()
    var lockedOrientation: UIInterfaceOrientationMask = .all
    
    func lockOrientation(_ orientation: UIInterfaceOrientationMask, andRotateTo rotateOrientation: UIInterfaceOrientation? = nil) {
        lockedOrientation = orientation
        
        if let rotateOrientation = rotateOrientation {
            UIDevice.current.setValue(rotateOrientation.rawValue, forKey: "orientation")
        }
        
        // Use the modern API instead of the deprecated method
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
}