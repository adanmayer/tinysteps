# Face Capture / Name Halo - Implementation Plan

Role: Lead Engineer and PM, integrated by orchestrator

## Upfront Questions

These are the decisions to confirm before implementation. Proposed defaults are included so engineering is not blocked.

1. **Should this MVP use the related FaceTagging experiment model path, or keep the current Vision feature-print path?**
   - Proposed default: use the experiment path as must-ship. `FaceEmbedder.mlpackage`, `MLFaceEmbedder`, `FaceAligner`, `IdentityMatcher`, and threshold labeling are part of the implementation. The current Vision feature-print enrollments are legacy/incompatible data.

2. **What happens to existing local enrollments created with the Vision feature-print extractor?**
   - Proposed default: treat them as stale because they are not 512-d AdaFace vectors. Do not compare 64-d and 512-d vectors. Require re-enrollment or an explicit rebuild flow.

3. **Where should the capture flow launch from?**
   - Proposed default: add a `Capture image` item to the existing class overview gear affordance. Present the capture flow above `TeacherHomeView`, scoped to the selected class.

4. **What should `Keep` do before a production portfolio create API exists?**
   - Proposed default: write a local photo draft through a `FaceCaptureDraftStore` boundary. Later, adapt that store to `PortfolioService` when a write endpoint exists.

5. **Can `Keep` proceed when unknown faces remain unresolved?**
   - Proposed default: yes. Preserve unresolved faces as unknown assignments in the draft so the teacher can continue, but make unresolved states visible.

6. **Should library images run face recognition?**
   - Proposed default: no. Recognition runs only for in-app camera Photo captures. Library Image entries remain manually attributed.

## References Read

- `docs/features/face-capture/t6-photo-name-halo.txt`
- `docs/features/face-capture/t6-photo-name-halo.png`
- `docs/requirements/face-tagging.md`
- `docs/requirements/app-feature-spec.md`
- `docs/implementation-priorities.md`
- `docs/workflows/feature-planning-orchestration.md`
- `docs/features/class-enrollment-roster/implementation-plan.md`
- `docs/features/class-enrollment-roster/implementation-tasks.md`
- `TinySteps/TinySteps/Features/Home/TeacherHomeView.swift`
- `TinySteps/TinySteps/Features/ClassRoster/ClassRosterView.swift`
- `TinySteps/TinySteps/Features/ClassRoster/ClassRosterModel.swift`
- `TinySteps/TinySteps/Features/ClassRoster/ClassRosterStudent.swift`
- `TinySteps/TinySteps/Core/FaceID/Persistence/FaceEnrollmentStore.swift`
- `TinySteps/TinySteps/Core/FaceID/Persistence/FaceEnrollmentEmbeddingExtractor.swift`
- `TinySteps/TinySteps/Core/FaceID/Persistence/EnrolledIdentity.swift`
- `TinySteps/TinySteps/Core/FaceID/Persistence/FaceIDModelContainer.swift`
- `TinySteps/TinySteps/Features/Portfolio/Services/PortfolioService.swift`
- `Packages/MBAPI/Sources/MBAPI/APIEndpoints/MBPortfolioEndpoint.swift`

## Product Intent

Give a teacher a class-scoped way to take one photo, identify the children in it on-device, and resolve any unrecognized faces by selecting from the current class roster.

The flow should reduce manual photo tagging while preserving the TinySteps privacy position: face matching runs on the device, embeddings remain local, and the UI feels like gentle recognition rather than surveillance.

## PM Product Frame

The teacher is already in the Class overview checking readiness. The gear menu action is a pragmatic interim launch point until the Today tab becomes the primary capture surface. Selecting `Capture image` should feel like a direct continuation of the current class context, not a separate global camera feature.

The post-shutter screen follows the T6 visual reference:

- captured image is the hero;
- matched children receive warm sage Name Halos and first-name pills;
- unknown faces receive a soft `?` halo and a `Tap to name` pill;
- bottom actions stay simple: `Keep` and `Retake`;
- privacy language is clear, short, and non-technical.

## Primary Users

- Classroom teachers capturing a moment for the selected class.
- Classroom assistants working in the same class-scoped roster context.
- Parents are not operators of this flow; they receive the resulting filed photo only after the teacher keeps/files it.

## User Stories

