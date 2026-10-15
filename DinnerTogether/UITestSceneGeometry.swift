#if DEBUG
import SwiftUI
import UIKit

/// Opt-in native geometry experiment, never a synthetic layout override.
/// The simulator may reject this request: tests must verify actual geometry.
struct UITestSceneGeometry: UIViewRepresentable {
    static let argument = "-dt-request-landscape-scene"
    /// Records the geometry without asking for anything (October 15: the
    /// Duo's inner display comes from opening the hinge, not from a request).
    static let probeArgument = "-dt-scene-geometry-probe"

    @ViewBuilder
    static var launchProbe: some View {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains(argument) || arguments.contains(probeArgument) {
            UITestSceneGeometry()
        }
    }

    func makeUIView(context: Context) -> Probe { Probe() }
    func updateUIView(_ view: Probe, context: Context) { view.scheduleRequest() }

    final class Probe: UIView {
        private weak var requestedScene: UIWindowScene?
        private var phase = "waiting"
        private var requestError = "none"

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            isAccessibilityElement = true
            accessibilityIdentifier = "dt-scene-geometry-status"
            accessibilityLabel = "Native scene geometry diagnostic"
            NotificationCenter.default.addObserver(self, selector: #selector(sceneActivated(_:)),
                                                   name: UIScene.didActivateNotification, object: nil)
        }
        required init?(coder: NSCoder) { nil }
        deinit { NotificationCenter.default.removeObserver(self) }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            scheduleRequest()
        }
        override func layoutSubviews() {
            super.layoutSubviews()
            recordGeometry()
        }
        @objc private func sceneActivated(_ notification: Notification) {
            guard let scene = notification.object as? UIWindowScene,
                  scene === window?.windowScene else { return }
            scheduleRequest()
        }
        func scheduleRequest() {
            DispatchQueue.main.async { [weak self] in self?.requestIfActive() }
        }
        private func requestIfActive() {
            guard let window, let scene = window.windowScene,
                  scene.activationState == .foregroundActive else { return }
            guard requestedScene !== scene else { recordGeometry(); return }
            guard ProcessInfo.processInfo.arguments.contains(UITestSceneGeometry.argument) else {
                phase = "observed"
                recordGeometry()
                return
            }
            requestedScene = scene
            phase = "requested"
            requestError = "none"
            window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            recordGeometry()
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape)) { [weak self, weak scene] error in
                DispatchQueue.main.async {
                    guard let self, self.window?.windowScene === scene else { return }
                    self.phase = "error"
                    let ns = error as NSError
                    self.requestError = "\(ns.domain):\(ns.code):\(ns.localizedDescription)"
                        .replacingOccurrences(of: ";", with: ",")
                        .replacingOccurrences(of: "\n", with: " ")
                    self.recordGeometry()
                }
            }
        }
        private func recordGeometry() {
            guard let window, let scene = window.windowScene else { return }
            let orientation: String
            switch scene.interfaceOrientation {
            case .landscapeLeft: orientation = "landscapeLeft"
            case .landscapeRight: orientation = "landscapeRight"
            case .portrait: orientation = "portrait"
            case .portraitUpsideDown: orientation = "portraitUpsideDown"
            default: orientation = "unknown"
            }
            let w = window.bounds.size, s = scene.coordinateSpace.bounds.size
            let inset = window.safeAreaInsets
            accessibilityValue = "phase=\(phase);orientation=\(orientation);window=\(Int(w.width.rounded()))x\(Int(w.height.rounded()));scene=\(Int(s.width.rounded()))x\(Int(s.height.rounded()));safe=\(Int(inset.top.rounded())),\(Int(inset.left.rounded())),\(Int(inset.bottom.rounded())),\(Int(inset.right.rounded()));session=\(scene.session.persistentIdentifier);traits=h\(window.traitCollection.horizontalSizeClass.rawValue),v\(window.traitCollection.verticalSizeClass.rawValue);error=\(requestError)"
        }
    }
}
#endif
