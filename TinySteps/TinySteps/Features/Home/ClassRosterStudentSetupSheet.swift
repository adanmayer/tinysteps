import SwiftUI
import Combine
import AVFoundation
import UIKit
import ImageIO
import Vision

struct ClassRosterStudentSetupSheet: View {
    let student: ClassRosterStudent
    let onDismiss: () -> Void
    let onSetupCompleted: () -> Void
    let faceEnrollmentStore: FaceEnrollmentStore

    private let requiredPhotoCount = 3
    private let photoSlotSpacing: CGFloat = 16
    private let maxPhotoSlotSize: CGFloat = 112

    @StateObject private var cameraManager = FaceEnrollmentCameraManager()
    @State private var capturedPhotos: [UIImage] = []
    @State private var isSaving = false
    @State private var setupError: String?
    @State private var showsPrivacyInfo = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#F5EDE0")
                    .ignoresSafeArea()

                if student.needsFaceEnrollment {
                    enrollmentBody
                } else {
                    alreadySetupBody
                }
            }
            .onAppear {
                capturedPhotos = []
                setupError = nil
                if student.needsFaceEnrollment {
                    Task {
                        await cameraManager.start()
                        cameraManager.setPoseRequirement(capturedPhotoCount)
                    }
                }
            }
            .onChange(of: capturedPhotoCount) { _, newCapturedPhotoCount in
                guard student.needsFaceEnrollment else { return }
                cameraManager.setPoseRequirement(newCapturedPhotoCount)
            }
            .onDisappear {
                cameraManager.stop()
            }
            .navigationBarBackButtonHidden(true)
        }
    }

    private var enrollmentBody: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                topNavigationBar

                headline
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                photoStrip
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                viewfinder
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                captureRow
                    .padding(.horizontal, 24)
                    .padding(.top, 18)

                if let setupError {
                    Text(setupError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                }

                Spacer(minLength: 22)
            }
            .padding(.top, 8)
        }
        .alert("Photos stay on this \(deviceType).", isPresented: $showsPrivacyInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("They never leave this \(deviceType). We use them only to match faces in today's photos, and you can delete them any time from \(displayName)'s profile.")
        }
    }

    private var alreadySetupBody: some View {
        VStack(spacing: 14) {
            Button(action: onDismiss) {
                HStack(spacing: 10) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: "#3A342E"))
                    Text("Close")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color(hex: "#3A342E"))
                }
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(Color(hex: "#FFFDF8"))
                .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 16)
            .padding(.horizontal, 24)

            Text("Face setup is ready for \(displayName).")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color(hex: "#3A342E"))
                .padding(.horizontal, 24)
                .padding(.top, 6)

            Text("You can return here to re-take photos in the future.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var topNavigationBar: some View {
        ZStack {
            Text("Step \(currentStep) of \(requiredPhotoCount)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "#3A342E"))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(hex: "#FFFDF8"))
                .clipShape(Capsule())

            HStack {
                Button(action: onDismiss) {
                    Circle()
                        .fill(Color(hex: "#FFFDF8"))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "xmark")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color(hex: "#3A342E"))
                        )
                        .overlay(
                            Circle()
                                .stroke(Color(hex: "#E6D8C2"), lineWidth: 1)
                        )
                }
                .accessibilityLabel("Close")

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(hex: "#A89E8F"))
                        .frame(minWidth: 42, minHeight: 44)
                }
                .accessibilityLabel("Cancel face setup")
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var headline: some View {
        VStack(spacing: 12) {
            Text("Let's help TinySteps recognise \(displayName).")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color(hex: "#3A342E"))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text("One quick photo at a time — we'll do 3 in total.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }

    private var photoStrip: some View {
        GeometryReader { geometry in
            let slotSize = min(
                maxPhotoSlotSize,
                max(92, (geometry.size.width - (photoSlotSpacing * CGFloat(requiredPhotoCount - 1))) / CGFloat(requiredPhotoCount))
            )

            HStack(spacing: photoSlotSpacing) {
                ForEach(0..<requiredPhotoCount, id: \.self) { index in
                    VStack(spacing: 8) {
                        faceSlot(for: index, size: slotSize)
                        caption(for: index)
                    }
                    .frame(width: slotSize)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(height: maxPhotoSlotSize + 28)
    }

    private func faceSlot(for index: Int, size: CGFloat) -> some View {
        let state = slotState(for: index)
        return ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            state == .empty ? Color(hex: "#8DA67A").opacity(0.55) : Color(hex: "#8DA67A"),
                            style: state == .empty ? StrokeStyle(lineWidth: 2, dash: [7, 5]) : StrokeStyle(lineWidth: state == .active ? 3 : 2)
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                )
                .overlay(
                    Group {
                        if state == .active {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(hex: "#F3E2BA"), lineWidth: 2)
                                .shadow(color: Color(hex: "#8DA67A").opacity(0.35), radius: 8)
                        }
                    }
                )
                .overlay(
                    Group {
                        if state == .active {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(hex: "#8DA67A"), lineWidth: 1.5)
                                .shadow(color: Color(hex: "#8DA67A").opacity(0.45), radius: 12, x: 0, y: 0)
                        }
                    }
                )
                .overlay(alignment: .center) {
                    if state == .empty || state == .active || state == .completed {
                        poseImage(for: index)
                            .padding(size * 0.08)
                            .opacity(state == .active ? 0.95 : 0.55)
                            .saturation(state == .active ? 0.95 : 0.72)
                            .transaction { transaction in
                                transaction.animation = nil
                            }
                            .accessibilityHidden(true)
                    }
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                .transaction { transaction in
                    transaction.animation = nil
                }

            if state == .completed {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color(hex: "#8DA67A"))
                    .background(
                        Circle()
                            .fill(Color(hex: "#FFFDF8"))
                            .frame(width: 24, height: 24)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(8)
            }
        }
    }

    private func poseAssetName(for index: Int) -> String {
        switch index {
        case 0:
            return "FaceEnrollmentStraightAhead"
        case 1:
            return "FaceEnrollmentSlightTurn"
        default:
            return "FaceEnrollmentBigSmile"
        }
    }

    @ViewBuilder
    private func poseImage(for index: Int) -> some View {
        let name = poseAssetName(for: index)
        if let uiImage = UIImage(named: name, in: .main, with: nil) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
        } else {
            #if DEBUG
            Image(systemName: "questionmark.circle")
                .resizable()
                .scaledToFit()
            #else
            Image(systemName: "person.crop.circle")
                .resizable()
                .scaledToFit()
            #endif
        }
    }

    private var viewfinder: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#F8EEE3"),
                            Color(hex: "#F2E3D0")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if cameraManager.isReady {
                FaceEnrollmentCameraPreview(
                    session: cameraManager.session,
                    isFrontCamera: cameraManager.currentPosition == .front
                )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .accessibilityHidden(true)
            } else {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#EFE2CF").opacity(0.7))
                        .blur(radius: 32)
                        .frame(width: 240, height: 240)
                        .offset(y: 52)

                    VStack(spacing: 14) {
                        Spacer()

                        if let cameraError = cameraManager.errorMessage {
                            Text(cameraError)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 18)
                        } else {
                            ProgressView()
                                .tint(Color(hex: "#8DA67A"))
                            Text("Preparing camera…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                }
            }

            VStack(spacing: 0) {
                viewfinderStatusRow
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                Spacer(minLength: 18)

                cameraGuide
                    .frame(width: 198, height: 198)

                Spacer(minLength: 22)
            }
        }
        .frame(height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
    }

    private var viewfinderStatusRow: some View {
        let isLightingGood = cameraManager.isLightingGood
        let instructionIndex = min(capturedPhotoCount, requiredPhotoCount - 1)
        let currentInstruction = promptText(for: instructionIndex)
        let poseState = cameraManager.poseValidationState
        let instructionColor = poseState.isAligned ? Color(hex: "#3A342E") : Color(hex: "#AD3A30")
        let poseText = poseState.isAligned ? currentInstruction : poseState.message
        let lightStateKnown = isLightingGood != nil
        let isGoodLighting = isLightingGood == true
        let lightLabel = lightStateKnown ? (isGoodLighting ? "Good light" : "Low light") : "Checking light"
        let lightIcon = lightStateKnown && isGoodLighting ? "sun.max.fill" : "exclamationmark.triangle.fill"
        let lightBadgeColor: Color = lightStateKnown && isGoodLighting
            ? Color(hex: "#8DA67A").opacity(0.92)
            : Color(hex: "#EAB7A9").opacity(0.88)
        let lightTextColor: Color = lightStateKnown && isGoodLighting
            ? Color(hex: "#3A342E")
            : Color(red: 0.72, green: 0.08, blue: 0.07)

        return HStack(spacing: 10) {
            Text(poseText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(instructionColor)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(hex: "#FFFDF8").opacity(0.82))
                .clipShape(Capsule())

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: lightIcon)
                    .font(.system(size: 12, weight: .semibold))
                Text(lightLabel)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(lightTextColor)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(lightBadgeColor)
            .clipShape(Capsule())
        }
    }

    private var cameraGuide: some View {
        return ZStack {
            Image(systemName: "face.smiling")
                .font(.system(size: 62, weight: .thin))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color(hex: "#8DA67A").opacity(0.32))
        }
        .frame(width: 198, height: 198, alignment: .center)
    }

    private var captureRow: some View {
        ZStack {
            HStack {
                Button {
                    showsPrivacyInfo = true
                } label: {
                    Circle()
                        .fill(Color(hex: "#FFFDF8"))
                        .frame(width: 38, height: 38)
                        .overlay(
                            Image(systemName: "info")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color(hex: "#6E6456"))
                        )
                        .overlay(
                            Circle()
                                .stroke(Color(hex: "#E6D8C2"), lineWidth: 1)
                        )
                }
                .accessibilityLabel("Privacy information")
                .frame(width: 104, alignment: .leading)
                .padding(.leading, 14)
                flipCameraButton
                    .frame(width: 104, alignment: .trailing)
                    .padding(.trailing, 14)
                
                Spacer()
            }

            shutterButton
        }
        .frame(height: 104)
    }

    private var shutterButton: some View {
        Button {
            Task {
                await captureCurrentPhoto()
            }
        } label: {
            Rectangle()
                .fill(Color(hex: "#8DA67A"))
                .frame(width: 84, height: 84)
                .overlay(
                    Image(systemName: capturedPhotoCount >= requiredPhotoCount
                               ? symbol(for: "checkmark", fallback: "checkmark")
                               : symbol(for: "camera", fallback: "camera"))
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.white)
                )
        }
        .buttonStyle(.plain)
        .disabled(
            isSaving
            || capturedPhotoCount >= requiredPhotoCount
            || !cameraManager.canCapture
            || !cameraManager.poseValidationState.isAligned
        )
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private func symbol(for preferred: String, fallback: String) -> String {
        if UIImage(systemName: preferred) != nil {
            return preferred
        }
        return fallback
    }

    private var flipCameraButton: some View {
        Button {
            cameraManager.toggleCamera()
        } label: {
            Circle()
                .fill(Color(hex: "#FFFDF8"))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(hex: "#3A342E"))
                )
                .overlay(
                    Circle()
                        .stroke(Color(hex: "#E6D8C2"), lineWidth: 1)
                )
        }
        .disabled(isSaving || !cameraManager.canCapture)
        .accessibilityLabel("Switch camera")
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private func caption(for index: Int) -> some View {
        let state = slotState(for: index)
        let actionText = promptText(for: index)
        let title: String
        let styleColor: Color

        title = state == .active ? "\(actionText) · capturing…" : actionText

        styleColor = state == .empty ? Color(hex: "#A89E8F") : Color(hex: "#8DA67A")
        return Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(styleColor)
            .multilineTextAlignment(.center)
            .frame(height: 18)
    }

    private func promptText(for index: Int) -> String {
        switch index {
        case 0:
            return "Look straight into camera"
        case 1:
            return "Slight turn to the left"
        default:
            return "Please smile"
        }
    }

    private var currentStep: Int {
        if capturedPhotoCount >= requiredPhotoCount {
            return requiredPhotoCount
        }
        return capturedPhotoCount + 1
    }

    private var capturedPhotoCount: Int {
        capturedPhotos.count
    }

    private enum SlotState {
        case empty
        case active
        case completed
    }

    private func slotState(for index: Int) -> SlotState {
        if index < capturedPhotoCount {
            return .completed
        }
        if index == capturedPhotoCount && capturedPhotoCount < requiredPhotoCount {
            return .active
        }
        return .empty
    }

    @MainActor
    private func captureCurrentPhoto() async {
        guard isSaving == false else {
            return
        }

        guard cameraManager.canCapture else {
            return
        }

        guard cameraManager.poseValidationState.isAligned else {
            setupError = "Adjust your pose to match the instruction."
            return
        }

        guard capturedPhotoCount < requiredPhotoCount else {
            onSetupCompleted()
            return
        }

        setupError = nil
        do {
            let capturedPhoto = try await cameraManager.capturePhoto()
            capturedPhotos.append(capturedPhoto)
        } catch {
            setupError = error.localizedDescription
            return
        }

        guard capturedPhotoCount == requiredPhotoCount else {
            return
        }

        await saveEnrollment()
    }

    @MainActor
    private func saveEnrollment() async {
        isSaving = true
        setupError = nil
        do {
            try await faceEnrollmentStore.upsertEnrollment(
                for: student.studentKey,
                displayName: student.displayName,
                photoCount: capturedPhotoCount
            )
            onSetupCompleted()
        } catch {
            if capturedPhotos.count >= requiredPhotoCount {
                capturedPhotos.removeLast()
            }
            setupError = error.localizedDescription
            isSaving = false
        }
    }

    private var displayName: String {
        let rawName: String
        if student.firstName.isEmpty == false {
            rawName = student.firstName
        } else {
            rawName = student.displayName
        }

        guard let firstCharacter = rawName.first else {
            return rawName
        }
        return firstCharacter.uppercased() + String(rawName.dropFirst())
    }

    private var deviceType: String {
        switch UIDevice.current.userInterfaceIdiom {
        case .pad:
            return "iPad"
        case .phone:
            return "iPhone"
        default:
            return "device"
        }
    }

    private final class FaceEnrollmentCameraManager: NSObject,
                                                    ObservableObject,
                                                    AVCapturePhotoCaptureDelegate,
                                                    AVCaptureVideoDataOutputSampleBufferDelegate {
        enum CameraError: LocalizedError {
            case captureInProgress
            case noCameraPermission
            case noCameraAvailable
            case sessionInactive
            case photoDataMissing

            var errorDescription: String? {
                switch self {
                case .captureInProgress:
                    return "A photo is already being captured."
                case .noCameraPermission:
                    return "Camera permission is required to enroll faces."
                case .noCameraAvailable:
                    return "No camera is available on this device."
                case .sessionInactive:
                    return "Camera session is not running."
                case .photoDataMissing:
                    return "Unable to decode captured photo."
                }
            }
        }

        enum PoseStep: Int {
            case straightAhead = 0
            case slightTurnLeft = 1
            case smile = 2

            static func from(_ index: Int) -> PoseStep {
                switch PoseStep(rawValue: index) {
                case .some(let value):
                    return value
                case .none:
                    return .straightAhead
                }
            }

            var label: String {
                switch self {
                case .straightAhead:
                    return "Look straight into camera"
                case .slightTurnLeft:
                    return "Slight turn to the left"
                case .smile:
                    return "Please smile"
                }
            }
        }

        enum PoseValidationState: Equatable {
            case unknown
            case noFace
            case tooManyFaces
            case guidance(String)
            case aligned

            var isAligned: Bool {
                if case .aligned = self {
                    return true
                }
                return false
            }

            var message: String {
                switch self {
                case .unknown:
                    return "Analyzing pose…"
                case .noFace:
                    return "No face detected"
                case .tooManyFaces:
                    return "Too many faces in view"
                case .guidance(let message):
                    return message
                case .aligned:
                    return "Pose matched"
                }
            }
        }

        @Published private(set) var isReady = false
        @Published private(set) var isCapturing = false
        @Published private(set) var errorMessage: String?
        @Published private(set) var currentPosition: AVCaptureDevice.Position = .back
        @Published private(set) var isLightingGood: Bool? = nil
        @Published private(set) var poseValidationState: PoseValidationState = .unknown

        let session = AVCaptureSession()

        private let sessionQueue = DispatchQueue(label: "co.faria.tinysteps.faceenrollment.camera")
        private let photoOutput = AVCapturePhotoOutput()
        private let videoOutput = AVCaptureVideoDataOutput()
        private let analysisQueue = DispatchQueue(label: "co.faria.tinysteps.faceenrollment.analysis")
        private var photoContinuation: CheckedContinuation<UIImage, Error>?
        private var currentPoseStep: PoseStep = .straightAhead
        private var lastLightingSample = Date.distantPast
        private var lastPoseSample = Date.distantPast
        private let minimumLightingSampleInterval: TimeInterval = 0.4
        private let minimumPoseSampleInterval: TimeInterval = 0.25
        private let minimumGoodLightLuma: Float = 0.36

        var canCapture: Bool {
            isReady && isCapturing == false && session.isRunning
        }

        func setPoseRequirement(_ step: Int) {
            let normalizedStep = max(0, min(step, 2))
            analysisQueue.async {
                self.currentPoseStep = PoseStep.from(normalizedStep)
                self.updatePoseValidationState(.guidance(self.currentPoseStep.label))
            }
        }

        private func updatePoseValidationState(_ state: PoseValidationState) {
            DispatchQueue.main.async {
                self.poseValidationState = state
            }
        }

        @MainActor
        func start() async {
            let authorized = await requestPermission()
            guard authorized else {
                isReady = false
                errorMessage = CameraError.noCameraPermission.errorDescription
                return
            }

            await withCheckedContinuation { continuation in
                sessionQueue.async {
                    do {
                        try self.configureSession()
                        self.session.startRunning()
                        DispatchQueue.main.async {
                            self.errorMessage = nil
                            self.currentPosition = .back
                            self.isReady = self.session.isRunning
                            continuation.resume()
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.errorMessage = error.localizedDescription
                            self.isReady = false
                            continuation.resume()
                        }
                    }
                }
            }
        }

        func stop() {
            sessionQueue.async {
                if let photoContinuation = self.photoContinuation {
                    photoContinuation.resume(throwing: CameraError.sessionInactive)
                }
                self.photoContinuation = nil
                self.session.stopRunning()
                DispatchQueue.main.async {
                    self.isReady = false
                    self.isCapturing = false
                }
            }
        }

        func toggleCamera() {
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
                        self.errorMessage = nil
                        self.currentPosition = nextPosition
                        self.isReady = wasRunning
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.errorMessage = error.localizedDescription
                        self.isReady = false
                    }
                }
            }
        }

        func capturePhoto() async throws -> UIImage {
            guard isReady else {
                throw CameraError.sessionInactive
            }
            guard session.isRunning else {
                throw CameraError.sessionInactive
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
                        DispatchQueue.main.async {
                            self.isCapturing = false
                        }
                        continuation.resume(throwing: CameraError.captureInProgress)
                        return
                    }

                    guard self.session.isRunning else {
                        DispatchQueue.main.async {
                            self.isCapturing = false
                        }
                        continuation.resume(throwing: CameraError.sessionInactive)
                        return
                    }

                    self.photoContinuation = continuation

                    self.applyPortraitVideoConnectionOrientation(to: self.photoOutput.connection(with: .video), isFrontCamera: self.currentPosition == .front)

                    let settings = AVCapturePhotoSettings()
                    DispatchQueue.main.async {
                        self.photoOutput.capturePhoto(with: settings, delegate: self)
                    }
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

            if let error {
                DispatchQueue.main.async {
                    self.isCapturing = false
                }
                continuation.resume(throwing: error)
                return
            }

            guard let data = photo.fileDataRepresentation(),
                  let image = UIImage(data: data) else {
                DispatchQueue.main.async {
                    self.isCapturing = false
                }
                continuation.resume(throwing: CameraError.photoDataMissing)
                return
            }

            DispatchQueue.main.async {
                self.isCapturing = false
            }
            continuation.resume(returning: image)
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
            case .denied, .restricted:
                return false
            default:
                return false
            }
        }

        private func configureSession(position: AVCaptureDevice.Position = .back) throws {
            session.beginConfiguration()
            defer {
                session.commitConfiguration()
            }

            session.sessionPreset = .photo
            session.inputs.forEach { session.removeInput($0) }
            session.outputs.forEach { session.removeOutput($0) }

            guard let device = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: position
            ) else {
                throw CameraError.noCameraAvailable
            }

            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                throw CameraError.noCameraAvailable
            }
            guard session.canAddOutput(photoOutput) else {
                throw CameraError.noCameraAvailable
            }
            guard session.canAddOutput(videoOutput) else {
                throw CameraError.noCameraAvailable
            }

            session.addInput(input)
            session.addOutput(photoOutput)
            session.addOutput(videoOutput)

            let isFrontCamera = position == .front
            applyPortraitVideoConnectionOrientation(to: photoOutput.connection(with: .video), isFrontCamera: isFrontCamera)
            applyPortraitVideoConnectionOrientation(to: videoOutput.connection(with: .video), isFrontCamera: isFrontCamera)

            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: analysisQueue)
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            ]
        }

        private func applyPortraitVideoConnectionOrientation(
            to connection: AVCaptureConnection?,
            isFrontCamera: Bool
        ) {
            guard let connection else {
                return
            }

            if #available(iOS 17.0, *) {
                let candidateAngles: [CGFloat] = isFrontCamera ? [270, 90] : [90, 270]
                for portraitAngle in candidateAngles {
                    if connection.isVideoRotationAngleSupported(portraitAngle) {
                        connection.videoRotationAngle = portraitAngle
                        break
                    }
                }
            } else if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }

            guard connection.isVideoMirroringSupported else {
                return
            }

            guard connection.automaticallyAdjustsVideoMirroring == false else {
                return
            }

            connection.isVideoMirrored = isFrontCamera
        }

        func captureOutput(
            _ output: AVCaptureOutput,
            didOutput sampleBuffer: CMSampleBuffer,
            from connection: AVCaptureConnection
        ) {
            guard output == videoOutput else { return }

            let now = Date()
            let shouldSampleLighting = now.timeIntervalSince(lastLightingSample) >= minimumLightingSampleInterval
            let shouldSamplePose = now.timeIntervalSince(lastPoseSample) >= minimumPoseSampleInterval
            guard shouldSampleLighting || shouldSamplePose else {
                return
            }

            if shouldSampleLighting {
                lastLightingSample = now
            }

            if shouldSamplePose {
                lastPoseSample = now
            }

            if shouldSampleLighting {
                guard let averageLuma = averageLuma(from: sampleBuffer) else {
                    return
                }

                let isGood = averageLuma >= minimumGoodLightLuma
                DispatchQueue.main.async {
                    self.isLightingGood = isGood
                }
            }

            if shouldSamplePose {
                analyzePose(from: sampleBuffer)
            }
        }

        private func analyzePose(from sampleBuffer: CMSampleBuffer) {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                updatePoseValidationState(.unknown)
                return
            }

            let orientation = imageOrientation(for: currentPosition)
            let request = VNDetectFaceLandmarksRequest()
            let requestHandler = VNImageRequestHandler(
                cvPixelBuffer: pixelBuffer,
                orientation: orientation,
                options: [:]
            )

            do {
                try requestHandler.perform([request])
            } catch {
                updatePoseValidationState(.unknown)
                return
            }

            guard let observations = request.results, observations.isEmpty == false else {
                updatePoseValidationState(.noFace)
                return
            }

            guard observations.count == 1 else {
                updatePoseValidationState(.tooManyFaces)
                return
            }

            let sortedObservations = observations.sorted {
                $0.boundingBox.width * $0.boundingBox.height >
                $1.boundingBox.width * $1.boundingBox.height
            }
            guard let mainFace = sortedObservations.first else {
                updatePoseValidationState(.noFace)
                return
            }

            let validation = evaluatePose(for: mainFace)
            updatePoseValidationState(validation)
        }

        private func evaluatePose(for faceObservation: VNFaceObservation) -> PoseValidationState {
            let yaw = faceObservation.yaw?.doubleValue ?? 0
            let pitch = faceObservation.pitch?.doubleValue ?? 0
            let roll = faceObservation.roll?.doubleValue ?? 0

            let yawDegreesSigned = yaw * 180 / .pi
            let yawDegrees = abs(yawDegreesSigned)
            let pitchDegrees = abs(pitch * 180 / .pi)
            let rollDegrees = abs(roll * 180 / .pi)
            let yawDegreesForLeftStep = (currentPosition == .front ? -yawDegreesSigned : yawDegreesSigned)

            switch currentPoseStep {
            case .straightAhead:
                if yawDegrees > 16 {
                    return .guidance("Center your face")
                }
                if pitchDegrees > 14 {
                    return .guidance("Look directly into camera")
                }
                if rollDegrees > 12 {
                    return .guidance("Keep head level")
                }
            case .slightTurnLeft:
                if yawDegreesForLeftStep < 10 {
                    return .guidance("Turn slightly left")
                }
                if yawDegreesForLeftStep > 32 {
                    return .guidance("Turn less sharply")
                }
                if rollDegrees > 14 {
                    return .guidance("Keep head level")
                }
                if pitchDegrees > 18 {
                    return .guidance("Look at the camera levelly")
                }
            case .smile:
                let smileScore = estimateSmile(from: faceObservation)
                if smileScore < 0.05 {
                    return .guidance("Please smile")
                }
                if rollDegrees > 16 {
                    return .guidance("Keep head level")
                }
                if pitchDegrees > 18 {
                    return .guidance("Keep head level with camera")
                }
            }

            return .aligned
        }

        private func estimateSmile(from faceObservation: VNFaceObservation) -> Double {
            guard let outerLips = faceObservation.landmarks?.outerLips else {
                return 0
            }

            let outerScore = mouthSmileScore(from: outerLips.normalizedPoints)
            guard let innerLips = faceObservation.landmarks?.innerLips else {
                return outerScore
            }

            let innerScore = mouthSmileScore(from: innerLips.normalizedPoints)
            return (outerScore * 0.7) + (innerScore * 0.3)
        }

        private func mouthSmileScore(from points: [CGPoint]) -> Double {
            guard points.isEmpty == false else {
                return 0
            }

            guard let left = points.min(by: { $0.x < $1.x }),
                  let right = points.max(by: { $0.x < $1.x }),
                  let top = points.min(by: { $0.y < $1.y }),
                  let bottom = points.max(by: { $0.y < $1.y }) else {
                return 0
            }

            let mouthWidth = max(0.0001, right.x - left.x)
            let mouthHeight = max(0.0001, bottom.y - top.y)
            let openness = mouthHeight / mouthWidth
            let cornerLift = ((left.y + right.y) / 2) - ((top.y + bottom.y) / 2)

            return max(0, openness * 4.0) + max(0, cornerLift * 4.0)
        }

        private func imageOrientation(for position: AVCaptureDevice.Position) -> CGImagePropertyOrientation {
            guard position == .front else {
                return .right
            }
            return .leftMirrored
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
                  let lumaBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)
            else {
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

        deinit {
            if photoContinuation != nil {
                photoContinuation?.resume(throwing: CameraError.sessionInactive)
                photoContinuation = nil
            }
            videoOutput.setSampleBufferDelegate(nil, queue: nil)
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    private struct FaceEnrollmentCameraPreview: UIViewRepresentable {
        let session: AVCaptureSession
        let isFrontCamera: Bool

        func makeUIView(context: Context) -> FaceEnrollmentCameraPreviewView {
            let view = FaceEnrollmentCameraPreviewView()
            view.videoPreviewLayer.session = session
            view.videoPreviewLayer.videoGravity = .resizeAspectFill
            return view
        }

        func updateUIView(_ uiView: FaceEnrollmentCameraPreviewView, context: Context) {
            uiView.videoPreviewLayer.session = session
            if let connection = uiView.videoPreviewLayer.connection {
                if #available(iOS 17.0, *) {
                    let candidateAngles: [CGFloat] = isFrontCamera ? [270, 90] : [90, 270]
                    for portraitAngle in candidateAngles {
                        if connection.isVideoRotationAngleSupported(portraitAngle) {
                            connection.videoRotationAngle = portraitAngle
                            break
                        }
                    }
                } else if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }

                if connection.isVideoMirroringSupported {
                    if !connection.automaticallyAdjustsVideoMirroring {
                        connection.isVideoMirrored = isFrontCamera
                    }
                }
            }
        }
    }

    private final class FaceEnrollmentCameraPreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            videoPreviewLayer.frame = bounds
        }
    }
}

#if DEBUG
#Preview {
    ClassRosterStudentSetupSheet(
        student: ClassRosterStudent(
            id: "student-id",
            studentKey: "student-id",
            displayName: "Amara Quinn",
            firstName: "Amara",
            initials: "AQ",
            avatarURL: nil,
            enrollmentStatus: .needsSetup,
            todayObservationCount: nil,
            presence: .present
        ),
        onDismiss: {},
        onSetupCompleted: {},
        faceEnrollmentStore: FaceEnrollmentStoreUnavailable()
    )
    .presentationDetents([.large])
}
#endif
