# Child Voice - Implementation Plan

Role: Lead Engineer and PM, integrated by orchestrator

Note: Lead Engineer, PM, Senior Engineer, and Lead Review passes were performed sequentially by the orchestrator because agent delegation was not explicitly requested for this turn.

## Upfront Questions

These are the decisions to confirm before implementation. Proposed defaults are included so implementation can start without waiting.

1. **Which upload endpoint should return the audio `signed_id`?**
   - Decision from old app: use the direct upload flow. `POST /direct_uploads` with filename, content type, byte size, and checksum. The response is `MBAmazonResponse` with `signed_id` and `direct_upload` URL/headers. Upload the local audio bytes to `direct_upload.url` with those headers, then use `signed_id` as `audio_description_id` on the portfolio resource payload.

2. **Can a standalone note have an empty body when it has audio?**
   - Decision: no empty body for the hackathon implementation. Use a fixed note body of `<student> voice`, for example `Amara voice`, and use the same default note theme/preset currently used for observation notes.

3. **Should direct child voice go through Review?**
   - Decision: yes. Direct capture from the class gear menu records locally, creates a local pending child-voice note draft, and uploads audio only when the teacher publishes from Review. This keeps child audio on device until the explicit publish step.

4. **What makes the image child-voice button enabled?**
   - Decision: exactly one child must be linked to the image and no unknown faces may remain. If zero children, multiple children, or any unknown face remains, disable the button. This is stricter than counting linked children only, and avoids attaching one child's voice to an ambiguous group photo.

5. **How much safeguarding is in MVP?**
   - Proposed default: include the child-assent step and sensitive-audio storage cleanup in MVP. Parent-consent enforcement remains a release gate for production if consent data is not available locally yet.

6. **Should child voice be allowed on video?**
   - Decision from product requirements: no. Video already carries audio and remains out of scope for child voice.

7. **Which endpoint creates the personal portfolio entry?**
   - Hackathon demo default: continue using the existing class resource endpoint with exactly one `assigned_user_ids` value. Treat this as personal in the app because every child-voice draft has one fixed child. Production follow-up: confirm whether student portfolio visibility requires the student resource endpoint or `share_to_student_portfolios: true`.

8. **What audio format should local child voice use?**
   - Decision: record AAC in an `.m4a` container. Upload with MIME type `audio/mp4`.

9. **Should direct child voice become a new Review item type?**
   - Decision: no for the hackathon. Represent direct child voice as a note draft with attached child voice audio. The note body is `<student> voice`, tags remain empty, and `pendingRetag` is false.

10. **Should the app switch to Review after direct child voice capture?**
   - Decision: no for now. Save the local note draft and stay in the current class context because the button is expected to move shortly.

## References Read

