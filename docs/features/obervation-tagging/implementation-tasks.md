# Observation Tagging - Implementation Tasks

Role: Senior Engineer, reviewed and amended by Lead Engineer

Source plan: `docs/features/obervation-tagging/implementation-plan.md`

## Working Assumptions

- The existing feature folder remains `docs/features/obervation-tagging/` for this pass.
- The feature launches from the selected class overview gear menu.
- The menu label is exactly `Capture observation`.
- The capture flow uses a separate `ObservationCaptureView`.
- The transcript remains the observation description.
- The model never writes a replacement narrative.
- Child matching is deterministic, local, and scoped to the selected class roster snapshot.
- PYP tagging uses the experiment schema: `tags`, `confidence`, and `evidenceSpans`.
- Direct production client-to-LLM calls are not allowed unless explicitly gated and approved.
- Tagging failure must never block transcript capture or local draft save.
- Backend publication must not be faked. If no real create endpoint exists, save as local draft/review only.
- If no backend create endpoint exists, local draft persistence is durable protected app storage, not in-memory storage and not `UserDefaults`.
- Production speech recognition either requires on-device recognition or uses Apple server-backed recognition only after privacy-approved copy and behavior.

## Delivery Slices

| Slice | Title | Depends On | Primary Owner |
|---|---|---|---|
| 1 | Observation domain models and draft boundary | None | iOS feature engineer |
| 2 | Speech transcription abstraction and permissions | Slice 1 | iOS platform engineer |
| 3 | Local roster-scoped child matcher | Slice 1 | iOS feature engineer |
| 4 | PYP tagging models, strict parser, and gated service boundary | Slice 1 | AI/ML integration engineer |
| 5 | Observation capture view model state machine | Slices 1 through 4 | iOS feature engineer |
| 6 | ObservationCaptureView UI | Slice 5 | iOS feature engineer |
| 7 | Class overview gear menu and TeacherHome presentation wiring | Slice 6 | iOS feature engineer |
| 8 | Save, discard, fallback, and draft recovery behavior | Slices 5 through 7 | iOS feature engineer |
| 9 | Tests, iPhone QA, privacy review, and build cleanup | Slices 1 through 8 | QA engineer and tech lead |

## Task 0 - Confirm Defaults And Guardrails

**Owner:** Mobile lead

**Goal:** Confirm the decisions that affect privacy, backend behavior, and user trust before implementation starts.

**Files:**

- `docs/features/obervation-tagging/implementation-plan.md`
- `docs/features/obervation-tagging/implementation-tasks.md`

**Work:**

- Confirm the feature folder typo is intentionally preserved for this pass.
- Confirm the exact menu label is `Capture observation`.
- Confirm the first implementation uses a separate `ObservationCaptureView`.
- Confirm the transcript is the observation description.
- Confirm child matching is local roster matching only.
- Confirm remote or local-LAN LLM tagging is not enabled in production without a privacy-approved backend or explicit non-production gate.
- Confirm local draft/review behavior is acceptable until a real create-observation endpoint exists.
- Confirm local drafts use durable protected storage with retention and deletion rules.
- Confirm remote tagging redacts matched child names unless approved backend explicitly allows raw names.

**Acceptance:**

- Engineering does not need to guess whether remote tagging is production-safe.
- The UI does not imply backend publication unless a real endpoint exists.
- The feature can be implemented incrementally without fake save or fake tag behavior.

## Task 1 - Add Observation Domain Models And Local Draft Boundary

**Owner:** iOS feature engineer

**Depends on:** Task 0

**Goal:** Create the observation capture foundation without UI or speech integration.

**Files:**

- `TinySteps/TinySteps/Features/ObservationCapture/ObservationCaptureSession.swift`
- `TinySteps/TinySteps/Features/ObservationCapture/ObservationCaptureDraft.swift`
- `TinySteps/TinySteps/Features/ObservationCapture/ObservationCaptureDraftStore.swift`
- `TinySteps/TinySteps/Features/ObservationCapture/ObservationCaptureState.swift`
- `TinySteps/TinySteps/Features/ObservationCapture/ObservationTagModels.swift`
- `TinySteps/TinySteps.xcodeproj/project.pbxproj`

**Work:**

