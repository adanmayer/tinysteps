# Portfolio Publish - Implementation Plan

Role: Expert Lead Engineer

Companion task list: [implementation-tasks.md](implementation-tasks.md)

## Goal

Publish locally stored review items to the ManageBac portfolio backend so a teacher can move a moment from the device-only Review queue into the selected class portfolio stream.

Unpublished observation and photo drafts are currently local-device state only. After publish succeeds, the local draft can be removed. If publish fails at any point, the draft must stay on the device with enough error detail for retry.

## References Reviewed

- `/Users/dave/Development/swift/managebac-mobile-native-ios-copy/docs/portfolio-stream-porting-guide.md`
- `/Users/dave/Development/swift/managebac-mobile-native-ios-copy/docs/standards-tagging-integration-guide.md`
- `TinySteps/TinySteps/Features/ReviewQueue/ObservationDraftPublisher.swift`
- `TinySteps/TinySteps/Features/ReviewQueue/ObservationReviewQueueModel.swift`
- `TinySteps/TinySteps/Features/ObservationCapture/ObservationCaptureDraft.swift`
- `TinySteps/TinySteps/Features/ObservationCapture/ObservationCaptureDraftStore.swift`
- `TinySteps/TinySteps/Features/ObservationCapture/StandardTagging/ObservationStandardTaggingModels.swift`
- `TinySteps/TinySteps/Features/FaceCapture/FaceCaptureDraft.swift`
- `TinySteps/TinySteps/Features/FaceCapture/FaceCaptureDraftStore.swift`
- `TinySteps/TinySteps/Features/Portfolio/Services/PortfolioService.swift`
- `Packages/MBAPI/Sources/MBAPI/APIEndpoints/MBPortfolioEndpoint.swift`
- `Packages/MBAPI/Sources/MBAPI/MBClient.swift`

## Current State

- `ObservationReviewQueueModel` already has a publish flow through `ObservationDraftPublishing`.
- Live app composition still injects `UnavailableObservationDraftPublisher`, so publish always fails with "Publishing is not connected yet."
- Drafts are stored in `FileObservationCaptureDraftStore` under application support and are class-scoped by `classID`.
- A draft contains the transcript, matched students, selected PYP/static tags, selected standard tag suggestions, evidence, and status.
- Current `MBPortfolioEndpoint` only supports listing timeline items.
- Current `MBEndpointRequesting.send` can send JSON but does not decode a response body.
- There is no multipart upload path in the new TinySteps `MBAPI` layer yet.
- Existing Observation Review publish deletes a draft only after `publisher.publish` returns successfully.
- `FaceCaptureDraft` stores one JPEG image plus detected/assigned faces, but the store is currently in-memory and only supports `saveDraft`.
- Review filters already reserve photo/image/video/file/website cases, but only note-style observation drafts currently match.

## Product Decision

MVP publish target is the class learning stream:

```text
POST /{role}/portfolio/classes/{classID}/resources/notes
POST /{role}/portfolio/classes/{classID}/resources/photos
```

Use `teacher` role path for teacher and advisor accounts. This aligns with the existing class Stream reader:

```text
GET /{role}/portfolio/classes/{classID}/timeline
```

Do not use teacher bulk-create for the MVP. Bulk-create posts into student/program portfolio resources and requires `programUid`. Our Review queue is class-scoped and already represents a class learning moment, so the class stream resource endpoint is the correct first target.

Text observations publish as `note` resources. Captured class photos publish as `photo` resources after an upload-first step to `/photos`.

## MVP Scope

### Must Ship

