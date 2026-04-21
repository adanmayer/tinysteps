# Face Capture / Name Halo - Implementation Tasks

Role: Senior Engineer, reviewed and amended by Lead Engineer

Source plan: `docs/features/face-capture/implementation-plan.md`

## Working Assumptions

- Capture is class-scoped and launches from the Class roster gear affordance.
- The related FaceTagging experiment ML path is must-ship, not optional.
- `FaceEmbedder.mlpackage` is required in the app bundle.
- Existing Vision feature-print enrollments are incompatible with AdaFace enrollment records and must be treated as stale.
- Face detection and matching run entirely on-device.
- Embeddings never leave the local FaceID container.
- Captured photos stay in memory until `Keep`.
- No face crops or thumbnails are persisted as identity storage.
- No CloudKit, analytics, export, network calls, or raw logging are allowed for the identification pipeline.
- DEBUG/demo fallback is allowed only behind explicit demo-mode gates.
- Unknown and zero-face results must still allow a usable review/draft path.

## Delivery Slices

1. **Model resource and experiment pipeline PR:** bundle `FaceEmbedder.mlpackage`, port the experiment-parity crop/align/embed/match/threshold pipeline, and prove the 512-d output shape.
2. **Enrollment compatibility PR:** update enrollment extraction/store guards for AdaFace, reject stale Vision records, and add threshold configuration.
3. **Capture session PR:** add camera capture, session state, class roster snapshot, and local draft persistence.
4. **UI PR:** build the Photo capture review screen, Name Halo overlay, and unknown-face assignment picker.
5. **Roster integration PR:** add `Capture image` to the class overview gear affordance and present capture from `TeacherHomeView`.
6. **Verification PR:** add privacy, resource, state, and device QA gates.

## Task 0 - Confirm Defaults And Guardrails

**Owner:** Mobile lead

**Goal:** Lock the decisions that affect data compatibility and scope before implementation starts.

**Files:**

- `docs/features/face-capture/implementation-plan.md`
- `docs/features/face-capture/implementation-tasks.md`

**Work:**

- Confirm that AdaFace/`FaceEmbedder.mlpackage` is required for this feature.
- Confirm that existing Vision feature-print enrollments are stale and require re-enrollment or an explicit rebuild flow.
- Confirm that `Keep` writes through a local draft boundary until a portfolio create path exists.
- Confirm that `Capture image` is the exact gear menu label.
- Confirm that Image/library import remains out of scope for recognition.

**Acceptance:**

- Engineering does not need to guess whether the experiment model is optional.
- No task depends on a backend portfolio create endpoint.
- No task mixes Vision and AdaFace embedding formats.

## Task 1 - Add FaceEmbedder Model Resource

**Owner:** Mobile developer

**Depends on:** Task 0

**Files:**

- `TinySteps/TinySteps/FaceEmbedder.mlpackage` or the chosen app-bundle resource location
- `TinySteps/TinySteps.xcodeproj/project.pbxproj` or file-system-synchronized target membership metadata if required
- `TinySteps/TinyStepsTests/` model resource tests

**Goal:** Bundle the experiment ML model as a required app resource.

**Work:**

- Add `FaceEmbedder.mlpackage` from the related FaceTagging experiment to the app target.
- Keep the resource at bundle root unless Xcode project conventions require a specific location.
- Document the expected model identity, input shape, output shape, and bundle size.
- Add a small load test or runtime assertion that the model exists in the app bundle.
- Fail clearly if the model resource is missing.

**Acceptance:**

- The app bundle contains `FaceEmbedder.mlpackage`.
- A test or startup check can load the model resource.
- The resource is not treated as DEBUG-only.
- Build-system membership is explicit enough that CI/device builds include the model.

## Task 2 - Port Experiment-Parity FaceID Pipeline

**Owner:** Mobile developer

**Depends on:** Task 1

**Files:**

- `TinySteps/TinySteps/Core/FaceID/Identification/FaceCropper.swift`
- `TinySteps/TinySteps/Core/FaceID/Identification/FaceAligner.swift`
- `TinySteps/TinySteps/Core/FaceID/Identification/AlignedFace.swift`
- `TinySteps/TinySteps/Core/FaceID/Identification/MLFaceEmbedder.swift`
- `TinySteps/TinySteps/Core/FaceID/Identification/FaceEmbedding.swift`
- `TinySteps/TinySteps/Core/FaceID/Identification/IdentityMatcher.swift`
- `TinySteps/TinySteps/Core/FaceID/Identification/FaceIdentificationService.swift`
- `TinySteps/TinyStepsTests/` FaceID pipeline tests