- Add `ObservationCaptureSession` with `id`, `classID`, `className`, and `rosterSnapshot`.
- Add `ObservationRosterStudent` with the minimum roster fields needed for local matching.
- Add `ObservationMatchedChild` with student identity, matched text, and match kind.
- Add `ObservationCaptureDraft` preserving teacher transcript as the observation description.
- Add `ObservationPYPTagBundle` matching the experiment shape.
- Add `ObservationEvidenceSpan` with structured category, canonical taxonomy value, `quote`, optional `start`, and optional `end`.
- Add `ObservationDraftStatus` with local, tagging, ready, retryable, unsynced, and saved states as needed.
- Add `ObservationCaptureDraftStore` protocol with `saveDraft` and `deleteDraft`.
- Add an in-memory draft store only for previews, tests, or DEBUG/demo integration.
- Add durable protected draft storage if local drafts are the production save path.
- Do not store classroom transcripts in `UserDefaults`.
- Define draft retention and cleanup behavior for unsynced drafts.
- Delete drafts after explicit discard or successful backend create.
- Do not add backend publication behavior in this task.

**Acceptance:**

- Observation capture models compile as part of the app target.
- `ObservationCaptureDraft.transcript` is the only narrative observation description field.
- Draft state can represent transcript-only fallback with `pendingRetag = true`.
- PYP tags can represent empty key concepts, empty ATL skills, and empty learner profile.
- No backend success, publication, sync, or parent-facing state is implied.
- Production local drafts are recoverable across app relaunch if local drafts are the save path.
- Local draft storage uses file protection appropriate for sensitive classroom transcript data.

**Tests:**

- Model encoding and decoding round-trips for `ObservationCaptureDraft`.
- Empty tag arrays are valid.
- `pendingRetag = true` can be stored with empty tags and `confidence = 0`.
- Draft discard deletes protected local storage.
- Draft retention cleanup removes expired unsynced drafts.

## Task 2 - Add Speech Transcription Abstraction And Permissions

**Owner:** iOS platform engineer

**Depends on:** Task 1

**Goal:** Add an app-local speech transcription boundary that supports press-and-hold capture.

**Files:**

- `TinySteps/TinySteps/Features/ObservationCapture/ObservationSpeechTranscriber.swift`
- `TinySteps/TinySteps/Features/ObservationCapture/ObservationCaptureState.swift`
- `TinySteps/TinySteps/Info.plist`
- `TinySteps/TinySteps.xcodeproj/project.pbxproj`

**Work:**

- Add `ObservationSpeechTranscribing` protocol.
- Add `ObservationTranscriptEvent` for partial and final transcript updates.
- Add `ObservationSpeechAuthorizationStatus`.
- Implement an `SFSpeechRecognizer` backed adapter behind the protocol.
- Keep recognizer callback state queue-safe.
- Check deployment target before using `OSAllocatedUnfairLock`; use an actor or serial queue fallback if unsupported.
- Avoid `@Observable` and main-actor mutable state inside recognizer callbacks.
- In local-only speech mode, require on-device recognition where supported and fail to a recoverable unavailable state when unsupported.
- Use app, organization, or class locale if available. Fall back to `Locale.current`; keep `en-GB` for tests/demo only if required.
- Handle `AVAudioSession` activation, deactivation, interruptions, route changes, cancellation cleanup, and no background recording.
- Support `requestAuthorization`, `start`, `stop`, and `cancel`.
- Surface permission denied, recognizer unavailable, no speech, and cancellation as distinct recoverable states.
- Add `NSSpeechRecognitionUsageDescription` if missing.
- Confirm `NSMicrophoneUsageDescription` exists and is specific to classroom observation capture.

**Acceptance:**

- SwiftUI views do not depend directly on `SFSpeechRecognizer`.
- Permission-denied state is recoverable and does not crash.
- Stopping capture returns the final transcript string.
- Cancelling capture does not save or publish anything.
- Permission copy clearly explains speech and microphone use.
- No transcript is sent to any remote LLM or backend from this task.
- Production server-backed speech recognition is not enabled without privacy-approved copy and behavior.

**Tests:**

