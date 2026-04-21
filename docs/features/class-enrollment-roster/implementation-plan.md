# Class Enrollment Roster - Implementation Plan

Role: Mobile Lead, with PM review integrated

## Upfront Questions

These are the only decisions I would confirm before implementation. The plan below includes a proposed default for each so engineering is not blocked.

1. **What is the source of "In today" vs "Not in today"?**
   - Proposed default: add a small local roster-state store and default every fetched class member to "in today" until attendance/check-in exists. Keep the UI sections, but hide "Not in today" when the absent set is empty. Do not call an attendance API for this feature unless we explicitly add one.

2. **What should observation counts represent on the roster tiles?**
   - Proposed default: show counts from the local TinySteps portfolio/draft store once that exists; otherwise show `--` rather than inventing counts or querying historical server data. Never show `0`, matching the visual spec.

3. **What does the gear icon route to?**
   - Proposed default: reserve the button for the future T11 settings screen and use a lightweight placeholder/settings sheet if T11 is not implemented yet.

4. **Is face enrolment scoped to a child across all classes, or to a child inside one class?**
   - Proposed default: enrolment is child-scoped and local-device-scoped, keyed by `studentID ?? user.id`. The current class only determines which roster members are displayed. This avoids duplicate enrolments if one child appears in more than one class.

5. **What should happen when the selected context is "All Classes"?**
   - Proposed default: the Class tab shows a "Choose a class" empty state with the class picker active. The roster must be class-scoped, so it should not merge students across classes.

6. **Should the roster distinguish "no local face data" from "not allowed to enrol yet"?**
   - Proposed default: no for this implementation. The roster is a capture-readiness view: enrolled means the required local face data exists on this device. Consent/permission gating belongs in the enrolment flow before saving embeddings, not as a second status on the overview tile.

## References Read

- `docs/features/class-enrollment-roster/T6-class-roster.txt`
- `docs/features/class-enrollment-roster/T6-class-roster.png`
- `docs/features/face-enrollment/T8-face-enrolment.txt`
- `docs/requirements/face-tagging.md`
- `/Users/dave/Development/swift/tinysteps/docs/experiments/experiment-02-on-device-face-id.md`
- `/Users/dave/Development/swift/tinysteps/Experiments/FaceTagging/FaceTagging/Persistence/EnrolledIdentity.swift`
- `/Users/dave/Development/swift/tinysteps/Experiments/FaceTagging/FaceTagging/Persistence/ModelContainer+FaceID.swift`
- `TinySteps/TinySteps/App/View/SignedInRootView.swift`
- `TinySteps/TinySteps/App/Model/SignedInSessionModel.swift`
- `TinySteps/TinySteps/Features/Home/TeacherHomeView.swift`
- `TinySteps/TinySteps/Features/Classes/Services/ClassesService.swift`
- `Packages/MBAPI/Sources/MBAPI/APIEndpoints/MBMembersEndpoint.swift`
- `Packages/MBAPI/Sources/MBAPI/Domain/Models/MBMember.swift`
- Reference app examples:
  - `/Users/dave/Development/swift/MobileManageBac/MobileManageBac/Features/Classes/Overview/ClassesOverviewModel.swift`
  - `/Users/dave/Development/swift/MobileManageBac/MobileManageBac/Features/Classes/Overview/ClassesOverviewView.swift`
  - `/Users/dave/Development/swift/MobileManageBac/MobileManageBac/Features/ParentAssociation/Overview/ParentAssociationOverviewModel.swift`
- Old app API reference:
  - `/Users/dave/Development/swift/managebac-mobile-native-ios-copy/Packages/MBAPI/Sources/MBAPI/APIEndpoints/MembersAPI.swift`
  - `/Users/dave/Development/swift/managebac-mobile-native-ios-copy/Packages/MBAPI/Sources/MBAPI/APIEndpoints/ClassesAPI.swift`

