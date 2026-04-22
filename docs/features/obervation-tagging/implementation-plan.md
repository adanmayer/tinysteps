# Observation Tagging - Implementation Plan

Role: Lead Engineer and PM, integrated by orchestrator

## Upfront Questions

These decisions should be confirmed before implementation. Proposed defaults are included so engineering is not blocked.

1. **Should we keep the existing feature folder typo `obervation-tagging`?**
   - Proposed default: keep it for this planning pass because the source image and text already live there. Optionally rename the folder in a separate cleanup commit.

2. **Should the first app version call the experiment's local-LAN LLM tagger directly?**
   - Proposed default: no direct client-to-LLM production call. Use a service boundary. If approved for demo/dev, gate the local-LAN tagger behind configuration. Production should route remote tagging through a controlled backend or stay transcript-only with `pendingRetag`.

3. **What happens when tagging is unavailable, offline, or privacy-disabled?**
   - Proposed default: allow transcript-first local drafts. Store empty tags, `confidence = 0`, and `pendingRetag = true`. Do not block capture on tagging. If no backend create endpoint exists, local draft storage must be durable protected app storage, not in-memory storage and not `UserDefaults`.

4. **Should the model write the observation narrative?**
   - Proposed default: no. The teacher's transcript is the observation description. The model only suggests PYP tags, confidence, and evidence spans.

5. **How should child names be detected?**
   - Proposed default: deterministic local roster matching only. The LLM must not invent or infer children. Ambiguous matches stay unresolved for review. Fuzzy matching is default-off for MVP because false child attribution is higher risk than missed attribution.

6. **Where should the flow launch from?**
   - Proposed default: add a class-scoped gear menu item labelled exactly `Capture observation` in the class overview. Present a separate `ObservationCaptureView` from `TeacherHomeView`, mirroring the current face-capture presentation pattern.

7. **What should save do before a production create-observation API exists?**
   - Proposed default: save through an `ObservationDraftStore` boundary and label it as a local draft/review state. Do not pretend the observation was published, synced, or created on the backend.

## References Read

- `docs/features/obervation-tagging/tagging.txt`
- `docs/features/obervation-tagging/tagging.png`
- `docs/workflows/feature-planning-orchestration.md`
- `docs/features/face-capture/implementation-plan.md`
- `docs/features/face-capture/implementation-tasks.md`
- `docs/requirements/face-tagging.md`
- `TinySteps/TinySteps/Features/ClassRoster/ClassRosterView.swift`
- `TinySteps/TinySteps/Features/Home/TeacherHomeView.swift`
- `TinySteps/TinySteps/Features/Portfolio/Services/PortfolioService.swift`
- `Packages/MBAPI/Sources/MBAPI/APIEndpoints/MBPortfolioEndpoint.swift`
- `Packages/MBAPI/Sources/MBAPI/Domain/Models/Portfolio/Portfolio.swift`
- `/Users/dave/Development/swift/tinysteps/docs/experiments/experiment-03-pyp-capture-and-tagging.md`
- `/Users/dave/Development/swift/tinysteps/docs/experiments/exp-03-pyp-gold-decisions.md`
- `/Users/dave/Development/swift/tinysteps/docs/experiments/exp-03-pyp-taxonomy-source.md`
- `/Users/dave/Development/swift/tinysteps/Experiments/VoiceTranscript/VoiceTranscript/STT/SpeechTranscriber.swift`
- `/Users/dave/Development/swift/tinysteps/Experiments/VoiceTranscript/VoiceTranscript/Drafting/ObservationDraft.swift`
- `/Users/dave/Development/swift/tinysteps/Experiments/VoiceTranscript/VoiceTranscript/Drafting/PYPTag.swift`
- `/Users/dave/Development/swift/tinysteps/Experiments/VoiceTranscript/VoiceTranscript/Drafting/PYPTagBundle.swift`
- `/Users/dave/Development/swift/tinysteps/Experiments/VoiceTranscript/VoiceTranscript/Drafting/PYPTaxonomy.swift`
- `/Users/dave/Development/swift/tinysteps/Experiments/VoiceTranscript/VoiceTranscript/Drafting/PYPScoring.swift`
- `/Users/dave/Development/swift/tinysteps/Experiments/VoiceTranscript/VoiceTranscript/Drafting/DraftingEngine.swift`
- `/Users/dave/Development/swift/tinysteps/Experiments/VoiceTranscript/VoiceTranscript/Drafting/OpenAICompatibleDraftingEngine.swift`
- `/Users/dave/Development/swift/tinysteps/Experiments/VoiceTranscript/VoiceTranscriptTests/VoiceTranscriptTests.swift`