- `docs/workflows/feature-planning-orchestration.md`
- `docs/requirements/app-feature-spec.md`
- `docs/requirements/live-capture.md`
- `docs/implementation-priorities.md`
- `/Users/dave/Development/swift/managebac-mobile-native-ios-copy/docs/portfolio-stream-porting-guide.md`
- `/Users/dave/Development/swift/managebac-mobile-native-ios-copy/Packages/MBAPI/Sources/MBAPI/Models/Domain/MBAudioMessage.swift`
- `/Users/dave/Development/swift/managebac-mobile-native-ios-copy/Packages/MBAPI/Sources/MBAPI/Models/Domain/Portfolio/MBPortfolio+Photo.swift`
- `/Users/dave/Development/swift/managebac-mobile-native-ios-copy/ManageBac/ManageBac/MB/Presentation/Screens/Portfolio/CardComponents/AudioView/PortfolioRoster+AudioView.swift`
- `/Users/dave/Development/swift/managebac-mobile-native-ios-copy/ManageBac/ManageBac/MB/Presentation/Screens/Portfolio/CardComponents/AudioView/PortfolioRoster+AudioViewModel.swift`
- `/Users/dave/Development/swift/managebac-mobile-native-ios-copy/ManageBac/ManageBac/MB/Presentation/Screens/Portfolio/CardComponents/AudioView/PortfolioRoster+AttachmentsViewModel.swift`
- `/Users/dave/Development/swift/managebac-mobile-native-ios-copy/ManageBac/ManageBac/MB/Presentation/Shared/Classes/DirectAttachmentsViewModel.swift`
- `/Users/dave/Development/swift/managebac-mobile-native-ios-copy/Packages/MBAPI/Sources/MBAPI/APIEndpoints/ChatAttachmentsAPI.swift`
- `/Users/dave/Development/swift/managebac-mobile-native-ios-copy/Packages/MBAPI/Sources/MBAPI/Models/Domain/Attachments/MBAmazonResponse.swift`
- `/Users/dave/Development/swift/managebac-mobile-native-ios-copy/Packages/MBAudio/Sources/MBAudio/Services/AudioEngine.swift`
- `/Users/dave/Development/swift/managebac-mobile-native-ios-copy/Packages/MBAudio/Sources/MBAudio/Services/CachingPlayerItem.swift`
- `/Users/dave/Development/swift/managebac-mobile-native-ios-copy/Packages/MBAudio/Sources/MBAudio/ViewModel/PlayerViewModel.swift`
- `TinySteps/TinySteps/Features/FaceCapture/Photo/FaceCaptureView.swift`
- `TinySteps/TinySteps/Features/FaceCapture/Photo/FaceCaptureViewModel.swift`
- `TinySteps/TinySteps/Features/FaceCapture/FaceCaptureDraft.swift`
- `TinySteps/TinySteps/Features/ClassRoster/ClassRosterView.swift`
- `TinySteps/TinySteps/Features/Home/TeacherHomeView.swift`
- `TinySteps/TinySteps/Features/ReviewQueue/PortfolioPublishPayload.swift`
- `TinySteps/TinySteps/Features/ReviewQueue/PortfolioReviewItemPublisher.swift`
- `TinySteps/TinySteps/Features/Portfolio/Services/PortfolioService.swift`
- `Packages/MBAPI/Sources/MBAPI/APIEndpoints/MBPortfolioEndpoint.swift`
- `Packages/MBAPI/Sources/MBAPI/Domain/Models/Portfolio/Timeline/PortfolioTimelineItem.swift`

## Product Intent

Child Voice lets a child contribute their own words to a portfolio item. The feature should feel like handing the phone to the child, not like adding another teacher admin field.

For this implementation, child voice records audio into a local draft first. On publish, the app uploads the local recording, takes the returned `signed_id`, and sends it as `audio_description_id` when creating the ManageBac portfolio resource. Once published, ManageBac returns the audio as `logable.audio_description`.

## PM Product Frame

The child is the author of this moment. The teacher controls context and publishing, but the capture screen should visually and verbally shift attention to the child.

Primary jobs:

- Let a teacher add one child's voice to a just-captured photo when the photo has exactly one linked child.
- Let a teacher create a standalone personal note draft from the class gear menu by selecting a child first, then recording the child's voice.
- Show the resulting child voice in the stream as `In <child>'s words`, not as a generic file or hidden attachment.

## MVP Scope

### Must Ship

- Decode portfolio `audio_description_id` and `audio_description`.
- Normalize audio into `PortfolioEntry`.
- Render a child-voice card in the portfolio stream.
- Add a reusable child voice capture flow with record, stop, playback, discard, and save.
- Cap recordings at 30 seconds.
- Require a fixed child for every child-voice capture.
- Add a child-voice button to the image review screen.
- Enable that image button only when exactly one child is linked to the photo.
- Attach image-flow child voice to `FaceCaptureDraft` so publish creates a photo with `audio_description_id`.
- Add `Capture Child Voice` to the class gear menu.
- For direct capture, select one child first, then record and save a local pending note draft with that child as the only assigned user.
- Upload audio only during publishing, before creating the note/photo resource.
- Show and play child voice in the portfolio Stream with explicit playback controls.
- Clean up local audio files on discard and after successful publish.

### Should Ship If Nearby

- Local waveform preview during recording and playback.
- Retry upload without re-recording.
- Duration label in review and stream, such as `In Amara's words - 18s`.
- Parent-facing hero treatment for standalone child-voice notes.

### Explicitly Out Of Scope

- Child voice on video.
- Comments audio.
- After-the-fact attaching to already published items.
- Audio transcription or translation.
- Server-side retention controls.
- Parent-consent data model unless an existing source is already available.
- Speaker diarisation.

## Key Decisions

