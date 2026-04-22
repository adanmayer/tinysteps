# Standards Loading Implementation Plan

Companion task list: [implementation-tasks.md](docs/features/standards-loading/implementation-tasks.md).

## Goal
Load ManageBac standards for observation tagging from the currently selected class in TinySteps. The selected class provides `classID` and `program`; units are fetched by class, and standards are fetched from each unit's components. PYP classes additionally require loading the school's transdisciplinary themes catalog through the existing role-scoped ManageBac route shape for `/school/tr_themes`; the final `MBAPI` path prefix must be confirmed before implementation.

## Current State
- TinySteps already models `MBClass` with `program.uid`, `program.code`, and `program.name`.
- ManageBac API support is currently portfolio-timeline focused.
- Missing pieces are ManageBac endpoints, response models, a standards-loading service, and a cache for class/program-scoped results.
- Existing feature docs conventionally use `implementation-plan.md` and `implementation-tasks.md`; keep this feature aligned with that naming.
- The old app used role-scoped ManageBac paths. Endpoint suffixes in this plan are discovery targets and old-app-confirmed shapes where marked, not final `/v2` route strings.
- Current code already confirms role-scoped paths in `MBClassUnitEndpoint` (`<role>/classes/{classID}/units`).

## Confirmed Defaults (Decision Log)
- Route convention: preserve existing role-scoped path style and school context in `MBAPI` and avoid introducing `/v2` without existing confirmation.
- PYP detection: check `program.code` first, then `program.name`, then `program.uid` (all normalized to trimmed lower-case for comparison).
- No explicit `isPYP` helper is present in the legacy app repo, so detection should be implemented as a small, testable utility in TinySteps.
- Hashtag generation applies to all normalized reference kinds: `standard`, `syllabus`, `scopeSequence`, and `pypTheme`.
- Hashtag runtime: local deterministic generation for short titles, and local Qwen3.5 for long titles.
- Cache scope: in-memory only; clear on logout, account change, or school switch.
- Partial failure policy: keep successful data and continue; surface failed units + retry.
- Non-PYP behavior: run non-PYP curriculum path and skip `/school/tr_themes`.
- Loading trigger: lazy, only when tagging UI requests standards for selected class.
- Error copy strategy: non-blocking errors for auth/network/partial failures with clear retry actions, while always allowing capture progress.

## Requirements
- Resolve standards from a selected `MBClass`, not from a global standards list.
- Load units by `classID` before loading unit-level components.
- Load standards, syllabus links, and scope sequences from unit components by unit.
- Detect PYP from `MBClass.program` and load the school transdisciplinary themes route only for PYP classes.
- Generate short display hashtags for all loaded references so selected tags can be scanned in compact observation UI.
- Cache results on demand by selected class and program so switching classes does not require unnecessary refetching.
- Expose loading, empty, partial, and error states suitable for observation tagging UI.
- Keep the API layer independent of SwiftUI so it can be reused by tagging, sync, and future curriculum screens.
- Confirm the ManageBac role scope and path prefix in the existing client before implementation; do not introduce `/v2` routes unless that prefix is verified in current TinySteps conventions.

## ManageBac API Endpoint Shapes To Confirm
These are endpoint shapes for discovery and `MBAPI` additions. Treat them as role-scoped old-app shapes where marked, not final TinySteps route strings. The implementation must preserve the existing ManageBac client convention for role scope, school context, API prefix, authentication, and pagination.

- `GET {roleScope}/classes/{classID}/units`
  - Status: old-app-confirmed role-scoped shape; final prefix/scope must be confirmed in `MBAPI`.
  - Purpose: load units for the selected class.
  - Input: ManageBac class ID from `MBClass.classID`.
  - Output: unit IDs, titles, date ranges, and any program metadata returned by ManageBac.
- `GET {roleScope}/units/{unitID}/components`
  - Status: old-app-confirmed role-scoped shape; final prefix/scope must be confirmed in `MBAPI`.
  - Purpose: load curriculum components attached to each unit.
  - Input: unit ID from the class units response.
  - Output: standards, syllabus items, scope sequences, and PYP-related component links when present.
- `GET {roleScope}/school/tr_themes`
  - Status: old-app-confirmed route suffix `/school/tr_themes`; final prefix/scope must be confirmed in `MBAPI`.
  - Purpose: load the PYP transdisciplinary themes catalog.
  - Input: none beyond the authenticated school context.
  - Output: school-level PYP theme IDs, names, descriptions, and ordering.

If TinySteps already uses a different API prefix or route construction helper, preserve that convention in `MBAPI` rather than introducing a second style.

## Data Model
Add response DTOs close to the API layer, then map them into app-facing curriculum models.

- `MBUnitDTO`
  - `id`, `title`, `startDate`, `endDate`, optional `description`, optional raw program fields.
- `MBUnitComponentsDTO`
  - `unitID`, `standards`, `syllabusItems`, `scopeSequences`, optional PYP theme references.
