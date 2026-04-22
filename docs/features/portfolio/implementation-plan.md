# Portfolio Timeline - Implementation Plan

Role: Lead Engineer and PM, integrated by orchestrator

## Upfront Questions

These are the decisions I would confirm before implementation. The plan includes proposed defaults so engineering can start without waiting.

1. **Should the teacher Stream show only today or the whole class portfolio?**
   - Decision: rename the teacher `Today` tab to `Stream` and add a top range filter with `Today` and `All`. `Today` shows entries from the selected class for the device-local current day, newest first. `All` shows the selected class portfolio timeline beyond today, newest first. The parent Journal uses the same range filter where helpful, defaulting to `All`.

2. **What is the source of student attribution for filtering?**
   - Proposed default: use explicit attributed child/student identifiers from the portfolio timeline response or TinySteps portfolio entry model. Do not filter by scanning text, labels, or display names. If the current ManageBac timeline response does not expose child attribution, extend `MBAPI.Portfolio.TimelineItem` before shipping the student filter.

3. **Can the portfolio endpoint filter by student server-side?**
   - Proposed default: load the selected class timeline and filter client-side when attribution IDs are present. If the server supports a confirmed `student_id` or `child_id` query parameter, use it for selected-student refreshes but keep local filtering for already loaded pages.

4. **How should parent class selection work?**
   - Proposed default: parents get a class selector only for classes visible to their selected child context. Load parent-visible classes with `ClassesService.loadClasses(for:childContext:)` if the endpoint supports the parent role. If the endpoint is unavailable, show an `All` class scope and keep the child journal usable.

5. **Should cards include actions?**
   - Proposed default: no actions in this surface. Cards are read-only. Tap can open a detail view when one exists, but there are no Publish, Save, Delete, Like, Comment, or Edit controls in this milestone.

6. **Should unpublished local drafts appear in Stream?**
   - Proposed default: no. Stream shows published/filed portfolio entries. Local saved-for-review drafts stay in Review. Local in-progress capture drafts stay in the capture/review flow until published.

## References Read

- `docs/features/review-queue/t04-review-queue.txt`
- `docs/features/review-queue/t04-review-queue.png`
- `docs/requirements/app-feature-spec.md`
- `docs/workflows/feature-planning-orchestration.md`
- `TinySteps/TinySteps/Features/Portfolio/Services/PortfolioService.swift`
- `Packages/MBAPI/Sources/MBAPI/APIEndpoints/MBPortfolioEndpoint.swift`
- `Packages/MBAPI/Sources/MBAPI/Domain/Models/Portfolio/Portfolio.swift`
- `Packages/MBAPI/Sources/MBAPI/Domain/Models/Portfolio/Timeline/PortfolioTimelineItem.swift`
- `TinySteps/TinySteps/Features/Home/TeacherHomeView.swift`
- `TinySteps/TinySteps/Features/Home/ParentHomeView.swift`
- `TinySteps/TinySteps/App/Model/SignedInSessionModel.swift`
- `TinySteps/TinySteps/App/Composition/FeatureServicesComposition.swift`
- `TinySteps/TinySteps/Features/Classes/Services/ClassesService.swift`

## Product Intent

Build a read-only class portfolio timeline that makes captured learning moments visible outside the end-of-day Review queue.

For teachers, this replaces the placeholder Today tab with `Stream`: the selected class portfolio, a `Today`/`All` range filter, and a student filter. The screen answers "what has already been captured for this class?" without turning into a task manager.

For parents, the same card language becomes the child journal. Parents can read the entries shared with their child, filtered by class where available and by their own children when multiple children are paired.

## PM Product Frame

The portfolio is a quiet reading surface. Review is where teachers make decisions; Portfolio is where teachers and parents see the story that already exists.

The UI should borrow the Review screen's calm reading-list feel: warm cream background, ivory cards, soft shadows, type icons, chips, and child avatars. It should remove the task-oriented pieces: no left ready/draft semantics, no publish/delete/save actions, no sticky CTA, and no unpublished count badge.

### Primary Users

- **Teacher during the day:** checks what has already been filed for the selected class.
- **Teacher at handoff:** quickly filters to one child and scans today's moments or the full class stream.
- **Parent:** reads a child's journal entries in a warm, non-dashboard surface.
- **Parent with multiple children:** uses the avatar row to switch between all paired children and one child.