- Real publish implementation for text observation drafts and photo drafts.
- MBAPI support for creating portfolio class-stream note and photo resources.
- MBAPI support for uploading captured photos to `/photos`.
- Create payload mapping from `ObservationCaptureDraft` to ManageBac portfolio note payload.
- Create payload mapping from `FaceCaptureDraft` or a unified local review item to ManageBac portfolio photo payload.
- Student attribution mapping from `draft.matchedChildren` to backend student/user IDs.
- Student attribution mapping from `FaceCaptureDraft.faces.studentKey` to backend student/user IDs.
- Standard tag mapping from `ObservationStandardTagSuggestion.sourceIdentity` into portfolio academic tagging id arrays.
- Strong validation before network submission.
- Error handling that leaves local drafts untouched on failure.
- Review queue UI state showing publishing in progress, success, and retryable failures.
- Tests for endpoint paths, payload encoding, standard id partitioning, and delete-after-success behavior.

### Should Ship If Nearby

- Publish response decode into `Portfolio.TimelineItem` or a lightweight `Portfolio.ResourceDetails` model.
- Refresh the class Stream after publish if the Stream tab is visible or next opened.
- Per-draft debug logging with draft id, class id, endpoint, status, and non-sensitive validation failures.
- Retry affordance per failed draft.

### Explicitly Out Of Scope

- File/website/reflection publishing.
- Audio description upload.
- Comments, reactions, likes, moderation, and editing published portfolio items.
- Client-side fan-out to multiple student portfolios.
- Deleting a local draft before server confirmation.

## Backend Contract

The portfolio porting guide defines class stream creation as:

```text
POST /{role}/portfolio/classes/{classID}/resources/{kind}
```

For observation text, use `kind = notes`.

For captured photos, upload binary first:

```text
POST /photos
POST /{role}/portfolio/classes/{classID}/resources/photos
```

Minimum note payload:

```json
{
  "title": "Observation",
  "body": "Brian did paint a nice picture and was very happy with it.",
  "start_date": "2026-04-23",
  "allowed_user_roles": ["student", "parent", "teacher"],
  "notify_via_email": false,
  "assigned_user_ids": [12345],
  "share_to_student_portfolios": false,
  "atl_ids": [],
  "learner_profile_ids": [],
  "units_standard_ids": [1954],
  "standard_ids": [123],
  "units_syllabus_ids": null,
  "syllabus_ids": null,
  "units_expectation_ids": [],
  "expectation_ids": [],
  "transdisciplinary_themes_ids": [3],
  "transdisciplinary_theme_descriptions_ids": [33]
}
```

Minimum photo payload after upload:

```json
{
  "title": "Observation photo",
  "description": "Optional teacher note or generated summary.",
  "start_date": "2026-04-23",
  "photo_ids": [333],
  "allowed_user_roles": ["student", "parent", "teacher"],
  "notify_via_email": false,
  "assigned_user_ids": [12345],
  "share_to_student_portfolios": false,
  "atl_ids": [],
  "learner_profile_ids": [],
  "units_standard_ids": [],
  "standard_ids": [],
  "units_syllabus_ids": null,
  "syllabus_ids": null,
  "units_expectation_ids": [],
  "expectation_ids": [],
  "transdisciplinary_themes_ids": [],
  "transdisciplinary_theme_descriptions_ids": []
}
```

Defaults:

- `title`: `"Observation"` for MVP.
- `body`: `draft.transcript` trimmed.
- `start_date`: local date from `draft.createdAt`, encoded as `YYYY-MM-DD`.
- `allowed_user_roles`: `["student", "parent", "teacher"]` to match old-app teacher default visibility.
- `notify_via_email`: `false`; class stream publish should not send mail from the review queue.
- `share_to_student_portfolios`: `false` until product explicitly asks for class stream moments to also appear in each student portfolio.

Photo defaults:

- `title`: `"Observation photo"` for MVP.
- `description`: empty unless the review item has teacher-entered text.
- `start_date`: local date from `FaceCaptureDraft.capturedAt`, encoded as `YYYY-MM-DD`.
- `photo_ids`: server ids returned by `POST /photos`.
- `allowed_user_roles`, `notify_via_email`, and `share_to_student_portfolios`: same defaults as notes.