- `MBStandardDTO`
  - `id`, `code`, `label`, `description`, optional strand/domain/category fields, optional source metadata.
- `MBSyllabusItemDTO`
  - `id`, `code`, `title`, `description`, optional parent/category fields.
- `MBScopeSequenceDTO`
  - `id`, `code`, `title`, `description`, optional strand/phase/level fields.
- `MBTRThemeDTO`
  - `id`, `name`, `description`, optional `order`.

App-facing models should normalize all taggable curriculum references into a single observation-friendly shape:

```swift
struct MBStandardReference: Identifiable, Hashable {
    let id: String
    let kind: Kind
    let classID: String
    let code: String?
    let title: String
    let detail: String?
    let unitID: String
    let unitTitle: String
    let programCode: String?
    let displayHashtag: String
}
```

`Kind` should distinguish at least `standard`, `syllabus`, `scopeSequence`, and `pypTheme` so observation tags can preserve source semantics.

Use a stable identity convention for normalized references. If ManageBac IDs are not globally unique across component types, derive `id` from `kind`, source ID, `classID`, and `unitID` rather than relying on a raw component ID alone.

`displayHashtag` is display metadata only. It must never replace the normalized reference ID, source ManageBac ID, `kind`, `classID`, `unitID`, or `programCode` used for persistence and sync.

## Display Hashtag Generation
All normalized references are often too long for compact tagged-standard lists. The standards-loading/indexing layer should generate a short, stable `displayHashtag` for every normalized reference.

Preferred generation path:

- Use the local Qwen3.5 service/model for references whose display title has more than two meaningful words.
- Use deterministic local generation for titles with two words or fewer.
- Generate hashtags during standards indexing, not while SwiftUI lists render.
- Batch requests per class/program load to reduce latency and keep output consistent.
- Cache generated hashtags together with the normalized standards result.
- Reuse cached hashtags for the same class/program/reference identity.

Concrete request/response contract example:

```json
POST /ai/standard-hashtags
Content-Type: application/json

{
  "items": [
    {
      "id": "std_abc123",
      "kind": "standard",
      "programCode": "PYP",
      "code": "PYP-1-2",
      "text": "Learners ask questions that are important to them and investigate to find answers."
    },
    {
      "id": "scope_xyz456",
      "kind": "scopeSequence",
      "programCode": "PYP",
      "code": null,
      "text": "Apply knowledge and skills in authentic contexts through inquiry."
    }
  ],
  "options": {
    "maxHashtagLength": 24,
    "forceDeterministic": true
  }
}
```

```json
{
  "provider": "qwen3.5",
  "items": [
    { "id": "std_abc123", "status": "ok", "hashtag": "#CuriousInquiry" },
    { "id": "scope_xyz456", "status": "ok", "hashtag": "#ApplyInContext" }
  ],
  "meta": {
    "requestId": "8fa1d9",
    "generatedAt": "2026-04-22T10:21:03Z"
  }
}
```

Failure response:

```json
{
  "provider": "qwen3.5",
  "items": [
    {
      "id": "std_abc123",
      "status": "invalid_payload",
      "error": "text too short for AI generation"
    }
  ]
}
```

The service should map `status` into local fallback generation for each `id` independently.

Validation rules:

- Hashtag starts with `#`.
- Max length is 24 characters unless product explicitly changes the display budget.
- No spaces, punctuation, emojis, quotes, or student/classroom-specific names.
- Prefer educational meaning over exact wording.
- Output must be stable for the same input as far as the model path allows.
- If the model fails, times out, returns invalid JSON, or returns an invalid hashtag, fall back to deterministic keyword extraction.
- If two hashtags collide in the same class corpus, append a short deterministic suffix from the reference code or ID.

Prompting requirements:

- Use strict JSON input and output.
- Use temperature `0` or the closest deterministic setting available.
- Include only curriculum reference text and non-sensitive metadata such as `id`, `kind`, `programCode`, and optional `code`.
- Do not include transcripts, student names, child identifiers, teacher notes, or observation evidence in hashtag generation prompts.
- Treat generated hashtags as suggestions that are normalized by validation code before entering the cache.

The Qwen3.5 path is preferred over device-local AI frameworks because curriculum text is non-student metadata, batching gives more consistent results, and device-local model availability differs by iPhone, OS version, and language.

## Service Design
Create a dedicated service above `MBAPI` and below SwiftUI/view models.

- `MBAPI`
  - Adds raw endpoint functions for class units, unit components, and PYP transdisciplinary themes.
  - Owns request construction, authentication, pagination if needed, and DTO decoding.
- `MBStandardsLoadingService`
  - Public entry point: `loadStandards(for selectedClass: MBClass, forceRefresh: Bool = false)`.
  - Reads `selectedClass.classID` and `selectedClass.program`.
  - Loads class units first.
  - Loads unit components for each unit.
  - For PYP only, loads the role-scoped transdisciplinary themes endpoint and merges theme references into the result.
  - Maps DTOs into `MBStandardReference` values grouped by unit.