## Product Intent

Observation Tagging gives a teacher a fast, class-scoped way to capture a spoken classroom moment and turn it into a reviewable PYP-aligned draft.

The feature should preserve the teacher's words. It should not rewrite the observation or overstate AI confidence. The system assists by suggesting conservative tags for review: transdisciplinary theme, key concepts, ATL skills, learner profile attributes, confidence, and evidence spans.

## PM Product Frame

The teacher is already in the class overview checking children and setup. `Capture observation` should feel like a direct class action, not a new global capture destination. The separate capture view should match the supplied visual direction: warm cream, large sage microphone, calm transcript area, and PYP chips that bloom when the teacher speaks.

The core promise is speed plus structure:

- Speed: press and hold, speak, release.
- Structure: chips suggest PYP tags after the transcript exists.
- Trust: transcript stays primary, child matching stays local, and unsupported tags are omitted.

## Primary Users

- Classroom teachers capturing short in-the-moment observations.
- Teaching assistants capturing observations for later review by the lead teacher.
- Future reviewers such as coordinators or admins, after backend draft/review workflows exist.

## User Stories

- As a teacher viewing a specific class, I can open the gear menu and choose `Capture observation`.
- As a teacher, I can press and hold a large microphone control to record what I saw or heard.
- As a teacher, I can see live transcript text so I know capture is working.
- As a teacher, I can review suggested PYP tags that are tied to transcript evidence.
- As a teacher, I can see children detected only from the current class roster.
- As a teacher, I can keep a local draft even if tagging or backend save is unavailable.
- As a teacher, I can discard an empty or wrong capture without creating a misleading record.

## MVP Scope

Must ship:

- `Capture observation` menu item in the class overview gear menu.
- Availability limited to a concrete selected class; unavailable for `All Classes`.
- Separate `ObservationCaptureView` presented above `TeacherHomeView`.
- `ObservationCaptureSession` carrying selected class id, class name, and roster snapshot.
- Press-and-hold voice capture using an app-local speech service abstraction.
- Live transcript display with placeholder `Your words will appear here...`.
- PYP chip bloom row for `Theme`, `Concept`, `ATL`, and `Profile`.
- Local deterministic child name matching against the selected class roster.
- PYP tagging service boundary using the experiment schema: `tags`, `confidence`, and `evidenceSpans`.
- Strict taxonomy validation for PYP theme, key concepts, ATL skills, and learner profile.
- Transcript-only fallback when tagging is unavailable.
- Local draft boundary that does not pretend backend publication succeeded.
- Durable local draft storage with file protection, retention, and deletion rules when backend create is unavailable.
- If suggested tags or child matches are persisted as confirmed data, teacher controls to remove incorrect suggestions before save.
- Error handling for permission denied, no speech, tagging failure, and save failure.
- iPhone-first layout and manual QA.

Should ship if nearby:

- Teacher can remove an incorrect child match before saving the draft when suggestions are persisted as confirmed data.
- Teacher can remove an unsupported tag suggestion before saving the draft when suggestions are persisted as confirmed data.
- Evidence-span reveal when tapping a suggested chip.
- Typed correction/editing of transcript before saving.
- Local draft recovery after app background/foreground.

Explicit non-goals:

- No model-written narrative summary.
- No gamification, badges, streaks, or progression UI.
- No use of the placeholder Today tab as the launch surface.
- No cross-class capture.
- No LLM-generated child attribution.
- No production fake tags, fake students, or fake successful saves.
- No direct client API keys for remote LLM calls.
- No parent-facing sharing in this milestone.
- No full admin review workflow.

## Key Decisions