Upload requirements:

- Encode captured image as JPEG using the already stored `FaceCaptureDraft.imageData`.
- Multipart field name must be `file`, matching the old app and portfolio guide.
- The upload response must decode at least `id`, `url`, and available `versions`.
- If upload succeeds but resource creation fails, keep the local draft. Server-side orphan cleanup can be added later if needed.

## Local Review Item Model

The Review queue needs to publish more than observation text. Add a local review item abstraction instead of forcing photos into `ObservationCaptureDraft`.

```swift
enum PortfolioReviewItemKind: String, Codable, Sendable {
    case note
    case photo
}

struct PortfolioReviewItem: Identifiable, Codable, Sendable {
    let id: UUID
    let classID: String
    let className: String
    let kind: PortfolioReviewItemKind
    var noteDraft: ObservationCaptureDraft?
    var photoDraft: FaceCaptureDraft?
    var status: PortfolioReviewItemStatus
    var createdAt: Date
    var updatedAt: Date
}
```

Implementation options:

- Minimal route: keep `ObservationCaptureDraftStore` for notes and extend `FaceCaptureDraftStore` to load/delete persisted photo drafts, then let the Review model merge both stores into one displayed list.
- Cleaner route: introduce `PortfolioReviewItemStore` and migrate note/photo drafts into a single persisted queue.

Recommendation for hackathon speed: extend the existing stores and merge in the Review queue first. Avoid a migration unless it becomes necessary.

## Student Attribution

Observation drafts store `ObservationMatchedChild.studentKey`. Photo drafts store `FaceCaptureDraftFace.studentKey`. `ClassRosterStudent` builds this from `MBMember.rosterStudentKey`, which is `MBMember.studentID` when present and otherwise `MBMember.user.id`.

Publishing must not assume that `studentKey` is definitely the value expected by `assigned_user_ids`. The publisher should resolve selected draft/photo students against the current class roster before posting:

- Load class students through `ClassesService.loadClassStudents(for:classID:)`.
- Match by `MBMember.rosterStudentKey`.
- Use the backend id confirmed by API testing for portfolio assignment.
- If the API expects user ids, send `MBMember.user.id`.
- If the API expects student ids, send `MBMember.studentID`.
- If a selected student cannot be resolved, block publish for that draft with a clear local error and keep the draft.

This should be verified once with the development API because the old app naming differs between `assigned_user_ids`, `assigned_users`, and `portfolio_student_ids`.

## Standards And Tag Payload Mapping

Use `ObservationStandardTagSuggestion.sourceIdentity`, not hashtags and not generated display IDs, to build portfolio outcome arrays.

Mapping:

| Source identity | Portfolio fields |
|---|---|
| `.standard(unitID, standardID)` | `units_standard_ids += unitID`, `standard_ids += standardID` |
| `.syllabus(unitID, syllabusID)` | `units_syllabus_ids += unitID`, `syllabus_ids += syllabusID` |
| `.scopeSequence(unitID, expectationID)` | `units_expectation_ids += unitID`, `expectation_ids += expectationID` |
| `.pypTheme(themeID)` | `transdisciplinary_themes_ids += themeID` |
| `.pypThemeDescription(themeID, descriptionID)` | `transdisciplinary_themes_ids += themeID`, `transdisciplinary_theme_descriptions_ids += descriptionID` |
| `.unresolved` | not publishable; block with a validation error |

Rules from the old app:

- Send both `units_X_ids` and `X_ids` for standards, syllabus, and scope sequences.
- For PYP classes, send `nil` for syllabus fields.
- For non-PYP classes, send `nil` for transdisciplinary theme fields.
- De-duplicate all arrays while preserving selection order.
- If any selected standard source id is non-numeric, fail validation and keep the draft local. Do not silently drop a teacher-selected standard.

## Proposed App Architecture