### User Stories

- As a teacher, I can open Stream and see the selected class portfolio entries without going through Review.
- As a teacher, I can switch the Stream between `Today` and `All`.
- As a teacher with multiple classes, I can use the same top class picker pattern as Review to switch the portfolio scope.
- As a teacher, I can tap `All` or a student avatar to filter entries by attributed child.
- As a parent, I can see the journal entries available for my child in the same visual language as the teacher portfolio.
- As a parent with more than one paired child, I can filter with `All` or one child avatar.
- As a parent, I never see students who are not my own children.

### Success Signals

- Teacher can switch from Review to Stream and recognize the same card language immediately.
- Teacher can filter a class of 14 students to one child with one tap.
- Parent can read the first entry without encountering teacher-only terms such as draft, publish, queue, or review.
- Empty, loading, and error states feel intentional rather than like missing data.
- No unconfirmed student attribution is shown or used for filtering.

## MVP Scope

### Must Ship

- Shared portfolio timeline feature module under `TinySteps/TinySteps/Features/Portfolio/`.
- `PortfolioTimelineModel` that loads entries through the existing `PortfolioService`.
- UI-ready normalized `PortfolioEntry` model for card rendering.
- Teacher Stream integration replacing the placeholder `todayTab`.
- Top `Today`/`All` range filter for Stream.
- Parent Home/Journal integration using the same entry cards.
- Top class selector for teacher and parent contexts where class options exist.
- Horizontal student avatar filter with an `All` option.
- Read-only portfolio cards with type icon, timestamp, body/description, media preview when available, tag chips, and attributed child avatars.
- Loading, empty, filtered-empty, no-class, and error states.
- Unit tests for normalization, student filtering, and role-specific visibility.

### Should Ship If Nearby

- Pull-to-refresh for the timeline.
- Pagination support if `MBPortfolioEndpoint` response metadata becomes available.
- Lightweight detail sheet for tapping an entry.
- Reuse card subcomponents from Review if it can be done without coupling review actions to read-only cards.

### Explicitly Out Of Scope

- Publish, Save, Delete, Edit, Like, Comment, Export, or other card actions.
- Showing unpublished local drafts in Portfolio.
- Creating portfolio entries from this plan.
- Parent access to teacher-only roster, face enrolment, or local draft state.
- Fake student filtering based on text, labels, author names, or card titles.
- Analytics or engagement nudges.

## Key Decisions

- Build a shared portfolio surface, not separate teacher and parent card implementations.
- Keep role differences in configuration and copy, not in duplicated views.
- Reuse `PortfolioService.loadPortfolioTimeline(for:childContext:classID:query:)`.
- Use `ClassesService.loadClassStudents(for:classID:)` for the teacher avatar filter.
- Use `ChildrenService`/`SignedInSessionModel.availableChildren` for the parent avatar filter. Parents must only see their own children.
- Add parent class options only from role-appropriate class data. Do not expose all teacher classes to parents.
- Treat the class selector as the top scope and the student avatar row as the second scope.
- Cards are newest-first.
- Teacher Stream has a top range filter: `Today` applies a current-day query or client-side date filter, and `All` shows all loaded entries. Parent Journal may use the same filter but defaults to `All`.
- Existing Review visuals are the source for color, spacing, typography, chip shape, and card rhythm.

## Data Model

Add UI models close to the new Portfolio feature module rather than rendering raw `MBAPI` models directly.

```swift
enum PortfolioTimelineRole: Equatable, Sendable {
    case teacherStream
    case parentJournal
}

enum PortfolioRangeFilter: String, CaseIterable, Identifiable, Sendable {
    case today = "Today"
    case all = "All"

    var id: String { rawValue }
}

enum PortfolioEntryKind: String, CaseIterable, Sendable {
    case note
    case photo
    case image
    case video
    case file
    case website
    case reflection
    case event
    case unknown
}

struct PortfolioEntry: Identifiable, Equatable, Sendable {
    let id: String
    let kind: PortfolioEntryKind
    let title: String?
    let bodyText: String?
    let createdAt: Date?
    let media: PortfolioEntryMedia?
    let tags: [String]
    let attributedStudents: [PortfolioStudent]
    let sourceStatus: String?
}

struct PortfolioStudent: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let avatarURL: URL?
}
```