- The existing `ClassRosterView` gear menu pattern is the integration point.
- `TeacherHomeView` owns presentation state, as it already does for face capture.
- Observation capture gets its own module under `TinySteps/TinySteps/Features/ObservationCapture/`.
- The transcript is the observation description.
- The tagging engine returns only structured PYP tags, confidence, and evidence spans.
- Child matching is local and roster-scoped.
- Empty key concepts, empty ATL skills, and empty learner profile are valid.
- Tag suggestions are capped before reaching UI: theme max 1, key concepts max 2, ATL skills max 2, learner profile max 2.
- Every visible tag must be backed by an evidence span or dropped.
- Tagging failures never discard the transcript.
- Save goes through an explicit draft/create service boundary.
- Observation drafts contain sensitive classroom transcript data and require protected storage, retention, and deletion behavior.
- Before any transcript leaves device for tagging, matched child names should be redacted to placeholders unless an approved backend contract explicitly allows raw names.
- Production code must not log transcripts, prompts, model responses, child names, or evidence quotes.

## Data Model

Add observation capture values under:

```text
TinySteps/TinySteps/Features/ObservationCapture/
|-- ObservationCaptureSession.swift
|-- ObservationCaptureDraft.swift
|-- ObservationCaptureDraftStore.swift
|-- ObservationCaptureState.swift
|-- ObservationCaptureView.swift
|-- ObservationCaptureViewModel.swift
|-- ObservationTagModels.swift
|-- ObservationTaggingService.swift
|-- ObservationChildNameMatcher.swift
`-- ObservationSpeechTranscriber.swift
```

`ObservationCaptureSession` should carry the class context:

```swift
struct ObservationCaptureSession: Identifiable, Equatable, Sendable {
    let id: UUID
    let classID: String
    let className: String
    let rosterSnapshot: [ObservationRosterStudent]
}
```

`ObservationCaptureDraft` should preserve the teacher-authored transcript and draft state:

```swift
struct ObservationCaptureDraft: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var classID: String
    var className: String
    var transcript: String
    var matchedChildren: [ObservationMatchedChild]
    var tags: ObservationPYPTagBundle
    var confidence: Double
    var evidenceSpans: [ObservationEvidenceSpan]
    var pendingRetag: Bool
    var status: ObservationDraftStatus
    var createdAt: Date
    var updatedAt: Date
}
```

The app model should mirror the experiment's PYP shape:

```swift
struct ObservationPYPTagBundle: Codable, Equatable, Sendable {
    var transdisciplinaryTheme: PYPTheme?
    var keyConcepts: [PYPKeyConcept]
    var atlSkills: [PYPATLSkillCluster]
    var learnerProfile: [PYPLearnerProfile]
}
```

Use taxonomy enums copied or adapted from the experiment:

```swift
enum PYPTheme: String, CaseIterable, Codable, Sendable
enum PYPKeyConcept: String, CaseIterable, Codable, Sendable
enum PYPATLSkillCluster: String, CaseIterable, Codable, Sendable
enum PYPLearnerProfile: String, CaseIterable, Codable, Sendable
```

`ObservationEvidenceSpan` should keep a structured tag reference, the exact quote, and optionally offsets when available. A free string tag is too weak for validation.

```swift
struct ObservationEvidenceSpan: Codable, Equatable, Sendable {
    var category: ObservationPYPTagCategory
    var value: String
    var quote: String
    var start: Int?
    var end: Int?
}
```

## API And Services

### SpeechTranscribing

Wrap `SFSpeechRecognizer` behind an app-local protocol. Use the experiment's concurrency lesson: avoid `@Observable` and main-actor state inside the recognizer callback path. Keep callback state queue-safe.

```swift
protocol ObservationSpeechTranscribing: Sendable {
    func requestAuthorization() async -> ObservationSpeechAuthorizationStatus
    func start(locale: Locale) async throws -> AsyncThrowingStream<ObservationTranscriptEvent, Error>
    func stop() async -> String
    func cancel() async
}
```

Default behavior:

- Production either requires on-device speech recognition or uses Apple server-backed speech recognition only after privacy-approved copy and behavior are explicitly accepted.
- If local-only speech is configured, set on-device recognition as required where supported and fail to a recoverable unavailable state when unsupported.
- Use the app, organization, or class locale if available. Fall back to `Locale.current`. Keep `en-GB` for tests/demo only if required.
- Show a recoverable permission-denied state.
- Keep transcript capture usable even when tagging is unavailable.
- Handle `AVAudioSession` activation/deactivation, interruptions, route changes, cancellation cleanup, and no background recording.
- Check deployment target before adopting `OSAllocatedUnfairLock`; if unsupported, use an actor or serial queue fallback.

### ObservationTaggingService

Use the experiment's strict structured output:

```text
{
  "tags": {
    "transdisciplinaryTheme": "...",
    "keyConcepts": [],
    "atlSkills": [],
    "learnerProfile": []
  },
  "confidence": 0.0,
  "evidenceSpans": []
}
```

Proposed protocol:

```swift
protocol ObservationTaggingService: Sendable {
    func suggestTags(
        transcript: String,
        classContext: ObservationCaptureSession
    ) -> AsyncThrowingStream<ObservationTaggingEvent, Error>
}
```

Default behavior:

- Validate taxonomy values before exposing suggestions.
- Reject prose responses.
- Drop tags without evidence spans.
- Cap theme at 1, key concepts at 2, ATL skills at 2, and learner profile at 2.
- Prefer fewer tags over weak tags.
- If tagging fails, return transcript-only draft state with `pendingRetag = true`.
- Redact matched child names before remote tagging unless the approved backend contract explicitly permits raw names.

### ChildNameMatching

Implement this in the app; no reusable `ChildNameMatcher` source file was found in the experiment tree.

```swift
protocol ObservationChildNameMatching: Sendable {
    func matchChildren(
        in transcript: String,
        roster: [ObservationRosterStudent]
    ) -> [ObservationMatchedChild]
}
```

Default algorithm:

- Lowercase and normalize transcript tokens.
- Strip punctuation and possessive suffixes.
- Match exact first/display/preferred names.
- Keep fuzzy matching default-off for MVP.
- Optionally allow Levenshtein <= 2 for names with at least 5 characters only after explicit product/privacy approval.
- Leave ambiguous matches unresolved.
- Never ask the LLM to identify children.

### ObservationDraftStore

Use this as the MVP save boundary if the production create endpoint is missing.

```swift
protocol ObservationCaptureDraftStore: Sendable {
    func saveDraft(_ draft: ObservationCaptureDraft) async throws -> ObservationCaptureDraft.ID
    func deleteDraft(id: ObservationCaptureDraft.ID) async throws
}
```

Storage requirements:

- Use protected app storage, not `UserDefaults`.
- Use file protection appropriate for sensitive classroom transcript data.
- Delete drafts after explicit discard or successful backend create.
- If unsynced drafts are retained, define a retention period and cleanup path.
- Restrict in-memory stores to previews, tests, or DEBUG/demo use.

### ObservationCreating

Only add a final create service if the backend/API contract exists.

```swift
protocol ObservationCreating: Sendable {
    func createObservation(_ request: ObservationCreateRequest) async throws -> ObservationRecord
}
```

If absent, the UI must use draft/review language only.

## View Model / State Model

Use an explicit state machine:

```swift
enum ObservationCaptureState: Equatable {
    case idle
    case permissionUnknown
    case requestingPermission
    case ready
    case recording
    case transcribing
    case suggestingTags
    case draftReady
    case saving
    case saved
    case failed(ObservationCaptureError)
}
```

`ObservationCaptureViewModel` should be `@MainActor`. Speech recognizer callback state should remain off the main actor.

View-model responsibilities:

- Request microphone and speech permissions.
- Start recording on press.
- Stop recording on release.
- Stream live transcript text into the UI.
- Run local child matching after transcript changes.
- Run tag suggestions after final transcript.
- Persist local draft state.
- Save or mark unsynced through the draft/create boundary.
- Keep transcript when tagging fails.
- Confirm discard when transcript text exists.

State rules:

- Empty transcript disables save.
- No speech creates no draft unless the teacher explicitly keeps text from a retry.
- Tagging failure is not fatal to the draft.
- Save failure keeps the local draft retryable.
- Dismiss without transcript closes immediately.
- Dismiss with transcript prompts to discard or keep draft.

## Product States

- Class menu action available.
- Class menu action unavailable for `All Classes`.
- Speech permission unknown.
- Speech permission denied.
- Ready to record.
- Recording.
- No speech detected.
- Transcribing.
- Suggesting tags.
- Tagging unavailable.
- Draft ready with suggested tags.
- Draft ready with transcript only.
- Child matches found.
- Ambiguous child names.
- Save in progress.
- Local draft saved.
- Backend save failed.
- Discard confirmation.

## UI Plan

The capture view follows the supplied `tagging.png` and `tagging.txt` direction.

Screen direction:

- Warm cream background `#FBF6EE`.
- Soft rounded typography consistent with the app's warm teacher UI.
- Class context label near the top.
- Large centered sage microphone hero.
- Subtle pulsing ring during recording.
- Instruction text: `Press and hold to observe`.
- Transcript placeholder: `Your words will appear here...`.
- Live transcript area with enough height for a classroom note.
- Caption: `Chips bloom when you speak`.
- Four chip groups: `Theme`, `Concept`, `ATL`, `Profile`.
- Skeleton or low-opacity chips while recording/tagging.
- Suggested chips after tagging.
- Optional detected-child row below transcript.
- Bottom actions for keep/save draft and discard/retake.

