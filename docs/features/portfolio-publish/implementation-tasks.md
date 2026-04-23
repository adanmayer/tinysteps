# Portfolio Publish - Implementation Tasks

Role: Senior Mobile Developer, reviewed by Lead Engineer

Source plan: [implementation-plan.md](implementation-plan.md)

## Working Assumptions

- MVP publishes observation text as portfolio `note` resources and captured class photos as portfolio `photo` resources.
- MVP target is class stream: `/{role}/portfolio/classes/{classID}/resources/notes` and `/{role}/portfolio/classes/{classID}/resources/photos`.
- Photo publishing uploads image data to `/photos` first, then sends returned `photo_ids` to the photo resource endpoint.
- Review queue drafts remain local until server publish succeeds.
- Advisor uses the teacher URL segment through existing `MBAPIRole.urlPathComponent`.
- Selected standard tags are published from `ObservationStandardTagSuggestion.sourceIdentity`.
- Publishing failure never deletes a local draft.

## Delivery Slices

| Slice | Title | Owner |
|---|---|---|
| 1 | MBAPI create-resource and upload support | Senior mobile developer |
| 2 | Portfolio publish payload models | Senior mobile developer |
| 3 | Local review item model for notes and photos | Senior mobile developer |
| 4 | Standards/student mapping helpers | Senior mobile developer |
| 5 | Real review item publisher | Senior mobile developer |
| 6 | Review queue integration polish | Senior mobile developer |
| 7 | Tests and iPhone QA | Lead + QA |

## Task 1 - Add Decoded JSON POST Support To MBAPI

Files:

- `Packages/MBAPI/Sources/MBAPI/MBClient.swift`
- `Packages/MBAPI/Sources/MBAPI/Infrastructure/MBAPIRequestor.swift`
- `Packages/MBAPI/Sources/MBAPI/Infrastructure/MBAPIMockRequestor.swift`
- `Packages/MBAPI/Tests/MBAPITests/MBAPITests.swift`

Work:

- Add a requestor method for JSON body requests that decodes a response.
- Reuse authorization, accept/content-type headers, demo data capture/replay, and API issue logging patterns.
- Keep existing `send` for no-response operations.
- Add tests for success, non-2xx issue logging, and decode failure.

Acceptance:

- Shared networking can perform `POST` with an `Encodable` body and `Decodable` response.
- Existing GET/list behavior is unchanged.

## Task 2 - Add Multipart Photo Upload Support To MBAPI

Files:

- `Packages/MBAPI/Sources/MBAPI/MBClient.swift`
- `Packages/MBAPI/Sources/MBAPI/Infrastructure/MBAPIRequestor.swift`
- `Packages/MBAPI/Sources/MBAPI/Infrastructure/MBAPIMockRequestor.swift`
- `Packages/MBAPI/Tests/MBAPITests/MBAPITests.swift`

Work:

- Add a requestor method for multipart uploads that decodes a response.
- Use multipart field name `file`.
- Support JPEG upload with configurable filename and MIME type.
- Add `PortfolioUploadedPhoto` or equivalent MBAPI photo upload response model.
- Reuse authorization and API issue logging.

Acceptance:

- MBAPI can upload image data to `/photos`.
- Upload response exposes at least `id`, `url`, and `versions` when present.
- Upload failure logs an API issue and surfaces a typed error.

## Task 3 - Add Portfolio Create Endpoints

Files:

- `Packages/MBAPI/Sources/MBAPI/APIEndpoints/MBPortfolioEndpoint.swift`
- `Packages/MBAPI/Sources/MBAPI/MBClient.swift`
- `Packages/MBAPI/Tests/MBAPITests/MBAPITests.swift`

Work:

- Add `PortfolioResourceKind` with at least `.notes` and `.photos`.
- Add `createClassResource` or `createClassNote`.
- Add `createClassPhoto`.
- Build path with `context.role.urlPathComponent`.
- Use `portfolio/classes/{classID}/resources/notes`.
- Use `portfolio/classes/{classID}/resources/photos`.
- Decode either `Portfolio.TimelineItem` or a lightweight response model if the API returns resource details.

Acceptance:

- Teacher request path is `teacher/portfolio/classes/{classID}/resources/notes`.
- Advisor request path is also `teacher/portfolio/classes/{classID}/resources/notes`.
- Photo request path is `teacher/portfolio/classes/{classID}/resources/photos`.
- Endpoint tests assert URL and encoded body.

## Task 4 - Add Publish Payload Models

Files:

- `TinySteps/TinySteps/Features/ReviewQueue/PortfolioPublishPayload.swift`
- `TinySteps/TinySteps/Features/ReviewQueue/ObservationDraftPublisher.swift`

Work:

- Add `PortfolioNoteCreatePayload`.
- Add `PortfolioPhotoCreatePayload`.
- Add `PortfolioOutcomePayload`.
- Encode portfolio wire keys in snake case.
- Support nil versus empty arrays explicitly for PYP/non-PYP partitioning.
- Encode `start_date` as local `YYYY-MM-DD`.
- Encode `photo_ids` for photo publishing.

Acceptance:

- Payload JSON matches the portfolio porting guide.
- `body` is used for notes, not `description`.
- `photo_ids` is used for photos.
- Unit tests cover key encoding and nil field behavior.

## Task 5 - Add Local Review Item Support For Photos

Files:

- `TinySteps/TinySteps/Features/ReviewQueue/PortfolioReviewItem.swift`
- `TinySteps/TinySteps/Features/FaceCapture/FaceCaptureDraft.swift`
- `TinySteps/TinySteps/Features/FaceCapture/FaceCaptureDraftStore.swift`
- `TinySteps/TinySteps/Features/ReviewQueue/ObservationReviewQueueModel.swift`

Work:

- Add a review item abstraction or extend the Review queue model to load both observation drafts and photo drafts.
- Persist `FaceCaptureDraft` to disk instead of in-memory only.
- Add `loadDrafts(forClassID:)` and `deleteDraft(id:)` to `FaceCaptureDraftStore`.
- Ensure image data uses file protection and a retention policy comparable to observation drafts.
- Make Review filters return photo drafts for `.photo` and `.image`.

Acceptance:

- Captured photos survive app restart until published or deleted.
- Review queue can show note and photo items in one list.
- Photo publish can delete only the published local photo draft.

## Task 6 - Build Standards Outcome Mapper

Files:

- `TinySteps/TinySteps/Features/ReviewQueue/PortfolioOutcomePayloadBuilder.swift`

Work:

- Map `ObservationStandardTagSuggestion.sourceIdentity` into portfolio outcome arrays.
- Parse numeric ids safely.
- De-duplicate arrays in stable order.
- Apply PYP partitioning.
- Fail validation on `.unresolved` or non-numeric ids.

Acceptance:

- Standards, syllabus, scope sequence, and PYP theme selections map to the correct wire arrays.
- Invalid selections produce typed validation errors and do not publish.

## Task 7 - Resolve Student Assignment IDs

Files:

- `TinySteps/TinySteps/Features/ReviewQueue/PortfolioStudentAssignmentResolver.swift`
- `TinySteps/TinySteps/Features/Classes/Services/ClassesService.swift`

Work:

- Resolve `draft.matchedChildren.studentKey` against `ClassesService.loadClassStudents`.
- Resolve `FaceCaptureDraft.faces.studentKey` against `ClassesService.loadClassStudents`.
- Confirm by API test whether `assigned_user_ids` expects `MBMember.user.id` or `MBMember.studentID`.
- Keep this decision inside the resolver.
- Fail validation when a selected student is no longer present in the roster.

Acceptance:

- Publish payload contains stable backend ids for selected students.
- Missing students do not silently disappear from the published item.

## Task 8 - Implement Live Review Item Publisher

Files:

- `TinySteps/TinySteps/Features/ReviewQueue/ObservationDraftPublisher.swift`
- `TinySteps/TinySteps/Features/ReviewQueue/PortfolioReviewItemPublisher.swift`
- `TinySteps/TinySteps/App/Composition/FeatureServicesComposition.swift`
- `TinySteps/TinySteps/App/AppDependencies.swift`
- `TinySteps/TinySteps/Features/Portfolio/Services/PortfolioService.swift`

Work:

- Add `MBObservationDraftPublisher` or replace it with `MBPortfolioReviewItemPublisher`.
- Inject credentials-backed `PortfolioService` and `ClassesService`.
- Validate draft readiness and class id.
- For note items, build payload and call `portfolioService.createClassNote`.
- For photo items, upload image data with `portfolioService.uploadPhoto`, then call `portfolioService.createClassPhoto`.
- Return only after server success.
- Replace `UnavailableObservationDraftPublisher()` in live dependencies.

Acceptance:

- Review queue publish uses the real backend in live mode.
- Local draft deletion remains controlled by `ObservationReviewQueueModel` after publish returns.
- Photo upload failure and photo create failure both leave the local photo draft intact.

## Task 9 - Improve Review Queue Publish Feedback

Files:

- `TinySteps/TinySteps/Features/ReviewQueue/ObservationReviewQueueModel.swift`
- `TinySteps/TinySteps/Features/ReviewQueue/ObservationReviewQueueView.swift`

Work:

- Keep existing per-draft acting state.
- Show retryable publish error copy.
- Ensure bulk publish stops on first failure and reports count already published.
- Avoid deleting failed/unattempted drafts.
- Show photo-specific card preview and publish state for captured images.

Acceptance:

- Teacher can retry a failed publish without reopening the screen.
- Error copy makes it clear the item is still on this device.

## Task 10 - Add Tests

Files:

- `TinySteps/TinyStepsTests/...`
- `Packages/MBAPI/Tests/MBAPITests/MBAPITests.swift`

Work:

- Add payload builder tests.
- Add outcome mapper tests.
- Add student resolver tests with fake roster service.
- Add publisher tests with fake portfolio service.
- Add review queue model tests for delete-after-success and keep-on-failure.
- Add photo upload/create publisher tests.
- Add persisted photo draft store tests.

Acceptance:

- Tests cover the core failure paths, not only happy path.
- Build passes for iPhone simulator.

## Task 11 - iPhone QA Checklist

Work:

- Publish a plain transcript.
- Publish a transcript with one selected student.
- Publish a transcript with multiple selected students.
- Publish a PYP draft with theme tags.
- Publish a non-PYP draft with standard/syllabus/scope tags.
- Publish a captured photo with no assigned faces.
- Publish a captured photo with one assigned face.
- Publish a captured photo with multiple assigned faces.
- Turn off network during publish and verify the draft remains.
- Force a photo upload failure and verify the photo draft remains.
- Force a photo resource create failure after upload and verify the photo draft remains.
- Reopen the app after failed publish and verify the draft remains.
- Open class Stream and confirm the published item appears from the server.

Acceptance:

- QA signs off that iPhone publish does not lose local drafts on failure.