**Goal:** Implement the same runtime path validated by the FaceTagging experiment.

**Work:**

- Implement `FaceCropper.fixedOrientation` to bake EXIF orientation into pixels.
- Implement `FaceAligner.alignAll` using `VNDetectFaceLandmarksRequest`.
- Produce aligned 112x112 BGR face canvases.
- Implement `MLFaceEmbedder` backed by `FaceEmbedder.mlpackage`.
- Pass raw `CGImage` inputs through `MLFeatureValue(cgImage:constraint:)`; do not duplicate normalization in Swift because the model bakes it in.
- Ensure embedding output is 512-d Float32 and unit-normalized.
- Implement `IdentityMatcher.bestMatch` using min squared distance across all enrolled vectors for a student.
- Implement `FaceIdentificationService` to return matched and unknown face results for the UI.
- Keep zero faces as a normal empty result, not an error.
- Do not call the network.

**Acceptance:**

- A captured image can produce zero or more aligned faces.
- Embedding output is 512-d Float32.
- Vectors are unit-normalized or re-normalized at the API boundary.
- Matching uses min `d2` across enrolled vectors.
- The Vision feature-print extractor is not the shipping runtime matcher.

**Tests:**

- Model loads from bundle.
- Embedder reports 512-d output shape.
- Unit normalization is within tolerance.
- Zero-face image returns an empty result.
- Matcher chooses the nearest enrolled identity by min `d2`.
- Unknown result is returned when no enrolled identity is under threshold.

## Task 3 - Add Threshold Configuration And Enrollment Compatibility Guards

**Owner:** Mobile developer

**Depends on:** Task 2

**Files:**

- `TinySteps/TinySteps/Core/FaceID/Persistence/FaceIDModelContainer.swift`
- `TinySteps/TinySteps/Core/FaceID/Persistence/FaceEnrollmentStore.swift`
- `TinySteps/TinySteps/Core/FaceID/Persistence/EnrolledIdentity.swift`
- `TinySteps/TinySteps/Core/FaceID/Identification/FaceIdentificationThreshold.swift`
- `TinySteps/TinyStepsTests/` threshold and migration tests

**Goal:** Prevent stale Vision records from being matched and make threshold ownership explicit.

**Work:**

- Update active FaceID requirements to the AdaFace model identifier and `vectorLength == 512`.
- Add a local threshold configuration value/entity or equivalent persistence boundary.
- Seed the threshold with the experiment reference `d2 = 1.48` only as a default for tuning.
- Add a clear path to update the threshold without changing matcher code.
- Add `FaceEnrollmentSnapshot` or an equivalent projection for matcher reads.
- Ensure stale Vision records with `vectorLength == 64` or Vision model identifiers return `.invalid` or `.needsSetup`.
- Never compare embeddings across model identifiers or vector lengths.
- Preserve privacy-safe `CustomStringConvertible` behavior.

**Acceptance:**

- Legacy Vision enrollments cannot enter the AdaFace matcher.
- Threshold labeling is not hidden as a magic number in UI code.
- Store reads expose only the data needed by the matcher, not SwiftData entities to the UI.
- Invalid/stale status can drive re-enrollment UI later.

**Tests:**

- Legacy 64-d enrollment is rejected.
- Mixed model identifiers are rejected.
- 512-d AdaFace enrollment is accepted when byte count matches.
- Threshold labels matched and unknown examples correctly.
- `EnrolledIdentity.description` does not include embedding bytes.

## Task 4 - Update Enrollment Extraction To Produce AdaFace Records

**Owner:** Mobile developer

**Depends on:** Task 2, Task 3

**Files:**

- `TinySteps/TinySteps/Core/FaceID/Persistence/FaceEnrollmentEmbeddingExtractor.swift`
- `TinySteps/TinySteps/Features/Home/ClassRosterStudentSetupSheet.swift`
- `TinySteps/TinySteps/Core/FaceID/Persistence/FaceEnrollmentStore.swift`
- `TinySteps/TinyStepsTests/` enrollment extraction tests

**Goal:** Ensure newly enrolled students use the same AdaFace model as runtime capture.

**Work:**