- Treat child voice as a portfolio audio description, not a file attachment.
- Persist embedded child voice with the draft that owns the final resource. For photo capture, that means extending `FaceCaptureDraft`.
- Direct child voice creates a local draft first. It does not upload or create the note until the teacher publishes from Review.
- Do not reuse `ObservationSpeechTranscriber` for child voice. This feature needs raw audio capture, not speech-to-text.
- Keep child selection based on `ObservationRosterStudent` or `FaceCaptureStudentSnapshot` so the app has `studentKey`, `userID`, and display name.
- Publishing requires a valid child `userID`, because `assigned_user_ids` needs server user ids. If missing, block with a clear message.

## Data Model

Add a small audio model in `MBAPI` based on the reference app:

```swift
public struct MBAudioMessage: Codable, Equatable, Sendable {
    public let url: URL
    public let blob: Blob

    public var duration: Double? { blob.metadata?.duration }
}
```

Decode these fields on `Portfolio.TimelineItem.Logable`:

```swift
public let audioDescriptionID: String?
public let audioDescription: MBAudioMessage?
```

Add UI-normalized audio:

```swift
struct PortfolioEntryAudio: Equatable, Sendable {
    let url: URL
    let duration: TimeInterval?
}
```

Extend `PortfolioEntry`:

```swift
let audio: PortfolioEntryAudio?
```

Extend local photo drafts:

```swift
struct ChildVoiceDraft: Codable, Equatable, Sendable {
    let childStudentKey: String
    let childUserID: String
    let childDisplayName: String
    let localFilename: String
    let duration: TimeInterval
    let createdAt: Date
    var uploadedAudioDescriptionID: String?
}
```

The local filename is resolved by a dedicated child voice store at runtime. Do not persist absolute app-container file URLs because iOS container paths can change.

`uploadedAudioDescriptionID` is set only after a publish attempt successfully uploads the audio but fails before resource creation. Retry should reuse this signed id first to avoid leaking extra orphan audio blobs.

`FaceCaptureDraft` gains:

```swift
let childVoice: ChildVoiceDraft?
```

The draft remains backwards-compatible by decoding missing `childVoice` as nil.

`ObservationCaptureDraft` also gains optional child voice metadata for direct child-voice note drafts:

```swift
var childVoice: ChildVoiceDraft?
```

Direct child-voice note drafts use:

- `transcript = "<student> voice"`
- `matchedChildren = [selected child]`
- `tags = .empty`
- `standardTagSuggestions = []`
- `pendingRetag = false`

## API And Services

Current portfolio service supports timeline reads, class note creation, photo upload, class photo creation, and settings. Required additions:

- Add `PortfolioAudioUploadResponse` or equivalent with at least `signedID`.
- Add `MBPortfolioEndpoint.uploadAudioDescription(...)`.
- Add `PortfolioService.uploadAudioDescription(...)`.
- Add `audioDescriptionID` to `PortfolioNoteCreatePayload`.
- Add `audioDescriptionID` to `PortfolioPhotoCreatePayload`.
- Ensure payload encodes `audio_description_id` as nil or string.
- Decode `audio_description` on timeline reads so published entries render audio.
- Persist the uploaded `signed_id` back to the local draft if audio upload succeeds but resource creation fails, then retry resource creation with that signed id before uploading again.
- Standalone direct child-voice note uses title `In <student>'s words`, body `<student> voice`, and the existing default note preset/theme resolved through `loadClassPortfolioSettings` just like current observation notes.
- TinySteps already supports the first direct-upload leg through generic authenticated JSON requests to base-path endpoints such as `/direct_uploads`.
- TinySteps does not currently have the second direct-upload leg: raw upload to the returned storage URL with custom headers. Add that capability to `MBEndpointRequesting`/`MBAPIRequestor` before implementing audio publish.

Reference upload contract during publish:

- Build a direct-upload request payload from the local audio file: filename, MIME type, byte size, checksum.
- `POST /direct_uploads`.
- Read `signed_id` and `direct_upload.url` plus `direct_upload.headers`.
- Upload the audio bytes to `direct_upload.url` with the returned headers.
- Send `signed_id` as `audio_description_id`.
- Read back `logable.audio_description`.

## View Model / State Model

Add a focused feature module:

```text
TinySteps/TinySteps/Features/ChildVoice/
```

Suggested files:

- `ChildVoiceCaptureSession.swift`
- `ChildVoiceCaptureView.swift`
- `ChildVoiceCaptureViewModel.swift`
- `ChildVoiceAudioRecorder.swift`
- `ChildVoiceStudentPickerSheet.swift`
- `ChildVoicePortfolioPublisher.swift`
- `ChildVoiceModels.swift`

