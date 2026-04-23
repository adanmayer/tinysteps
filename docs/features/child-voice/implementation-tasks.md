# Child Voice - Implementation Tasks

Role: Senior Engineer, reviewed and amended by Lead Engineer

Source plan: `docs/features/child-voice/implementation-plan.md`

Note: Senior Engineer and Lead Review passes were performed sequentially by the orchestrator because agent delegation was not explicitly requested for this turn.

## Working Assumptions

- Portfolio child voice maps to `audio_description_id` on create/update payloads and `audio_description` on timeline reads.
- Audio upload returns a Rails Active Storage `signed_id`, and upload occurs only during publishing.
- Direct child voice creates a local note draft immediately after recording.
- Embedded image child voice attaches to the photo draft and is published with the photo from Review.
- Exactly one linked child is required for every child voice capture.
- Image child voice also requires no unknown faces in the captured image.
- Local recordings use `.m4a` with MIME type `audio/mp4`.
- Direct child voice is represented as a normal note draft with attached child voice audio, not a separate Review item type.
- Direct child voice save does not switch to Review for now.
- Parent-consent enforcement is a production release gate if no consent source exists in the app yet.

## Delivery Slices

1. Read, render, and play existing audio descriptions.
2. Add audio upload and payload support.
3. Build local child voice capture.
4. Attach child voice to image/photo drafts.
5. Add direct class gear menu local draft flow.
6. Publish child-voice drafts.
7. Add required Stream playback controls.
8. Add tests, cleanup, and release gates.

## Task 0 - Confirm Defaults And Guardrails

Owner: Lead engineer

Files:

- `docs/features/child-voice/implementation-plan.md`
- `Packages/MBAPI/Sources/MBAPI/APIEndpoints/MBPortfolioEndpoint.swift`
- `TinySteps/TinySteps/Features/Portfolio/Services/PortfolioService.swift`

Goal:

Confirm TinySteps can implement the old app's direct-upload contract before implementation.

Work:

- Verify `POST /direct_uploads` works from TinySteps with the current auth/requestor stack.
- Verify response decodes `signed_id`, `direct_upload.url`, and upload headers.
- Add or verify requestor support for uploading audio bytes to the returned storage URL with returned headers.
- Use fixed note body `<student> voice`; do not spend implementation time testing empty-body notes for the hackathon.
- Decide whether production build blocks child voice until consent data exists.
- Document any confirmed change back into the plan.

Acceptance Criteria:

- Direct upload endpoint and response model are known.
- Storage upload with returned URL/headers is possible.
- `MBEndpointRequesting`/`MBAPIRequestor` has a raw upload method for returned storage URLs.
- Fixed note body behavior is documented.
- Consent gate decision is explicit before release.

Tests:

- None.

## Task 1 - Decode And Render Portfolio Audio

Owner: App engineer

Files:

- `Packages/MBAPI/Sources/MBAPI/Domain/Models/MBAudioMessage.swift`
- `Packages/MBAPI/Sources/MBAPI/Domain/Models/Portfolio/Timeline/PortfolioTimelineItem.swift`
- `TinySteps/TinySteps/Features/Portfolio/PortfolioEntry.swift`
- `TinySteps/TinySteps/Features/Portfolio/PortfolioEntryNormalizer.swift`
- `TinySteps/TinySteps/Features/Portfolio/PortfolioTimelineView.swift`
- `TinySteps/TinyStepsTests/PortfolioTimelineModelTests.swift`

Goal:

Make existing `audio_description` data visible in the stream.

Work:

- Add an `MBAudioMessage` model with `url`, `blob`, `content_type`, and optional duration metadata.
- Decode `audio_description_id` and `audio_description` on timeline `Logable`.
- Add `PortfolioEntryAudio` and `PortfolioEntry.audio`.
- Normalize `logable.audioDescription` into `PortfolioEntry.audio`.
- Render a child-voice card in `PortfolioTimelineView` using the `child-voice-in-portfolio.png` control structure: play/pause button, waveform/progress area, duration label, and mic/copy row.
- Use role-specific copy: parent `"<Child name> wanted to tell you something."`, teacher `"<Child name> wanted to share something."`
- Do not autoplay under any condition.
- Promote standalone audio note rendering when note body is empty and audio exists.

Acceptance Criteria:

- Timeline JSON with `audio_description` decodes successfully.
- Stream cards show a distinct child-voice audio row/card.
- Child-voice cards include explicit play controls, waveform/progress, duration, and child-centered copy.
- Child-voice cards never autoplay.
- Audio is not rendered as a generic file.
- Existing timeline items without audio render unchanged.

Tests:

- Add decode fixture/test for `audio_description`.
- Add normalizer test for `PortfolioEntry.audio`.

## Task 2 - Add Audio Upload And Payload Encoding

Owner: API/app integration engineer

Files:

- `Packages/MBAPI/Sources/MBAPI/Domain/Models/Portfolio/PortfolioPublishModels.swift`
- `Packages/MBAPI/Sources/MBAPI/APIEndpoints/MBPortfolioEndpoint.swift`
- `TinySteps/TinySteps/Features/Portfolio/Services/PortfolioService.swift`
- `TinySteps/TinySteps/Features/ReviewQueue/PortfolioPublishPayload.swift`
- `TinySteps/TinyStepsTests/PortfolioPublishPayloadTests.swift`

Goal:

Allow note and photo resource creation to carry child voice via `audio_description_id`.

Work:

- Add an upload response model that exposes `signedID`.
- Add direct-upload request/response models matching old app `MBAmazonUpload`, `MBAmazonResponse`, `MBAmazonDirectUpload`, and returned headers.
- Add endpoint/service method for `POST /direct_uploads`.
- Add `MBEndpointRequesting`/`MBAPIRequestor` support for raw upload to the returned `direct_upload.url` with returned headers.
- Add service logic that records/upload files as `.m4a` with MIME type `audio/mp4`.
- Add optional `audioDescriptionID` to note and photo payload structs.
- Encode it as `audio_description_id`.
- Ensure nil does not break existing note/photo creation.
- Add payload factory parameters for optional audio.

Acceptance Criteria:

- Note payload can encode `audio_description_id`.
- Photo payload can encode `audio_description_id`.
- Existing publish paths still work with nil audio.
- Upload service returns a signed id that can be passed to resource creation.
- Upload service performs both phases: create direct upload blob, then upload audio bytes to returned storage URL.

Tests:

- Payload encoding tests for note and photo with audio.
- Payload encoding tests for note and photo without audio.

## Task 3 - Build Reusable Child Voice Capture Module

Owner: Feature engineer

Files:

- `TinySteps/TinySteps/Features/ChildVoice/ChildVoiceCaptureSession.swift`
- `TinySteps/TinySteps/Features/ChildVoice/ChildVoiceCaptureView.swift`
- `TinySteps/TinySteps/Features/ChildVoice/ChildVoiceCaptureViewModel.swift`
- `TinySteps/TinySteps/Features/ChildVoice/ChildVoiceAudioRecorder.swift`
- `TinySteps/TinySteps/Features/ChildVoice/ChildVoiceModels.swift`
- `TinySteps/TinySteps/Features/ChildVoice/ChildVoiceStudentPickerSheet.swift`
- `TinySteps/TinyStepsTests/ChildVoiceCaptureViewModelTests.swift`

Goal:

Create a child-centered audio recording flow independent of teacher speech transcription.

Work:

- Implement `ChildVoiceChild` and `ChildVoiceDraft`.
- Implement AVFoundation recording to a local `.m4a` file using AAC.
- Return/store a generated local audio filename or id, not an absolute file URL.
- Request microphone permission.
- Enforce max duration of 30 seconds.
- Provide states for assent, ready, recording, recorded, saving local draft, saved, failed.
- Add playback/rerecord/discard controls.
- Add child-centered copy such as `<Name> said yes`.
- Store temporary audio with file protection.
- Delete temporary audio on discard.