- As a teacher, I can open `Capture image` from the class overview gear menu without losing the current class context.
- As a teacher, I can take a photo and see enrolled children labeled with Name Halos.
- As a teacher, I can see unrecognized faces as `?` halos and resolve them from the current class roster.
- As a teacher, I can keep the photo when the assignments look right, or retake without saving.
- As a teacher, I can trust that face matching happens on-device and faces never leave the phone for recognition.
- As a teacher, I can handle zero faces, one face, many faces, matched faces, and unknown faces without losing the capture.

## MVP Scope

### Must ship

- `Capture image` menu item in the class overview gear affordance.
- Class-scoped camera capture launched from the roster context.
- Experiment-parity FaceTagging pipeline:
  - `UIImage`;
  - `FaceCropper.fixedOrientation`;
  - `FaceAligner.alignAll` using `VNDetectFaceLandmarksRequest`;
  - 112x112 BGR aligned face canvas;
  - `MLFaceEmbedder.embed` backed by `FaceEmbedder.mlpackage`;
  - 512-d Float32 unit-normalized embeddings;
  - `IdentityMatcher.bestMatch` using min squared distance across enrolled vectors;
  - configurable threshold labeling as matched or unknown.
- `FaceEmbedder.mlpackage` bundled in the app target as a required resource.
- Threshold storage/configuration. The experiment reference `d2 = 1.48` may seed tuning, but the app must not bury the threshold as an unowned magic constant.
- Legacy enrollment guard for existing Vision feature-print data. Do not mix 64-d Vision embeddings with 512-d AdaFace embeddings.
- Post-shutter Name Halo review UI matching the T6 reference.
- Unknown-face assignment picker scoped only to the selected class roster.
- `Keep` through a local draft boundary with assignments preserved.
- `Retake` that discards the current photo and session data.
- Zero-face state that still reaches a usable review/draft path.
- Privacy gates for local-only face matching, no embedding export, no CloudKit for face data, no analytics, no raw embedding/face crop logging.

### Should ship if nearby

- Subtle `long-press to show face rect` affordance from the visual reference.
- DEBUG/demo-only known-good photo fallback for rehearsals.
- Lightweight class name display in the capture chrome to reinforce context.
- View-model tests for capture state transitions.

### Explicit non-goals

- No face matching on library Image entries.
- No school-wide or cross-class student picker for unknown faces.
- No automatic retraining from corrections in MVP.
- No attendance automation.
- No age, emotion, behavior, or surveillance-style inference.
- No production reliance on fake students, fake faces, or synthetic match data.
- No Today tab redesign as part of this milestone.
- No portfolio write API work beyond the draft boundary unless the backend contract already exists.

## Key Decisions

- Use the related FaceTagging experiment as the source of truth for the ML path. The current `VNGenerateImageFeaturePrintRequest` extractor is not the shipping runtime path for this feature.
- Keep model orchestration modular, but do not make AdaFace optional for MVP.
- Store model metadata on every enrollment. `modelIdentifier`, `vectorLength`, `embeddingCount`, and `elementType` are release gates before matching.
- Reject stale or incompatible enrollments before matching starts.
- Snapshot the active class roster at capture start and use that snapshot for unknown-face assignment.
- Keep presentation state in `TeacherHomeView`; emit the action from `ClassRosterView`.
- Extend the existing gear affordance additively. Do not remove future class-settings behavior.
- Persist captured photo bytes only after `Keep`, through draft/portfolio media storage. Do not persist face crops or thumbnails in the identity store.

## Data Model

Add experiment-parity FaceID values under `TinySteps/TinySteps/Core/FaceID/Identification/`:

```text
Core/FaceID/Identification/
|-- AlignedFace.swift
|-- FaceAlignment.swift
|-- FaceCropper.swift
|-- FaceDetector.swift
|-- FaceEmbedding.swift
|-- MLFaceEmbedder.swift
|-- IdentityMatcher.swift
|-- FaceIdentificationThreshold.swift
`-- FaceIdentificationService.swift
```

Add capture feature values under `TinySteps/TinySteps/Features/FaceCapture/`:

```text
Features/FaceCapture/
|-- FaceCaptureSession.swift
|-- FaceCaptureFace.swift
|-- FaceCaptureAssignment.swift
|-- FaceCaptureDraft.swift
|-- FaceCaptureDraftStore.swift
|-- Photo/FaceCaptureView.swift
|-- Photo/FaceCaptureViewModel.swift
|-- Photo/FaceCaptureCameraController.swift
|-- Shared/NameHaloOverlay.swift
`-- Assignments/FaceAssignmentPicker.swift
```