`PortfolioEntryMedia` should normalize the preview surface:

- `photo(url:thumbnailURL:altText:)`
- `video(thumbnailURL:duration:)`
- `file(title:subtitle:thumbnailURL:)`
- `website(url:title:faviconURL:)`
- `none`

The normalizer maps `MBAPI.Portfolio.TimelineItem` into `PortfolioEntry`:

- `logable.kind == "note"` maps to `.note` and body comes from `logable.body`.
- Photo items use `logable.photos.first` and prefer `versions.thumb`, then `versions.square`, then `url`.
- File items use `logable.assets`.
- Website/video items use `logable.urls` until the API exposes richer preview metadata.
- Tags come from `TimelineItem.labels` and `logable.labels`, de-duplicated in display order.
- `createdAt` uses `TimelineItem.createdDate`.
- Student attribution must come from explicit API fields added to `TimelineItem` or a local TinySteps portfolio model, not from labels.

## API And Services

The current endpoint already supports class-scoped portfolio timeline reads:

```swift
client.listPortfolioTimeline(
    in: context,
    classID: classID,
    query: query
)
```

The app service already wraps it:

```swift
protocol PortfolioService {
    func loadPortfolioTimeline(
        for session: AuthSession,
        childContext: ChildContext,
        classID: String?,
        query: [String: String]
    ) async throws -> [MBAPI.Portfolio.TimelineItem]
}
```

Required additions:

- Confirm and document query parameters for date range, page size, pagination, and student/child filter if available.
- Extend `MBAPI.Portfolio.TimelineItem` with explicit attributed children/students if the endpoint returns them but the model does not currently decode them.
- Add a small `PortfolioTimelineLoadingService` only if the view model needs role-specific query construction, pagination merging, or parent class resolution beyond what `PortfolioService` should own.
- Keep `PortfolioService` network-focused. Keep UI normalization in the Portfolio feature module unless multiple features need the same normalized model.

Teacher query default:

```text
classID = selectedClass.id
childContext = .allChildren
query = date range for local current day, newest first, page size if supported
```

Parent query default:

```text
classID = selected parent-visible class ID, or nil for All classes
childContext = selected child context
query = newest first, page size if supported
```

Do not introduce create/update/delete API calls for this feature.

## View Model / State Model

Add:

```text
TinySteps/TinySteps/Features/Portfolio/
|-- PortfolioTimelineModel.swift
|-- PortfolioEntry.swift
|-- PortfolioEntryNormalizer.swift
|-- PortfolioTimelineView.swift
|-- PortfolioEntryCard.swift
|-- PortfolioStudentFilterStrip.swift
|-- PortfolioClassScope.swift
`-- Services/
    `-- PortfolioService.swift
```

`PortfolioTimelineModel` should be `@Observable @MainActor`, matching current view model style.

Inputs:

- `session`
- `role: PortfolioTimelineRole`
- `portfolioService`
- `classesService`
- teacher: `classContext`, `selectedClass`, `onShowClassSwitcher`
- parent: `childContext`, `availableChildren`, optional parent class options

State:

- `entries: [PortfolioEntry]`
- `students: [PortfolioStudent]`
- `selectedRange: PortfolioRangeFilter`
- `selectedStudentID: PortfolioStudent.ID?` where `nil` means `All`
- `classScopes: [PortfolioClassScope]`
- `selectedClassID: String?` where `nil` means `All`
- `isLoading`
- `isRefreshing`
- `errorMessage`
- `hasLoaded`

Derived state:

- `filteredEntries`
- `rangeFilteredEntries`
- `visibleStudentFilters`
- `emptyTitle`
- `emptyDescription`
- `headerTitle`
- `headerSubtitle`

Lifecycle:

- `loadIfNeeded()`
- `reload()`
- `selectStudent(_:)`
- `selectClass(_:)`
- `refresh()`

Filtering rules:

- `All` student filter shows all loaded entries for the current class scope.
- Selected student shows entries whose attributed student IDs include that student.
- `Today` range filter includes only entries whose `createdAt` falls in the user's local current day.
- `All` range filter includes all loaded entries in the current class scope.
- Parent `All` shows only the parent's paired children, never classmates.
- If attribution is missing for an entry, show it under `All` only and do not include it in a selected-student result.

