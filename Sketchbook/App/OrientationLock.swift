import SwiftUI

/// Global holder for the app's allowed interface orientations. The editor can
/// pin the current orientation so the canvas doesn't rotate while drawing.
final class OrientationManager: ObservableObject {
    static let shared = OrientationManager()

    /// Currently allowed orientations (read by `AppDelegate`).
    @Published private(set) var mask: UIInterfaceOrientationMask = .all
    @Published private(set) var isLocked = false

    /// Lock to whatever orientation the device is currently in.
    func lockToCurrent() {
        let orientation = UIApplication.shared.activeWindowScene?.interfaceOrientation ?? .portrait
        switch orientation {
        case .landscapeLeft: mask = .landscapeLeft
        case .landscapeRight: mask = .landscapeRight
        case .portraitUpsideDown: mask = .portraitUpsideDown
        default: mask = .portrait
        }
        isLocked = true
        apply()
    }

    /// Allow all orientations again.
    func unlock() {
        mask = .all
        isLocked = false
        apply()
    }

    func toggle() { isLocked ? unlock() : lockToCurrent() }

    private func apply() {
        guard let scene = UIApplication.shared.activeWindowScene else { return }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
        scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}

extension UIApplication {
    var activeWindowScene: UIWindowScene? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? connectedScenes.compactMap { $0 as? UIWindowScene }.first
    }
}

/// Supplies the allowed orientations to UIKit from `OrientationManager`.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        OrientationManager.shared.mask
    }
}