`FaceCaptureFace` should carry:

```swift
struct FaceCaptureFace: Identifiable, Equatable, Sendable {
    let id: UUID
    let bounds: CGRect
    var label: FaceCaptureLabel
    var assignedStudentKey: String?
}
```

`FaceCaptureLabel` should separate matched and unknown states:

```swift
enum FaceCaptureLabel: Equatable, Sendable {
    case matched(studentKey: String, displayName: String, distanceSquared: Float)
    case unknown(distanceSquared: Float?)
}
```

`EnrolledIdentity` must continue to store local embeddings only, but now AdaFace-compatible records require:

- `vectorLength == 512`;
- `modelIdentifier` matching the active AdaFace model;
- `embeddingCount >= 3`;
- `elementType` matching Float32;
- byte count matching `embeddingCount * vectorLength * MemoryLayout<Float32>.size`.

Legacy records created by the Vision feature-print extractor are incompatible and must resolve to `.invalid` or `.needsSetup` with a stale-model reason.

## API And Services

### FaceIdentificationService

Owns the experiment-parity pipeline:

```text
UIImage from camera
  -> FaceCropper.fixedOrientation
  -> FaceAligner.alignAll
  -> MLFaceEmbedder.embed
  -> IdentityMatcher.bestMatch
  -> Threshold.label
  -> FaceCaptureFace values for UI
```

The service must be non-networked. It can depend on:

- the active class roster snapshot;
- a safe local enrollment projection from `FaceEnrollmentStore`;
- the bundled `FaceEmbedder.mlpackage`;
- threshold configuration.

### FaceEnrollmentStore changes

Add a read projection for matching without exposing SwiftData models directly to UI:

```swift
struct FaceEnrollmentSnapshot: Sendable {
    let studentKey: String
    let displayName: String
    let embeddings: Data
    let embeddingCount: Int
    let elementType: Int
    let vectorLength: Int
    let modelIdentifier: String
}
```

The matcher may receive snapshots, but no UI layer should receive raw embedding data.

### FaceCaptureDraftStore

This is the MVP save boundary:

```swift
protocol FaceCaptureDraftStore: Sendable {
    func saveDraft(_ draft: FaceCaptureDraft) async throws -> FaceCaptureDraft.ID
}
```

Use an in-memory implementation until portfolio create is available. The draft store is not a face identity store.

## View Model / State Model

`FaceCaptureViewModel` owns user-visible state and delegates work:

```swift
enum FaceCaptureState: Equatable {
    case requestingCameraPermission
    case cameraReady
    case capturing
    case processing
    case reviewing(FaceCaptureSession)
    case assigning(faceID: UUID, session: FaceCaptureSession)
    case saving
    case saved(FaceCaptureDraft.ID)
    case failed(message: String)
}
```

Rules:

- The photo buffer exists only in the active session before `Keep`.
- `Retake` clears photo and assignments.
- Unknown assignment updates only the tapped face.
- Class roster is snapshotted at start to avoid class-switch drift.
- Zero detected faces becomes `.reviewing` with an empty face list, not a fatal error.

## Product States

- Gear menu available with `Capture image` when a concrete class is selected.
- Gear menu action hidden or disabled for `All Classes`.
- Camera permission not determined.
- Camera permission denied.
- Camera ready.
- Capture in progress.
- Face identification processing.
- Matched faces.
- Unknown faces.
- Zero faces.
- Unknown assignment picker.
- Keep saving.
- Retake discard.
- Save failure.

## UI Plan

The review screen should follow the face-capture reference:

- cream top chrome;
- close X at top left;
- centered `Photo` title;
- type chip row at top right where supported by existing capture UI;
- captured photo as the main hero;
- soft sage halo for matched children;
- dusty-rose or warm unknown halo for `Tap to name`;
- optional small bottom-left hint: `long-press to show face rect`;
- bottom caption: `Keep saves and takes you to the draft sheet.`;
- primary sage `Keep` button;
- secondary outlined `Retake` button.

The halo overlay must map normalized face bounds to displayed image coordinates. If the image is aspect-filled or aspect-fitted, the overlay must use the same transform as the rendered image.

## Navigation