- Mock transcriber emits partial and final transcript events.
- Authorization denied maps to a recoverable state.
- No speech maps to a save-disabled state.
- Audio interruption stops or recovers recording without leaving the audio engine active.
- App backgrounding during recording stops capture and does not continue background recording.

**Manual QA:**

- Trigger microphone permission prompt on a fresh install.
- Trigger speech recognition permission prompt on a fresh install.
- Deny each permission and verify recoverable error copy once UI exists.

## Task 3 - Add Local Roster-Scoped Child Matcher

**Owner:** iOS feature engineer

**Depends on:** Task 1

**Goal:** Detect children mentioned in the transcript using only the selected class roster snapshot.

**Files:**

- `TinySteps/TinySteps/Features/ObservationCapture/ObservationChildNameMatcher.swift`
- `TinySteps/TinySteps/Features/ObservationCapture/ObservationTagModels.swift`
- `TinySteps/TinySteps.xcodeproj/project.pbxproj`

**Work:**

- Add `ObservationChildNameMatching` protocol.
- Implement deterministic local matching against `ObservationCaptureSession.rosterSnapshot`.
- Normalize transcript text by lowercasing, stripping punctuation, and handling possessive suffixes.
- Match exact first names, display names, and preferred names when available.
- Keep fuzzy matching default-off for MVP.
- Optionally support Levenshtein distance `<= 2` only after explicit product/privacy approval.
- Mark ambiguous matches unresolved instead of assigning a child.
- Never call the LLM for child identification.
- Never match against children outside the selected class roster.

**Acceptance:**

- Matching only uses the roster snapshot passed in the capture session.
- The same transcript can produce different matches when different rosters are provided.
- Ambiguous names are not auto-assigned.
- Child matching works offline.
- No cross-class lookup or global student search is introduced.

**Tests:**

- Exact first-name match works.
- Display-name or preferred-name match works when present.
- Possessive forms are normalized.
- Ambiguous names are not auto-assigned.
- A child outside the selected roster is not matched.
- Empty transcript returns no matches.
- Duplicate first names are not auto-assigned.
- Nickname collisions are not auto-assigned.
- Name substrings inside other words are not matched.
- Hyphenated names, apostrophes, and diacritics are handled deliberately.
- Class-only observations with zero matched children remain valid.

**Manual QA:**

- Speak a known child name and confirm a local match appears once UI exists.
- Use an ambiguous roster name and confirm the app does not auto-assign the child.

## Task 4 - Add PYP Tagging Models, Strict Parser, And Gated Service Boundary

**Owner:** AI/ML integration engineer

**Depends on:** Task 1

**Goal:** Add PYP tagging infrastructure using the experiment schema while preventing unsafe production LLM use.

**Files:**

- `TinySteps/TinySteps/Features/ObservationCapture/ObservationTagModels.swift`
- `TinySteps/TinySteps/Features/ObservationCapture/ObservationTaggingService.swift`
- `TinySteps/TinySteps/Features/ObservationCapture/ObservationCaptureState.swift`
- `TinySteps/TinySteps.xcodeproj/project.pbxproj`

**Work:**

- Add taxonomy enums copied or adapted from the experiment for PYP theme, key concepts, ATL skill clusters, and learner profile.
- Add `ObservationTaggingService` protocol.
- Parse only strict structured output with `tags`, `confidence`, and `evidenceSpans`.
- Reject prose responses.
- Reject malformed JSON.
- Reject unknown taxonomy values.
- Drop any visible tag without supporting evidence span.
- Use structured evidence spans with category plus canonical taxonomy value, not free string tags.
- Cap theme at 1, key concepts at 2, ATL skills at 2, and learner profile at 2.
- Prefer fewer tags over weak tags.
- Return transcript-only fallback with empty tags, `confidence = 0`, and `pendingRetag = true` when tagging is unavailable.
- Add a no-op or local fallback implementation suitable for production.
- Redact matched child names before any remote tagging unless the approved backend contract explicitly allows raw names.
- If a local-LAN experiment tagger is added for demo, hide it behind explicit non-production configuration.
- Do not ship direct client API keys.
- Do not directly call remote LLM APIs from production client code.
- Do not log transcripts, prompts, model responses, child names, or evidence quotes in production.
- Add release-build enforcement so production builds fail closed with no local-LAN endpoint, no direct LLM endpoint, and no bundled API key.