Interaction defaults:

- Press down starts recording.
- Release stops recording.
- Chip tap shows evidence quote when available.
- Chip remove deletes a suggestion from the draft.
- Matched child tap can remove or mark unresolved.
- Save requires non-empty transcript.
- Close with draft asks before discard.

Do not add:

- Badges.
- Streaks.
- Progression meter.
- Confetti.
- Heavy gamified motion.

## Navigation

Class roster change:

```swift
struct ObservationCaptureLaunchContext: Equatable, Sendable {
    let classID: String
    let className: String
    let rosterSnapshot: [ObservationRosterStudent]
}

let onCaptureObservation: (ObservationCaptureLaunchContext) -> Void
```

Gear menu addition:

```swift
Button("Capture observation") {
    onCaptureObservation(launchContext)
}
.disabled(classContext == .allClasses || model.isLoading || selectedClass == nil)
```

Home presentation:

```swift
@State private var observationCaptureSession: ObservationCaptureSession?
```

```swift
.fullScreenCover(item: $observationCaptureSession) { session in
    ObservationCaptureView(captureSession: session, ...)
}
```

Dismissal returns to the same roster state and does not change the selected tab.

## Dependencies And Sequencing

1. Add domain models and taxonomy enums.
2. Add draft store boundary.
3. Add speech transcription service wrapper.
4. Add child name matcher.
5. Add tagging service protocol and strict parser.
6. Add remote/backend/local tagging implementation choice behind configuration.
7. Add `ObservationCaptureViewModel`.
8. Add `ObservationCaptureView`.
9. Wire class roster menu callback.
10. Wire `TeacherHomeView` full-screen presentation.
11. Add create-observation or local-draft save path.
12. Add dependency composition for speech, tagging, draft, and create services.
13. Add target membership for all new Swift files.
14. Add tests and iPhone manual QA.