Add a small publishing module under ReviewQueue or Portfolio, keeping the existing Review queue model mostly unchanged.

```text
ObservationReviewQueueModel
  -> PortfolioReviewItemPublishing
      -> MBPortfolioReviewItemPublisher
          -> PortfolioPublishPayloadBuilder
          -> PortfolioStudentAssignmentResolver
          -> PortfolioOutcomePayloadBuilder
          -> PortfolioPhotoUploadService
          -> PortfolioService / MBClient
              -> MBPortfolioEndpoint.createClassNote(...)
              -> MBPortfolioEndpoint.createClassPhoto(...)
```

### New Types

```swift
struct PortfolioNoteCreatePayload: Encodable, Sendable
struct PortfolioPhotoCreatePayload: Encodable, Sendable
struct PortfolioOutcomePayload: Equatable, Sendable
struct PortfolioUploadedPhoto: Decodable, Sendable
struct PortfolioPublishValidationError: LocalizedError, Equatable, Sendable
struct MBObservationDraftPublisher: ObservationDraftPublishing
struct MBPortfolioReviewItemPublisher: PortfolioReviewItemPublishing
struct PortfolioPublishPayloadBuilder: Sendable
struct PortfolioStudentAssignmentResolver: Sendable
struct PortfolioOutcomePayloadBuilder: Sendable
struct PortfolioPhotoUploadService: Sendable
```

### Service Boundary

Extend `PortfolioService`:

```swift
protocol PortfolioService {
    func loadPortfolioTimeline(...) async throws -> [MBAPI.Portfolio.TimelineItem]

    func createClassNote(
        for session: AuthSession,
        classID: String,
        payload: PortfolioNoteCreatePayload
    ) async throws -> MBAPI.Portfolio.TimelineItem?

    func uploadPhoto(
        for session: AuthSession,
        imageData: Data,
        filename: String
    ) async throws -> PortfolioUploadedPhoto

    func createClassPhoto(
        for session: AuthSession,
        classID: String,
        payload: PortfolioPhotoCreatePayload
    ) async throws -> MBAPI.Portfolio.TimelineItem?
}
```

Extend `MBPortfolioEndpoint`:

```swift
func createClassResource<Response: Decodable, Payload: Encodable>(
    in context: MBSessionContext,
    classID: String,
    kind: PortfolioResourceKind,
    payload: Payload,
    responseType: Response.Type
) async throws -> Response

func uploadPhoto(
    in context: MBSessionContext,
    imageData: Data,
    filename: String,
    mimeType: String
) async throws -> PortfolioUploadedPhoto
```

`MBEndpointRequesting` needs a JSON request that decodes a response and a multipart request that decodes a response. Reuse the existing issue logging behavior from `loadObject` and `send`.

## Publish Flow

### Note

1. User taps Publish on a review draft.
2. `ObservationReviewQueueModel` verifies `isReadyForPublish`.
3. Publisher validates transcript, class id, selected students, and selected standard ids.
4. Publisher resolves matched students against class roster.
5. Publisher builds `PortfolioNoteCreatePayload`.
6. `MBPortfolioService` posts the payload to the class stream note endpoint.
7. On 2xx and valid response, `ObservationReviewQueueModel` deletes the local draft.
8. On any validation, transport, auth, server, or decoding failure, the draft remains local and the UI shows a retryable error.

### Photo

1. User captures a class photo and keeps it for Review.
2. Review queue loads the local photo draft alongside note drafts.
3. User taps Publish on the photo item.
4. Publisher validates class id, image data, and assigned faces/students.
5. Publisher resolves selected students against class roster.
6. Publisher uploads image data to `/photos`.
7. Publisher builds `PortfolioPhotoCreatePayload` with returned `photo_ids`.
8. `MBPortfolioService` posts the payload to the class stream photo endpoint.
9. On 2xx and valid response, the Review model deletes the local photo draft.
10. On upload or create failure, the local photo draft remains available for retry.