**Acceptance:**

- Parser accepts the experiment schema.
- Parser rejects prose or malformed model output.
- Invalid taxonomy values are not exposed to UI.
- Tags without evidence spans are dropped before becoming visible.
- Theme output is capped at one.
- Key concept output is capped at two.
- ATL output is capped at two.
- Learner profile output is capped at two.
- Empty transcript does not trigger tagging.
- Production configuration does not call a direct client LLM endpoint.
- Transcript-only draft remains usable when tagging is disabled or fails.
- Remote tagging redacts matched child names unless explicitly approved otherwise.

**Tests:**

- Taxonomy raw values match the experiment prompt values.
- Strict tag JSON parses into `ObservationPYPTagBundle`.
- Invalid taxonomy values are rejected.
- Prose output is rejected.
- Malformed JSON is rejected.
- Tags without evidence spans are dropped.
- Theme suggestions are capped at one.
- Key concept suggestions are capped at two.
- ATL suggestions are capped at two.
- Learner profile suggestions are capped at two.
- Evidence offset bounds are valid.
- Evidence quote text is a substring of the transcript or is rejected.
- Repeated quote ambiguity is handled deterministically.
- Evidence category/value pairs must match emitted taxonomy values.
- Empty transcript does not trigger tagging.
- Tagging failure produces `pendingRetag = true`.

**Manual QA:**

- Disable tagging and confirm the UI can still create a transcript-only draft once integrated.
- Use a weak or sentiment-only transcript and confirm unsupported tags are omitted once integrated.

## Task 5 - Add Observation Capture View Model State Machine

**Owner:** iOS feature engineer

**Depends on:** Tasks 1, 2, 3, and 4

**Goal:** Coordinate permissions, recording, transcript updates, child matching, tagging, draft creation, save, and discard.

**Files:**

- `TinySteps/TinySteps/Features/ObservationCapture/ObservationCaptureViewModel.swift`
- `TinySteps/TinySteps/Features/ObservationCapture/ObservationCaptureState.swift`
- `TinySteps/TinySteps/Features/ObservationCapture/ObservationCaptureDraftStore.swift`
- `TinySteps/TinySteps/App/Composition/FeatureServicesComposition.swift`
- `TinySteps/TinySteps/App/AppDependencies.swift`
- `TinySteps/TinySteps.xcodeproj/project.pbxproj`

**Work:**

- Implement `ObservationCaptureViewModel`.
- Mark `ObservationCaptureViewModel` as `@MainActor`.
- Use explicit states: idle, permission unknown, requesting permission, ready, recording, transcribing, suggesting tags, draft ready, saving, saved, and failed.
- Inject speech, tagging, child matcher, draft store, and create service dependencies; do not instantiate production services directly in the view or view model.
- Request microphone and speech permissions before recording.
- Start recording on press.
- Stop recording on release.
- Stream live transcript text into observable UI state.
- Run local child matching after transcript changes.
- Run tag suggestions after final non-empty transcript.
- Keep transcript when tagging fails.
- Build a draft with transcript, local child matches, tags, confidence, evidence spans, `pendingRetag`, and status.
- Disable save for empty transcript.
- Preserve local draft state when save fails.
- Confirm discard when transcript text exists.
- Dismiss immediately when no transcript exists.
- Avoid model-written narrative fields.

**Acceptance:**

- Press start and release stop transitions are represented in the view model.
- Live transcript updates are observable by SwiftUI.
- Empty transcript disables save.
- No speech does not create a misleading draft.
- Tagging failure results in transcript-only draft state.
- Child matching runs locally from the session roster.
- Save failure leaves retryable local draft state.
- Discard removes local draft state when confirmed.
- The transcript remains the observation description.

**Tests:**

- State flow covers idle, permission unknown, ready, recording, suggesting tags, and draft ready.
- Permission denied produces recoverable failure.
- Empty transcript disables save.
- No speech leaves save disabled.
- Transcript-only fallback sets `pendingRetag = true`.
- Save failure preserves local draft.
- Discard deletes local draft state.
- Child matcher is called with the selected session roster only.
- Tagging is not called for empty transcript.

## Task 6 - Build ObservationCaptureView UI

**Owner:** iOS feature engineer

