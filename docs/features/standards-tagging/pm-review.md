# Standards Tagging With Local AI - PM Review

Role: Expert PM Review

Reviewed plan: [implementation-plan.md](implementation-plan.md)

## Review Status

Approved with conditions.

The plan matches the product direction: use the standards already loaded from ManageBac, scope suggestions to the selected unit, and make AI return stable IDs that map back to server standards. This is the right trust model for standards because display labels and hashtags are not unique enough.

## Product Requirements Confirmed

- Teachers should see selected standards as compact hashtags.
- Standards must come from the server-loaded selected unit.
- AI must return IDs for standards, not generated labels.
- Maximum visible suggestions should be 4.
- Unit selection should directly affect the candidate standards.
- Changing units should update candidate hashtags and rerun tagging for the new unit when a transcript exists.
- Tagging failure must not block saving the observation.

## PM Conditions Before Implementation

1. Local AI availability must be clear.

   If the local Qwen host is unavailable, the screen should not feel broken. Show a calm non-blocking state and allow the teacher to save the transcript.

2. The selected unit must be obvious.

   The teacher needs to understand why the suggested standards changed. Unit pills above the transcript are important and should stay visible.

3. Suggested standards need teacher control.

   The teacher must be able to remove a wrong suggested standard before save.

4. No fake confidence.

   Confidence is useful for internal behavior, but the first UI should not overemphasize a model confidence number. The product should communicate "suggested" rather than "confirmed".

5. Do not show long standards in the compact capture screen.

   Use hashtags in the compact row. Full standard text can be available through tap/expanded detail or accessibility.

6. Privacy copy needs review before broader distribution.

   A local LAN model is still outside the iPhone. The app should not silently send teacher transcripts to a developer machine in any non-development context.

## PM Amendments To Engineering Plan

- Keep the first implementation selected-unit-only. Do not tag across all units yet.
- Use "Suggested standards" language in UI copy.
- Keep selected chips removable.
- Do not block Save while tagging runs.
- Do not show model errors as scary technical errors. Use copy like "Standard suggestions are unavailable. You can still save this observation."
- Consider manual standard selection as the next slice if model suggestions are not reliable enough in classroom use.

## Acceptance Criteria From PM

- With a transcript and selected unit, up to 4 suggested standard hashtags appear.
- The same transcript can produce different suggestions when a different unit is selected.
- If the local model is offline, the transcript can still be saved.
- If the AI returns an invalid ID, it is never shown to the teacher.
- Teacher can remove a suggested standard before saving.
- Saved drafts show selected standard hashtags later without reloading the standards API.
- iPhone layout remains calm and uncluttered with long standards.

## Open PM Questions

- Should local AI be enabled only for developer/debug builds for now?
- Should low-confidence suggestions appear as normal suggested chips, or in a "Review carefully" visual state?
- Should manual standard selection ship in the same implementation slice?
- Should static PYP chips stay visible once server-standard suggestions are working?
