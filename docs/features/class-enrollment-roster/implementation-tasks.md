# Class Enrollment Roster - Implementation Tasks

Role: Expert Mobile Developer, reviewed and amended by Mobile Lead

Source plan: `docs/features/class-enrollment-roster/implementation-plan.md`

## Working Assumptions

- Ship the roster against the currently selected class only. Do not merge "All Classes".
- Use `teacher/classes/{id}/members?role=students` through existing `MBClient.listClassMembers`.
- Face setup status is local-device-only and must never be added to API payloads, logs, analytics, CloudKit, or export.
- Treat unknown local face status as not ready. If the local store cannot be read, fail closed.
- Observation counts and "Not in today" are not blockers. Show `--` for missing counts and hide absent sections unless local presence data exists.
- T8 enrolment can be incomplete when the roster lands; the roster must still provide a placeholder route.

## Delivery Slices

1. **Foundation PR:** roster API service, local FaceID status protocol, app dependency wiring.
2. **Model PR:** roster model joins API students with local status and covers all product states.
3. **UI PR:** T6 visual implementation, tab shell wiring, search/filter basics, previews.
4. **Navigation and demo PR:** setup tap route, demo seeding, local refresh after enrolment.
5. **Verification PR or final pass:** tests, privacy checks, build and manual QA.

The slices are ordered so the Class tab can land before full face enrolment is complete.

## Task 0 - Confirm Defaults And Guardrails

**Owner:** Mobile developer

**Goal:** Record non-blocking product defaults before implementation starts.

**Work:**

- Confirm the six upfront questions from the plan are accepted as implementation defaults.
- Add a short comment or issue note that attendance API, historical counts, and server face status are explicitly out of scope.
- Identify whether the first implementation targets live API, demo replay, or both.

**Acceptance:**

- Engineering can start without waiting for product answers.
- No task depends on attendance API or server face status.

## Task 1 - Add Class Student Loading To ClassesService

**Owner:** Mobile developer

**Files:**

- `TinySteps/TinySteps/Features/Classes/Services/ClassesService.swift`
- `Packages/MBAPI/Sources/MBAPI/APIEndpoints/MBMembersEndpoint.swift` if any endpoint signature gaps are found
- `Packages/MBAPI/Tests/MBAPITests/MBAPITests.swift` or a focused endpoint test file

**Goal:** Expose current class students to the app feature layer using existing MBAPI capabilities.

**Work:**

- Extend `ClassesService` with:

```swift
func loadClassStudents(
    for session: AuthSession,
    classID: String
) async throws -> [MBMember]
```

- Implement it in `MBClassesService` by calling:

```swift
client.listClassMembers(
    in: credentials.sessionContext(childID: nil),
    classID: classID,
    roleFilter: "students"
)
```

- Keep this as a class-scoped method. Do not accept `.allClasses`.
- Add a small helper or test around the `role=students` query if not already covered.

**Acceptance:**

- A selected class ID can load student members.
- The implementation does not add a new network endpoint shape.
- No face setup state is added to `MBMember`.

## Task 2 - Add Local Face Enrollment Status Types

**Owner:** Mobile developer

**Files:**

- `TinySteps/TinySteps/Core/FaceID/Persistence/FaceEnrollmentStatus.swift`
- `TinySteps/TinySteps/Core/FaceID/Persistence/EnrolledIdentity.swift`
- `TinySteps/TinySteps/Core/FaceID/Persistence/FaceIDModelContainer.swift`

**Goal:** Create local-only status primitives for the roster.

**Work:**

- Adapt `EnrolledIdentity` from the experiment with fields:
  - `id`
  - `studentKey`
  - `displayName`
  - `embeddings`
  - `embeddingCount`
  - `elementType`
  - `vectorLength`
  - `modelIdentifier`
  - `isDisabled`
  - `correctionCount`
  - `updatedAt`
- Copy the six privacy invariants from the face-tagging requirement into `EnrolledIdentity` and `FaceIDModelContainer`.
- Add `FaceEnrollmentStatus`:

```swift
enum FaceEnrollmentStatus: Equatable, Sendable {
    case enrolled(photoCount: Int, updatedAt: Date)
    case needsSetup
    case invalid(reason: String)
    case disabled
    case unavailable
}
```

- Add validity logic in one place:
  - embeddings non-empty
  - `embeddingCount >= 3`
  - vector length matches active model config
  - model identifier matches active model config
  - not disabled