**Depends on:** Task 5

**Goal:** Build the separate capture screen matching the supplied warm mic-first design.

**Files:**

- `TinySteps/TinySteps/Features/ObservationCapture/ObservationCaptureView.swift`
- `TinySteps/TinySteps/Features/ObservationCapture/ObservationCaptureViewModel.swift`
- `TinySteps/TinySteps/Features/ObservationCapture/ObservationTagModels.swift`
- `TinySteps/TinySteps.xcodeproj/project.pbxproj`

**Work:**

- Build a dedicated `ObservationCaptureView`.
- Show selected class context near the top.
- Use warm cream background `#FBF6EE`.
- Add a large centered sage microphone hero.
- Add a subtle pulsing ring while recording.
- Add instruction text exactly `Press and hold to observe`.
- Add transcript placeholder exactly `Your words will appear here...`.
- Add a live transcript area sized for a classroom note.
- Add caption exactly `Chips bloom when you speak`.
- Add chip groups for `Theme`, `Concept`, `ATL`, and `Profile`.
- Show low-opacity or skeleton chips while recording or tagging.
- Show suggested chips only after validated tagging.
- Add optional detected-child row below transcript.
- Add bottom actions for saving or keeping draft and discard or retake.
- Add chip tap evidence reveal where evidence spans exist if feasible.
- If suggested tags are persisted as confirmed data, add a remove affordance before save.
- If child matches are persisted as confirmed data, add a remove or unresolved affordance before save.
- If removal controls are not shipped, persist suggestions as review-only data, not confirmed teacher choices.
- Avoid badges, streaks, progression meters, confetti, or gamified motion.
- Keep iPhone-first layout with Dynamic Type support.
- Add VoiceOver labels for mic, transcript area, chips, children, save, discard, and close.

**Acceptance:**

- `ObservationCaptureView` is separate from class overview code.
- The class overview does not embed capture UI.
- Transcript placeholder text matches the plan exactly.
- Instruction and chip caption text match the plan exactly.
- Chip groups render the four required categories.
- Save is visually and functionally disabled for empty transcript.
- Permission denied, no speech, tagging unavailable, and save failure states have visible copy.
- The UI uses draft or review language and does not say published or synced.
- Layout is usable on small iPhone screens.
- VoiceOver labels exist for core controls.
- Persisted child/tag suggestions are either removable before save or clearly stored as review-only suggestions.

**Manual QA:**

- Open the view with a mock class and confirm warm mic-first layout.
- Confirm transcript placeholder appears before recording.
- Confirm skeleton or low-opacity chips appear during tagging.
- Confirm suggested chips appear only after validation.
- Confirm save remains disabled for empty transcript.
- Confirm Dynamic Type does not break the primary flow.
- Confirm VoiceOver can identify the mic control and save action.

## Task 7 - Wire Class Overview Gear Menu And TeacherHome Presentation

**Owner:** iOS feature engineer

**Depends on:** Task 6

**Goal:** Launch capture from the selected class overview gear menu and present it above `TeacherHomeView`.

**Files:**

- `TinySteps/TinySteps/Features/ClassRoster/ClassRosterView.swift`
- `TinySteps/TinySteps/Features/Home/TeacherHomeView.swift`
- `TinySteps/TinySteps/Features/ObservationCapture/ObservationCaptureSession.swift`
- `TinySteps/TinySteps.xcodeproj/project.pbxproj`

**Work:**

- Extend `ClassRosterView` with an `onCaptureObservation` callback that receives launch context, not just students.
- Add `ObservationCaptureLaunchContext` with class id, class name, and roster snapshot.
- Add a gear menu button labelled exactly `Capture observation`.
- Keep existing `Capture image` behavior unchanged.
- Disable observation capture for `All Classes`.
- Disable observation capture while roster is loading.
- Disable observation capture if no selected concrete class id/name is available.
- Do not disable solely because the roster is empty; empty roster should still allow class-scoped transcript-only capture.
- Pass selected class id, class name, and current roster snapshot into `ObservationCaptureSession`.
- Add `@State private var observationCaptureSession: ObservationCaptureSession?` to `TeacherHomeView`.
- Present `ObservationCaptureView` using `.fullScreenCover(item:)`.
- Dismiss back to the same roster state.
- Do not change selected tab as a side effect.
- Do not use the placeholder Today tab as a launch surface.

