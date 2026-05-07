import Flutter
import UIKit
import SwiftUI
import RealityKit
@preconcurrency import _RealityKit_SwiftUI
import ARKit

/// Flutter platform channel for Apple's Object Capture API.
///
/// Provides LiDAR-based 3D scanning of hearing aids. The session captures
/// images from multiple angles, then reconstructs a USDZ 3D model.
///
/// Requires iOS 17.0+ and a LiDAR-equipped device.
@available(iOS 17.0, *)
@MainActor
class ObjectCapturePlugin {
    private var channel: FlutterMethodChannel?
    private var session: ObjectCaptureSession?
    private var captureDir: URL?
    private var stateTask: Task<Void, Never>?
    private var shotsTask: Task<Void, Never>?
    private var feedbackTask: Task<Void, Never>?
    private let messenger: FlutterBinaryMessenger
    private var viewFactoryRegistered = false
    private var viewFactory: ObjectCaptureViewFactory?

    nonisolated init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        let channel = FlutterMethodChannel(
            name: "recycled_sound/object_capture",
            binaryMessenger: messenger
        )

        // Handle isSupported synchronously — it's a static property,
        // no MainActor needed. Everything else dispatches to MainActor.
        channel.setMethodCallHandler { [weak self] call, result in
            if call.method == "isSupported" {
                // Synchronous — no Task dispatch, no race condition
                result(ObjectCaptureSession.isSupported)
                return
            }
            Task { @MainActor in
                guard let self = self else {
                    // Plugin was deallocated — return error instead of hanging
                    result(FlutterError(
                        code: "DISPOSED",
                        message: "Plugin was disposed",
                        details: nil
                    ))
                    return
                }
                self.handle(call, result: result)
            }
        }
        Task { @MainActor in
            self.channel = channel
        }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isSupported":
            result(ObjectCaptureSession.isSupported)

        case "startSession":
            startSession(result: result)

        case "startDetecting":
            startDetecting(result: result)

        case "startCapturing":
            startCapturing(result: result)

        case "startCapture":
            startCapture(result: result)

        case "beginNewScanPass":
            beginNewScanPass(result: result)

        case "beginNewScanPassAfterFlip":
            beginNewScanPassAfterFlip(result: result)

        case "getState":
            result(session.map { stateString($0.state) } ?? "idle")

        case "finish":
            finishSession(result: result)

        case "cancel":
            cancelSession(result: result)

        case "getModelPath":
            result(captureDir?.path)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func startSession(result: @escaping FlutterResult) {
        guard ObjectCaptureSession.isSupported else {
            result(FlutterError(
                code: "NOT_SUPPORTED",
                message: "Object Capture is not supported on this device",
                details: nil
            ))
            return
        }

        // Create output directory
        let documentsDir = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first!
        let dir = documentsDir.appendingPathComponent(
            "object_capture_\(Int(Date().timeIntervalSince1970))"
        )
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true
        )
        captureDir = dir

        // Clean up any previous session
        cleanup()

        let session = ObjectCaptureSession()
        self.session = session

        // Register or update the platform view factory
        if let factory = viewFactory {
            // Update existing factory with the new session
            factory.session = session
        } else if let registrar = ObjectCapturePluginRegistrar.flutterRegistrar {
            let factory = ObjectCaptureViewFactory(session: session)
            registrar.register(factory, withId: "object-capture-view")
            self.viewFactory = factory
            viewFactoryRegistered = true
        }

        // Checkpoint directory must be OUTSIDE the images directory —
        // Apple requires imagesDirectory to be completely empty on start.
        let checkpointDir = documentsDir.appendingPathComponent(
            "object_capture_checkpoints_\(Int(Date().timeIntervalSince1970))"
        )
        try? FileManager.default.createDirectory(
            at: checkpointDir, withIntermediateDirectories: true
        )

        // Start the session with over-capture for higher quality
        var config = ObjectCaptureSession.Configuration()
        config.checkpointDirectory = checkpointDir
        config.isOverCaptureEnabled = true

        print("[ObjectCapture] Starting session, imagesDir=\(dir.path)")
        print("[ObjectCapture] isSupported=\(ObjectCaptureSession.isSupported)")
        session.start(imagesDirectory: dir, configuration: config)
        print("[ObjectCapture] session.start() called, current state=\(stateString(session.state))")

        // Return to Flutter immediately — the session is started.
        // State changes will arrive via the async observer below.
        result(nil)

        // Observe state changes
        stateTask = Task { [weak self] in
            print("[ObjectCapture] Starting stateUpdates observer...")
            for await state in session.stateUpdates {
                guard let self = self else { return }
                print("[ObjectCapture] State changed: \(self.stateString(state))")

                self.channel?.invokeMethod("onStateChanged", arguments: [
                    "state": self.stateString(state),
                ])
                if case .completed = state {
                    self.channel?.invokeMethod("onModelReady", arguments: [
                        "path": self.captureDir?.path ?? "",
                    ])
                }
            }
            print("[ObjectCapture] stateUpdates sequence ended")
        }