Acceptance Criteria:

- A child can record, play back, rerecord, discard, or save.
- Recording stops automatically at 30 seconds.
- The view never produces a result without a selected child.
- Raw audio is not transcribed.
- Discard removes local audio.

Tests:

- View model state tests using a fake recorder.
- Max-duration behavior test.
- Discard cleanup test with fake file manager or recorder.

## Task 4 - Attach Child Voice From Image Review

Owner: Feature engineer

Files:

- `TinySteps/TinySteps/Features/FaceCapture/FaceCaptureDraft.swift`
- `TinySteps/TinySteps/Features/FaceCapture/Photo/FaceCaptureViewModel.swift`
- `TinySteps/TinySteps/Features/FaceCapture/Photo/FaceCaptureView.swift`
- `TinySteps/TinySteps/Features/ReviewQueue/PortfolioReviewItemPublisher.swift`
- `TinySteps/TinySteps/Features/ReviewQueue/PortfolioPublishPayload.swift`
- `TinySteps/TinyStepsTests/FaceCaptureViewModelTests.swift`
- `TinySteps/TinyStepsTests/PortfolioReviewItemPublisherTests.swift`

Goal:

Let a teacher attach one child's voice to a photo draft from the captured-image review screen.

Work:

- Add optional `childVoice` to `FaceCaptureDraft` with backwards-compatible decoding.
- Add `linkedChildForVoice` to `FaceCaptureViewModel`.
- Return a child only when exactly one face label is matched and no unknown face labels remain.
- Add `attachChildVoice(_:)` and `removeChildVoice()`.
- Add child-voice button to `FaceCaptureView.reviewActionBar`.
- Disable the button for zero or multiple linked children.
- Present `ChildVoiceCaptureView` from the image review screen.
- Save returned child voice into the face capture draft.
- During photo publish, upload audio first, then include `audio_description_id` in the photo payload.
- Delete local child-voice audio after successful photo publish.

Acceptance Criteria:

- Button disabled when no child is linked.
- Button disabled when multiple children are linked.
- Button disabled when any unknown face remains.
- Button enabled when exactly one child is linked and no unknown face remains.
- Attached voice survives saving the photo draft.
- Publishing the photo uploads audio before creating the photo resource.
- Photo resource receives `audio_description_id`.

Tests:

- Enablement tests for zero, one, and multiple matched labels.
- Face draft Codable test for old drafts missing `childVoice`.
- Publisher order test using fake `PortfolioService`.

## Task 5 - Add Direct Capture Child Voice Local Draft Flow

Owner: Feature engineer

Files:

- `TinySteps/TinySteps/Features/ClassRoster/ClassRosterView.swift`
- `TinySteps/TinySteps/Features/Home/TeacherHomeView.swift`
- `TinySteps/TinySteps/Features/ChildVoice/ChildVoicePortfolioPublisher.swift`
- `TinySteps/TinySteps/Features/ChildVoice/ChildVoiceStudentPickerSheet.swift`
- `TinySteps/TinySteps/Features/ReviewQueue/PortfolioReviewItem.swift`
- `TinySteps/TinySteps/Features/ReviewQueue/ObservationReviewQueueModel.swift`
- `TinySteps/TinySteps/Features/ReviewQueue/ObservationReviewQueueView.swift`
- `TinySteps/TinySteps/Features/ObservationCapture/ObservationCaptureDraft.swift`
- `TinySteps/TinySteps/Features/ObservationCapture/ObservationCaptureDraftStore.swift`
- `TinySteps/TinySteps/Features/ReviewQueue/PortfolioStudentAssignmentResolver.swift`
- `TinySteps/TinySteps/Features/ReviewQueue/PortfolioPublishPayload.swift`
- `TinySteps/TinyStepsTests/ObservationCaptureDraftStoreTests.swift`

