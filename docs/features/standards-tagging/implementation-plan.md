# Standards Tagging With Local AI - Implementation Plan

Role: Lead Engineer

PM review source: [pm-review.md](pm-review.md)  
Companion task list: [implementation-tasks.md](implementation-tasks.md)

## PM Review Status

Approved with conditions. The PM review requirements are merged into this plan and the companion task list so implementation can proceed from the plan without a separate interpretation pass.

Required PM conditions:

- Local AI unavailable must be a calm non-blocking state.
- The selected unit must remain obvious because it controls candidate standards.
- Suggested standards must be removable before save.
- The UI must communicate suggestions, not confirmed model truth.
- Confidence must not be overemphasized in the first UI.
- Compact capture UI must show hashtags, not long standards text.
- Local LAN transcript processing must be treated as sensitive and must not be silently enabled outside the approved build scope.

## Goal

Add local-AI standard tagging to Observation Capture so the model suggests server-loaded standard references for the currently selected unit. The AI must return stable standard reference IDs, not display text, hashtags, or free-form labels.

The model input comes from:

- The teacher transcript captured in Observation Capture.
- The currently selected class and selected unit.
- The selected unit's `MBStandardReference` values loaded by `MBStandardsLoadingService`.

The model output must be:

- A maximum of 4 selected standard reference IDs.
- Evidence quotes from the transcript for each selected ID.
- A confidence score.

## Current State

- Observation Capture already exists under `TinySteps/TinySteps/Features/ObservationCapture/`.
- `ObservationCaptureViewModel` already loads standards through `MBStandardsLoadingService`.
- Unit pills already exist in the Observation Capture screen and `selectedUnitID` scopes the active unit.
- `MBStandardReference` already normalizes server standards, syllabus items, scope sequences, and PYP themes into one taggable reference shape.
- `MBStandardReference.id` is the stable in-app identity. `sourceID` alone is not safe because IDs may collide across units or component kinds.
- `displayHashtag` exists for compact display.
- `ObservationTaggingService` currently defaults to `DisabledObservationTaggingService`.
- Existing PYP tagging models are static taxonomy based. Standards tagging must use server-loaded references instead of fixed hard-coded PYP category enums.
- The local tagging experiment has a working Ollama/Qwen path using `qwen3.5:35b-a3b` at `http://192.168.14.108:11434`.

## Decision Summary

- Standard tagging is primary for server-loaded standards.
- The model must return `MBStandardReference.id` values only.
- The candidate vocabulary is the selected unit's loaded standards, not all class standards by default.
- The compact UI uses `displayHashtag` for selected references.
- Manual standard tagging is always available, both when local AI is unavailable and when the teacher wants to add more tags.
- Persistence stores normalized reference snapshots, not just model output strings.
- Tagging failure never blocks saving a transcript draft.
- The local AI call is behind an explicit local-AI service boundary and configuration.
- The local AI implementation reuses the experiment's Ollama learnings: structured JSON schema, deterministic sampling, `think=false`, streaming via `URLSessionDataDelegate`, and strict parser validation.

## Why IDs Instead Of Labels

Standards are long, often similarly worded, and may share display hashtags. The only safe model contract is to give the model a candidate list with stable IDs and require it to return IDs from that list.

The parser must reject anything else:

- Unknown IDs.
- Hashtags in place of IDs.
- Titles in place of IDs.
- IDs from another unit.
- IDs without transcript evidence.
- Free-form new standards invented by the model.

## Source References

Feature docs:

- `docs/features/obervation-tagging/implementation-plan.md`
- `docs/features/standards-loading/implementation-plan.md`

App code boundaries:

- `TinySteps/TinySteps/Features/ObservationCapture/ObservationTaggingService.swift`
- `TinySteps/TinySteps/Features/ObservationCapture/ObservationCaptureViewModel.swift`
- `TinySteps/TinySteps/Features/ObservationCapture/StandardsLoading/ObservationStandardModels.swift`
- `TinySteps/TinySteps/Features/ObservationCapture/StandardsLoading/MBStandardsLoadingService.swift`
- `TinySteps/TinySteps/Features/ObservationCapture/StandardsLoading/MBStandardHashtagGenerator.swift`
- `TinySteps/TinySteps/App/AppDependencies.swift`
- `TinySteps/TinySteps/App/Composition/FeatureServicesComposition.swift`

Experiment learnings:

- `experiments/VoiceTranscript/VoiceTranscript/Drafting/OllamaAPI.swift`
- `experiments/VoiceTranscript/VoiceTranscript/Drafting/OllamaDraftingEngine.swift`
- `experiments/VoiceTranscript/VoiceTranscript/Drafting/ObservationDraftSchema.swift`
- `experiments/VoiceTranscript/VoiceTranscript/Drafting/DebugConfig.swift`
- `experiments/VoiceTranscript/VoiceTranscript/Drafting/PYPTaxonomy.swift`
- `experiments/VoiceTranscript/VoiceTranscript/Drafting/PYPScoring.swift`