**Acceptance:**

- The class overview gear menu shows `Capture observation` for a concrete selected class.
- The label is exactly `Capture observation`.
- The action is unavailable for `All Classes`.
- The action does not appear as a global capture destination.
- The capture screen presents as a separate `ObservationCaptureView`.
- Existing face capture flow remains unchanged.
- Presentation uses the selected class snapshot at launch time.
- Empty roster launches are allowed and produce no child matches.
- Returning from capture leaves the teacher on the same roster context.

**Tests:**

- Class roster menu action is unavailable for `All Classes`.
- `TeacherHomeView` presents capture with selected class id, class name, and roster snapshot.
- Empty roster context can still launch a transcript-only capture when a concrete class is selected.
- Existing face capture callback still works if covered by existing tests.

**Manual QA:**

- Select a concrete class and verify the gear menu shows `Capture observation`.
- Switch to `All Classes` and verify capture is unavailable.
- Select `Capture observation` and verify full-screen capture opens.
- Dismiss capture and verify roster context is unchanged.
- Verify `Capture image` still works as before.

## Task 8 - Add Save, Discard, Fallback, And Draft Recovery Behavior

**Owner:** iOS feature engineer

**Depends on:** Tasks 5, 6, and 7

**Goal:** Make draft lifecycle behavior honest, retryable, and safe when tagging or backend create is unavailable.

**Files:**

- `TinySteps/TinySteps/Features/ObservationCapture/ObservationCaptureDraftStore.swift`
- `TinySteps/TinySteps/Features/ObservationCapture/ObservationCaptureViewModel.swift`
- `TinySteps/TinySteps/Features/ObservationCapture/ObservationCaptureView.swift`
- `TinySteps/TinySteps/App/Composition/FeatureServicesComposition.swift`
- `TinySteps/TinySteps/App/AppDependencies.swift`
- `TinySteps/TinySteps/Features/Portfolio/Services/PortfolioService.swift` only if a real create-observation API exists
- `Packages/MBAPI/Sources/MBAPI/APIEndpoints/MBPortfolioEndpoint.swift` only if a real create-observation API exists
- `Packages/MBAPI/Sources/MBAPI/Domain/Models/Portfolio/Portfolio.swift` only if a real create-observation API exists

**Work:**

- Persist a local draft before any network operation.
- Use draft or review language in all save states.
- Do not say published, synced, or created on backend unless a real create endpoint succeeds.
- If no production create-observation API exists, keep the save path local only.
- If a real create endpoint exists, add an `ObservationCreating` boundary before integrating the API.
- If a real create endpoint exists, add explicit request and response models, error mapping, and timeline invalidation/refetch after successful create.
- Keep create-observation integration separate from local draft save semantics.
- Store empty tags with `confidence = 0` and `pendingRetag = true` when tagging is unavailable.
- Preserve the transcript and draft on save failure.
- Prompt before discard when transcript text exists.
- Dismiss immediately when transcript is empty.
- Support retry after save failure.
- Add durable local draft recovery across app relaunch/background when local draft is the production save path.

**Acceptance:**

- Save requires non-empty transcript.
- A local draft is persisted or recoverable before risky network work.
- Tagging failure does not discard transcript.
- Save failure leaves a retryable draft.
- UI copy clearly says local draft or review state when backend create is absent.
- No fake backend success is shown.
- Discard confirmation appears only when there is transcript text.
- Empty capture can close without confirmation.
- Optional backend create code is behind a real API contract and service boundary.
- Successful backend create invalidates or refetches the relevant portfolio/timeline view.
- Durable draft recovery is available when local draft is the production save path.

**Tests:**

- Save is disabled for empty transcript.
- Save failure preserves draft.
- Tagging failure saves transcript-only draft with `pendingRetag = true`.
- Discard deletes local draft state.
- Closing with transcript requests confirmation.
- Closing without transcript does not request confirmation.
- Backend create is not called when no real create contract is configured.
- Successful backend create maps response/error correctly and triggers timeline invalidation or refetch.
- Reopen after app relaunch restores unsynced local drafts when local draft is the production save path.

