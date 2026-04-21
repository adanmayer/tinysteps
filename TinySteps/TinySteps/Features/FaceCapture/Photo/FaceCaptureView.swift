import SwiftUI
import AVFoundation
import MBAPI

struct FaceCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: FaceCaptureViewModel
    @State private var isShowingAssignment = false
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
                draftStore: draftStore
            )
        )
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#FBF6EE")
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                    photoViewport
                        .frame(maxHeight: .infinity)
                        .padding(.horizontal, 16)

                    actionBar
                        .padding(.horizontal, 18)
                        .padding(.bottom, 14)
                }
            }
            .onAppear {
                viewModel.start()
            }
            .onDisappear {
                viewModel.stop()
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
            .onChange(of: viewModel.state) { newState in
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
                                displayName: $0.displayName,
                                firstName: $0.displayName,
                                initials: "",
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
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "#E6D8C2").opacity(0.7))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Image(systemName: "waveform")
                            .font(.caption)
                            .foregroundStyle(Color(hex: "#6E6456"))
                    )
                Image(systemName: "camera.rotate")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(hex: "#8DA67A"))
                    .frame(width: 30, height: 30)
                    .background(Color(hex: "#8DA67A").opacity(0.2))
                    .clipShape(Circle())
            }
            .font(.system(size: 12))
        }
    }

    private var photoViewport: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                if case .reviewing = viewModel.state,
                   let image = viewModel.capturedImage {
                    photoReviewView(image: image, container: geometry.size)
                } else if case .processing = viewModel.state {
                    progressSection
                } else {
                    cameraPreview
                }

                if case .reviewing = viewModel.state {
                    Text("Long-press to show face rect")
                        .font(.system(size: 11))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Color(hex: "#3A342E").opacity(0.28))
                        .clipShape(Capsule())
                        .padding(10)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(hex: "#FFFDF8"))
                    .stroke(Color(hex: "#F0E7D7"), lineWidth: 0.8)
            )
        }
    }

    private var cameraPreview: some View {
        FaceCapturePreview(session: viewModel.cameraPreviewSession)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay {
                if viewModel.isCameraReady == false {
                    ProgressView("Starting camera...")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#6E6456"))
                }
            }
    }

    private var actionBar: some View {
        VStack(spacing: 12) {
            if case .reviewing = viewModel.state {
                Text("Keep saves and takes you to the draft sheet.")
                    .font(.caption2)
                    .foregroundStyle(Color(hex: "#6E6456"))

                HStack(spacing: 12) {
                    Button(action: {
                        viewModel.keep()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                            Text("Keep")
                        }
                        .font(.system(size: 18, weight: .semibold))
                        .frame(height: 56)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.white)
                        .background(Color(hex: "#8DA67A"))
                        .clipShape(Capsule())
                    }
                    .disabled(viewModel.canKeep == false)

                    Button(action: {
                        viewModel.retake()
                    }) {
                        Text("Retake")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 100, height: 56)
                            .foregroundStyle(Color(hex: "#3A342E"))
                            .overlay(
                                Capsule()
                                    .stroke(Color(hex: "#D8CEBD"), lineWidth: 1.2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            } else if case .failed = viewModel.state {
                Button("Try again") {
                    viewModel.reset()
                    viewModel.start()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color(hex: "#8DA67A"))
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .padding(.top, 8)
            } else {
                Button {
                    viewModel.capturePhoto()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#8DA67A"))
                            .frame(width: 72, height: 72)
                        if viewModel.state == .processing {
                            ProgressView()
                                .tint(.white)
                        }
                    }
                }
                .padding(.bottom, 4)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var progressSection: some View {
        ZStack {
            ProgressView("Processing faces…")
                .progressViewStyle(.circular)
        }
    }

    private func photoReviewView(image: UIImage, container: CGSize) -> some View {
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
                    .aspectRatio(contentMode: .fit)
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
        let scale = min(widthRatio, heightRatio)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }
}

private struct FaceCapturePreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        context.coordinator.layer = previewLayer
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.layer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        weak var layer: AVCaptureVideoPreviewLayer?
    }
}
