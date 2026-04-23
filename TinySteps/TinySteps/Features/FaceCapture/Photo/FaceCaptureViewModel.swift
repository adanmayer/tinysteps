import Foundation
import AVFoundation
import Combine
import UIKit
import SwiftUI
import MBAPI

@MainActor
final class FaceCaptureViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case requestingPermission
        case ready
        case capturing
        case processing
        case reviewing
        case saving
        case saved
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var capturedImage: UIImage?
    @Published private(set) var detectedFaces: [FaceCaptureFace] = []
    @Published private(set) var isCameraReady = false
    @Published private(set) var selectedFace: FaceCaptureFace?
    @Published private(set) var errorMessage: String?
    @Published private(set) var childVoiceDraft: ChildVoiceDraft?

    let session: AuthSession
    let classID: String
    let className: String
    let candidateStudents: [FaceCaptureStudentSnapshot]

    private let faceEnrollmentStore: FaceEnrollmentStore
    private let draftStore: FaceCaptureDraftStore
    private let camera = FaceCaptureCameraController()
    private let identificationService: FaceIdentificationService?
    private var cameraCancellables: Set<AnyCancellable> = []

    init(
        session: AuthSession,
        classID: String,
        className: String,
        candidateStudents: [FaceCaptureStudentSnapshot],
        faceEnrollmentStore: FaceEnrollmentStore,
        draftStore: FaceCaptureDraftStore
    ) {
        self.session = session
        self.classID = classID
        self.className = className
        self.candidateStudents = candidateStudents
        self.faceEnrollmentStore = faceEnrollmentStore
        self.draftStore = draftStore
        self.identificationService = try? FaceIdentificationService()
        camera.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cameraCancellables)
    }

    var cameraPreviewSession: AVCaptureSession {
        camera.previewSession
    }

    var cameraDevice: AVCaptureDevice? {
        camera.currentDevice
    }

    var isFrontCamera: Bool {
        camera.currentPosition == .front
    }

    var isLightingGood: Bool? {
        camera.isLightingGood
    }

    var canSwitchCamera: Bool {
        isCameraReady && state == .ready
    }

    var hasMatches: Bool {
        detectedFaces.contains { face in
            if case .matched = face.label {
                return true
            }
            return false
        }
    }

    var canKeep: Bool {
        state == .reviewing && capturedImage != nil
    }

    var childVoiceTarget: ChildVoiceChild? {
        let hasUnknownFace = detectedFaces.contains { face in
            if case .unknown = face.label {
                return true
            }
            return false
        }
        guard hasUnknownFace == false else {
            return nil
        }

        var linkedChildren: [String: ChildVoiceChild] = [:]
        for face in detectedFaces {
            guard case .matched(let studentKey, _, _) = face.label else {
                continue
            }

            guard linkedChildren[studentKey] == nil else {
                continue
            }

            guard let student = candidateStudents.first(where: { $0.studentKey == studentKey }) else {
                continue
            }
            guard let userID = student.userID else {
                continue
            }

            linkedChildren[studentKey] = ChildVoiceChild(
                studentKey: student.studentKey,
                userID: userID,
                displayName: student.displayName
            )
        }

        guard linkedChildren.count == 1 else {
            return nil
        }

        return linkedChildren.values.first
    }

    var isChildVoiceButtonEnabled: Bool {
        childVoiceTarget != nil
    }

    func start() {
        if case .capturing = state {
            return
        }
        if case .processing = state {
            return
        }
        if case .reviewing = state {
            return
        }
        if case .saving = state {
            return
        }
        state = .requestingPermission
        Task {
            await camera.start()
            isCameraReady = camera.isReady
            if camera.isReady {
                state = .ready
            } else {
                state = .failed(camera.errorMessage ?? "Camera unavailable")
            }
        }
    }

    func stop() {
        camera.stop()
        isCameraReady = false
        if case .capturing = state { return }
    }

    func toggleCamera() {
        guard canSwitchCamera else {
            return
        }
        camera.toggleCamera()
    }

    func capturePhoto() {
        guard state == .ready else {
            return
        }
        guard let identificationService else {
            let message = "Face recognition model is unavailable."
            errorMessage = message
            state = .failed(message)
            return
        }
        state = .capturing
        errorMessage = nil

        Task {
            do {
                let photo = try await camera.capturePhoto()
                capturedImage = photo
                state = .processing
                let keys = candidateStudents.map(\.studentKey)
                let snapshots = try await faceEnrollmentStore.snapshots(for: keys)
                let faces = try await identificationService.identifyFaces(in: photo, using: snapshots)
                detectedFaces = faces
                state = .reviewing
                camera.stop()
            } catch {
                camera.stop()
                errorMessage = error.localizedDescription
                state = .failed(error.localizedDescription)
            }
        }
    }

    func retake() {
        state = .requestingPermission
        selectedFace = nil
        capturedImage = nil
        detectedFaces = []
        childVoiceDraft = nil
        errorMessage = nil
        Task {
            await camera.start()
            isCameraReady = camera.isReady
            state = camera.isReady ? .ready : .failed(camera.errorMessage ?? "Camera unavailable")
        }
    }

    func assignFace(_ face: FaceCaptureFace) {
        selectedFace = face
    }

    func clearSelectedFace() {
        selectedFace = nil
    }

    func assignStudent(_ studentKey: String?) {
        guard let selectedFace else {
            return
        }

        guard let index = detectedFaces.firstIndex(where: { $0.id == selectedFace.id }) else {
            self.selectedFace = nil
            return
        }

        let matchedLabel = selectedStudentLabel(studentKey: studentKey)
        detectedFaces[index].label = matchedLabel
        self.selectedFace = nil
    }

    func keep() {
        guard canKeep, let image = capturedImage, let imageData = image.jpegData(compressionQuality: 0.88) else {
            errorMessage = "No photo captured."
            state = .failed("No photo captured.")
            return
        }

        state = .saving

        let draft = FaceCaptureDraft(
            classID: classID,
            className: className,
            imageData: imageData,
            faces: detectedFaces.map { face in
                let studentKey: String?
                let userID: String?
                if case .matched(let key, _, _) = face.label {
                    studentKey = key
                    userID = candidateStudents.first(where: { $0.studentKey == key })?.userID
                } else {
                    studentKey = nil
                    userID = nil
                }
                return FaceCaptureDraftFace(
                    faceID: face.id,
                    bounds: FaceCaptureDraftFaceBounds(
                        x: face.bounds.minX,
                        y: face.bounds.minY,
                        width: face.bounds.width,
                        height: face.bounds.height
                    ),
                    studentKey: studentKey,
                    userID: userID
                )
            },
            childVoice: childVoiceDraft
        )

        Task {
            do {
                _ = try await draftStore.saveDraft(draft)
                state = .saved
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    func reset() {
        state = .idle
        selectedFace = nil
        capturedImage = nil
        detectedFaces = []
        childVoiceDraft = nil
        errorMessage = nil
        isCameraReady = false
    }

    func setChildVoiceDraft(_ draft: ChildVoiceDraft) {
        if let existing = childVoiceDraft,
           existing.localFilename != draft.localFilename {
            let recorder = ChildVoiceAudioRecorder()
            try? recorder.deleteRecording(filename: existing.localFilename)
        }
        childVoiceDraft = draft
    }

    func removeChildVoiceDraft() {
        childVoiceDraft = nil
    }

    func selectedStudentDisplayName(for key: String?) -> String {
        guard let key else {
            return ""
        }
        return candidateStudents.first(where: { $0.studentKey == key })?.displayName ?? key
    }

    private func selectedStudentLabel(studentKey: String?) -> FaceCaptureLabel {
        guard let studentKey else {
            return .unknown(distanceSquared: nil)
        }
        let displayName = candidateStudents.first(where: { $0.studentKey == studentKey })?.displayName ?? studentKey
        return .matched(studentKey: studentKey, displayName: displayName, distanceSquared: 0)
    }
}
