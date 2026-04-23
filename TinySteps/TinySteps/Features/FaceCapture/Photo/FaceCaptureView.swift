import SwiftUI
import AVFoundation
import UIKit
import MBAPI

struct FaceCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: FaceCaptureViewModel
    @State private var isShowingAssignment = false
    @State private var isShowingChildVoiceCapture = false
    private let onSaved: () -> Void

    init(
        session: AuthSession,
        captureSession: FaceCaptureSession,
        faceEnrollmentStore: FaceEnrollmentStore,
        draftStore: FaceCaptureDraftStore,
        onSaved: @escaping () -> Void = {}
    ) {
        _viewModel = StateObject(
            wrappedValue: FaceCaptureViewModel(
                session: session,
                classID: captureSession.classID,
                className: captureSession.className,
                candidateStudents: captureSession.rosterSnapshot,
                faceEnrollmentStore: faceEnrollmentStore,
                draftStore: draftStore,
                initialDraft: captureSession.initialDraft
            )
        )
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            captureContent
            .onAppear {
                viewModel.start()
            }
            .onDisappear {
                viewModel.stop()
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
            .onChange(of: viewModel.state) { _, newState in
                if case .saved = newState {
                    onSaved()
                    dismiss()
                }
            }
            .sheet(isPresented: $isShowingAssignment) {
                if let selectedFace = viewModel.selectedFace {
                    let targetKey: String? = {
                        if case .matched(let studentKey, _, _) = selectedFace.label {
                            return studentKey
                        }
                        return nil
                    }()
                    FaceAssignmentPicker(
                        students: viewModel.candidateStudents.compactMap {
                            ClassRosterStudent(
                                id: $0.studentKey,
                                studentKey: $0.studentKey,
                                userID: $0.userID,
                                displayName: $0.displayName,
                                firstName: $0.displayName,
                                initials: "",
                                avatarURL: nil,
                                enrollmentStatus: .needsSetup,
                                todayObservationCount: nil,
                                presence: .present
                            )
                        },
                        selectedStudentKey: targetKey
                    ) { selectedKey in
                        isShowingAssignment = false
                        if let selectedKey {
                            viewModel.assignStudent(selectedKey)
                        } else {
                            viewModel.clearSelectedFace()
                        }
                    }
                    .presentationDetents([.medium])
                }
            }
            .sheet(isPresented: $isShowingChildVoiceCapture) {
                if let targetChild = viewModel.childVoiceTarget {
                    ChildVoiceCaptureView(
                        session: ChildVoiceCaptureSession(
                            mode: .photoAttachment(
                                classID: viewModel.classID,
                                className: viewModel.className,
                                child: targetChild
                            )
                        ),
                        onSaved: { draft in
                            viewModel.setChildVoiceDraft(draft)
                        }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var captureContent: some View {
        if case .reviewing = viewModel.state, let image = viewModel.capturedImage {
            reviewContent(image: image)
        } else {
            liveCaptureContent
        }
    }

    private var liveCaptureContent: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            cameraPreview
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .background(Color(hex: "#FBF6EE").opacity(0.94))

                liveStatusRow
                    .padding(.horizontal, 18)
                    .padding(.top, 14)

                Spacer()

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(hex: "#FEF7F0"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(hex: "#A92E2E").opacity(0.88))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 22)
                        .padding(.bottom, 14)
                }

                liveCaptureControls
                    .padding(.bottom, 22)
            }
        }
    }

    private func reviewContent(image: UIImage) -> some View {
        ZStack {
            Color(hex: "#FBF6EE")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .background(Color(hex: "#FBF6EE"))

                photoReviewView(image: image)
                    .frame(maxHeight: .infinity)
                    .clipped()

                reviewActionBar
                    .padding(.horizontal, 18)
                    .padding(.top, 24)
                    .padding(.bottom, 26)
                    .background(Color(hex: "#FBF6EE"))
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Circle()
                    .fill(Color(hex: "#FFFDF8"))
                    .frame(width: 38, height: 38)
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(hex: "#3A342E"))
                    )
            }

            Spacer()

            Text("Photo")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color(hex: "#3A342E"))

            Spacer()

            HStack(spacing: 8) {
                if case .reviewing = viewModel.state {
                    Button {
                    } label: {
                        Text("TYPE")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(hex: "#7C9A68"))
                            .frame(width: 72, height: 36)
                            .background(Color(hex: "#E8EDDE").opacity(0.78))
                            .overlay(
                                Capsule()
                                    .stroke(Color(hex: "#D4DDC8"), lineWidth: 1)
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Photo type")
                } else {
                    Button {
                        viewModel.toggleCamera()
                    } label: {
                        Image(systemName: "camera.rotate")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(viewModel.canSwitchCamera ? Color(hex: "#8DA67A") : Color(hex: "#A89E8F"))
                            .frame(width: 38, height: 38)
                            .background(
                                (viewModel.canSwitchCamera ? Color(hex: "#8DA67A") : Color(hex: "#D8CEBD"))
                                    .opacity(0.2)
                            )
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.canSwitchCamera == false)
                    .accessibilityLabel("Switch camera")
                }
            }
            .font(.system(size: 12))
        }
    }

    private var cameraPreview: some View {
        ZStack {
            FaceCapturePreview(
                session: viewModel.cameraPreviewSession,
                device: viewModel.cameraDevice,
                isFrontCamera: viewModel.isFrontCamera
            )

            if viewModel.isCameraReady == false {
                Color.black.opacity(0.34)
                ProgressView("Starting camera...")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "#FEF7F0"))
                    .tint(Color(hex: "#FEF7F0"))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.38))
                    .clipShape(Capsule())
            }
        }
    }

    private var liveStatusRow: some View {
        HStack(spacing: 10) {
            Text(liveInstructionText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: "#3A342E"))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color(hex: "#FFFDF8").opacity(0.84))
                .clipShape(Capsule())

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: lightingIcon)
                    .font(.system(size: 12, weight: .semibold))

                Text(lightingLabel)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(lightingTextColor)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(lightingBadgeColor)
            .clipShape(Capsule())
        }
    }

    private var liveCaptureControls: some View {
        ZStack {
            if case .failed = viewModel.state {
                Button {
                    viewModel.reset()
                    viewModel.start()
                } label: {
                    Text("Try again")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(height: 56)
                        .frame(maxWidth: .infinity)
                        .background(Color(hex: "#8DA67A"))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 28)
            } else {
                Button {
                    viewModel.capturePhoto()
                } label: {
                    ZStack {
                        Circle()
                            .fill(liveCaptureButtonFill)

                        Circle()
                            .stroke(liveCaptureOuterRing, lineWidth: 4)
                            .padding(3)

                        Circle()
                            .stroke(liveCaptureInnerRing, lineWidth: 2)
                            .padding(10)

                        if viewModel.state == .capturing || viewModel.state == .processing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(liveCaptureIconColor)
                        }
                    }
                    .frame(width: 84, height: 84)
                    .contentShape(Circle())
                    .shadow(
                        color: liveCanCapture ? Color(hex: "#6F9258").opacity(0.36) : .clear,
                        radius: 8,
                        x: 0,
                        y: 4
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                liveCanCapture ? Color(hex: "#8DA67A") : Color(hex: "#C8B7A6"),
                                lineWidth: liveCanCapture ? 2 : 1
                            )
                            .opacity(liveCanCapture ? 0.86 : 0.6)
                    )
                }
                .buttonStyle(.plain)
                .disabled(liveCanCapture == false)
                .accessibilityLabel(liveCanCapture ? "Take photo" : "Take photo unavailable")
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 104)
    }

    private var reviewActionBar: some View {
        VStack(spacing: 18) {
            Text("Keep saves and takes you to the draft sheet.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "#6E6456"))

            HStack(spacing: 20) {
                Button(action: {
                    viewModel.retake()
                }) {
                    Text("Retake")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(height: 68)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(Color(hex: "#3A342E"))
                        .background(Color(hex: "#FBF6EE"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color(hex: "#E1D7C6"), lineWidth: 1.2)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                }
                .buttonStyle(.plain)

                Button(action: {
                    isShowingChildVoiceCapture = true
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "waveform.circle.fill")
                        Text(viewModel.childVoiceDraft == nil ? "Capture child voice" : "Replace child voice")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .frame(height: 68)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(Color(hex: "#3A342E"))
                    .background(Color(hex: "#F1F5EA"))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color(hex: "#D6DECD"), lineWidth: 1.2)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.isChildVoiceButtonEnabled)
                .opacity(viewModel.isChildVoiceButtonEnabled ? 1 : 0.5)

                Button(action: {
                    viewModel.keep()
                }) {
                    HStack(spacing: 12) {
                        Text("Keep")
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22, weight: .semibold))
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .frame(height: 68)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.white)
                    .background(Color(hex: "#8DA67A"))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                }
                .disabled(viewModel.canKeep == false)
                .opacity(viewModel.canKeep ? 1 : 0.6)
            }
        }
    }

    private var liveCanCapture: Bool {
        viewModel.state == .ready && viewModel.isCameraReady
    }

    private var liveInstructionText: String {
        switch viewModel.state {
        case .requestingPermission:
            return "Preparing camera"
        case .capturing:
            return "Capturing photo"
        case .processing:
            return "Finding faces"
        case .failed:
            return "Camera needs attention"
        default:
            return "Frame the class photo"
        }
    }

    private var lightingLabel: String {
        guard let isLightingGood = viewModel.isLightingGood else {
            return "Checking light"
        }
        return isLightingGood ? "Good light" : "Low light"
    }

    private var lightingIcon: String {
        guard let isLightingGood = viewModel.isLightingGood else {
            return "exclamationmark.triangle.fill"
        }
        return isLightingGood ? "sun.max.fill" : "exclamationmark.triangle.fill"
    }

    private var lightingBadgeColor: Color {
        guard let isLightingGood = viewModel.isLightingGood else {
            return Color(hex: "#EAB7A9").opacity(0.88)
        }
        return isLightingGood
            ? Color(hex: "#8DA67A").opacity(0.92)
            : Color(hex: "#EAB7A9").opacity(0.88)
    }

    private var lightingTextColor: Color {
        guard let isLightingGood = viewModel.isLightingGood else {
            return Color(red: 0.72, green: 0.08, blue: 0.07)
        }
        return isLightingGood
            ? Color(hex: "#3A342E")
            : Color(red: 0.72, green: 0.08, blue: 0.07)
    }

    private var liveCaptureButtonFill: Color {
        liveCanCapture ? Color(hex: "#6F9258") : Color(hex: "#D7CBBB")
    }

    private var liveCaptureOuterRing: Color {
        liveCanCapture ? Color(hex: "#D9EDCC") : Color(hex: "#EFE3D1")
    }

    private var liveCaptureInnerRing: Color {
        liveCanCapture ? Color(hex: "#FFFDF8") : Color(hex: "#F4EBDD")
    }

    private var liveCaptureIconColor: Color {
        liveCanCapture ? .white : Color(hex: "#8A7F70")
    }

    private func photoReviewView(image: UIImage) -> some View {
        GeometryReader { geometry in
            let renderedSize = geometry.size
            let imageSize = image.size

            let fitSize = aspectFill(from: imageSize, into: renderedSize)
            let fitFrame = CGRect(
                x: max(0, (renderedSize.width - fitSize.width) / 2),
                y: max(0, (renderedSize.height - fitSize.height) / 2),
                width: fitSize.width,
                height: fitSize.height
            )

            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: fitFrame.width, height: fitFrame.height)
                    .clipped()
                    .position(x: renderedSize.width / 2, y: renderedSize.height / 2)

                NameHaloOverlay(
                    faces: viewModel.detectedFaces,
                    bounds: fitFrame
                ) { face in
                    viewModel.assignFace(face)
                    isShowingAssignment = true
                }
            }
        }
    }

    private func aspectFill(from imageSize: CGSize, into containerSize: CGSize) -> CGSize {
        guard imageSize.width > 0 && imageSize.height > 0 else {
            return containerSize
        }
        let widthRatio = containerSize.width / imageSize.width
        let heightRatio = containerSize.height / imageSize.height
        let scale = max(widthRatio, heightRatio)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }
}

private struct FaceCapturePreview: UIViewRepresentable {
    let session: AVCaptureSession
    let device: AVCaptureDevice?
    let isFrontCamera: Bool

    func makeUIView(context: Context) -> FaceCapturePreviewView {
        let view = FaceCapturePreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: FaceCapturePreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
        if let connection = uiView.videoPreviewLayer.connection {
            if #available(iOS 17.0, *) {
                if let device {
                    uiView.rotationCoordinator = AVCaptureDevice.RotationCoordinator(
                        device: device,
                        previewLayer: uiView.videoPreviewLayer
                    )
                }

                let previewAngle = uiView.rotationCoordinator?.videoRotationAngleForHorizonLevelPreview ?? 90
                let fallbackAngle: CGFloat = isFrontCamera ? 270 : 90
                let angle = connection.isVideoRotationAngleSupported(previewAngle)
                    ? previewAngle
                    : fallbackAngle
                if connection.isVideoRotationAngleSupported(angle) {
                    connection.videoRotationAngle = angle
                }
            } else if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }

            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = isFrontCamera
            }
        }
    }
}

private final class FaceCapturePreviewView: UIView {
    var rotationCoordinator: AVCaptureDevice.RotationCoordinator?

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