- Replace the Vision feature-print enrollment extraction path with the experiment-parity crop/align/embed path.
- Store `embeddingCount`, `vectorLength == 512`, Float32 element type, and active AdaFace model identifier.
- Keep photos in memory only during enrollment.
- Keep existing enrollment UI behavior unless needed for compatibility errors.
- Surface stale or incompatible existing enrollment as needing setup.

**Acceptance:**

- New enrollments produce AdaFace-compatible records.
- Runtime matching and enrollment use the same model identifier and vector length.
- Stale Vision records do not show as ready for capture matching.
- No enrollment photo is persisted as part of face identity storage.

**Tests:**

- Enrollment extraction produces byte count equal to `embeddingCount * 512 * MemoryLayout<Float32>.size`.
- Store status reports AdaFace records as enrolled.
- Store status reports Vision records as invalid/stale.

## Task 5 - Add Face Capture Session, Camera Runtime, And Draft Store

**Owner:** Mobile developer

**Depends on:** Task 2, Task 3

**Files:**

- `TinySteps/TinySteps/Features/FaceCapture/FaceCaptureSession.swift`
- `TinySteps/TinySteps/Features/FaceCapture/FaceCaptureFace.swift`
- `TinySteps/TinySteps/Features/FaceCapture/FaceCaptureAssignment.swift`
- `TinySteps/TinySteps/Features/FaceCapture/FaceCaptureDraft.swift`
- `TinySteps/TinySteps/Features/FaceCapture/FaceCaptureDraftStore.swift`
- `TinySteps/TinySteps/Features/FaceCapture/Photo/FaceCaptureCameraController.swift`
- `TinySteps/TinySteps/App/Composition/FeatureServicesComposition.swift`
- `TinySteps/TinySteps/App/AppDependencies.swift`

**Goal:** Provide the state and persistence boundary for capture before UI integration.

**Work:**

- Add transient capture session values for photo, face results, assignments, and selected class snapshot.
- Add a camera controller/session wrapper for still-photo capture.
- Add `FaceCaptureDraftStore` as the mandatory MVP save boundary.
- Implement an in-memory draft store until production portfolio creation exists.
- Keep photo bytes in memory before `Keep`.
- Save exactly once on `Keep`.
- Clear the photo and assignments on `Retake` or cancel.
- Keep library image import out of this path.

**Acceptance:**

- A session can hold a captured photo and face results.
- A class roster snapshot is available for assignment.
- `Keep` creates one draft with preserved assignments.
- `Retake` clears all transient capture data.
- No draft is created before `Keep`.

**Tests:**

- `Keep` saves once through a spy draft store.
- `Retake` clears photo and assignments.
- No persistence before `Keep`.
- Class roster snapshot remains stable if external class selection changes.

## Task 6 - Build FaceCapture View Model And Name Halo UI

**Owner:** Mobile developer

**Depends on:** Task 5

**Files:**

- `TinySteps/TinySteps/Features/FaceCapture/Photo/FaceCaptureView.swift`
- `TinySteps/TinySteps/Features/FaceCapture/Photo/FaceCaptureViewModel.swift`
- `TinySteps/TinySteps/Features/FaceCapture/Shared/NameHaloOverlay.swift`
- `TinySteps/TinySteps/Features/FaceCapture/Assignments/FaceAssignmentPicker.swift`

**Goal:** Build the post-shutter experience from the T6 face-capture reference.

**Work:**

- Add state transitions for camera ready, capturing, processing, reviewing, assigning, saving, saved, and failed.
- Render cream top chrome, close control, centered `Photo` title, captured photo hero, bottom caption, `Keep`, and `Retake`.
- Render matched faces with sage halo and first-name pill.
- Render unknown faces with `?` halo and `Tap to name`.
- Map normalized face bounds to rendered image coordinates correctly.
- Tapping an unknown face opens the picker for that face only.
- Picker is limited to the current class roster snapshot.
- Zero detected faces still advances to the same review shell with empty halo state and usable `Keep`/`Retake`.
- Halo labels are driven by AdaFace threshold results.

**Acceptance:**

- Matched faces show sage Name Halos.
- Unknown faces show `?` and `Tap to name`.
- Unknown picker cannot show students outside the current class.
- Assigning a student updates only the tapped face.
- Zero-face state does not block the user.
- `Keep` and `Retake` follow the session rules from Task 5.

**Tests:**