Goal:

Add `Capture Child Voice` to the class gear menu and save a personal note draft locally.

Work:

- Add `onCaptureChildVoice` callback to `ClassRosterView`.
- Add `Capture Child Voice` menu item for concrete selected class with loaded roster.
- In `TeacherHomeView`, present a student picker before recording.
- Start `ChildVoiceCaptureView` in standalone note mode after child selection.
- Save a normal `ObservationCaptureDraft` after recording.
- Attach optional child voice metadata to the note draft.
- Store the local audio filename/id, duration, class, and selected child identity.
- Resolve selected child to one future `assigned_user_ids` value before accepting the draft.
- Use title `In <child>'s words`.
- Add child-voice drafts into the Review queue.
- Refresh Review count after save.
- Stay in the current class context after save; do not switch to Review yet.

Acceptance Criteria:

- Menu entry appears only when class context can produce a roster.
- Direct flow cannot start recording before child selection.
- Direct flow cannot save a draft without one child user id.
- Created local draft has exactly one assigned child.
- Created local draft is a note draft with fixed transcript/body `<student> voice`, empty tags, and `pendingRetag == false`.
- No audio upload occurs during direct capture save.
- User returns to the class/review context after success.
- Review shows the child-voice note draft as a note.

Tests:

- Direct draft save blocks missing user id.
- Direct draft stores exactly one assigned child and local audio URL.
- Direct capture save does not call upload.
- Direct draft has empty tags and `pendingRetag == false`.
- Menu callback test if existing view tests support it.

## Task 6 - Publish Child-Voice Drafts

Owner: Feature engineer

Files:

- `TinySteps/TinySteps/Features/ChildVoice/ChildVoicePortfolioPublisher.swift`
- `TinySteps/TinySteps/Features/ChildVoice/ChildVoiceDraftStore.swift`
- `TinySteps/TinySteps/Features/ReviewQueue/PortfolioReviewItemPublisher.swift`
- `TinySteps/TinySteps/Features/ReviewQueue/PortfolioPublishPayload.swift`
- `TinySteps/TinySteps/Features/ReviewQueue/PortfolioReviewItem.swift`
- `TinySteps/TinySteps/Features/ReviewQueue/ObservationReviewQueueModel.swift`
- `TinySteps/TinyStepsTests/ChildVoicePortfolioPublisherTests.swift`

Goal:

Upload child voice only during Review publishing and then create the portfolio resource.

Work:

- Add child-voice note draft support to the publish pipeline.
- Upload the local audio file during publish.
- Use the returned `signed_id` as `audio_description_id`.
- Persist the uploaded `signed_id` on the local draft if resource creation fails after upload.
- On retry, reuse the persisted signed id before uploading again.
- Create a class note with exactly one `assigned_user_ids` value.
- Use title `In <student>'s words`.
- Use body `<student> voice`, for example `Amara voice`.
- Use the same default note preset/theme resolution as current observation notes.
- Delete local audio after successful publish.
- Keep the local draft and audio if upload or note creation fails.
- Ensure photo drafts with attached child voice follow the same upload-during-publish rule.

Acceptance Criteria:

- Direct child-voice note draft does not upload before publish.
- Publishing uploads audio before creating the note.
- Created note includes `audio_description_id`.
- Created note has exactly one assigned user.
- Created note uses fixed body `<student> voice`.
- Created note uses the default note preset/theme.
- Failed publish preserves the local audio for retry.
- Successful publish removes the local audio file and local draft.

Tests:

- Publisher order test: upload audio, then create note.
- Failed upload keeps local draft/audio.
- Failed create after upload keeps local draft/audio for retry.
- Failed create after upload stores the signed id for retry.
- Successful publish deletes local audio.