- `MBStandardHashtagGenerator`
  - Public entry point: `hashtags(for references: [MBStandardReference])`.
  - Uses deterministic local generation for short titles.
  - Uses the local Qwen3.5 service/model for long titles when available.
  - Validates, de-duplicates, and falls back locally before results enter the cache.
- `MBStandardsCache`
  - In-memory, on-demand cache keyed by class/program.
  - Suggested key type: `MBStandardsCacheKey(classID:programIdentifier:)`, where `programIdentifier` uses `program.uid` and falls back to `program.code` when `uid` is unavailable.
  - Stores the normalized result, generated hashtags, and fetch metadata.
  - Supports `forceRefresh` and invalidation on logout, school switch, or ManageBac account change.
  - Class switching should select a different cache key; it should not clear all cached class results unless account or school context changed.

## Loading Flow
1. Observation tagging receives or observes the selected `MBClass`.
2. The tagging view model requests `MBStandardsLoadingService.loadStandards(for:)`.
3. Service checks `MBStandardsCache` using class/program key.
4. On cache miss, service loads units for `classID`.
5. Service loads components for each unit and normalizes standards, syllabus items, and scope sequences.
6. If program is PYP, service loads the role-scoped transdisciplinary themes route and attaches matching theme references.
7. Service generates or reuses validated display hashtags for normalized references.
8. Service returns a grouped result for display and tag selection.

## PYP Decisions
- Treat PYP as a program-specific loading path, not a separate feature.
- Detect PYP using `program.code` first, then `program.name`, then `program.uid` only if ManageBac provides stable PYP identifiers.
- Load the transdisciplinary themes route only for PYP classes to avoid unnecessary requests for MYP, DP, or other programs.
- Keep PYP themes as first-class taggable references when they are directly relevant to observation tagging.
- If a unit component references a theme ID that is missing from `/school/tr_themes`, surface the unit data and mark the theme as unresolved rather than failing the whole load.
- Use the user-facing label `PYP theme` for theme references; reserve `TR theme` or raw API naming for DTO/API internals only.

## Observation Tagging Integration Points
- Add a standards provider dependency to the observation tagging view model or coordinator.
- Trigger loading when the selected class changes and when the tagging sheet/screen needs curriculum tags.
- Present standards grouped by unit, with filtering by kind and text search.
- Use `displayHashtag` in compact tagged-standard lists; show the long title/detail in expanded rows, detail views, or accessibility labels.
- Persist selected tags using stable normalized reference IDs plus source ManageBac IDs where available, `kind`, `programCode`, `classID`, `unitID`, `displayHashtag`, and display fields needed to render without an immediate reload.
- Avoid embedding raw DTOs in observation records; store normalized references needed for display and sync.

## Error, Empty, And Loading States
- `idle`: no class selected or standards not requested yet.
- `loading`: initial class/program load in progress.
- `refreshing`: cached results are visible while a forced refresh is running.
- `loaded`: standards are available, including partial results if some unit component requests failed.
- `empty`: units loaded but no taggable standards, syllabus items, scope sequences, or PYP themes were found.
- `partialFailure`: some units failed; show available standards and a retry action.
- `failed`: class units failed or authentication/account state prevents loading.

Error messages should distinguish authentication, network, decoding, unsupported program, no units, and partial unit failures. The UI should not block observation creation when standards cannot be loaded.
Unrecognized program metadata should default to the non-PYP loading path unless a confirmed program-specific requirement says otherwise.
When program detection is missing or unknown, emit a non-blocking debug event and continue on the non-PYP path so tagging remains functional.

## Acceptance Criteria
- Endpoint implementation confirms and uses existing role-scoped ManageBac path conventions, and does not hardcode unverified `/v2` routes.
- Given a selected non-PYP class, TinySteps loads units by class and unit components by unit, then shows taggable standards without calling the transdisciplinary themes endpoint.
- Given a selected PYP class, TinySteps loads units, unit components, and the role-scoped transdisciplinary themes endpoint, then exposes PYP theme references where applicable.
- Results are cached by class/program and reused when the same class is selected again.
- Long standards receive validated display hashtags generated during indexing, and invalid/failed AI output falls back to deterministic local hashtags.
- Hashtag generation never sends transcripts, student names, child identifiers, or observation evidence to the model.
- Class switching uses the selected class/program cache key and does not show stale standards from the previous class.
- Force refresh bypasses the cache and replaces cached data only after a successful load or a documented safe partial-load policy.
- Observation tags store normalized references with enough metadata to render without reloading ManageBac immediately.
- Partial unit failures preserve successfully loaded standards and surface retry/error state.
- Existing portfolio timeline API behavior is unchanged.
- No standards-loading request is made before a class is selected.