## Integration Steps

- Add `ObservationCapture` module files to the app target.
- Add `NSSpeechRecognitionUsageDescription` if missing.
- Confirm `NSMicrophoneUsageDescription` copy is present and specific enough.
- Confirm `PrivacyInfo.xcprivacy` or the app privacy manifest covers microphone, speech recognition, transcript storage, and any remote AI processing.
- Add observation draft store to app dependency composition.
- Add tagging service dependency to app dependency composition.
- Add speech service dependency to app dependency composition.
- Add create-observation service dependency only if a real backend contract exists.
- Extend `ClassRosterView` with `onCaptureObservation`.
- Extend `TeacherHomeView` with observation capture session state.
- Keep `Capture image` unchanged and add `Capture observation` as a sibling action.
- Add backend client endpoint only if a real create contract exists.
- After successful backend create, invalidate or refetch the relevant portfolio/timeline view.
- If using local-LAN experiment tagging for demo, keep it behind non-production configuration.

## Tests

Targeted tests should cover:

- Taxonomy raw values match the compressed prompt.
- Strict tag JSON parses into `ObservationPYPTagBundle`.
- Invalid taxonomy values are rejected.
- Prose or malformed model output is rejected.
- Tags without evidence spans are dropped.
- Theme suggestions are capped at one.
- Key concept suggestions are capped at two.
- ATL skill suggestions are capped at two.
- Learner profile suggestions are capped at two.
- Evidence offset bounds and quote substring matching are validated.
- Empty transcript does not trigger tagging.
- No speech leaves save disabled.
- Transcript-only fallback sets `pendingRetag = true`.
- Exact child name match works against current roster.
- Possessive child name forms are normalized.
- Ambiguous child names are not auto-assigned.
- Duplicate first names are not auto-assigned.
- Nickname collisions are not auto-assigned.
- Name substrings inside other words are not matched.
- Hyphenated names, apostrophes, and diacritics are handled deliberately.
- View-model flow: ready -> recording -> suggestingTags -> draftReady.
- Save failure preserves the local draft.
- Discard deletes local draft state.
- Class roster menu action is unavailable for `All Classes`.
- `TeacherHomeView` presents capture with the selected class snapshot.