## Product States

- `noClass`: teacher or parent class selector has no concrete class and the product requires one. Show a calm choose-class state with the selector active.
- `loading`: show skeleton cards with the same card geometry as loaded entries.
- `loaded`: show the card feed.
- `emptyTeacherStreamToday`: "Nothing captured yet today. Press and hold to record what you saw."
- `emptyTeacherStreamAll`: "No moments in this stream yet."
- `emptyParentJournal`: "`<Child>`'s journey starts here. Their teacher will share the first moment soon."
- `filteredEmpty`: "No moments for `<student>` yet."
- `error`: show a non-blocking banner and a retry action. Existing loaded cards remain visible during refresh failures.
- `partialAttribution`: if some entries lack attribution, keep them visible in `All` and avoid claiming they belong to a specific child.

## UI Plan

### Shared Visual Direction

Follow the Review screen where surfaces are similar:

- Background: warm cream `#FBF6EE`.
- Top selector pill: ivory `#FFFDF8`, warm shadow, chevron.
- Cards: ivory `#FFFDF8`, warm shadow, hairline border, generous padding.
- Chips: sage tint and sage border for learning tags.
- Icons: small SF Symbol/Lucide-equivalent type icon in a pale circular well.
- Avatar row: 32 pt circles, horizontal, overlapping only within cards.
- Typography: same weight and scale family as Review. Use existing app typography helpers if available.

### Teacher Stream Layout

1. Safe area.
2. Header with class picker pill on the left and a quiet count on the right: "`3 today`" or "`18 moments`" depending on the selected range.
3. Title row: `Stream`; subtitle: formatted date for `Today`, or selected class name for `All`.
4. Top range filter:
   - Segmented control with `Today` and `All`.
   - `Today` is selected by default for teachers.
   - Selected segment uses sage fill/border consistent with Review filter chips.
5. Student filter strip:
   - First chip is `All`.
   - Then horizontally scrolling student avatars.
   - Selected state uses sage ring and sage label.
   - Unselected state uses ivory/pale sand with warm border.
6. Portfolio card feed:
   - Compact enough for Stream, but same card family as Review.
   - No actions row.
   - No left ready/draft accent bar unless the entry type needs a subtle type accent. Default is no bar.
7. Existing tab bar remains native `TabView`.

### Parent Journal Layout

1. Safe area.
2. Header with child/class selector appropriate to available context:
   - If multiple children: `All children`/child selector.
   - If class options exist: class selector pill below or alongside the child scope without crowding.
3. Title row: "`<Child>`'s journal" for one child, `Journal` for all children.
4. Student filter strip:
   - `All` plus only the parent's paired children.
   - If one child only, show the child avatar as selected or omit the strip if it would add noise. Proposed default: keep the strip only when there are multiple children.
5. Same read-only cards, with warmer parent-facing copy.

### Portfolio Card Anatomy

Top to bottom:

- Header row: type icon, attributed child or entry title, relative timestamp.
- Optional media preview:
  - Photo/image: rounded 16:9 thumbnail.
  - Video: thumbnail with play glyph.
  - File: document row with filename.
  - Website: URL preview row.
- Body text: teacher-authored description/body, up to 5 lines in teacher Stream and more in parent Journal if space allows.
- Chip grid: labels/PYP tags if present.
- Avatar row: attributed children.

No card actions. Tapping a card may open read-only detail only if the detail screen is available in the same milestone.

## Navigation

Teacher:

- Rename the first teacher tab from `Today` to `Stream`.
- Replace `TeacherHomeView.todayTab` placeholder with `PortfolioTimelineView(role: .teacherStream, ...)`.
- Preserve the selected tab when class changes.
- Continue to pass `onShowClassSwitcher` into the top selector.
- Keep Review badge behavior unchanged.

Parent:

- Replace the placeholder content in `ParentHomeView` with `PortfolioTimelineView(role: .parentJournal, ...)`.
- Keep attendance excusal reachable only if still product-required. If it remains, put it behind a secondary affordance or an `About`/utility area rather than above the journal.
- Use `selectedChildContext`, `selectedContextTitle`, and `onShowChildSwitcher` for parent scope.
- Add `portfolioService`, `classesService`, and available child context into `ParentHomeView` dependencies as needed.