## Product Intent

Build the teacher-facing **Class** tab roster for the currently selected class. The screen answers one operational question: which students in this class already have enough local face-tagging data to be auto-tagged in Photo captures, and which students still need setup.

This is not a server-backed enrolment status. The API can provide the current class roster, but the face-tagging state must stay local on this device for security and GDPR posture. A student is considered enrolled only when the device has valid local face embeddings for that student.

## PM Product Frame

The PM framing is: **make capture readiness visible before the teacher needs it**. A teacher should be able to glance at the Class tab before taking photos and know which children will be auto-tagged, without thinking about APIs, model status, biometric data, or sync.

The roster should not feel like an admin database. It should feel like a calm class portrait with practical readiness signals. Missing face data is a setup task, not a warning or error.

### Primary Users

- **Nursery teacher before or during a session:** checks whether today's children are ready for Photo capture.
- **Teacher setting up the app:** works through students who still need local face data.
- **Teacher after a mismatch:** returns to a child profile to refresh face data, once the enrolment/detail flow supports that.

### User Stories

- As a teacher, I can see the students in my currently selected class without selecting from a fixed demo list.
- As a teacher, I can identify which students still need face setup at a glance.
- As a teacher, I can search for a child's name and preserve the same face-tagging status in the filtered result.
- As a teacher with multiple classes, I can switch class and see the roster/statuses for that class only.
- As a teacher, I can tap a student needing setup and start the enrolment flow or see a clear placeholder if the flow is not implemented yet.
- As a privacy-conscious setting, I can be confident that face readiness is computed only from local device data and is not sent to the API.

### Success Signals

No product telemetry should be added for the FaceID subsystem. Validate success through QA, demo rehearsal, and privacy review:

- A teacher can answer "who still needs setup?" in under 5 seconds on a 14-child class.
- A teacher can reach the enrolment flow from a missing-status tile in one tap.
- Switching classes never shows stale status from the previous class.
- The roster remains useful when observation counts and attendance are unavailable.
- Privacy review confirms no local face status or embedding data is exported, logged, synced, or added to API payloads.

## MVP Scope

### Must ship

- Current selected class roster loaded from class members.
- Local-only face enrolment status joined onto each roster member.
- Missing enrolment count in the header.
- Search by student name.
- Three-column tile grid matching T6 direction.
- Missing setup affordance on tiles.
- Empty, loading, error, search-empty, and all-classes states.
- Tap path from missing setup tile to enrolment or a clear placeholder.

### Should ship if nearby

- Local-only presence grouping for "In today" / "Not in today".
- Local observation counts from the in-memory or SwiftData TinySteps portfolio store.
- Filter control that can show "needs setup" only.
- Demo seeding for 14 children with 3 missing enrolments.

### Explicitly out of scope

- Server-backed face enrolment status.
- Uploading or syncing face readiness.
- Attendance API integration for "In today".
- Historical observation-count API integration.
- Progress bars, percentages, achievement badges, or warnings on roster tiles.
- Face matching or model inference inside the roster screen.
- Parent-facing copy or parent controls.

## Key Decisions

- Use the existing `ClassSelectionStore` and `SignedInSessionModel.selectedClassContext`; do not introduce a second class picker.
- Load roster members from the existing `MBMembersEndpoint` via `MBClient.listClassMembers(in:classID:roleFilter:)` with `roleFilter = "students"`.
- Keep face enrolment status out of `MBAPI`. Add a local app/Core FaceID store that reads SwiftData records from a separate, no-CloudKit model container.
- Treat the roster view model as the join point between API roster data and local device state.
- Key local enrolment by stable student identity, not display name. Prefer `MBMember.studentID`, fallback to `MBMember.user.id`.
- Use `displayName`/avatar from the class roster response at render time; keep only mirrored display fields in local face enrolment for audit/debug and offline resilience.
- Show "awaiting face enrolment" for students whose local status is not valid. "Valid" means non-empty embeddings, `embeddingCount >= 3`, vector length matches the active model/configuration, and the record is not disabled.
- Use teacher-facing language: "face setup", "teach TinySteps", and "setup", not "biometric", "identity", "training", or "surveillance".