- View-model state transitions for capture to processing to reviewing.
- Unknown assignment updates one face only.
- Zero-face capture reaches reviewing state.
- Picker source is current class only.

**Manual QA:**

- Capture one matched face.
- Capture one unknown face.
- Capture no faces.
- Verify halo alignment on real device image aspect ratios.

## Task 7 - Wire Class Roster Gear Menu And Presentation

**Owner:** Mobile developer

**Depends on:** Task 6

**Files:**

- `TinySteps/TinySteps/Features/ClassRoster/ClassRosterView.swift`
- `TinySteps/TinySteps/Features/Home/TeacherHomeView.swift`

**Goal:** Expose the feature from the class overview.

**Work:**

- Extend the existing gear affordance to expose a menu/action item labeled exactly `Capture image`.
- Add `onCaptureImage` from `ClassRosterView`.
- Own capture presentation state in `TeacherHomeView`.
- Present `FaceCaptureView` above the tab stack with selected class and roster snapshot.
- Hide or disable `Capture image` when `All Classes` or no concrete class is selected.
- Preserve the existing student setup sheet behavior.
- Do not replace future class-settings behavior; this action is additive.

**Acceptance:**

- Gear menu includes `Capture image` with exact casing.
- Selecting it opens capture in the active class context.
- Dismiss returns to the same roster state.
- No capture route exists for `All Classes`.

**Tests:**

- UI or view-model coverage for menu action availability if practical.
- Presentation action preserves selected class context.

**Manual QA:**

- Select a class, open gear, launch capture, dismiss, and verify roster state remains intact.
- Switch to `All Classes` and verify capture is unavailable.

## Task 8 - Privacy, Resource, And Build Verification

**Owner:** Mobile lead and mobile developer

**Depends on:** Task 1 through Task 7

**Files:**

- `TinySteps/TinySteps/Info.plist`
- `TinySteps/TinySteps/App/Composition/FeatureServicesComposition.swift`
- `TinySteps/TinySteps/App/AppDependencies.swift`
- `TinySteps/TinyStepsTests/`
- Any new resource membership files required by Xcode

**Goal:** Close release gates before the feature is called done.

**Work:**

- Verify `NSCameraUsageDescription` is present and specific to class photo capture.
- Verify `FaceEmbedder.mlpackage` loads on device.
- Verify Core ML uses the intended local model path with neural-engine preference where supported.
- Confirm no network dependency is called during detection, embedding, matching, or assignment.
- Confirm no raw face embeddings, vectors, face crops, thumbnails, or photo bytes are logged.
- Confirm no temporary capture artifacts remain after `Retake` or cancel.
- Confirm Release builds do not depend on fake/demo data.
- Run the final app build.

**Acceptance:**

- Permission prompts are correct and minimal.
- Face analysis works in airplane mode.
- The model resource is present in the app bundle.
- Privacy gates pass.
- Targeted tests pass.
- App build succeeds.

**Tests:**

- Spy/mocked no-network assertion for identification pipeline.
- Spy draft store proves no save before `Keep`.
- Logging tests or code review checklist for no raw embedding/photo logging.
- Resource loading test for `FaceEmbedder.mlpackage`.

**Manual QA:**

- Allow and deny camera access.
- Capture with airplane mode enabled.
- Verify matched, unknown, and zero-face flows.
- Verify `Keep` and `Retake`.
- Inspect debug logs for sensitive output.

## Optional Follow-Up Tasks

- Add production portfolio create-entry adapter behind `FaceCaptureDraftStore`.
- Add post-keep editing or reopenable capture drafts.
- Add long-press face-rectangle reveal from the visual reference.
- Add deeper accessibility and VoiceOver tuning.
- Add richer DEBUG rehearsal photo packs, gated behind explicit demo mode only.

## Lead Review Amendments Integrated

- AdaFace and `FaceEmbedder.mlpackage` moved from optional to must-ship.
- Vision feature-print matching demoted to legacy/incompatible state.
- Model resource membership, threshold configuration, migration/stale enrollment guards, and neural-engine/device verification are explicit tasks.
- Class roster snapshot ownership is explicit.
- Capture presentation state lives in `TeacherHomeView`; action is emitted by `ClassRosterView`.
- Gear action is additive, not a replacement for future settings behavior.
- Zero-face behavior is explicit in state modeling, UI, tests, and QA.
- Privacy gates include no persistence before `Keep`, no network during matching, and no raw face artifact logging.