Bulk publish should keep the current sequential behavior for MVP. Stop on the first failure so the teacher can see which draft needs attention; already-published drafts are removed, failed/unattempted drafts stay local.

## Error Handling Requirements

Errors must be typed internally and calm in UI copy.

Validation errors:

- Empty transcript.
- Missing class id.
- Selected student no longer exists in roster.
- Standard selection contains unresolved or non-numeric source identity.
- PYP/non-PYP field partition cannot be determined.
- Missing or corrupt photo data.
- Captured photo has assigned face keys that no longer resolve to class students.

Network/API errors:

- Unauthorized or wrong role path.
- 403/404 endpoint mismatch.
- 422 validation response from portfolio API.
- Photo upload failure.
- Photo upload succeeds but portfolio photo resource creation fails.
- Transport timeout/offline.
- Response decode failure.

Expected user-facing behavior:

- Never delete a local draft after a failed publish.
- Keep the per-draft spinner/action state local to that draft.
- Show a useful message such as `"Publish failed. This moment is still saved on this device."`
- Log endpoint path, status code, draft id, class id, and response issue file path where available.
- Do not log transcript text, student names, or evidence quotes in release logs.

## Tests

Unit tests:

- Draft-to-note payload encodes `body`, `title`, `start_date`, privacy, and student assignment fields.
- Advisor role resolves to `teacher` URL path.
- `createClassNote` builds `teacher/portfolio/classes/{classID}/resources/notes`.
- Source identity mapping partitions standard, syllabus, scope sequence, and PYP theme ids correctly.
- PYP payload nulls syllabus fields.
- Non-PYP payload nulls transdisciplinary fields.
- Unresolved/non-numeric standard source ids fail validation.
- `ObservationReviewQueueModel` deletes a draft only after publisher success.
- Failed publish leaves the draft in the store.
- Photo publish uploads to `/photos` before creating `resources/photos`.
- Photo create uses returned `photo_ids`.
- Failed photo upload keeps local photo draft.
- Failed photo resource create keeps local photo draft.

Manual iPhone QA:

- Publish one review draft with no students selected.
- Publish one review draft with one selected student.
- Publish one review draft with multiple selected students.
- Publish one PYP draft with transdisciplinary theme tags.
- Publish one non-PYP draft with standards/syllabus/scope tags.
- Kill network during publish and confirm the draft remains.
- Publish a captured class photo with no assigned faces.
- Publish a captured class photo with one assigned face.
- Turn off network after photo upload and before resource create if possible; confirm the local draft remains.
- Reopen app after failed publish and confirm the draft is still present.
- Open Stream after publish and confirm the item appears in the selected class timeline.

## Risks

- The exact student id expected by `assigned_user_ids` must be confirmed against the API.
- Portfolio create response shape may differ from list timeline shape; support a lightweight `ResourceDetails` response fallback if needed.
- Existing `MBAPI` requestor has no decoded POST or multipart helper yet; adding these touches shared networking and needs tests.
- Standard source identities are strings today. Publishing requires numeric ids for ManageBac portfolio arrays.
- If the server applies class stream moderation, a successfully published item may appear as pending rather than immediately visible in Stream.
- Face photo drafts are currently in-memory only. Persisting them is required before photo Review/Publish is reliable across app restarts.
- Upload orphaning is possible if `/photos` succeeds and class resource creation fails.

## Acceptance Criteria

- The live app no longer uses `UnavailableObservationDraftPublisher`.
- Pressing Publish on a ready review item creates a ManageBac class stream note.
- Pressing Publish on a ready photo item uploads the photo and creates a ManageBac class stream photo resource.
- Published notes contain transcript text, selected students, and selected standard outcome ids.
- Published photos contain the captured image and selected student assignments.
- Successful publish removes the local draft.
- Failed publish keeps the local draft and displays a clear error.
- Class Stream can load and display the newly published item from the server.