## Product Behavior

When a teacher captures or types an observation:

1. The app ensures standards are loaded for the selected class.
2. The teacher selects a unit using the horizontal unit pills.
3. The app builds the candidate list from that selected unit.
4. The local model receives the transcript and candidate list.
5. Suggestions stream back as selected standard IDs.
6. The UI resolves each ID to its `displayHashtag`, title, and source metadata.
7. The teacher can save the draft even if no standards are suggested.
8. The teacher can remove any incorrect suggested standard before saving.
9. The UI labels these as suggested standards, not confirmed standards.
10. The teacher can manually add standards from the selected unit when local AI is unavailable or when additional standards are needed.

When the selected unit changes:

1. Existing standard suggestions are cleared if they belong to the previous unit.
2. Candidate preview hashtags update immediately from the newly selected unit.
3. If the transcript is non-empty, the standard tagging request is rerun for the new unit.
4. In-flight tagging for the old unit is cancelled or ignored by request ID.

Manual tagging behavior:

1. The capture view provides an `Add standard` or `Add tag` action near the suggested standards row.
2. The action opens a selected-unit standard picker with search.
3. The picker lists the selected unit's `MBStandardReference` values using `displayHashtag`, kind, code, title, and enough detail to disambiguate long standards.
4. Manually selected references are added to the same selected standards row as AI suggestions.
5. Teacher-removed tags stay removed until the teacher manually adds them again or explicitly reruns AI suggestions.
6. Local AI unavailable should make manual tagging more prominent, not block the capture flow.

## Candidate Scope

Default scope:

- Use only `selectedUnitSection.references`.
- Include all normalized kinds: `standard`, `syllabus`, `scopeSequence`, and `pypTheme`.
- Prefer selected-unit candidates over all-class candidates to reduce false positives and prompt size.

Large unit fallback:

- If a selected unit has more than 40 references, prefilter candidates locally before calling Qwen.
- Always keep PYP theme references when present.
- Rank remaining references by simple lexical overlap between transcript and `title`, `detail`, `code`, and `displayHashtag`.
- Send the top-ranked references up to the configured prompt budget.
- Record whether the model saw the full or filtered candidate set for debug diagnostics.

Do not send all class standards unless product explicitly adds a "tag across all units" mode.

## Local AI Configuration

Create a local AI configuration boundary rather than scattering hard-coded host strings.

Recommended defaults:

```swift
struct LocalAITaggingConfiguration: Sendable {
    var ollamaHost: URL = URL(string: "http://192.168.14.108:11434")!
    var model: String = "qwen3.5:35b-a3b"
    var requestTimeout: TimeInterval = 120
    var maxSuggestedStandards: Int = 4
    var maxCandidates: Int = 40
    var think: Bool? = false
}
```

The host should be overridable for development builds through environment, launch argument, or a clearly named debug config. Production builds must not silently depend on a developer LAN IP unless product explicitly accepts that deployment shape.

Enablement must be explicit by build scope. Until product approves a broader rollout, treat local AI as DEBUG/developer-only or explicitly configured TestFlight behavior, not as a silent production dependency.

## Model Contract

### Request Payload

The service should build a compact JSON payload and put it in the user message. The system prompt should define rules and output shape.

```json
{
  "transcript": "Bryan is drawing a wonderful picture and is very happy with it.",
  "class": {
    "id": "123",
    "name": "Nursery Meadow"
  },
  "selectedUnit": {
    "id": "unit_456",
    "title": "How we express ourselves"
  },
  "candidates": [
    {
      "id": "123|unit_456|standard|std_1",
      "kind": "standard",
      "sourceID": "std_1",
      "code": "VA.1",
      "hashtag": "#CreativeExpression",
      "title": "Learners express ideas and feelings through visual media.",
      "detail": "Children use drawing, painting, and construction to communicate meaning."
    }
  ],
  "rules": {
    "maxSelections": 4,
    "requireEvidenceQuote": true,
    "returnOnlyCandidateIDs": true
  }
}
```

### Response Payload

The model must return strict JSON with no prose:

```json
{
  "standardTagIDs": [
    "123|unit_456|standard|std_1"
  ],
  "confidence": 0.82,
  "evidenceSpans": [
    {
      "standardID": "123|unit_456|standard|std_1",
      "quote": "drawing a wonderful picture",
      "start": 9,
      "end": 36
    }
  ]
}
```

### JSON Schema

Generate a dynamic schema per request:

- `standardTagIDs.items.enum` contains only candidate `MBStandardReference.id` values.
- `standardTagIDs.maxItems` is 4.
- `evidenceSpans.items.properties.standardID.enum` contains only candidate IDs.
- `additionalProperties` is `false` for every object.
- `confidence` is a number from `0.0` to `1.0`.

The experiment showed that schema enforcement is helpful but not sufficient. The app parser still needs full validation.

## Prompting Rules

System prompt requirements:

- You are tagging a classroom observation against a provided list of standards.
- Select only standards that are directly evidenced by the transcript.
- Return IDs from the candidate list only.
- Do not return hashtags, labels, titles, or invented IDs.
- Do not select a standard just because the activity might fit; require transcript evidence.
- Missing a tag is better than a wrong tag.
- If evidence is weak, return an empty list and lower confidence.
- Every selected ID must have at least one evidence quote copied from the transcript.
- Return only the JSON object.

Use structured model settings from the experiment:

- Use `qwen3Structured(seed: 42)` style settings.
- Do not use the Qwen general preset with schema output because the experiment showed presence penalty breaks JSON syntax.
- Use `temperature` around `0.3`.
- Use `presence_penalty = 0.0`.
- Use `repeat_penalty = 1.1`.
- Send `think=false` for the configured Qwen model.
- Use 120 seconds timeout for the 35B model path.

## Streaming Behavior

Use the experiment's streaming approach:

- Use Ollama `/api/chat` with `stream=true`.
- Use `Accept-Encoding: identity` and `Cache-Control: no-cache`.
- Use a `URLSessionDataDelegate` NDJSON stream rather than APIs that buffer the whole response.
- Accumulate streamed content and extract partial `standardTagIDs` when valid IDs appear.
- Yield UI updates only when the valid selected ID set changes.
- Finalize by normalizing and parsing the complete JSON payload.

Streaming events should be standard-specific:

```swift
enum ObservationStandardTaggingEvent: Equatable, Sendable {
    case partial([ObservationStandardTagSuggestion])
    case final(ObservationStandardTaggingResult)
    case unavailable
}
```

## Parser And Validation

Add a strict parser for standard tagging output.

Validation rules:

- Transcript must be non-empty.
- Candidate list must be non-empty.
- Decode JSON only after normalizing known drift modes from the experiment.
- Accept wrapper drift only if it cleanly unwraps to the expected object.
- Reject malformed JSON.
- Reject unknown IDs.
- Reject duplicate IDs.
- Reject IDs outside the selected unit candidate set.
- Reject evidence spans whose `standardID` is unknown or not selected.
- Reject evidence quotes that are empty.
- Reject evidence quotes not contained in the transcript.
- Validate optional offsets if present.
- Drop selected IDs with no valid evidence span.
- Preserve model order after validation.
- Cap final suggestions at 4.
- Clamp confidence to `0.0...1.0`.

The final result should be safe even if the model response is not.

## App Models

Add standard-specific tagging models under Observation Capture:

```swift
struct ObservationStandardTagSuggestion: Identifiable, Codable, Equatable, Sendable {
    var id: String { referenceID }
    let referenceID: String
    let selectionSource: ObservationStandardTagSelectionSource
    let sourceID: String
    let kind: MBStandardReference.Kind
    let classID: String
    let unitID: String
    let unitTitle: String
    let programCode: String?
    let code: String?
    let title: String
    let detail: String?
    let displayHashtag: String
    let confidence: Double
    let evidenceQuotes: [String]
}
```

```swift
enum ObservationStandardTagSelectionSource: String, Codable, Sendable {
    case localAI
    case manual
}
```

```swift
struct ObservationStandardTaggingResult: Equatable, Sendable {
    var suggestions: [ObservationStandardTagSuggestion]
    var confidence: Double
    var pendingRetag: Bool
}
```

Persist a snapshot of selected references in `ObservationCaptureDraft`. Do not persist only `standardTagIDs`, because drafts should render without immediately reloading ManageBac standards.

## Service Design

Recommended new service:

```swift
protocol ObservationStandardTaggingService: Sendable {
    func suggestStandards(
        transcript: String,
        classContext: ObservationCaptureSession,
        selectedUnit: MBStandardUnitSection
    ) -> AsyncThrowingStream<ObservationStandardTaggingEvent, Error>
}
```

Concrete implementations:

- `OllamaObservationStandardTaggingService`
  - Uses local Ollama/Qwen.
  - Adapts experiment `OllamaAPIClient`.
  - Owns request schema, prompt, streaming, parser, and validation.
- `DisabledObservationStandardTaggingService`
  - Yields `.unavailable`.
  - Keeps save flow unblocked.
- `PreviewObservationStandardTaggingService`
  - Deterministic preview/test suggestions only.

Keep this separate from the existing PYP `ObservationTaggingService` initially. Standard tagging has different candidate inputs, output shape, parser rules, and persistence requirements.

## Integration With ObservationCaptureViewModel