**Acceptance:**

- Status validity is testable without a SwiftUI view.
- Invalid and unavailable statuses cannot be accidentally treated as enrolled.
- `CustomStringConvertible` or debug output never includes embedding bytes.

## Task 3 - Implement FaceEnrollmentStore

**Owner:** Mobile developer

**Files:**

- `TinySteps/TinySteps/Core/FaceID/Persistence/FaceEnrollmentStore.swift`
- `TinySteps/TinySteps/App/Composition/FeatureServicesComposition.swift`
- `TinySteps/TinySteps/App/AppDependencies.swift`

**Goal:** Provide a batch local status lookup service for roster assembly.

**Work:**

- Define:

```swift
protocol FaceEnrollmentStore: Sendable {
    func statuses(for studentKeys: [String]) async throws -> [String: FaceEnrollmentStatus]
    func status(for studentKey: String) async throws -> FaceEnrollmentStatus
    func deleteEnrollment(for studentKey: String) async throws
}
```

- Implement a SwiftData-backed store using the separate FaceID `ModelContainer`.
- Add a preview/demo in-memory implementation if it reduces preview and test friction.
- Wire the store into `FeatureServicesComposition` and `AppDependencies`.
- Ensure store errors can be surfaced as `.unavailable` by the roster model.
- Do not make app startup depend on FaceID store creation succeeding. If the SwiftData container cannot be created, inject an unavailable store implementation and surface the local-status banner in the roster.

**Acceptance:**

- The roster can request statuses for a whole class in one call.
- Store creation explicitly uses `cloudKitDatabase: .none`.
- File protection is applied to the store and sidecars.
- A FaceID store initialization failure does not crash sign-in or the teacher home.

## Task 4 - Add ClassRoster Domain Values

**Owner:** Mobile developer

**Files:**

- `TinySteps/TinySteps/Features/ClassRoster/ClassRosterStudent.swift`
- `TinySteps/TinySteps/Features/ClassRoster/ClassRosterPresence.swift`
- `TinySteps/TinySteps/Features/ClassRoster/MBMember+ClassRoster.swift`

**Goal:** Convert API members and local state into stable UI-ready values.

**Work:**

- Add `ClassRosterStudent`:
  - stable `id`
  - `studentKey`
  - `displayName`
  - `firstName`
  - `initials`
  - `avatarURL`
  - `enrollmentStatus`
  - optional `todayObservationCount`
  - `presence`
- Add `ClassRosterPresence` with at least `.present` and `.notInToday`.
- Add a single `studentKey` mapping helper:
  - prefer `MBMember.studentID`
  - fallback to `MBMember.user.id`
- Add display helpers:
  - `needsFaceEnrollment`
  - `isFaceEnrolled`
  - `observationCountText`
  - accessibility summary copy

**Acceptance:**

- Name changes do not break local status joins.
- `0` counts render as `--`.
- `.unavailable`, `.invalid`, `.disabled`, and `.needsSetup` all render as setup/not-ready states.

## Task 5 - Build ClassRosterModel

**Owner:** Mobile developer

**Files:**

- `TinySteps/TinySteps/Features/ClassRoster/ClassRosterModel.swift`

**Goal:** Load and join class students with local face setup status.

**Work:**

- Implement `@Observable @MainActor final class ClassRosterModel`.
- Inputs:
  - `session`
  - selected `MBClass?`
  - selected `ClassContext`
  - `classesService`
  - `faceEnrollmentStore`
- State:
  - `students`
  - `searchText`
  - `isLoading`
  - `errorMessage`
  - `localStatusErrorMessage`
- Behavior:
  - `.allClasses` returns choose-class state without loading members.
  - `loadIfNeeded()` and `reload()`.
  - Class switch reloads via `.task(id: selectedClass?.id)`.
  - API roster error is separate from local FaceID error.
  - Local FaceID error shows roster but marks statuses unavailable.
- Derived values:
  - `filteredStudents`
  - `presentStudents`
  - `notInTodayStudents`
  - `awaitingFaceEnrollmentCount`
  - `headerMetaText`
  - `isSearchEmpty`

**Acceptance:**

- Switching classes never shows stale student status from the previous class.
- If FaceID status loading fails, no student is shown as enrolled.
- Search preserves enrolled/setup state.

## Task 6 - Add ClassRoster UI Components

**Owner:** Mobile developer

**Files:**