## Data Model

Add a local FaceID persistence layer under `TinySteps/TinySteps/Core/FaceID/`:

```text
Core/FaceID/
|-- Persistence/
|   |-- EnrolledIdentity.swift
|   |-- FaceIDModelContainer.swift
|   |-- FaceEnrollmentStore.swift
|   `-- FaceEnrollmentStatus.swift
`-- Matching/
    `-- existing experiment ports as needed by enrolment/capture
```

`EnrolledIdentity` should adapt the experiment model, not redesign it:

```swift
@Model
final class EnrolledIdentity {
    var id: UUID
    var studentKey: String
    var displayName: String
    var embeddings: Data
    var embeddingCount: Int
    var elementType: Int
    var vectorLength: Int
    var modelIdentifier: String
    var isDisabled: Bool
    var correctionCount: Int
    var updatedAt: Date
}
```

Keep the six privacy invariants from `docs/requirements/face-tagging.md` as comment blocks on `EnrolledIdentity` and `FaceIDModelContainer`:

- embeddings are local `Data` only;
- SwiftData store uses `.completeUntilFirstUserAuthentication`;
- no CloudKit on the FaceID model container;
- no raw embedding logging;
- no analytics in the FaceID subsystem;
- enrolment photos stay in memory only.

`FaceEnrollmentStatus` should be a small value type used by UI/models:

```swift
enum FaceEnrollmentStatus: Equatable, Sendable {
    case enrolled(photoCount: Int, updatedAt: Date)
    case needsSetup
    case invalid(reason: String)
    case disabled
}
```

The roster tile should collapse `.needsSetup`, `.invalid`, and `.disabled` into the honey `?`/`Setup` treatment unless we intentionally expose repair copy on a child detail screen.

PM copy rule: the roster does not explain technical failure reasons. A detailed reason can appear in a child detail/enrolment repair screen, but the overview should keep one action-oriented state: `Setup`.

## API And Services

The current `MBAPI` package already has the class-members endpoint:

```swift
client.listClassMembers(in: context, classID: classID, roleFilter: "students")
```

Extend the app-level `ClassesService` rather than adding another network service:

```swift
protocol ClassesService {
    func loadClasses(...) async throws -> [MBClass]
    func loadClassTasks(...) async throws -> [MBClassTask]
    func loadClassUnits(...) async throws -> [MBClassUnit]
    func loadClassStudents(
        for session: AuthSession,
        classID: String
    ) async throws -> [MBMember]
}
```

Implementation detail:

- Build the `MBSessionContext` the same way existing class methods do, using `credentials.sessionContext(...)` in this codebase.
- Use `roleFilter: "students"`; this maps to the old app's `MembersAPI.FilterRole.students` and the endpoint shape `teacher/classes/{id}/members?role=students`.
- Do not add face status to `MBMember` or API response models.

Add a local-only face enrolment service:

```swift
protocol FaceEnrollmentStore: Sendable {
    func statuses(for studentKeys: [String]) async throws -> [String: FaceEnrollmentStatus]
    func status(for studentKey: String) async throws -> FaceEnrollmentStatus
    func deleteEnrollment(for studentKey: String) async throws
}
```

Wire `FaceEnrollmentStore` through `FeatureServicesComposition` and `AppDependencies`, following the reference app's protocol + concrete service pattern.

## Roster View Model

Add a new feature module:

```text
TinySteps/TinySteps/Features/ClassRoster/
|-- ClassRosterModel.swift
|-- ClassRosterStudent.swift
|-- ClassRosterView.swift
|-- ClassRosterTileView.swift
|-- ClassRosterHeaderView.swift
`-- ClassRosterLocalStateStore.swift
```