        // Observe shot count
        shotsTask = Task { [weak self] in
            for await count in session.numberOfShotsTakenUpdates {
                self?.channel?.invokeMethod("onProgress", arguments: [
                    "shotsTaken": count,
                ])
            }
        }

        // Observe feedback/guidance
        feedbackTask = Task { [weak self] in
            for await feedbackSet in session.feedbackUpdates {
                guard let self = self else { return }
                let feedbackStrings = feedbackSet.map { self.feedbackString($0) }
                let text = feedbackStrings.joined(separator: ". ")
                let isFlippable = !feedbackSet.contains(.objectNotFlippable)
                let userCompletedPass = feedbackSet.contains(.overCapturing)
                self.channel?.invokeMethod("onGuidance", arguments: [
                    "guidance": text.isEmpty ? "Slowly orbit the object" : text,
                    "isFlippable": isFlippable,
                    "scanPassComplete": userCompletedPass,
                ])
            }
        }
    }

    /// Transition to detecting state — shows bounding box for user to frame object.
    private func startDetecting(result: @escaping FlutterResult) {
        guard let session = session else {
            result(FlutterError(code: "NO_SESSION", message: "No active session", details: nil))
            return
        }
        session.startDetecting()
        result(nil)
    }

    /// Transition to capturing state — begins guided orbit capture.
    /// Call after the user has framed the object in the bounding box.
    private func startCapturing(result: @escaping FlutterResult) {
        guard let session = session else {
            result(FlutterError(code: "NO_SESSION", message: "No active session", details: nil))
            return
        }
        session.startCapturing()
        result(nil)
    }

    /// Request a single manual image capture (legacy — for non-guided flow).
    private func startCapture(result: @escaping FlutterResult) {
        guard let session = session else {
            result(FlutterError(code: "NO_SESSION", message: "No active session", details: nil))
            return
        }

        if session.canRequestImageCapture {
            session.requestImageCapture()
            result(nil)
        } else {
            result(FlutterError(
                code: "CANNOT_CAPTURE",
                message: "Session is not ready for capture",
                details: nil
            ))
        }
    }

    /// Begin a new scan pass at a different height/angle (same orientation).
    private func beginNewScanPass(result: @escaping FlutterResult) {
        guard let session = session else {
            result(FlutterError(code: "NO_SESSION", message: "No active session", details: nil))
            return
        }
        session.beginNewScanPass()
        result(nil)
    }

    /// Begin a new scan pass after flipping the object over.
    private func beginNewScanPassAfterFlip(result: @escaping FlutterResult) {
        guard let session = session else {
            result(FlutterError(code: "NO_SESSION", message: "No active session", details: nil))
            return
        }
        session.beginNewScanPassAfterFlip()
        result(nil)
    }

    private func finishSession(result: @escaping FlutterResult) {
        guard let session = session else {
            result(FlutterError(code: "NO_SESSION", message: "No active session", details: nil))
            return
        }
        session.finish()
        result(nil)
        // State observer will report .completed or .failed
    }

    private func cancelSession(result: @escaping FlutterResult) {
        cleanup()
        result(nil)
    }

    private func cleanup() {
        session?.cancel()
        stateTask?.cancel()
        shotsTask?.cancel()
        feedbackTask?.cancel()
        session = nil
    }

    private nonisolated func stateString(_ state: ObjectCaptureSession.CaptureState) -> String {
        switch state {
        case .initializing: return "initializing"
        case .ready: return "ready"
        case .detecting: return "detecting"
        case .capturing: return "capturing"
        case .finishing: return "finishing"
        case .completed: return "completed"
        case .failed: return "failed"
        @unknown default: return "unknown"
        }
    }

    private nonisolated func feedbackString(_ feedback: ObjectCaptureSession.Feedback) -> String {
        switch feedback {
        case .objectTooClose: return "Move further away"
        case .objectTooFar: return "Move closer"
        case .movingTooFast: return "Slow down"
        case .objectNotFlippable: return "Object cannot be flipped"
        case .environmentLowLight: return "Need more light"
        case .environmentTooDark: return "Too dark"
        case .outOfFieldOfView: return "Object out of view"
        case .objectNotDetected: return "Point at the hearing aid"
        @unknown default: return "Keep going"
        }
    }
}

/// Register the plugin with the Flutter engine.
class ObjectCapturePluginRegistrar {
    /// Stored so the plugin can register platform view factories later.
    static var flutterRegistrar: FlutterPluginRegistrar?

    /// Keep a strong reference — prevents the plugin from being GC'd,
    /// which would silently drop all method channel calls.
    @available(iOS 17.0, *)
    private static var _plugin: ObjectCapturePlugin?

    static func register(with messenger: FlutterBinaryMessenger, registrar: FlutterPluginRegistrar? = nil) {
        flutterRegistrar = registrar
        if #available(iOS 17.0, *) {
            _plugin = ObjectCapturePlugin(messenger: messenger)
        }
    }
}