## Manual Acceptance

- On iPhone, select a concrete class and verify the gear menu shows `Capture observation`.
- Switch to `All Classes` and verify observation capture is unavailable.
- Open capture and verify the visual layout matches the warm mic-first reference.
- Deny microphone or speech permission and verify recoverable error copy.
- Press and hold the mic and verify live transcript appears.
- Release the mic and verify tag chips enter a tagging/skeleton state.
- Speak a clear child name and verify local roster match.
- Speak an ambiguous child name and verify it is not auto-assigned.
- Use a short sentiment-only observation and verify weak tags are omitted.
- Disable network/tagging and verify transcript-only draft behavior.
- Save a draft and verify copy says local draft/review, not published or synced.
- Close with a non-empty transcript and verify discard/keep behavior.
- Test offline mode with on-device speech unavailable.
- Interrupt audio during press-and-hold and verify cleanup.
- Background the app while recording and verify no background recording continues.
- Release outside the mic hit target and verify recording stops safely.
- Force quit and reopen with an unsynced local draft.
- Check iPhone small-screen layout, Dynamic Type, and VoiceOver labels.

## Risks And Mitigations

- **Remote transcript privacy risk:** do not ship direct client LLM calls without approval; route through backend or use transcript-only drafts.
- **Raw child names in remote tagging:** redact matched names to placeholders unless an approved backend contract explicitly allows raw names.
- **Backend create endpoint missing:** use local draft boundary and honest draft copy.
- **Over-tagging:** cap categories, require evidence spans, and drop low-confidence suggestions.
- **False child detection:** match locally and leave ambiguous cases unresolved.
- **Speech recognition unavailable:** show recoverable permission/unavailable state and keep retry path.
- **Tagging latency:** keep transcript primary and let chips update asynchronously.
- **Draft loss:** persist local draft state before network operations.
- **Sensitive logs:** do not write transcripts, prompts, model responses, child names, or evidence quotes to production logs, analytics, crash breadcrumbs, or telemetry.
- **Taxonomy drift:** centralize enum values and prompt text with tests.
- **UI overload:** follow the sparse visual reference and avoid progress/gamification.

## Definition Of Done

- `Capture observation` launches from the class roster gear menu.
- The flow is presented as a separate view scoped to the selected class.
- Press-and-hold voice capture works on iPhone.
- Transcript text remains the observation description.
- PYP chips render according to the feature visual.
- Child name matching is local and scoped to the selected roster.
- Tag suggestions use the experiment PYP schema and strict validation.
- Tagging failure produces a usable transcript-only draft.
- Save uses a real draft/create boundary and does not fake backend success.
- Privacy and permission copy are explicit.
- Targeted tests cover parser, matcher, state, and draft behavior.
- Manual iPhone QA passes.
- The app builds successfully before the feature is called done.
