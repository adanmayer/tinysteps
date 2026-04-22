# Standards Tagging With Local AI - Implementation Tasks

Role: Senior Mobile Developer, reviewed by Lead Engineer

Source plan: [implementation-plan.md](implementation-plan.md)

## Working Assumptions

- Feature folder is `docs/features/standards-tagging/`.
- Server-loaded standards are already available through `MBStandardsLoadingService`.
- Unit selection scopes standard tagging.
- The local AI host for development is `http://192.168.14.108:11434`.
- The local AI model is `qwen3.5:35b-a3b`.
- The model returns `MBStandardReference.id` values only.
- The app displays selected standards using `displayHashtag`.
- The maximum selected standard suggestions is 4.
- Tagging failure never blocks draft saving.
- PM-reviewed behavior is merged into this task list: suggestions are removable, local AI unavailable is non-blocking, selected unit is visually clear, manual standard tagging is available, and compact UI uses `Suggested standards` copy with hashtags.

## Delivery Slices

| Slice | Title | Owner |
|---|---|---|
| 1 | Local AI client boundary | Senior mobile developer |
| 2 | Standard tagging models and parser | Senior mobile developer |
| 3 | Qwen prompt, schema, and streaming service | Senior mobile developer |
| 4 | View model integration with selected unit | Senior mobile developer |
| 5 | Observation UI standard chips and manual picker | Senior mobile developer |
| 6 | Draft persistence of selected standards | Senior mobile developer |
| 7 | Tests, build, and iPhone QA | Lead + QA |

## Task 0 - Confirm Product Guardrails

Owner: Lead engineer and PM

Goal: Confirm local AI behavior before app source changes.

Work:

- Confirm whether local AI is DEBUG-only or allowed in TestFlight.
- Confirm the configured local host and model.
- Confirm selected-unit-only tagging is correct.
- Confirm maximum of 4 selected standard chips.
- Confirm whether static PYP chips stay visible after standard tagging ships.
- Confirm manual standard selection is part of the first implementation slice.
- Confirm user-facing copy for local AI unavailable.
- Confirm whether local AI is enabled only in DEBUG/developer builds or also in explicitly configured TestFlight builds.
- Confirm that confidence should remain secondary/internal in the first UI.

Acceptance:

- Engineering does not need to guess deployment scope.
- UI can be built without conflicting taxonomy displays.
- Product acceptance requires removable suggested standards, manual add, and non-blocking unavailable behavior.

## Task 1 - Add Local AI Configuration And Ollama Client

Owner: Senior mobile developer

Files:

- `TinySteps/TinySteps/Features/ObservationCapture/StandardTagging/LocalAITaggingConfiguration.swift`
- `TinySteps/TinySteps/Features/ObservationCapture/StandardTagging/OllamaAPIClient.swift`
- `TinySteps/TinySteps.xcodeproj/project.pbxproj`

Work:

- Create `StandardTagging` subfolder under Observation Capture.
- Add `LocalAITaggingConfiguration`.
- Default host to `http://192.168.14.108:11434`.
- Default model to `qwen3.5:35b-a3b`.
- Add development override through environment or launch argument.
- Gate local AI enablement by explicit build/configuration scope.
- Adapt the experiment's Ollama chat client.
- Support non-streaming and streaming `/api/chat`.
- Use 120 second timeout for 35B model path.
- Use `Accept-Encoding: identity` and `Cache-Control: no-cache` for streaming.
- Use `URLSessionDataDelegate` NDJSON streaming.
- Add privacy-safe version probe logging only.
- Do not log prompts, transcripts, evidence quotes, or raw model output.

Acceptance:

- App code has a reusable local AI client boundary.
- The client does not depend on experiment target files.
- Local AI host/model are configured in one place.
- Local AI cannot silently depend on a developer LAN IP in production.

Tests:

- Unit test URL construction for `/api/chat` and `/api/version`.
- Unit test request body contains `stream` and model options.

## Task 2 - Add Standard Tagging Domain Models

Owner: Senior mobile developer

Files:

- `TinySteps/TinySteps/Features/ObservationCapture/StandardTagging/ObservationStandardTagModels.swift`
- `TinySteps/TinySteps/Features/ObservationCapture/ObservationCaptureDraft.swift`
- `TinySteps/TinySteps.xcodeproj/project.pbxproj`

Work:

- Add `ObservationStandardTagSuggestion`.
- Add `ObservationStandardEvidenceSpan`.
- Add `ObservationStandardTaggingResult`.
- Add `ObservationStandardTaggingEvent`.
- Add `ObservationStandardTagSelectionSource` with at least `localAI` and `manual`.
- Extend `ObservationCaptureDraft` to persist selected standard snapshots.
- Persist full display snapshot, not only IDs.
- Keep drafts valid with zero selected standards.
- Preserve teacher removal state by only saving currently selected suggestions.

Acceptance:

- Selected standard tags can render offline from draft data.
- Draft encoding and decoding remains backward compatible or has an explicit migration/default path.
- Saved selected standards preserve whether they were added by local AI or manually.

Tests:

- Encode/decode draft with selected standards.
- Decode older draft payload without selected standards.
- Verify `referenceID` uses `MBStandardReference.id`.
- Encode/decode manual and local AI selection sources.

## Task 3 - Add Candidate Preparation

Owner: Senior mobile developer

Files:

- `TinySteps/TinySteps/Features/ObservationCapture/StandardTagging/ObservationStandardCandidateBuilder.swift`
- `TinySteps/TinySteps/Features/ObservationCapture/StandardsLoading/ObservationStandardModels.swift`

Work:

- Build candidate payloads from `selectedUnitSection.references`.
- Include `id`, `kind`, `sourceID`, `code`, `displayHashtag`, `title`, and `detail`.
- Preserve only selected-unit candidates.
- Add a max candidate budget, default 40.
- If references exceed the budget, rank by lexical overlap with transcript.
- Always include PYP theme candidates when present.
- Remove duplicate IDs before prompt creation.
- Keep a lookup map from candidate ID to `MBStandardReference`.

Acceptance:

- Candidate builder never includes references from another unit.
- Large units produce bounded prompt payloads.
- Candidate lookup can resolve every valid model ID to a full reference snapshot.

Tests:

- Selected unit candidates only.
- Duplicate IDs are removed.
- Large candidate set is capped.
- PYP theme references are retained during capping.

## Task 4 - Add Dynamic JSON Schema And Prompt Builder

Owner: Senior mobile developer

Files:

- `TinySteps/TinySteps/Features/ObservationCapture/StandardTagging/ObservationStandardTaggingPrompt.swift`
- `TinySteps/TinySteps/Features/ObservationCapture/StandardTagging/ObservationStandardTaggingSchema.swift`

Work:

- Build system prompt with conservative tagging rules.
- Build compact JSON user payload.
- Generate dynamic JSON schema with candidate ID enums.
- Set `standardTagIDs.maxItems` to 4.
- Set `additionalProperties = false` for every object.
- Require `standardTagIDs`, `confidence`, and `evidenceSpans`.
- Include `evidenceSpans[].standardID` enum matching candidate IDs.
- Include evidence quote requirements in prompt.

Acceptance:

- The model is constrained to candidate IDs.
- The prompt tells the model not to return labels, hashtags, or invented IDs.
- The schema can be generated for any non-empty selected unit candidate set.

Tests:

- Schema contains every candidate ID exactly once.
- Schema max items is 4.
- Prompt does not include child identifiers beyond transcript text.

## Task 5 - Add Standard Tagging Parser

Owner: Senior mobile developer

Files:

- `TinySteps/TinySteps/Features/ObservationCapture/StandardTagging/ObservationStandardTaggingParser.swift`

Work:

- Decode strict JSON response.
- Normalize known experiment drift modes, including single-key object wrappers.
- Reject malformed responses.
- Reject unknown IDs.
- Reject IDs outside the candidate lookup.
- De-duplicate IDs.
- Validate evidence quote containment in transcript.
- Validate optional offsets.
- Drop selected IDs with no evidence.
- Preserve model order.
- Cap final suggestions at 4.
- Clamp confidence to `0...1`.
- Produce `ObservationStandardTaggingResult`.