- `TinySteps/TinySteps/Features/ClassRoster/ClassRosterView.swift`
- `TinySteps/TinySteps/Features/ClassRoster/ClassRosterHeaderView.swift`
- `TinySteps/TinySteps/Features/ClassRoster/ClassRosterSearchBar.swift`
- `TinySteps/TinySteps/Features/ClassRoster/ClassRosterTileView.swift`
- `TinySteps/TinySteps/Features/ClassRoster/StudentAvatarView.swift`
- `TinySteps/TinySteps/Features/ClassRoster/TinyStepsRosterStyle.swift`

**Goal:** Implement the T6 visual surface with robust states.

**Work:**

- Build the warm cream page, ivory cards, sage/rose/honey status colors, and tile shadows from T6.
- Add header row:
  - class picker pill with sage dot and chevron
  - gear button placeholder
- Add title and meta:
  - `Class`
  - `{childCount} children - {missingCount} awaiting face enrolment`
- Add search/filter bar:
  - search field
  - filter icon
  - optional "Needs setup" filter if cheap
- Add `LazyVGrid` with three stable columns and fixed-format tiles.
- Add tile states:
  - enrolled
  - setup needed
  - status unavailable
  - not in today
- Add screen states:
  - choose class
  - loading
  - API error
  - local status banner
  - empty roster
  - search empty

**Acceptance:**

- The first viewport communicates selected class, total children, setup gap, and visible roster tiles.
- Tiles do not resize when count/status changes.
- No tile shows a numeric `0`.
- Missing setup is neutral and action-oriented, not alarming.

## Task 7 - Wire TeacherHomeView Three-Tab Shell

**Owner:** Mobile developer

**Files:**

- `TinySteps/TinySteps/Features/Home/TeacherHomeView.swift`
- `TinySteps/TinySteps/App/View/SignedInRootView.swift`

**Goal:** Put the roster into the teacher Class tab without duplicating class selection.

**Work:**

- Replace the placeholder teacher content with a three-tab shell:
  - Today placeholder or existing capture surface
  - Review placeholder
  - Class roster
- Reuse existing class switcher callbacks from `SignedInRootView`.
- Pass:
  - `session`
  - selected `MBClass?`
  - `classContext`
  - title/subtitle
  - class switcher affordance
  - `classesService`
  - `faceEnrollmentStore`
- Keep "All Classes" behavior as a choose-class state inside Class tab.

**Acceptance:**

- The class picker still uses existing `ClassSelectionStore` state.
- No second class selection source exists.
- The Class tab active state matches the bottom tab bar.

## Task 8 - Add Setup Navigation Hook

**Owner:** Mobile developer

**Files:**

- `TinySteps/TinySteps/Features/ClassRoster/ClassRosterView.swift`
- `TinySteps/TinySteps/Features/ClassRoster/ClassRosterStudentDetailView.swift`
- `TinySteps/TinySteps/Features/FaceID/Enrolment/FaceEnrolmentView.swift` if available

**Goal:** Make setup tiles actionable without blocking on full T8 completion.

**Work:**

- Add a route enum or selected student state for roster navigation.
- Tapping a setup tile opens:
  - `FaceEnrolmentView` when present, or
  - `ClassRosterStudentDetailView` placeholder with "Add photos so {name} gets tagged automatically."
- Tapping an enrolled tile opens the same detail shell with enrolment summary.
- Add a callback so successful enrolment triggers roster status reload.

**Acceptance:**

- A missing setup student has a one-tap path to the next action.
- The placeholder route can be replaced by T8 without changing roster tile code.

## Task 9 - Add Demo And Preview Data

**Owner:** Mobile developer

**Files:**

- `TinySteps/TinySteps/Features/ClassRoster/ClassRosterPreviewData.swift`
- `TinySteps/TinySteps/Features/Children/MBChild+Preview.swift` or a new roster preview file
- Demo replay snapshots if needed

**Goal:** Make T6 reviewable without depending on live API data.

**Work:**

- Add preview roster with 14 students and at least 3 setup-needed statuses.
- Include variety:
  - enrolled with count
  - enrolled with `--`
  - setup needed
  - status unavailable
  - not in today, if presence support is included
- Add `#Preview` cases for:
  - loaded roster
  - setup-only filter if implemented
  - choose class
  - API error
  - local status unavailable
  - search empty

**Acceptance:**

- UI can be reviewed from previews with no live credentials.
- Demo data matches the T6 story closely enough for stakeholder review.