## Task 7 - Add Required Stream Playback Controls

Owner: UI engineer

Files:

- `TinySteps/TinySteps/Features/ChildVoice/ChildVoiceAudioPlayer.swift`
- `TinySteps/TinySteps/Features/Portfolio/PortfolioTimelineView.swift`
- `TinySteps/TinySteps/Features/ChildVoice/ChildVoiceCaptureView.swift`

Goal:

Make recording and Stream playback functional, explicit, and app-native.

Work:

- Add simple audio player service using AVFoundation.
- Follow old app playback behavior: configure bearer-token-backed remote playback for non-S3 URLs and skip auth headers for S3/Amazon URLs.
- Either use an `AVURLAsset` with `AVURLAssetHTTPHeaderFieldsKey` for bearer auth or authenticated download to a protected local temp file before playback.
- Add progress/duration display for local and remote audio.
- Add soft waveform or pulse visualization.
- Ensure tapping the stream audio card or play button toggles playback.
- Do not start playback from visibility, scroll position, or timers.
- Ensure only one child-voice clip plays at a time.
- Respect silent mode/audio session expectations.
- Use role-specific copy in the Stream card.

Acceptance Criteria:

- Recorded audio can be replayed before save.
- Published audio can be played from Stream.
- Published audio only plays after explicit user action.
- Non-S3 remote audio playback sends bearer auth.
- S3/Amazon direct URLs play without bearer auth.
- Parent Stream copy says `<Child name> wanted to tell you something.`
- Teacher Stream copy says `<Child name> wanted to share something.`
- Playback stops when leaving the screen.
- UI uses the app's warm cream/green style.

Tests:

- View model/player tests with fake player where practical.
- Manual QA for audio route and interruption behavior.

## Task 8 - Security, Privacy, And Cleanup Pass

Owner: Lead engineer

Files:

- `TinySteps/TinySteps/Features/ChildVoice/ChildVoiceAudioRecorder.swift`
- `TinySteps/TinySteps/Features/FaceCapture/FaceCaptureDraftStore.swift`
- `TinySteps/TinySteps/Features/ObservationCapture/ObservationCaptureDraftStore.swift`
- `TinySteps/TinySteps/Features/ChildVoice/ChildVoiceCaptureView.swift`
- `docs/features/child-voice/implementation-plan.md`

Goal:

Close sensitive-audio handling gaps before release.

Work:

- Ensure local child voice files use file protection.
- Ensure local files are removed on discard, successful direct note publish, and successful photo publish.
- Ensure drafts persist generated audio filenames/ids rather than absolute URLs.
- Ensure raw audio file paths are not logged.
- Ensure raw audio is not serialized into observation draft JSON.
- Add user-facing copy for missing permission and upload failure.
- Document production consent gate if not implemented.

Acceptance Criteria:

- No raw child audio remains after successful save/publish.
- No raw child audio is stored in unrelated draft stores.
- Permission-denied state is clear and recoverable.
- Release gate is documented for parent consent if not implemented.

Tests:

- Cleanup tests for discard and successful publish.
- Manual check that logs do not contain local file paths.

## Optional Follow-Up Tasks

- After-the-fact attach child voice to already published items using PUT and purge support.
- Parent-facing transcript and translation controls.
- Parent consent source and resend-consent shortcut.
- Retention management UI.
- Rich waveform generation with cached waveform data.
- Audio moderation listen-before-publish chip in Review history.

## Lead Review Amendments Integrated

- Embedded photo child voice must follow the existing Review path rather than creating a second resource immediately.
- Direct class menu child voice must select the child before recording.
- All save/publish paths must send exactly one `assigned_user_ids` value.
- Audio upload must happen before resource creation, but only during publish.
- The feature must not reuse teacher speech transcription for child audio.
- Local child audio cleanup and consent are release gates, not polish.
- Direct class menu capture must create a local draft first; it must not upload or create the note until Review publish.