Acceptance:

- Parser output is safe even when model output is not.
- Unknown or invented IDs never reach the UI.
- A selected standard without evidence is dropped.

Tests:

- Parses valid response.
- Rejects unknown IDs.
- Rejects hashtag/title output.
- Drops missing evidence.
- Drops quote not found in transcript.
- Validates offsets.
- Handles wrapper drift.
- Caps to 4 suggestions.
- Clamps confidence.

## Task 6 - Add OllamaObservationStandardTaggingService

Owner: Senior mobile developer

Files:

- `TinySteps/TinySteps/Features/ObservationCapture/StandardTagging/ObservationStandardTaggingService.swift`
- `TinySteps/TinySteps/Features/ObservationCapture/StandardTagging/OllamaObservationStandardTaggingService.swift`
- `TinySteps/TinySteps/App/AppDependencies.swift`
- `TinySteps/TinySteps/App/Composition/FeatureServicesComposition.swift`
- `TinySteps/TinySteps.xcodeproj/project.pbxproj`

Work:

- Add `ObservationStandardTaggingService` protocol.
- Add `DisabledObservationStandardTaggingService`.
- Add `OllamaObservationStandardTaggingService`.
- Use experiment structured settings: temperature `0.3`, seed `42`, top-p `0.8`, top-k `20`, presence penalty `0.0`, repeat penalty `1.1`.
- Send `think=false`.
- Prewarm/version probe without transcript content.
- Implement streaming event flow.
- Emit partial suggestions only when valid selected IDs change.
- Emit final suggestions after full parser validation.
- Surface `.unavailable` on local AI connectivity failure.
- Do not throw in ways that block saving unless the caller explicitly needs diagnostics.

Acceptance:

- Service can stream selected standard suggestions from local Qwen.
- Local AI failure leaves caller able to save transcript.
- No sensitive content is logged.

Tests:

- Mock Ollama stream emits partial then final suggestions.
- Invalid model output yields no suggestions and recoverable state.
- Transport failure maps to unavailable or recoverable error.

## Task 7 - Integrate With ObservationCaptureViewModel

Owner: Senior mobile developer

Files:

- `TinySteps/TinySteps/Features/ObservationCapture/ObservationCaptureViewModel.swift`
- `TinySteps/TinySteps/Features/ObservationCapture/ObservationCaptureView.swift`
- `TinySteps/TinySteps/App/View/SignedInRootView.swift`

Work:

- Inject `ObservationStandardTaggingService`.
- Add standard suggestion state.
- After transcript capture or sample text insertion, tag selected-unit standards.
- Use `selectedUnitSection` as candidate scope.
- If standards are still loading, defer tagging until loaded or mark standards unavailable.
- On `selectUnit`, clear old unit suggestions.
- If transcript exists, retag for the new selected unit.
- Cancel or invalidate old tagging requests when unit changes.
- Add methods to manually add and remove selected standard references.
- Prevent duplicate selected standards across AI and manual additions.
- Track teacher-removed references so they do not immediately reappear from an in-flight AI stream.
- Keep `canSave` true when tagging fails.
- Preserve existing child matching and draft flow.
- Treat model confidence as secondary state and do not require UI to show it prominently.

Acceptance:

- Standard tagging only runs with transcript plus selected unit.
- Changing units retags against the new unit.
- Old unit suggestions cannot leak into the new unit.
- Save remains available if local AI is offline.
- Suggested standards can be removed and removed suggestions do not return unless retagging explicitly produces them again.
- Manual standard addition works without local AI.
- Manual standard addition can add tags after AI suggestions arrive.

Tests:

- Unit change clears previous suggestions.
- Unit change with transcript triggers retag.
- Missing standards does not crash.
- Failed tagging leaves draft ready.
- Manual add inserts a selected-unit reference.
- Manual add ignores duplicate selected references.
- Remove deletes AI and manually added suggestions.
- In-flight AI updates do not re-add a teacher-removed tag unless explicit retag occurs.

## Task 8 - Update Observation UI For Standard Suggestions And Manual Add