**Manual QA:**

- Disable network or tagging and verify transcript-only draft behavior.
- Save a draft and verify copy says local draft or review, not published or synced.
- Force save failure and verify retry is available.
- Close with non-empty transcript and verify discard or keep prompt.
- Close with empty transcript and verify immediate dismissal.

## Task 9 - Complete Tests, iPhone QA, Privacy Review, And Build Cleanup

**Owner:** QA engineer and tech lead

**Depends on:** Tasks 1 through 8

**Goal:** Complete required coverage, resource checks, privacy review, and final acceptance.

**Files:**

- `TinySteps/TinyStepsTests/`
- `Packages/MBAPI/Tests/` only if a real create-observation API exists
- `TinySteps/TinySteps/Info.plist`
- `TinySteps/TinySteps.xcodeproj/project.pbxproj`
- `TinySteps/TinySteps/PrivacyInfo.xcprivacy` or the app's existing privacy manifest location if present

**Work:**

- Confirm all new files are included in the correct app and test targets.
- Confirm speech and microphone usage descriptions exist.
- Confirm privacy manifest and App Store privacy-label implications for microphone, speech recognition, transcript storage, and remote AI processing.
- Confirm no direct production LLM endpoint, client API key, or local-LAN tagger is enabled in production.
- Confirm release builds fail closed with no local-LAN endpoint, no direct LLM endpoint, and no bundled API key.
- Confirm transcripts, prompts, model responses, child names, and evidence quotes are not written to app logs, analytics events, crash breadcrumbs, or debug telemetry in production.
- Confirm child matching uses only selected roster snapshot.
- Confirm transcript remains the observation description in model, UI, and save path.
- Confirm visible PYP tags require valid taxonomy values and evidence spans.
- Confirm theme, key concepts, ATL, and learner profile suggestions are capped.
- Confirm the gear label is exactly `Capture observation`.
- Confirm the flow uses separate `ObservationCaptureView`.
- Run targeted unit tests.
- Run app build.
- Complete iPhone manual QA.
- Complete privacy and security checklist.

**Acceptance:**

- App builds successfully.
- Targeted parser, matcher, state, and draft tests pass.
- Manual iPhone QA passes.
- Privacy review finds no direct production client LLM use.
- No client-side LLM API key is committed.
- No transcript is sent to remote services unless gated through approved backend or non-production configuration.
- No cross-class child matching is possible.
- UI copy does not overstate confidence or backend save status.
- Permission strings, privacy manifest, and release configuration are verified.

**Tests:**

- Taxonomy raw values match experiment schema.
- Strict tag JSON parses correctly.
- Invalid taxonomy values are rejected.
- Prose and malformed output are rejected.
- Tags without evidence spans are dropped.
- Theme suggestions are capped at one.
- Key concept suggestions are capped at two.
- ATL suggestions are capped at two.
- Learner profile suggestions are capped at two.
- Empty transcript does not trigger tagging.
- No speech leaves save disabled.
- Transcript-only fallback sets `pendingRetag = true`.
- Exact child match works against current roster.
- Possessive child names are normalized.
- Ambiguous child names are not auto-assigned.
- Duplicate first names, nickname collisions, substrings inside other words, hyphenated names, apostrophes, and diacritics are covered.
- View-model flow covers idle, permission unknown, ready, recording, suggesting tags, and draft ready.
- Save failure preserves local draft.
- Discard deletes local draft state.
- Class roster menu action is unavailable for `All Classes`.
- `TeacherHomeView` presents capture with selected class snapshot.

**Manual QA:**

- On iPhone, select a concrete class and verify the gear menu shows `Capture observation`.
- Switch to `All Classes` and verify observation capture is unavailable.
- Open capture and verify the visual layout matches the warm mic-first reference.
- Deny microphone permission and verify recoverable error copy.
- Deny speech recognition permission and verify recoverable error copy.
- Press and hold the mic and verify live transcript appears.
- Release the mic and verify tag chips enter tagging or skeleton state.
- Speak a clear child name and verify local roster match.
- Speak an ambiguous child name and verify it is not auto-assigned.
- Use a short sentiment-only observation and verify weak tags are omitted.
- Disable network or tagging and verify transcript-only draft behavior.
- Save a draft and verify copy says local draft or review, not published or synced.
- Close with non-empty transcript and verify discard or keep behavior.
- Test offline mode with on-device speech unavailable.
- Interrupt audio during press-and-hold and verify cleanup.
- Background the app while recording and verify no background recording continues.
- Release outside the mic hit target and verify recording stops safely.
- Force quit and reopen with an unsynced local draft when local draft is the production save path.
- Check small-screen iPhone layout.
- Check Dynamic Type.
- Check VoiceOver labels.