## Task 10 - Add Xcode Project Membership

**Owner:** Mobile developer

**Files:**

- `TinySteps/TinySteps.xcodeproj/project.pbxproj`
- Any new Swift files added under `TinySteps/TinySteps/Core/FaceID/`
- Any new Swift files added under `TinySteps/TinySteps/Features/ClassRoster/`
- Any new test files

**Goal:** Ensure new files compile in the intended targets.

**Work:**

- Add all new app Swift files to the `TinySteps` target.
- Add all new test Swift files to the `TinyStepsTests` target.
- Add no FaceID persistence files to unintended extension/test targets unless needed.
- Confirm any future model resources are added to the correct app bundle target, not hidden in a folder Xcode will not copy.

**Acceptance:**

- A clean Xcode build can see every new app file.
- Tests compile without relying on files excluded from the test target.
- No accidental resource or source duplication is introduced.

## Task 11 - Add Unit Tests

**Owner:** Mobile developer

**Files:**

- `TinySteps/TinyStepsTests/FaceEnrollmentStatusTests.swift`
- `TinySteps/TinyStepsTests/ClassRosterModelTests.swift`
- `Packages/MBAPI/Tests/MBAPITests/MBMembersEndpointTests.swift` if needed

**Goal:** Cover the core logic that could create privacy or product regressions.

**Work:**

- Test status validity:
  - valid embeddings with enough photos
  - too few embeddings
  - empty embeddings
  - disabled
  - model mismatch
  - store unavailable
- Test roster model:
  - joins by `studentID`
  - falls back to `user.id`
  - computes missing setup count
  - filters names case-insensitively
  - does not load members for all-classes state
  - FaceID store error fails closed
- Test member endpoint query if coverage is missing:
  - `role=students`

**Acceptance:**

- Tests fail if unavailable/invalid local status is treated as enrolled.
- Tests fail if the roster tries to load a merged all-classes roster.

## Task 12 - Privacy And Export Guard Check

**Owner:** Mobile lead

**Goal:** Verify implementation matches the local-only promise.

**Work:**

- Search for accidental usage of:
  - `EnrolledIdentity` in Codable/export paths
  - raw `embeddings` in logs, descriptions, analytics, or request payloads
  - CloudKit-enabled configuration for FaceID models
- Confirm FaceID store uses file protection.
- Confirm no analytics/MetricKit/third-party calls were added around FaceID status.

**Acceptance:**

- The local face status cannot be serialized into API/export paths.
- Review can point to the privacy invariant comments in the relevant files.

## Task 13 - Manual QA And Build Verification

**Owner:** Mobile developer, reviewed by Mobile lead

**Goal:** Validate the feature in realistic app flows.

**Work:**

- Build the app with Xcode/xcodebuild.
- Run targeted tests.
- Manually verify:
  - selected class roster loads
  - class switching reloads the roster
  - all-classes state prompts class choice
  - search filters results
  - setup count matches visible setup students
  - local status failure fails closed
  - API roster failure does not imply face setup failure
  - no counts show `0`
  - bottom tab Class state is active
- Check iPhone portrait layout at 390x844 points and one smaller viewport.

**Acceptance:**

- The feature satisfies the plan definition of done.
- Known limitations are documented in the PR description.

## Optional Follow-Up Tasks

Only take these after the must-ship path is working.

1. **Needs setup filter**
   - Add a filter menu behind the filter icon.
   - First mode: all students vs needs setup.

2. **Local presence store**
   - Add local-only present/not-in-today state.
   - Keep everyone present by default.

3. **Local observation counts**
   - Read counts from the TinySteps local portfolio/draft store once available.
   - Continue showing `--` when data is absent.

4. **Gear route**
   - Replace placeholder with T11 settings when that screen exists.

5. **Refresh after T8**
   - When full enrolment saves embeddings, publish a completion event or callback that reloads roster status.

## Lead Review Amendments Integrated

The Mobile Lead reviewed the developer task list and amended it in five places:

- Split delivery into PR-sized slices so the roster can ship before full T8 enrolment.
- Added fail-closed behavior as a concrete task and test requirement.
- Required explicit all-classes behavior to avoid accidentally merging rosters.
- Kept attendance and historical count work optional to avoid blocking the core readiness value.
- Added explicit Xcode target membership work because new Swift files will not help if they are not compiled into the app and test targets.
- Added a privacy/export guard task owned by the lead, because the local-only promise is a release gate, not just an implementation detail.
