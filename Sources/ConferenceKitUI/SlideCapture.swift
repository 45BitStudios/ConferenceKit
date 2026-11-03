import Foundation
import Observation
#if os(iOS)
import AVFoundation

/// Owns the rear camera while the cover-display companion is on.
/// Alarm-style entitlements are unrelated. The host still supplies `NSCameraUsageDescription`.
@Observable
@MainActor
final class SlideCaptureController {
    static let shared = SlideCaptureController()

    private let engine = SlideCaptureEngine()
    var isRunning = false
    var statusMessage: String?

    func start() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            let allowed = await AVCaptureDevice.requestAccess(for: .video)
            guard allowed else {
                statusMessage = "Camera access was denied."
                isRunning = false
                return false
            }
        default:
            statusMessage = "Camera access was denied."
            isRunning = false
            return false
        }
        let engine = self.engine
        let running = await Task.detached { engine.start() }.value
        isRunning = running
        if !running { statusMessage = "The camera could not start." }
        return running
    }

    func stop() {
        let engine = self.engine
        Task.detached { engine.stop() }
        isRunning = false
    }

    func takePhoto() async -> Data? {
        guard isRunning else { return nil }
        let engine = self.engine
        return await withCheckedContinuation { continuation in
            engine.capture { data in
                continuation.resume(returning: data)
            }
        }
    }

    func previewSession() -> AVCaptureSession { engine.session }
}

final class SlideCaptureEngine: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let lock = NSLock()
    private var handler: ((Data?) -> Void)?

    func start() -> Bool {
        session.beginConfiguration()
        session.sessionPreset = .photo
        let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(for: .video)
        guard let device, let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            session.commitConfiguration()
            return false
        }
        if session.inputs.isEmpty { session.addInput(input) }
        if session.canAddOutput(output) && !session.outputs.contains(where: { $0 === output }) {
            session.addOutput(output)
        }
        session.commitConfiguration()
        if !session.isRunning { session.startRunning() }
        return session.isRunning
    }

    func stop() {
        if session.isRunning { session.stopRunning() }
    }

    func capture(handler: @escaping (Data?) -> Void) {
        lock.lock()
        self.handler = handler
        lock.unlock()
        output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let data = error == nil ? photo.fileDataRepresentation() : nil
        lock.lock()
        let handler = self.handler
        self.handler = nil
        lock.unlock()
        handler?(data)
    }
}
#else
@Observable
@MainActor
final class SlideCaptureController {
    static let shared = SlideCaptureController()
    var isRunning = false
    var statusMessage: String?
    func start() async -> Bool {
        statusMessage = "The camera is only available on iPhone and iPad."
        return false
    }
    func stop() {}
    func takePhoto() async -> Data? { nil }
}
#endif