## Build-System And Resource Tasks

| Task | Owner | Must Ship |
|---|---|---|
| Add new ObservationCapture Swift files to the app target | iOS platform engineer | Yes |
| Add test files to the correct test target | iOS platform engineer | Yes |
| Add or confirm `NSSpeechRecognitionUsageDescription` | iOS platform engineer | Yes |
| Confirm `NSMicrophoneUsageDescription` is present and specific enough | iOS platform engineer | Yes |
| Confirm privacy manifest and App Store privacy-label implications | Security/privacy reviewer | Yes |
| Confirm production build flags do not enable local-LAN experiment tagging | AI/ML integration engineer | Yes |
| Add release-build fail-closed check for direct LLM endpoints and API keys | AI/ML integration engineer | Yes |
| Confirm no client LLM API keys or secrets are added to plist, source, or project settings | Security/privacy reviewer | Yes |
| Add assets only if required by the final UI | iOS feature engineer | No |
| Confirm app builds before calling the feature done | Tech lead | Yes |

## Privacy And Security Checklist

| Check | Required Outcome |
|---|---|
| Transcript ownership | Teacher transcript remains the observation description and is not rewritten by a model |
| Child detection | Local deterministic matching only |
| Roster scope | Matching limited to `ObservationCaptureSession.rosterSnapshot` |
| Ambiguous child names | Left unresolved for review |
| LLM child attribution | Not allowed |
| Production LLM use | Avoided unless routed through approved backend |
| Demo or local-LAN LLM use | Gated behind non-production configuration |
| API keys | No direct client API keys committed or bundled |
| Remote tagging redaction | Matched child names are replaced with placeholders unless approved backend allows raw names |
| Sensitive logging | No transcripts, prompts, model responses, child names, or evidence quotes in production logs, analytics, crash breadcrumbs, or telemetry |
| Evidence requirements | Visible tags require evidence spans |
| Taxonomy validation | Unknown PYP values rejected |
| Failure behavior | Tagging failure keeps transcript and sets `pendingRetag = true` |
| Save honesty | UI says local draft or review unless real backend create succeeds |
| Permissions | Speech and microphone permission copy is explicit and classroom-appropriate |
| Privacy manifest | Privacy manifest and App Store disclosure impact are reviewed |

## Optional Follow-Up Tasks

- Rename `docs/features/obervation-tagging` to fix the typo.
- Add typed transcript editing before saving.
- Add evidence-span reveal on chip tap if omitted from MVP.
- Add teacher controls to remove incorrect child matches only if MVP stores suggestions as review-only data and defers confirmation.
- Add teacher controls to remove unsupported tag suggestions only if MVP stores suggestions as review-only data and defers confirmation.
- Add enhanced draft recovery UX beyond the mandatory durable recovery path.
- Add backend create-observation endpoint integration when a real API contract exists.
- Add admin review workflow.
- Add parent-facing sharing.
- Add multi-locale speech configuration.
- Add richer chip-bloom animation after accessibility and layout are stable.

## Lead Review Amendments Integrated

- Launch callback now carries class id, class name, and roster snapshot.
- Empty roster no longer blocks transcript-only observation capture.
- Durable protected local draft storage is required when backend create is unavailable.
- Speech recognition privacy gate is stricter: production requires on-device speech or approved Apple server-backed behavior.
- Fuzzy child-name matching is default-off for MVP.
- PYP tag caps are explicit across all categories.
- Evidence spans use structured category/value validation.
- Remote tagging redaction, sensitive logging restrictions, privacy manifest review, and release-build fail-closed checks are explicit gates.
- Backend create files and MBAPI tests are conditional on a real create-observation API contract.
- Local draft recovery is mandatory when local draft storage is the production save path.
