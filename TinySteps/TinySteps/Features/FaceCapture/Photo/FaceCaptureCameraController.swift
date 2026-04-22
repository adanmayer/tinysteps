import Foundation
@preconcurrency import AVFoundation
import Combine
import UIKit

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
    @Published private(set) var currentPosition: AVCaptureDevice.Position = .front
    @Published private(set) var isLightingGood: Bool?

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "co.fariasystems.tinysteps.facecapture.camera")
    private let analysisQueue = DispatchQueue(label: "co.fariasystems.tinysteps.facecapture.analysis")
    private let lightingDelegate = FaceCaptureLightingSampleDelegate()
    private var photoContinuation: CheckedContinuation<UIImage, Error>?
    private var activeDevice: AVCaptureDevice?

    override init() {
        super.init()
        lightingDelegate.onLightingChanged = { [weak self] isGood in
            Task { @MainActor in
                self?.isLightingGood = isGood
            }
        }
    }

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
                    try self.configureSession(position: self.currentPosition)
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
                self.isLightingGood = nil
            }
        }
    }

    func toggleCamera() {
        guard isCapturing == false else {
            return
        }

        let nextPosition: AVCaptureDevice.Position = currentPosition == .back ? .front : .back
        sessionQueue.async {
            let wasRunning = self.session.isRunning
            if wasRunning {
                self.session.stopRunning()
            }

            do {
                try self.configureSession(position: nextPosition)
                if wasRunning {
                    self.session.startRunning()
                }
                DispatchQueue.main.async {
                    self.currentPosition = nextPosition
                    self.currentDevice = self.activeDevice
                    self.isReady = self.session.isRunning
                    self.errorMessage = nil
                }
            } catch {
                if wasRunning {
                    self.session.startRunning()
                }
                DispatchQueue.main.async {
                    self.isReady = self.session.isRunning
                    self.errorMessage = error.localizedDescription
                }
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
                self.applyPortraitPhotoConnectionOrientation(
                    to: self.photoOutput.connection(with: .video),
                    device: self.activeDevice,
                    isFrontCamera: self.currentPosition == .front
                )
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

    private func configureSession(position: AVCaptureDevice.Position) throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .photo
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: position
        ) else {
            throw CameraError.noCamera
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input),
              session.canAddOutput(photoOutput),
              session.canAddOutput(videoOutput) else {
            throw CameraError.noCamera
        }

        session.addInput(input)
        session.addOutput(photoOutput)
        session.addOutput(videoOutput)
        activeDevice = device
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        videoOutput.setSampleBufferDelegate(lightingDelegate, queue: analysisQueue)
        applyPortraitPhotoConnectionOrientation(
            to: photoOutput.connection(with: .video),
            device: device,
            isFrontCamera: position == .front
        )
    }

    private func applyPortraitPhotoConnectionOrientation(
        to connection: AVCaptureConnection?,
        device: AVCaptureDevice?,
        isFrontCamera: Bool
    ) {
        guard let connection else {
            return
        }

        if #available(iOS 17.0, *) {
            let captureAngle = device
                .map { AVCaptureDevice.RotationCoordinator(device: $0, previewLayer: nil).videoRotationAngleForHorizonLevelCapture }
                ?? 90
            let fallbackAngle: CGFloat = isFrontCamera ? 270 : 90
            let angle = connection.isVideoRotationAngleSupported(captureAngle)
                ? captureAngle
                : fallbackAngle
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        } else if connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }

        guard connection.isVideoMirroringSupported else {
            return
        }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = isFrontCamera
    }

    deinit {
        if photoContinuation != nil {
            photoContinuation?.resume(throwing: CameraError.inactive)
            photoContinuation = nil
        }
        videoOutput.setSampleBufferDelegate(nil, queue: nil)
        if session.isRunning {
            session.stopRunning()
        }
    }
}

private final class FaceCaptureLightingSampleDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var onLightingChanged: ((Bool) -> Void)?

    private var lastLightingSample = Date.distantPast
    private let minimumLightingSampleInterval: TimeInterval = 0.4
    private let minimumGoodLightLuma: Float = 0.36

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = Date()
        guard now.timeIntervalSince(lastLightingSample) >= minimumLightingSampleInterval else {
            return
        }
        lastLightingSample = now

        guard let averageLuma = averageLuma(from: sampleBuffer) else {
            return
        }

        onLightingChanged?(averageLuma >= minimumGoodLightLuma)
    }

    private func averageLuma(from sampleBuffer: CMSampleBuffer) -> Float? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }

        let status = CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        guard status == kCVReturnSuccess else {
            return nil
        }
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        }

        guard CVPixelBufferGetPlaneCount(pixelBuffer) >= 1,
              let lumaBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else {
            return nil
        }

        let lumaWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let lumaHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        let lumaBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        let y = lumaBaseAddress.assumingMemoryBound(to: UInt8.self)

        let rowStep = max(1, lumaHeight / 20)
        let colStep = max(1, lumaWidth / 20)
        var sum: UInt64 = 0
        var samples = 0

        var row = 0
        while row < lumaHeight {
            let rowBase = y.advanced(by: row * lumaBytesPerRow)
            var col = 0
            while col < lumaWidth {
                sum += UInt64(rowBase[col])
                samples += 1
                col += colStep
            }
            row += rowStep
        }

        guard samples > 0 else {
            return nil
        }

        return Float(sum) / Float(samples) / 255.0
    }
}