`ClassRosterModel` should be `@Observable @MainActor`, following `ClassesOverviewModel` and `ParentAssociationOverviewModel`:

- Inputs:
  - `session`
  - selected `MBClass?`
  - `classesService`
  - `faceEnrollmentStore`
  - optional local portfolio/roster-state stores when available
- Published state:
  - `students: [ClassRosterStudent]`
  - `searchText`
  - `isLoading`
  - `errorMessage`
- Lifecycle:
  - `loadIfNeeded()`
  - `reload()`
  - `.task(id: selectedClass?.id)` from the view to reload on class switches

`ClassRosterStudent` should be a UI-ready value:

```swift
struct ClassRosterStudent: Identifiable, Equatable, Sendable {
    var id: String
    var studentKey: String
    var displayName: String
    var firstName: String
    var initials: String
    var avatarURL: URL?
    var enrollmentStatus: FaceEnrollmentStatus
    var todayObservationCount: Int?
    var presence: ClassRosterPresence
}
```

Derived values:

- `isFaceEnrolled`: true only for `.enrolled`.
- `needsFaceEnrollment`: true for all non-enrolled states.
- `observationCountText`: count if present and non-zero, otherwise `--`.
- `displaySections`: present students first, absent students second; hide absent section if empty.
- `awaitingFaceEnrollmentCount`: non-enrolled students in the selected class.

## Product States

Treat the whole screen and each student tile as separate state machines. This prevents half-loaded combinations from producing confusing copy.

### Screen states

| State | UI treatment |
|---|---|
| No selected class / all classes | Warm empty state: "Choose a class to see face setup." Keep the class picker active. |
| Loading roster | Full-screen progress on first load; keep existing content on refresh if already loaded. |
| Roster API error | ContentUnavailableView-style message: "Unable to load this class." Do not imply face data failed. |
| Local FaceID store error | Show roster, mark statuses as unavailable, and include a small non-alarming banner. Do not show students as enrolled if the local status cannot be read. |
| Empty roster | "No children in this class yet." No setup counts. |
| Search empty | "No matching children." Preserve search field and class header. |
| Loaded roster | Header + search/filter + grouped grid. |

### Tile states

| State | Meaning | Tile treatment |
|---|---|---|
| Enrolled | Valid local embeddings exist on this device | Normal avatar, no honey `?`, count or `--`, sage dot when present. |
| Needs setup | No local record or too few embeddings | Honey `?`, `Setup` meta, tappable. |
| Needs refresh | Record invalid for active model, disabled, or stale after future correction logic | Same as setup in MVP; detail screen can explain. |
| Status unavailable | FaceID store could not be read | Conservative setup treatment plus screen-level note. |
| Not in today | Local presence says absent | Desaturated tile, `--`, rose dot. |

Important PM constraint: unknown local status is not success. If the local FaceID store cannot be read, fail closed and do not mark anyone enrolled.

## UI Plan

Replace the teacher placeholder with a three-tab teacher shell when this feature is implemented:

```text
TeacherHomeView
`-- TabView
    |-- Today placeholder/capture surface
    |-- Review placeholder
    `-- ClassRosterView
```

The Class tab must follow `T6-class-roster.txt`:

- page background `#FBF6EE`;
- warm ivory tiles `#FFFDF8`;
- top class picker pill with sage dot and chevron;
- gear button on the right;
- title "Class";
- meta line like `14 children - 3 awaiting face enrolment`;
- search/filter bar;
- `LazyVGrid` with three fixed columns and stable tile dimensions;
- student avatar, name, observation count row, present/absent dot;
- honey `?` overlay for missing enrolment;
- absent/not-in-today tile desaturation when presence data exists;
- bottom tab bar with Class active.

Tile rules:

- Enrolled student: avatar, name, observation count or `--`, sage status dot.
- Missing/invalid/disabled enrolment: warm placeholder if no avatar, name, `Setup`, honey `?` overlay.
- Absent: desaturate avatar/tile content, show `--`, use dusty rose dot.
- Do not show percentages, progress bars, achievement badges, or numeric `0`.
- If the filter icon is implemented, its first useful mode is "Needs setup"; defer richer filters until there are real additional dimensions.
- The section headers are present only when they communicate real state. If everyone defaults to present, show "In today" and hide "Not in today".

Use `AsyncImage` for remote avatars initially. If a shared image loader exists later, swap it behind a small `StudentAvatarView` without changing the roster model.

Copy:

- Header meta: `{childCount} children - {missingCount} awaiting face enrolment`.
- Search placeholder: `Search names`.
- Missing tile meta: `Setup`.
- All-classes empty title: `Choose a class`.
- All-classes empty description: `Face setup is tracked per class on this device.`
- Local status error banner: `Face setup status is unavailable on this device right now.`

Accessibility:

- Tile label: `Amara, face tagging enrolled, 28 observations, present today`.
- Missing setup: `Idris, face tagging needs setup`.
- Class picker remains a button only when more than one class exists.
- Search field has label `Search names`.

## Navigation

Initial implementation:

- Tapping a student with missing enrolment opens `FaceEnrolmentView` for that student if the T8 flow is in place.
- If T8 is not implemented yet, open a simple child detail placeholder with the same copy target: "Add photos so Amara gets tagged automatically."
- Tapping an enrolled student opens the same child detail shell, showing enrolment summary and future actions.
- Gear opens a settings placeholder until T11 exists.

Do not make the roster responsible for running the face pipeline. It only reads local status and navigates to the enrolment flow.

## Dependencies And Sequencing

PM recommendation: split implementation so the roster can land before the full T8 enrolment flow.

1. **Roster foundation:** API class members, local status store protocol, model join, UI states.
2. **Visual parity:** T6 layout, tile states, search, class picker integration.
3. **Navigation hook:** tapping setup opens either T8 or a placeholder child setup view.
4. **Live enrolment integration:** T8 writes local status and the roster refreshes.
5. **Presence/count polish:** add local presence and local observation counts only when their source is real.

This keeps the core product value testable even if face capture/enrolment arrives one PR later.

## Integration Steps

1. **Add roster API service method**
   - Extend `ClassesService` and `MBClassesService` with `loadClassStudents`.
   - Add mock/demo support through the existing `MBMockClient` path.

2. **Add local FaceID persistence**
   - Port/adapt `EnrolledIdentity` and `FaceIDModelContainer` from the experiment.
   - Add `FaceEnrollmentStore` implementation.
   - Wire it through `FeatureServicesComposition` and `AppDependencies`.

3. **Build roster model**
   - Add `ClassRosterModel` and `ClassRosterStudent`.
   - Join `MBMember` roster rows with local `FaceEnrollmentStatus`.
   - Implement search, counts, grouping, and all-classes empty state.

4. **Build the UI**
   - Add `ClassRosterView`, header/search/grid/tile subviews.
   - Match the visual tokens from T6.
   - Keep fixed tile dimensions and 3-column grid behavior for iPhone portrait.
   - Add explicit all-classes, empty roster, search-empty, local-status-error, and API-error states.

5. **Wire teacher shell**
   - Replace `TeacherHomeView` placeholder with the three-tab shell.
   - Reuse the existing class switcher sheet from `SignedInRootView`.
   - Pass the selected class and services down; do not create new global state.

6. **Connect enrolment navigation**
   - Route missing enrolment tiles to T8 when available.
   - Ensure successful enrolment invalidates/reloads the roster status.
   - Keep a placeholder route available so the roster can merge before T8 is complete.

7. **Add demo data**
   - Add class-member replay snapshots or mock data that includes 14 students with avatars where possible.
   - Seed local FaceID status in demo mode for a mix of enrolled and missing setup states.