Add view model state:

- `standardSuggestions: [ObservationStandardTagSuggestion]`
- `standardTaggingStatus`
- `standardTaggingMessage`
- `activeStandardTaggingTask`
- `standardTaggingRequestID`

Flow:

1. After transcript finalization, call standard tagging if `selectedUnitSection` exists.
2. Pass only the selected unit's candidates.
3. Apply partial suggestions while streaming.
4. Apply final suggestions after parser validation.
5. If tagging fails, keep transcript and save enabled.
6. If unit changes with a non-empty transcript, cancel or invalidate the previous request and retag for the new selected unit.
7. If standards are still loading, wait for the load result or show a non-blocking "standards unavailable" state.

Do not run tagging before a class and unit are available.

## UI Behavior

Observation Capture should show:

- Unit pills above the transcript input as already planned/implemented.
- The selected unit must be visually obvious because it determines the candidate standards.
- A compact standards suggestion row below the transcript.
- Up to 4 suggested standard chips using `displayHashtag`.
- An always-available manual `Add standard` action for adding tags from the selected unit.
- Loading/streaming animation while local Qwen is responding.
- A calm recoverable unavailable state if local AI is offline.
- Manual remove action for an incorrect suggested standard.
- User-facing copy should say `Suggested standards`.
- Error copy should be non-technical, for example: `Standard suggestions are unavailable. You can still save this observation.`
- Do not show confidence as a primary UI element in the first implementation.

The existing grayed-out candidate hashtags below the textbox should continue to reflect the selected unit. When model suggestions arrive, selected suggestions should be visually promoted from candidate chips to selected chips.

The UI should not show raw long standards in the compact row. Long title/detail can appear in an expanded sheet or accessibility label.

## Manual Standard Selection

Manual standard selection is required for two cases:

- Local AI is unavailable.
- The teacher needs to add another correct tag that AI did not suggest.

Picker requirements:

- Scope defaults to the currently selected unit.
- Search filters by hashtag, title, detail, code, kind, and source ID.
- Show already selected references as selected/checked.
- Prevent duplicate selections.
- Allow removing selected tags directly from chips without opening the picker.
- If product later allows cross-unit tagging, it must be a deliberate mode switch; the MVP picker should not silently mix units.
- Manual additions and AI additions use the same persisted snapshot model, with `selectionSource` preserving how the tag was added.

## Persistence

Extend `ObservationCaptureDraft` to store selected standards:

- `referenceID`
- `sourceID`
- `kind`
- `classID`
- `unitID`
- `unitTitle`
- `programCode`
- `code`
- `title`
- `detail`
- `displayHashtag`
- `confidence`
- `evidenceQuotes`

Save must still work when no standard suggestions exist.

## Privacy And Logging

Even though the model is local, the transcript leaves the iPhone and goes to a LAN host. Treat it as sensitive.

Rules:

- Do not log transcripts.
- Do not log prompts.
- Do not log raw model responses.
- Do not log evidence quotes.
- Do not log student names.
- Redact or avoid child identifiers in model prompts.
- Send only the transcript, class/unit display context, and standard candidate text required for tagging.
- Keep host/model/version logs privacy-safe.

## Error Handling

Recoverable states:

- Standards not loaded.
- Selected unit has no candidates.
- Local AI host unavailable.
- Ollama returns non-2xx.
- Model times out.
- Model returns malformed JSON.
- Parser rejects all suggestions.

All of these should leave the observation draft saveable.

## Acceptance Criteria

- Given a selected unit with loaded standards, the local AI request includes only that unit's candidate IDs.
- The model can only select IDs present in the candidate list.
- The parser rejects unknown IDs and invented labels.
- Suggestions render as server-derived `displayHashtag` chips under `Suggested standards` copy.
- Suggestions are capped at 4.
- Changing units updates candidates and retags against the new unit.
- Tagging unavailable does not block saving the transcript.
- Local AI unavailable is shown as calm non-blocking copy, not a scary technical error.
- The teacher can remove suggested standards before saving.
- The teacher can manually add standards from the selected unit even when local AI is unavailable.
- The teacher can manually add additional standards after AI suggestions arrive.
- Removed standards do not reappear unless manually re-added or an explicit retag action is invoked.
- Saved drafts include enough selected-standard snapshot data to render without reloading standards.
- No transcript, prompt, raw response, child name, or evidence quote is logged in production.
- The implementation compiles for iPhone.

## Open Decisions

- Should local AI be enabled by default in DEBUG only, or also in TestFlight builds?
- Should a low-confidence suggestion be shown as selected, or shown as "needs review" separately?
- Should manual standard selection ship in the same slice or follow immediately after local AI suggestions?
- Should standard tagging replace static PYP chips entirely, or should both be shown until product decides the final taxonomy UI?
