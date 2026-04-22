# Standards Loading Implementation Tasks

Plan reference: [implementation-plan.md](docs/features/standards-loading/implementation-plan.md).

## Phase 0: Endpoint Confirmation And Naming Alignment
- Confirm the existing `MBAPI` route construction style, including role scope, school context, API prefix, authentication, and pagination behavior.
- Confirm old-app role-scoped route shapes before coding final endpoints: `{roleScope}/classes/{classID}/units`, `{roleScope}/units/{unitID}/components`, and `{roleScope}/school/tr_themes`.
- Note: role-scoped class-unit path is already confirmed in current code via `Packages/MBAPI/.../MBClassUnitEndpoint.swift`.
- Verify legacy app does not provide an explicit `isPYP` utility; define and test TinySteps’ own PYP detection helper accordingly.
- Do not hardcode `/v2` paths unless the current TinySteps ManageBac client confirms that prefix.
- Use the repo feature-doc naming convention: `implementation-plan.md` and `implementation-tasks.md`.
- Use consistent implementation names from the plan: `MBStandardsLoadingService`, `MBStandardsCache`, `MBStandardsCacheKey`, and `MBStandardReference.Kind`.
- Confirm the local Qwen3.5 service boundary available for non-sensitive curriculum hashtag generation.

## Phase 1: API And Models
- Add `MBAPI` endpoint for loading units by selected class ID using the confirmed role-scoped path.
- Add `MBAPI` endpoint for loading unit components by unit ID using the confirmed role-scoped path.
- Add `MBAPI` endpoint for loading PYP transdisciplinary themes using the confirmed role-scoped school path.
- Add DTOs for units, unit components, standards, syllabus items, scope sequences, and transdisciplinary themes.
- Add app-facing normalized model for taggable standards references, including `classID`, `unitID`, `programCode`, `kind`, `displayHashtag`, display fields, and stable source metadata.
- Define normalized reference identity so collisions are avoided when ManageBac IDs are only unique within a component kind or unit.
- Add mapping from API DTOs to normalized references grouped by unit.

## Phase 2: Service And Cache
- Add `MBStandardsLoadingService` with `loadStandards(for:forceRefresh:)`.
- Ensure the service loads class units before requesting unit components.
- Add `MBStandardsCacheKey` using `classID` plus `program.uid` or `program.code` fallback.
- Add in-memory on-demand cache for normalized standards results and fetch metadata.
- Treat class switching as a cache-key change, not as a full cache clear.
- Add cache invalidation hooks for account logout, school switch, and ManageBac account change.
- Add force-refresh behavior that bypasses cached data.
- Define whether a safe partial load may replace cached data; otherwise keep the previous successful cached result when refresh is partially failed.
- Add partial-result handling when one or more unit component requests fail.

## Phase 3: Hashtag Generation
- Add `MBStandardHashtagGenerator` or equivalent service boundary.
- Generate hashtags during standards loading/indexing, not in SwiftUI row rendering.
- Use deterministic local hashtag generation for titles with two meaningful words or fewer.
- Use the local Qwen3.5 model/service for references with more than two meaningful words.
- Batch long-title hashtag generation per class/program load.
- Use strict JSON prompts and deterministic model settings.
- Define and implement the hashtag contract for Qwen3.5 with stable request/response fields (`id`, `kind`, `programCode`, `code`, `text`, `status`, `hashtag`) and failure statuses (e.g., `invalid_payload`).
- Send only curriculum reference text and non-sensitive metadata to Qwen3.5.
- Never send transcripts, student names, child identifiers, teacher notes, or observation evidence for hashtag generation.
- Validate generated hashtags before caching: starts with `#`, max 24 characters, no spaces, no punctuation except leading `#`, no emojis, and no student/classroom-specific names.
- Add deterministic fallback when Qwen3.5 is unavailable, times out, returns invalid JSON, or returns invalid hashtags.
- Add collision handling within the same class corpus by appending a short deterministic suffix from code or reference ID.
- Cache validated hashtags with the standards result.

## Phase 4: PYP Support
- Add PYP detection helper using `program.code`, then `program.name`, then stable `program.uid` if available.
- Default unrecognized program metadata to the non-PYP loading path.
- If program detection is missing or unknown, emit a non-blocking debug event and continue with non-PYP loading so tagging remains usable.
- Load the transdisciplinary themes endpoint only when the selected class is PYP.
- Merge PYP theme catalog data with unit component theme references.
- Represent unresolved theme references without failing the entire standards load.
- Use `PYP theme` as the user-facing label for theme references.
- Confirm display labels for PYP themes in observation tagging.

## Phase 5: Observation Tagging Integration
- Inject the standards-loading service into the observation tagging view model or coordinator.
- Start standards loading only after a selected class is available and the tagging flow requests it (lazy).
- Reload or reuse cache when the selected class changes.
- Display references grouped by unit and distinguish standards, syllabus items, scope sequences, and PYP themes.
- Use `displayHashtag` in compact tagged-standard lists while keeping the long standard title available in expanded UI and accessibility labels.
- Add search/filter behavior for tag selection.
- Persist selected normalized references with stable reference ID, source ManageBac ID where available, `kind`, `classID`, `unitID`, `programCode`, `displayHashtag`, and display fields needed for offline rendering.
- Ensure observation creation remains available if standards loading fails.

## Phase 6: UX States And Recovery
- Add UI state for idle, loading, refreshing, loaded, empty, partial failure, and failed.
- Show retry for failed class-unit load.
- Show retry or refresh for partial unit-component failures.
- Show empty state when units exist but no taggable references are returned.
- Show authentication/account-specific error copy when ManageBac credentials are unavailable or expired.
- Ensure partial failures keep successfully loaded references visible while clearly identifying unavailable units.
- Keep all capture flows usable even on auth/network/standard-loading errors; add explicit retry actions per error state.

## Phase 7: Product Acceptance Checks
- Confirm endpoint implementation uses existing role-scoped ManageBac path conventions and does not introduce unverified `/v2` routes.
- Verify non-PYP class loads units and unit components without requesting the transdisciplinary themes endpoint.
- Verify PYP class loads units, unit components, and the transdisciplinary themes endpoint.
- Verify all reference kinds receive validated display hashtags during indexing (`standard`, `syllabus`, `scopeSequence`, `pypTheme`).
- Verify Qwen3.5 hashtag failures fall back to deterministic local hashtags without blocking standards loading.
- Verify hashtag generation does not send transcripts, student names, child identifiers, teacher notes, or observation evidence to the model.
- Verify compact tagged-standard lists use `displayHashtag` while expanded UI can still show the full standard title.
- Verify cached results are reused for the same class/program key.
- Verify force refresh bypasses cache and follows the documented replacement policy for partial results.
- Verify class switching uses the new selected class key and does not show stale standards.
- Verify partial unit failures keep successfully loaded references visible.
- Verify existing portfolio timeline API behavior is unchanged.
- Verify loading triggers only when capture/tagging UI requests standards; no eager prefetch.
- Verify no standards-loading request is made before a class is selected.
- Verify observation tags can render from persisted normalized references without an immediate ManageBac reload.