- `ClassRosterView` emits `onCaptureImage`.
- `TeacherHomeView` owns `isShowingFaceCapture`.
- `TeacherHomeView` presents `FaceCaptureView` as a full-screen cover or large sheet above the tab stack.
- `FaceCaptureView` receives:
  - selected class;
  - roster snapshot;
  - face identification service;
  - draft store;
  - dismiss callback.
- Dismissing capture returns to the roster without resetting search or selected class state.

## Dependencies And Sequencing

1. Add bundled `FaceEmbedder.mlpackage` to the app target.
2. Port/build the experiment-parity FaceID pipeline.
3. Update enrollment extraction and store compatibility for 512-d AdaFace records.
4. Add threshold configuration and stale enrollment handling.
5. Add capture session and draft store boundaries.
6. Build the FaceCapture UI shell and Name Halo overlay.
7. Add unknown-face assignment scoped to current class roster.
8. Wire the class gear menu action and presentation.
9. Add tests, privacy gates, and device QA.

## Integration Steps

- Replace runtime matching reliance on `VNGenerateImageFeaturePrintRequest` with `MLFaceEmbedder`.
- Keep or adapt `FaceEnrollmentEmbeddingExtractor` only if it outputs AdaFace-compatible vectors.
- Update `FaceIDModelContainer.requiredVectorLength` and model identifier requirements for AdaFace.
- Add schema guards in `SwiftDataFaceEnrollmentStore.status(for:)`.
- Add dependency construction in `FeatureServicesComposition` and `AppDependencies`.
- Add new feature files to the Xcode target if file-system-synchronized membership does not pick them up.
- Ensure `FaceEmbedder.mlpackage` is copied into the app bundle.

## Tests

Targeted tests should cover:

- model resource loads from bundle;
- embedder returns 512-d Float32 unit-normalized vectors;
- threshold labels matched and unknown cases;
- identity matcher uses min `d2` across all enrolled vectors;
- legacy Vision records are rejected and never mixed with AdaFace records;
- zero-face capture produces a reviewable state;
- matched-face capture produces a Name Halo label;
- unknown-face assignment updates only the tapped face;
- picker roster is scoped to the current class;
- `Keep` persists once through the draft store;
- `Retake` clears photo and assignments;
- no persistence before `Keep` using a spy draft store;
- no network service is invoked by face detection/matching using spies or dependency boundaries.

## Manual Acceptance

- On a real iPhone, select a class, open the gear menu, and verify `Capture image` appears.
- Launch capture and accept camera permission.
- Capture a photo with one enrolled face and verify a sage name halo appears.
- Capture a photo with one unrecognized face and verify `Tap to name` opens only current-class students.
- Capture with no faces and verify `Keep`/`Retake` remain usable.
- Use airplane mode and verify face detection/matching still works.
- Tap `Retake` and verify no draft is saved.
- Tap `Keep` and verify assignments are preserved in the draft path.
- Verify logs do not include embeddings, raw vectors, face crops, or photo bytes.

## Risks And Mitigations

- **Risk:** existing local enrollments are Vision feature-print records.
  - **Mitigation:** stale-model guard and required re-enrollment before AdaFace matching.
- **Risk:** `FaceEmbedder.mlpackage` is missing from the app target.
  - **Mitigation:** explicit resource task and load test.
- **Risk:** threshold is wrong for real classroom data.
  - **Mitigation:** configurable threshold with experiment value only as seed.
- **Risk:** class context changes during capture.
  - **Mitigation:** roster snapshot captured at launch; picker uses the snapshot.
- **Risk:** overlay coordinates drift from displayed image coordinates.
  - **Mitigation:** test aspect-fit/aspect-fill transforms and manual QA on device.
- **Risk:** privacy regression through logs or draft persistence.
  - **Mitigation:** spy tests, release gates, and no raw identity artifacts outside FaceID storage.

## Definition Of Done

- `Capture image` launches from the class roster gear menu.
- Camera capture works on device.
- Runtime identification uses the experiment ML model path and bundled `FaceEmbedder.mlpackage`.
- Matched and unknown halos render over the captured image.
- Unknown faces can be assigned from the current class roster only.
- Legacy Vision enrollments are rejected or marked stale, not mixed.
- `Keep` and `Retake` behave correctly.
- The feature works offline during face analysis.
- Privacy gates pass.
- The app builds successfully.
