# Child-Voice Feature Work Log

## Execution mode
- Work through one step at a time.
- Mark a step as done only after code change lands.
- Keep this file as the single source of truth for sequencing and decisions.

## Implementation sequence

- [x] 1. Audit and confirm API contract for child-voice upload + payload fields.
- [x] 2. Add API/models for `direct_upload` request + response, direct blob upload, and service-level helper.
- [x] 3. Extend review queue payload support to carry optional `audio_description_id` on note and photo payloads.
- [x] 4. Add child voice draft capture module (audio recorder + child selection + temporary persistence).
- [x] 5. Wire image-flow attachment of child voice to `FaceCaptureDraft` + disable states.
- [ ] 6. Add class-gear “Capture Child Voice” entry and direct flow into child voice draft.
- [ ] 7. Integrate audio upload into publish path (note + photo), using fixed note body and child assignment fallback.
- [ ] 8. Add stream rendering for child-voice card with role-specific prompt and no autoplay.
- [ ] 9. Validate edge cases: empty assignment array means all students, one-child enforcement, and upload failures.

## Decisions
- Audio body format: `.m4a`/`audio/mp4`.
- Parent/journal copy: role specific phrasing.
- No autoplay for child-voice cards.
- Keep this as hackathon scope: local drafts persist until publish.

## Current step
- Step 6 in progress: Add class-gear “Capture Child Voice” entry and direct flow into child voice draft.