## Dependencies And Sequencing

1. Confirm portfolio timeline response contains attributed children/students or add decoding for existing payload fields.
2. Add normalized portfolio entry models and tests.
3. Add `PortfolioTimelineModel` with loading and filtering tests.
4. Add shared read-only card views and preview data.
5. Integrate teacher Stream.
6. Integrate parent Journal.
7. Add parent-visible class selector only after the role-appropriate class list path is confirmed.
8. Run unit tests, build, and simulator visual QA for teacher and parent roles.

## Integration Steps

1. Extend `Portfolio.TimelineItem` if needed for attribution fields.
2. Add `PortfolioEntryNormalizer` and fixtures for note/photo/file/website cards.
3. Add `PortfolioTimelineModel`.
4. Add `PortfolioTimelineView`, `PortfolioEntryCard`, and `PortfolioStudentFilterStrip`.
5. Update `TeacherHomeView` to use `PortfolioTimelineView` in the renamed Stream tab.
6. Update `ParentHomeView` to use `PortfolioTimelineView`.
7. Pass `portfolioService` and any needed class/child lists through `SignedInRootView`.
8. Add tests under `TinySteps/TinyStepsTests/PortfolioTimelineModelTests.swift` and `PortfolioEntryNormalizerTests.swift`.
9. Add previews for teacher one-class, teacher multi-class, parent one-child, and parent multi-child states.

## Tests

Unit tests:

- Normalizes note body from `logable.body`.
- Normalizes photo thumbnail preference from `versions.thumb`, `versions.square`, then `url`.
- De-duplicates tags from timeline and logable labels.
- Parses created dates and sorts newest-first.
- Filters by selected student ID using explicit attribution.
- Keeps unattributed entries visible only in `All`.
- Parent model never exposes non-paired children in the avatar strip.
- Teacher model reloads when selected class changes.
- Error during refresh keeps existing entries visible.

SwiftUI/UI tests or screenshot checks:

- Teacher Stream shows class selector, range filter, student `All`, avatars, and read-only cards.
- Parent Journal shows only parent-visible children.
- Empty teacher Stream `Today` state matches required copy.
- Filtered-empty state is readable on small iPhone width.
- Long child names and long class names do not overflow selector pills or avatar labels.

## Manual Acceptance

- On a teacher account with a selected class, Stream shows portfolio cards for that class.
- Switching `Today`/`All` changes whether the current day filter is applied.
- Switching class changes the entries and student avatar row.
- `All` shows all loaded entries.
- Tapping a student avatar filters to entries attributed to that student.
- Cards do not show Publish, Save, Delete, or any Review-only controls.
- On a parent account, the Journal/Portfolio surface uses the same cards but only shows children associated with that parent.
- Parent cannot see classmates in the avatar filter or card attribution.
- Loading and empty states match the warm Review visual direction.

## Risks And Mitigations

- **Risk: timeline payload lacks attribution.**
  - Mitigation: make attribution a release gate for student filtering. Do not ship fake filtering.

- **Risk: parent class list endpoint is unavailable.**
  - Mitigation: ship parent journal with `All` class scope and child filtering first, then add class selector when the endpoint is confirmed.

- **Risk: card reuse couples Portfolio to Review actions.**
  - Mitigation: extract shared read-only card primitives only. Keep Review actions in Review-specific wrappers.

- **Risk: Stream becomes visually crowded when capture controls return.**
  - Mitigation: Portfolio feed starts below the capture surface and can use compact cards. The class selector, range filter, and student filter remain near the top of the feed section.

- **Risk: parent and teacher copy drift into dashboard language.**
  - Mitigation: keep copy journal-like: moments, journal, today, class, child names. Avoid metrics, feed management, and task language.

## Definition Of Done

- Portfolio plan implemented with a shared read-only card surface.
- Teacher Stream shows selected-class portfolio entries with range, class, and student filtering.
- Parent Journal shows parent-visible entries with child filtering and class filtering where supported.
- Student filtering uses explicit attribution IDs.
- No Review-only actions appear in Portfolio.
- Unit tests cover normalization and filtering.
- Build succeeds for the TinySteps scheme.
- Manual QA covers teacher and parent roles on a small iPhone simulator.