8. **Verify**
   - Build the app.
   - Run unit tests for local status validity and roster assembly.
   - Manually test switching classes, search, no selected class, empty roster, no local enrolments, and mixed enrolment states.

## Tests

Add focused tests, not snapshot tests:

- `FaceEnrollmentStatusTests`
  - valid when embeddings exist, `embeddingCount >= 3`, vector length matches.
  - invalid/needs setup when embeddings are empty, count too low, disabled, or model identifier mismatches.

- `ClassRosterModelTests`
  - joins API students to local enrolment statuses by `studentID ?? user.id`.
  - computes `awaitingFaceEnrollmentCount`.
  - filters by display name and initials.
  - displays `--` for nil/zero counts.
  - returns all-classes empty state without loading members.

- `MBMembersEndpointTests` if not already covered
  - `role=students` query is sent for class members.

Manual acceptance:

- With the selected class containing 14 students and 3 missing local enrolments, the header says `14 children - 3 awaiting face enrolment`.
- Search narrows the grid without losing local status.
- Switching classes reloads roster members and local statuses.
- All-classes context shows a choose-class state, not a merged roster.
- If the local FaceID store fails, no student is shown as enrolled.
- If class-member API load fails, the error copy names the class load, not face setup.
- Airplane mode still shows existing local enrolment statuses if roster data is already cached/demo replay is used; otherwise only the API roster load fails, not the FaceID store.
- No embedding data appears in logs or any export path.

## PM Acceptance Checklist

- The first viewport communicates class, total children, and setup gap without scrolling.
- The primary action for a missing student is obvious from the tile.
- The UI does not shame the teacher or imply failure; setup is neutral.
- The teacher can still use the screen when counts or attendance are absent.
- The feature does not create a second source of truth for class selection.
- The implementation does not create a new API contract for face enrolment status.
- Privacy language and technical behavior match: local-only means local-only.

## Risks And Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| API roster response lacks `student_id` for some users | Local status join can fail | Fallback to `user.id`; keep this logic in one `studentKey` helper. |
| "In today" has no authoritative source | UI sections could mislead | Use local presence state only; default everyone present; hide absent section when empty. |
| Observation counts are not available yet | Tile could imply fake data | Show `--` until local portfolio/draft counts exist. |
| Enrolment keyed by name | Name changes break status | Key by stable student/user ID, mirror name only for display/debug. |
| Local FaceID store unavailable | False sense of readiness | Fail closed: show setup/unavailable, never enrolled. |
| PM scope creep into attendance/settings | Slips face readiness value | Ship roster/status/search first; defer attendance API, T11, and rich filters. |
| FaceID store accidentally syncs | Privacy breach | Separate SwiftData container, `cloudKitDatabase: .none`, file protection test/review gate. |
| Roster reload blocks UI | Janky tab switch | Load with async `.task(id:)`, show progress/empty states, keep local status fetch batched. |
| Large grids re-render too often | Scrolling stutter | Use value rows with stable IDs, small tile subviews, and `LazyVGrid`. |

## Definition Of Done

- The Class tab renders the current selected class roster, not fixed sample students.
- The header, search bar, tile grid, missing-enrolment overlays, and bottom Class tab match the T6 visual direction.
- Enrolment status is read from local device storage only.
- A student is marked enrolled only when local face embeddings are valid for the active face model.
- Missing enrolment count updates after local enrolment changes.
- The screen behaves correctly for no selected class, empty roster, loading, error, and search-empty states.
- The implementation follows the existing reference app structure: service protocol + concrete service, `@Observable` view model, SwiftUI view with injected dependencies, and composition through `FeatureServicesComposition`.
- Product copy stays teacher-facing and avoids biometric/surveillance language on the overview.
- Scope is preserved: no server face status, no attendance API dependency, and no fake counts.
