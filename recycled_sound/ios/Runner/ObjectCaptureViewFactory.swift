import Flutter
import SwiftUI
import UIKit
@preconcurrency import _RealityKit_SwiftUI

/// Factory that creates native ObjectCaptureView instances for Flutter.
///
/// The session is mutable so it can be updated when a new capture session
/// starts — the factory is registered once and reused across sessions.
@available(iOS 17.0, *)
class ObjectCaptureViewFactory: NSObject, FlutterPlatformViewFactory {
    var session: ObjectCaptureSession

    init(session: ObjectCaptureSession) {
        self.session = session
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        ObjectCapturePlatformView(frame: frame, session: session)
    }
}

/// Wraps Apple's ObjectCaptureView (SwiftUI) as a FlutterPlatformView.
///
/// Shows the live camera with built-in object detection, point cloud
/// materializing on the surface, and guided orbit indicators.
///
/// The hosting controller must be added to the view controller hierarchy
/// so SwiftUI's interactive overlays (bounding box, orbit dial) work.
@available(iOS 17.0, *)
class ObjectCapturePlatformView: NSObject, FlutterPlatformView {
    private let hostingController: UIHostingController<AnyView>

    init(frame: CGRect, session: ObjectCaptureSession) {
        let captureView = ObjectCaptureView(session: session)
        let wrappedView = AnyView(
            captureView
                .ignoresSafeArea()
        )
        hostingController = UIHostingController(rootView: wrappedView)
        hostingController.view.frame = frame
        hostingController.view.backgroundColor = .black
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        super.init()

        // Add to the view controller hierarchy so SwiftUI overlays render
        if let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
            .first {
            rootVC.addChild(hostingController)
            hostingController.didMove(toParent: rootVC)
        }
    }

    func view() -> UIView {
        hostingController.view
    }
}
