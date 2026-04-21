import Foundation
import AVFoundation
import Combine
import UIKit

@MainActor
final class FaceCaptureCameraController: NSObject,
                                        ObservableObject,
                                        AVCapturePhotoCaptureDelegate {
    enum CameraError: LocalizedError {
        case noPermission
        case noCamera
        case inactive
        case captureInProgress
        case photoMissing

        var errorDescription: String? {
            switch self {
            case .noPermission:
                return "Camera permission is required to capture photos."
            case .noCamera:
                return "No camera is available on this device."
            case .inactive:
                return "The camera is not ready."
            case .captureInProgress:
                return "A photo is already being captured."
            case .photoMissing:
                return "Unable to decode the captured photo."
            }
        }
    }

    @Published private(set) var isReady = false
    @Published private(set) var isCapturing = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var currentDevice: AVCaptureDevice?

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "co.fariasystems.tinysteps.facecapture.camera")
    private var photoContinuation: CheckedContinuation<UIImage, Error>?
    private var activeDevice: AVCaptureDevice?

    var previewSession: AVCaptureSession {
        session
    }

    func start() async {
        let permission = await requestPermission()
        guard permission else {
            await MainActor.run {
                isReady = false
                errorMessage = CameraError.noPermission.localizedDescription
            }
            return
        }

        await withCheckedContinuation { continuation in
            sessionQueue.async {
                do {
                    try self.configureSession()
                    self.session.startRunning()
                    DispatchQueue.main.async {
                        self.isReady = self.session.isRunning
                        self.currentDevice = self.activeDevice
                        self.errorMessage = nil
                        continuation.resume()
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.isReady = false
                        self.errorMessage = error.localizedDescription
                        continuation.resume()
                    }
                }
            }
        }
    }

    func stop() {
        sessionQueue.async {
            if let photoContinuation = self.photoContinuation {
                photoContinuation.resume(throwing: CameraError.inactive)
                self.photoContinuation = nil
            }

            if self.session.isRunning {
                self.session.stopRunning()
            }
            DispatchQueue.main.async {
                self.isReady = false
                self.isCapturing = false
                self.currentDevice = nil
            }
        }
    }

    func capturePhoto() async throws -> UIImage {
        guard isReady, session.isRunning else {
            throw CameraError.inactive
        }
        guard isCapturing == false else {
            throw CameraError.captureInProgress
        }
        guard photoContinuation == nil else {
            throw CameraError.captureInProgress
        }

        isCapturing = true

        return try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async {
                guard self.photoContinuation == nil else {
                    DispatchQueue.main.async { self.isCapturing = false }
                    continuation.resume(throwing: CameraError.captureInProgress)
                    return
                }
                guard self.session.isRunning else {
                    DispatchQueue.main.async { self.isCapturing = false }
                    continuation.resume(throwing: CameraError.inactive)
                    return
                }

                self.photoContinuation = continuation
                self.photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
            }
        }
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard let continuation = photoContinuation else {
            return
        }
        photoContinuation = nil

        let photoData = photo.fileDataRepresentation()

        Task { @MainActor in
            if let error {
                self.isCapturing = false
                continuation.resume(throwing: error)
                return
            }

            guard let data = photoData,
                  let image = UIImage(data: data) else {
                self.isCapturing = false
                continuation.resume(throwing: CameraError.photoMissing)
                return
            }

            self.isCapturing = false
            continuation.resume(returning: image)
        }
    }

    private func requestPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
        default:
            return false
        }
    }

    private func configureSession() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .photo
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .front
        ) else {
            throw CameraError.noCamera
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input), session.canAddOutput(photoOutput) else {
            throw CameraError.noCamera
        }

        session.addInput(input)
        session.addOutput(photoOutput)
        if let photoConnection = photoOutput.connection(with: .video) {
            if photoConnection.isVideoOrientationSupported {
                photoConnection.videoOrientation = .portrait
            }
            if photoConnection.isVideoMirroringSupported {
                photoConnection.isVideoMirrored = true
            }
        }
        activeDevice = device
    }

    deinit {
        if photoContinuation != nil {
            photoContinuation?.resume(throwing: CameraError.inactive)
            photoContinuation = nil
        }
        if session.isRunning {
            session.stopRunning()
        }
    }
}