Owner: Senior mobile developer

Files:

- `TinySteps/TinySteps/Features/ObservationCapture/ObservationCaptureView.swift`

Work:

- Keep unit pills above the transcript.
- Keep grayed candidate hashtag preview for selected unit.
- Add selected standard chips using `displayHashtag`.
- Limit selected chips to 4.
- Animate streamed suggestions in.
- Add remove action for incorrect suggestions.
- Add an always-visible `Add standard` or `Add tag` action near `Suggested standards`.
- Open a selected-unit standards picker from the add action.
- Picker supports search by hashtag, title, detail, code, kind, and source ID.
- Picker shows already selected references as selected/checked.
- Picker prevents duplicate additions.
- Picker allows adding standards even when local AI is unavailable.
- Show local AI unavailable state without blocking save.
- Use `Suggested standards` as the primary section copy.
- Use calm unavailable copy, for example `Standard suggestions are unavailable. You can still save this observation.`
- Make the selected unit visually obvious because it scopes the standard candidates.
- Keep confidence out of the primary compact UI for the first implementation.
- Add accessibility labels with full standard title/detail.
- Avoid showing raw long standard text in compact layout.

Acceptance:

- Selected standard chips are visually distinct from candidate preview chips.
- Chips update when unit changes.
- Long standards do not break iPhone layout.
- The teacher can remove a wrong suggestion.
- The UI communicates suggestions, not confirmed standards.
- The teacher can add standards manually when AI is unavailable.
- The teacher can add extra standards manually after AI suggestions appear.

Manual QA:

- iPhone portrait layout with 0, 1, and 4 selected standards.
- Long hashtag and long title accessibility behavior.
- Unit switch while tagging is streaming.
- Local AI offline.
- Manual add with local AI offline.
- Manual add after AI suggestions.
- Remove AI-added and manually added chips.
- Search and select a long standard title.

## Task 9 - Persist Selected Standards In Draft Save

Owner: Senior mobile developer

Files:

- `TinySteps/TinySteps/Features/ObservationCapture/ObservationCaptureViewModel.swift`
- `TinySteps/TinySteps/Features/ObservationCapture/ObservationCaptureDraft.swift`
- `TinySteps/TinySteps/Features/ObservationCapture/ObservationCaptureDraftStore.swift`

Work:

- Include selected standard snapshots in saved drafts.
- Preserve `displayHashtag`, title, detail, source ID, kind, unit ID, class ID, and selection source.
- Ensure save works when suggestions are empty.
- Ensure removed suggestions are not saved.
- Avoid requiring standards reload to render a saved draft.
- Keep transcript-only save behavior unchanged when no suggestions exist or local AI is unavailable.

Acceptance:

- Saved draft includes selected standard snapshots.
- Saved draft distinguishes manual and local AI selections.
- Removed suggestions stay removed.
- Transcript-only draft remains valid.

Tests:

- Save draft with selected standards.
- Save draft with manual selected standards.
- Save draft after removing one suggestion.
- Save transcript-only draft.

## Task 10 - QA, Build, And Review

Owner: Lead engineer and QA

Files:

- App source files changed in tasks 1 through 9.

Work:

- Compile TinySteps for iPhone simulator.
- Run targeted parser and view-model tests.
- Review privacy-sensitive logging.
- Review iPhone-only UI behavior.
- Test local AI reachable at `192.168.14.108`.
- Test local AI offline.
- Test selected unit switching.
- Test no standards loaded.
- Test large standard candidate set.
- Test malformed model output.
- Test removing a suggested standard before saving.
- Test manually adding a standard while local AI is offline.
- Test manually adding extra standards after AI suggestions arrive.
- Test removing both AI-added and manually added standards.
- Test that confidence is not overemphasized in compact UI.
- Test local AI disabled by build/configuration scope.

Acceptance:

- App build succeeds.
- Unknown IDs cannot be selected.
- No sensitive transcript/model data is logged.
- Observation save remains available when standard tagging fails.
- QA findings are either fixed or documented with severity and owner.
- PM conditions from `pm-review.md` are satisfied in plan and implementation behavior.