`ChildVoiceCaptureSession` should describe mode:

```swift
enum ChildVoiceCaptureMode: Equatable, Sendable {
    case photoAttachment(classID: String, className: String, child: ChildVoiceChild)
    case standaloneNote(classID: String, className: String, selectedClass: MBClass, child: ChildVoiceChild)
}
```

`ChildVoiceCaptureViewModel.State`:

- `askingAssent`
- `ready`
- `recording`
- `recorded`
- `savingLocalDraft`
- `saved`
- `failed(String)`

For embedded photo capture, `saved` returns a `ChildVoiceDraft` to `FaceCaptureViewModel`.

For direct capture, `saved` means the local child-voice note draft was saved for Review.

## Product States

- **Image review, exactly one child linked:** button enabled with copy like `Add Amara's voice`.
- **Image review, no child linked:** button disabled with copy like `Name one child first`.
- **Image review, multiple children linked:** button disabled with copy like `Voice needs one child`.
- **Image review, unknown face remains:** button disabled with copy like `Name everyone first`.
- **Direct menu, roster loaded:** `Capture Child Voice` is available.
- **Direct menu, all classes selected or roster unavailable:** menu entry hidden or disabled.
- **Direct flow before capture:** show child picker.
- **Capture screen first state:** child assent gate, `Amara said yes`.
- **Recording:** large child-centered mic, timer, soft waveform or pulse.
- **Recorded:** playback, rerecord, discard, save.
- **Publish upload failure:** keep local recording in the Review draft and offer retry/discard from Review.
- **Successful save:** dismiss, increment Review count, and keep audio local until publishing.

## UI Plan

### Image Review Button

Use the existing `FaceCaptureView.reviewActionBar` pattern. Add a third child-voice action above or between the explanatory copy and the Retake/Keep row.

Rules:

- Button enabled only when `viewModel.linkedChildForVoice != nil`.
- `linkedChildForVoice` returns a child only when exactly one detected face label is `.matched` and there are no unknown face labels.
- Button opens `ChildVoiceCaptureView` as a full-screen cover or sheet over `FaceCaptureView`.
- When child voice is saved, `FaceCaptureViewModel.attachChildVoice(_:)` stores it for the draft.
- Review action bar shows an attached-state chip like `In Amara's words - 18s`.

### Class Gear Menu

Update `ClassRosterView` class options:

- Existing entries: `Capture image`, `Capture observation`, `Clear cache`.
- Add `Capture Child Voice` when a concrete class is selected and students are loaded.
- Trigger a callback such as `onCaptureChildVoice(observationLaunchContext)` or a new child-voice launch context.

Update `TeacherHomeView`:

- Add state for direct child voice picker/session.
- Present `ChildVoiceStudentPickerSheet` first.
- After child selection, present `ChildVoiceCaptureView` in standalone note-draft mode.
- On success, refresh Review count but stay in the current class context for now.

### Stream Rendering

Update `PortfolioTimelineView` card rendering:

- If `entry.audio != nil`, render a child-voice pull-out card below chips.
- If kind is `.note`, body is empty, and audio exists, promote the audio card visually as the hero content.
- Do not render audio as generic file media.

Child voice card controls should follow `docs/features/child-voice/child-voice-in-portfolio.png` with one product change: no autoplay.

- Left: large circular play/pause button in the app green.
- Center: soft waveform/progress treatment; decorative until playback starts, then shows progress.
- Right: duration label such as `0:42`.
- Bottom row: small mic icon plus child-centered copy.
- Parent copy: `<Child name> wanted to tell you something.`
- Teacher copy: `<Child name> wanted to share something.`
- Tight-space fallback: `<Child name> has something to share.`
- No autoplay on open, scroll, hover, or visibility. Playback only starts from an explicit tap on the play button or card.
- Accessibility label: `Play <Child name>'s voice message, <duration>.`

Playback details from old app:

- Remote portfolio audio is played with a bearer-token-aware player.
- The old app sets `MBAudio.AudioEngine.shared.bearerToken` from the access token.
- Its cached player attaches `Authorization: Bearer <token>` to `AVURLAssetHTTPHeaderFieldsKey` for non-S3 URLs.
- It skips the auth header for direct S3/Amazon URLs.
- Playback pauses on disappear and only starts after an explicit play action.

## Navigation

Embedded photo path:

```text
Class gear -> Capture image -> FaceCaptureView review -> Add <child>'s voice -> ChildVoiceCaptureView -> return to FaceCaptureView -> Keep -> Review queue -> Publish photo with audio_description_id
```

Direct path:

```text
Class gear -> Capture Child Voice -> Select child -> ChildVoiceCaptureView -> save local note draft with child voice -> Review -> Publish -> upload audio -> create class note with assigned_user_ids=[child] and audio_description_id -> Stream
```

## Dependencies And Sequencing

1. Add read-side audio models and stream rendering first. This makes API responses visible and testable.
2. Add audio upload support and payload fields.
3. Add local child voice recording module.
4. Integrate embedded photo attachment.
5. Integrate direct class menu note creation.
6. Add final tests and manual QA.

## Integration Steps

1. Decode and normalize `audio_description`.
2. Render child voice in Stream.
3. Build reusable recorder and capture UI.
4. Add `ChildVoiceDraft` to `FaceCaptureDraft`.
5. Add image review button and enablement logic.
6. Upload audio during photo publish and pass `audio_description_id`.
7. Add class menu entry and child picker.
8. Create a standalone local note draft with one assigned child and local audio.
9. Clean up local audio files after discard and successful publish.

## Tests

- `MBAPI` decode test for `audio_description`.
- Portfolio normalizer test maps audio to `PortfolioEntry.audio`.
- Portfolio payload encoding test includes `audio_description_id` for note/photo.
- Face capture view model test enables button for exactly one linked child and disables for zero/multiple.
- Face draft Codable compatibility test for missing `childVoice`.
- Publisher test uploads audio before creating photo/note.
- Direct draft save test blocks when selected child has no `userID`.
- Publish test uploads local audio before creating the standalone note.
- Stream rendering snapshot or focused view test for child-voice card if the project has view test support.

## Manual Acceptance

- Capture an image with no matched child: child voice button is disabled.
- Capture an image with two matched children: child voice button is disabled.
- Capture an image with exactly one matched child: child voice button is enabled.
- Attach child voice to a photo, keep it, publish it from Review, and confirm request includes `audio_description_id`.
- Open Stream and see the audio card on the published item.
- From class gear menu, tap `Capture Child Voice`, select one child, record audio, save, and confirm a Review draft appears.
- Publish the child-voice Review draft and confirm a note appears in Stream for only that child.
- Cancel recording and confirm no orphan local audio file remains.
- Fail publish upload, retry, and confirm recording is not lost.

## Risks And Mitigations

- **Direct upload mismatch:** old app uses `/direct_uploads`; TinySteps can call base-path endpoints with generic JSON `send`, but needs a raw upload method for the returned storage URL and custom headers.
- **Fixed standalone note body:** use `<student> voice` to avoid empty-body server validation issues, but keep Stream rendering audio-first.
- **Sensitive child audio leakage:** store temporary files in app support/tmp with file protection, delete on discard/success, and never put raw audio in observation draft JSON.
- **Fragile local file URLs:** persist generated filenames/ids only, then resolve URLs through the child voice draft store.
- **Partial publish failure after audio upload:** persist `uploadedAudioDescriptionID` in the local draft and retry resource creation with the existing signed id before uploading again.
- **Protected remote audio URLs:** old app uses bearer-token-backed playback for non-S3 URLs. TinySteps should do the same rather than relying on unauthenticated `AVPlayer(url:)`.
- **Missing child server user id:** block publish/direct creation with clear copy. Do not send student keys as `assigned_user_ids`.
- **Confusing ownership on group photos:** enforce exactly one linked child and no unknown faces before audio capture.
- **Review vs direct publish inconsistency:** resolved by routing both embedded photo voice and direct standalone voice through local drafts and Review. Publishing is the only upload point.

## Definition Of Done

- Child voice audio is stored in ManageBac as `audio_description`, not as a generic file asset.
- Every child-voice entry has exactly one assigned child.
- Image review button is disabled unless exactly one child is linked.
- Image review button is also disabled while any unknown face remains.
- Direct class menu flow requires child selection before recording.
- Direct flow creates a normal note draft with attached child voice first.
- Direct child voice uploads only during publishing.
- Photo publish sends audio with the photo resource when attached.
- Stream renders published child voice audio.
- Local child audio is cleaned up on discard and after successful save.
- Targeted unit tests cover decoding, payloads, enablement, and publishing order.
