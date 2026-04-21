# TinySteps — Implementation Priorities

**Scope:** how to get from the current `TinySteps/` scaffolding to the demoable app described in `docs/hackathon-priorities.md`, by Wed 2026-04-22. This doc is the build order, the file-layout contract, and the day-by-day gate list. It is written to be actionable by two engineers working in parallel.

---

## 0. What already exists (and must not be rebuilt)

The codebase is **not greenfield**. Before writing any new file, read:

- `TinySteps/TinySteps/App/Composition/FeatureServicesComposition.swift` — service wiring. New services go here.
- `TinySteps/TinySteps/Core/Session/ClassSelectionStore.swift` + `ClassContext.swift` — class picker state. **Do not invent a second class picker.**
- `TinySteps/TinySteps/Features/Home/TeacherHomeView.swift` — currently placeholder (*"Roster placeholder"*, *"Assignments placeholder"*). This is where the capture surface lands.
- `TinySteps/TinySteps/Features/Portfolio/Services/PortfolioService.swift` — today only reads the timeline. Extending it with a *create-entry* path is on the critical path.
- `Packages/MBAPI/Sources/MBAPI/APIEndpoints/MBPortfolioEndpoint.swift` — the server-side portfolio shape. New capture entries go here eventually (may be stubbed in-memory for the hackathon).
- `Experiments/VoiceTranscript/VoiceTranscript/` — the validated STT + Ollama + PYP pipeline. **Port, don't reimplement.**
- `Experiments/FaceTagging/FaceTagging/` — the validated AdaFace face-ID pipeline. **Port, don't reimplement.**

**Load-bearing conventions** the new code must follow:

- One service per concern, protocol + implementation (`XxxService` protocol, `MBXxxService` struct). Injected via `FeatureServicesComposition`.
- Feature screens live in `Features/<Area>/` with their ViewModel, View, and (if needed) local Services subfolder.
- `MBAPI` package holds all backend I/O. Anything hitting a network or the Ollama box is a service in the app target, not in the package, because Ollama is LAN-local and not a ManageBac concern.
- SwiftUI + `@Observable` for view models, except for classes touching AVFoundation/Speech callbacks (`SpeechTranscriber` must stay `nonisolated final class` with `OSAllocatedUnfairLock<State>` — see `live-capture.md` §10 gotcha 4).

---

## 1. Module plan — what to add and where

### 1.1 New feature modules

```
TinySteps/TinySteps/Features/
├── Capture/                          # NEW — the record/photo/etc. surface
│   ├── CaptureView.swift
│   ├── CaptureViewModel.swift
│   ├── Types/
│   │   ├── CaptureType.swift         # enum: note, photo, image, video, file, website
│   │   └── CaptureTypeStripView.swift
│   ├── Note/
│   │   ├── NoteCaptureView.swift     # the Hold gesture lives here
│   │   └── HoldRecordButton.swift    # signature micro-interaction
│   └── Photo/
│       ├── PhotoCaptureView.swift    # AVCaptureSession + shutter
│       └── NameHaloOverlay.swift     # signature micro-interaction
│
├── DraftSheet/                       # NEW — shared post-capture surface
│   ├── DraftSheetView.swift
│   ├── DraftSheetViewModel.swift
│   ├── ChipBloomView.swift           # signature micro-interaction
│   └── ChildAttributionRow.swift
│
├── ChildVoice/                       # NEW — cross-type attachment
│   ├── ChildVoiceRecorderView.swift
│   └── ChildVoiceRecorderViewModel.swift
│
├── FaceID/                           # NEW — enrolment + inference
│   ├── Enrolment/
│   │   ├── FaceEnrolmentView.swift
│   │   └── FaceEnrolmentViewModel.swift
│   └── Services/
│       └── FaceIdentificationService.swift
│
├── ParentPreview/                    # NEW — fake parent-side rendering
│   └── ParentPreviewSheet.swift      # one sheet that renders a MomentCard
│
└── Portfolio/
    └── Services/
        └── PortfolioService.swift    # EXISTING — extend with createEntry
```

### 1.2 New core modules

```
TinySteps/TinySteps/Core/
├── Speech/                           # NEW — ported from Experiments/VoiceTranscript
│   └── SpeechTranscriber.swift       # verbatim port; keep the nonisolated class + unfair lock
│
├── Drafting/                         # NEW — ported from Experiments/VoiceTranscript
│   ├── OllamaAPI.swift               # includes NDJSONStreamDelegate
│   ├── OllamaDraftingEngine.swift
│   ├── DraftingEngine.swift          # protocol + FoundationModels + Ollama impls
│   ├── ObservationDraft.swift        # no `draft` field; transcript IS the description
│   ├── ObservationDraftSchema.swift
│   ├── PYPTag.swift
│   ├── PYPTaxonomy.swift             # compressed prompt v26
│   ├── PYPTagBundle.swift
│   └── DebugConfig.swift             # compile-time engine + sampling choices
│
├── FaceID/                           # NEW — ported from Experiments/FaceTagging
│   ├── FaceCropper.swift
│   ├── FaceAligner.swift
│   ├── MLFaceEmbedder.swift
│   ├── IdentityMatcher.swift
│   ├── EnrolledIdentity.swift        # @Model — own ModelContainer
│   └── FaceEmbedder.mlpackage        # 45 MB bundle resource
│
└── NameExtraction/                   # NEW — fuzzy + Metaphone against roster
    └── RosterNameMatcher.swift
```

### 1.3 New composition entries

Extend `FeatureServicesComposition` with:

- `draftingService: DraftingEngine` (compile-time bound via `DebugConfig.selectedEngine`).
- `faceIdentificationService: FaceIdentificationService`.
- `nameMatcher: RosterNameMatcher`.

The composition is where the Ollama `hostURL` is set — bake the venue M4 Max IP into `DebugConfig.ollamaHostURL` and document its demo-day value in `README`.

---

## 2. Porting plan — experiment code → main app

### 2.1 Verbatim ports (no change)

These files compile clean against the main app and do not need refactoring — copy them over, fix import paths, done:

| From | To |
|---|---|
| `Experiments/VoiceTranscript/VoiceTranscript/STT/SpeechTranscriber.swift` | `Core/Speech/SpeechTranscriber.swift` |
| `.../Drafting/OllamaAPI.swift` | `Core/Drafting/OllamaAPI.swift` |
| `.../Drafting/OllamaDraftingEngine.swift` | `Core/Drafting/OllamaDraftingEngine.swift` |
| `.../Drafting/DraftingEngine.swift` | `Core/Drafting/DraftingEngine.swift` |
| `.../Drafting/ObservationDraft*.swift` (both) | `Core/Drafting/` |
| `.../Drafting/PYPTag.swift`, `PYPTaxonomy.swift`, `PYPTagBundle.swift` | `Core/Drafting/` |
| `.../Drafting/FoundationModelsDraftingEngine.swift` | `Core/Drafting/` |
| `Experiments/FaceTagging/FaceTagging/...` (face-ID pipeline) | `Core/FaceID/` |

Risks on port: `DebugConfig.swift` references the experiment's corpus folder for batch running. Strip the `Harness/` coupling; keep only `selectedEngine`, `ollamaSampling`, `ollamaThink`, `useStreaming`, `taxonomyChoice`. Add `ollamaHostURL`.

### 2.2 Adapt, don't port

- `LiveCaptureView.swift` from the experiment is the shape of the capture UI but speaks to its own single-view world. Do not port it; rebuild the UI inside `Features/Capture/Note/NoteCaptureView.swift` using the same state machine (idle, recording, tagging, done, failed) but wired to `CaptureViewModel` and the existing ClassContext.

### 2.3 Leave behind

- `Experiments/VoiceTranscript/VoiceTranscript/Harness/` — batch-runner + CSV writer. Not production.
- `Experiments/VoiceTranscript/VoiceTranscript/Drafting/EYFS*.swift` — pre-pivot EYFS taxonomy. Retain in experiment repo only.
- `Experiments/VoiceTranscript/VoiceTranscript/Drafting/OpenAICompatible*.swift` — only needed if we demo against LM Studio, which we aren't. Leave.
- `Experiments/FaceTagging/FaceTagging/scripts/` — Python model-conversion scripts. Not shipped.
- Anything under `Experiments/prompt-eval/` — the winning prompt text is already embedded in `PYPTaxonomy.compressedPrompt` in the Swift file.

---

## 3. Milestones — day by day

**Today is Monday 2026-04-20. Demo is Wed 2026-04-22.** Two working days and the morning of demo day.

### Monday evening (tonight)

**Owner A (engine path)**

- M0.1 — Port `Core/Speech/`, `Core/Drafting/`, and `Core/FaceID/` (see §2.1). App compiles.
- M0.2 — Add `FaceEmbedder.mlpackage` as a bundle resource. Keep it at bundle root, not in a subdirectory (Xcode 16 file-system-synchronized groups flatten — see `live-capture.md` §10 gotcha 8).
- M0.3 — Extend `FeatureServicesComposition.live(...)` with `draftingService`, `faceIdentificationService`, `nameMatcher`. Wire through `AppDependencies`.
- M0.4 — Add `DebugConfig.ollamaHostURL` with the venue M4 Max IP as default.

**Acceptance:** `xcodebuild -scheme TinySteps build` succeeds; app launches to the existing placeholder Home view; `OllamaDraftingEngine.prewarm()` runs on app start and logs the Ollama version to the console.

**Owner B (UI scaffolding)**

- M0.5 — Replace `TeacherHomeView` placeholder with a three-tab `TabView` (Today / Review / Class). Today is landing.
- M0.6 — Add the Class picker pill to the top of each tab, reading from `ClassSelectionStore`. Hardcode two classes in the demo data path for offline operation.
- M0.7 — Create `Features/Capture/CaptureView.swift` with the type strip at the top, all six types visible, only Note and Photo enabled. Everything else tapping shows a *"coming soon"* toast.

**Acceptance:** app boots into a three-tab teacher home; class picker opens the existing `ClassSwitcherView`; tapping Today shows the capture surface with type strip and Note selected.

### Tuesday morning

**Owner A (capture pipeline)**

- M1.1 — `Features/Capture/Note/HoldRecordButton.swift` — the Hold gesture (press-and-hold; swells; haptic; tap-under-300ms falls through to tap-to-toggle).
- M1.2 — Wire `HoldRecordButton` → `SpeechTranscriber.start()`/`stop()` → live partial transcript rendering. Mic level indicator pulses.
- M1.3 — On stop, kick off `OllamaDraftingEngine.draftStream(from:)` and publish `PartialTagBundle` updates to the view model.
- M1.4 — Route the final `DraftResult` into a `DraftSheetViewModel`; present `DraftSheetView`.

**Acceptance:** Holding the button on a real iPhone dictates, releasing shows the transcript, and the draft sheet appears with the streaming tag bundle in ~4s. The Chip Bloom animation is not required yet — a placeholder rail is fine.

**Owner B (Chip Bloom + draft sheet)**

- M1.5 — `ChipBloomView` — four skeleton chips in canonical order (theme → keyConcepts → atlSkills → learnerProfile), each bloomed individually on update. Reduce Motion degrades to cross-fade.
- M1.6 — `DraftSheetView` for Note entries: transcript hero + chip rail + attributed children row + file button.
- M1.7 — Map `confidence` to one of three words (*"pretty sure"* / *"worth a check"* / *"I might be off here"*). Never show a number.

**Acceptance:** a full Note capture — Hold → release → Chip Bloom fills in progressively → confidence line appears → File button becomes primary.

### Tuesday afternoon

**Owner A (face ID + child voice)**

- M2.1 — `Features/FaceID/Enrolment/` — enrolment flow using `PhotosPicker(maxSelectionCount: 5, matching: .images)`. Three demo children enrolled from bundled photos, baked into the build for demo-data mode.
- M2.2 — `Features/Capture/Photo/PhotoCaptureView.swift` — AVCaptureSession + shutter. On capture, run the face-ID pipeline in a `TaskGroup` and present `NameHaloOverlay` over the photo.
- M2.3 — `NameHaloOverlay` — soft pulsing halo on matched faces, yellow `?` on unmatched. Tap on `?` opens roster picker scoped to the current ClassContext.
- M2.4 — `Features/ChildVoice/ChildVoiceRecorderView.swift` — ≤30s recorder reusing `SpeechTranscriber` but with `shouldReportPartialResults = true` and a larger centred mic button. The button enlarges ~1.4× and the background dims (see `app-feature-spec.md` — "The child holds the mic").

**Acceptance:** a Photo capture shows three halos (two matched, one unknown), the unknown resolves with one tap from the picker, and the teacher can attach a child-voice clip before filing.

**Owner B (child attribution + parent preview)**

- M2.5 — `Core/NameExtraction/RosterNameMatcher.swift` — fuzzy + Metaphone pass over the description text against the current ClassContext's roster. Pre-attribute matched children on the draft sheet before the teacher opens it.
- M2.6 — Draft sheet: unify face-detected children and name-extracted children, deduplicate, render avatar row.
- M2.7 — `Features/ParentPreview/ParentPreviewSheet.swift` — a segmented toggle at the top of the draft sheet (Teacher / Parent). Parent view renders a `MomentCard` with warm-serif teacher narration, chip pills, and the child-voice pull-out if present.
- M2.8 — In-memory entry store. On File, append the entry to a shared `@Observable` store; Today strip reads from it chronologically; ParentPreview reads the single entry from it by id.

**Acceptance:** filing an entry puts it in the Today strip; switching to Parent view on the same entry shows the rendered moment card.

### Tuesday evening

**Joint — rehearsal + hardening**

- M3.1 — Walk the demo narrative from cold boot to parent preview, three times on a real iPhone on the venue wifi. Time each run.
- M3.2 — Fix whichever two things felt wrong in rehearsal.
- M3.3 — Known-good demo data: three preselected test photos bundled for face-ID (bypassing live capture if needed), one canonical Note transcript (the u01 sample), one child-voice clip pre-recorded for emergency playback.
- M3.4 — Text-input fallback on the Note type: hidden *"type transcript"* toggle on the capture surface. Critical for Simulator and venue-noise emergencies.

**Acceptance:** three consecutive clean runs of the demo narrative, each under 90 seconds, no tap hanging more than 5s.

### Wednesday morning (demo day)

- M4.1 — Fresh install on the demo device. Launch, prewarm, rehearse once on the venue wifi with the Ollama box in the morning.
- M4.2 — Lock the build. No new features after 10am. Any bug after 10am is shipped with a Post-it workaround, not a fix.
- M4.3 — Charge the demo phone to 100%, Airplane-mode toggle ready for Beat 4 if asked.

**Definition of done:** the demo narrative runs end-to-end three times in a row without a restart, on the exact demo device, on the venue wifi, with the Ollama box warm.

---

## 4. Parallelization — who works on what

A two-engineer plan (Owner A = "engine", Owner B = "UI") with explicit hand-off points:

- **Owner A** owns everything under `Core/` (Speech, Drafting, FaceID, NameExtraction) and the composition wiring. Keeps the pipeline sound and the Ollama/model plumbing reliable.
- **Owner B** owns everything under `Features/` (Capture, DraftSheet, ChildVoice, FaceID enrolment UI, ParentPreview). Keeps the UX shape on track and bakes the signature micro-interactions.

Hand-off points are the **services**: Owner A publishes stable protocol APIs (`DraftingEngine`, `FaceIdentificationService`, `RosterNameMatcher`) on Monday night; Owner B codes against those protocols from Tuesday morning and mocks them where needed to unblock UI work.

If there is a third engineer, they should own **rehearsal & demo data** — M3.3 is a full half-day of work and is often the difference between a demo that lands and one that doesn't.

---

## 5. Testing — minimal but not zero

This is a hackathon, not a product release. But three tests are load-bearing; write them even if nothing else gets tests:

- **`PYPTaxonomyTests`** — assert that every `PYPTag` enum `rawValue` appears as a line prefix in `PYPTaxonomy.compressedPrompt`. Without this, dropping a tag from the enum silently produces prompts that can't surface it — a nightmare to debug on stage. (Already exists in the experiment; port it.)
- **`NormalizeObservationDraftJSONTests`** — feed the four drift modes (single-key wrapper, flat-tag shorthand, missing defaults, malformed evidence spans) and assert decode succeeds. The normaliser is on the critical path of every single capture; if it breaks, every draft shows the decode-failed error.
- **`RosterNameMatcherTests`** — fuzzy + Metaphone against a small fake roster. Catches accent/misspelling regressions that otherwise surface as *"the model didn't attribute Anna"* live.

Skip: SwiftUI view snapshot tests, face-ID pipeline tests (the experiment's tests cover this), Ollama integration tests (manual rehearsal is the test).

---

## 6. Known risks and mitigations

| Risk | When it bites | Mitigation |
|---|---|---|
| Ollama box unreachable on venue wifi | Live demo | Travel router; fallback to Foundation Models compile-time switch; text fallback to skip STT |
| First cold model load > 20s on stage | First capture of the session | Prewarm on app launch (M0.1); keep the box warm between rehearsal and demo |
| iOS Simulator mic delivers no buffers | Any simulator demo | Demo on real iPhone 15 Pro; text-input fallback (M3.4) |
| Face-ID false positive on stage | Photo beat | Use three known-good test photos (M3.3), not novel captures |
| Chip Bloom flashes partial data | Every capture | `extractStringField` already requires closing `"` before yielding; don't loosen |
| Hold gesture confusion | First-time rehearsal audience | The 300ms threshold converts to tap-to-toggle; rehearse both modes |
| SwiftData + CloudKit merge conflicts | As soon as multiple devices appear | Skip CloudKit for hackathon. In-memory store only |
| Bundle not finding mlpackage | First face-ID run | Keep resources at bundle root, not in subdirectory (§1.1, gotcha 8) |

---

## 7. Integration points with the existing app

Four places where new code must fit into existing scaffolding rather than stand beside it:

1. **`ClassSelectionStore`** — the class picker we designed is *already built*. Don't duplicate. The capture surface reads `ClassContext` from `AppShellModel` or equivalent and files the new entry against that class.
2. **`PortfolioService`** — currently read-only (`loadPortfolioTimeline(...)`). We add a create path. For the hackathon, this is an in-memory append; post-hackathon, extend `MBPortfolioEndpoint` with a `POST /portfolio` call.
3. **`ChildrenService`** / `ChildContext` — the existing roster source. The demo-data mode (`MBAPIDemoDataMode.replay`) is the path to run offline with baked-in children. Use it for rehearsal.
4. **`TeacherHomeView`** — currently a placeholder. The capture surface *replaces* the placeholder; the class picker pill *replaces* the existing `ClassSwitcherView` button at the top (or we re-skin the existing button to match the spec).

---

## 8. What to build first tomorrow (the critical 90 minutes)

From cold, in this order:

1. Port `SpeechTranscriber` and `OllamaDraftingEngine` into `Core/` (M0.1).
2. Add their services to `FeatureServicesComposition` (M0.3).
3. In `TeacherHomeView`, add one button labelled *"Test capture"* that calls `draftingService.draftStream(from: "Amara built a tower of six blocks")` and prints the streamed chunks to the console.
4. Run against the real Ollama box. Verify PYP tags arrive in under 5 seconds.

If step 4 works by 9:30am Tuesday, the rest of the plan unfolds. If step 4 doesn't work by 11am, pause feature work and fix the pipeline — everything else stranded on a broken engine is zero value.

---

## 9. Post-demo (not for this hackathon)

Listed here only so they don't accidentally leak into the hackathon build:

- Real `POST /portfolio` endpoint wiring.
- CloudKit sync for multi-device parent visibility.
- Offline retry queue with `pendingRetag` background task.
- The other four content types (Image, Video, File, Website) fully wired.
- Enrolment UI polish, re-enrolment nags, correction accrual.
- Multi-language translation rendering for parents.
- Settings surface (engine choice, locale, Ollama host).
- Accessibility audit (VoiceOver pass on each new screen).
- Proper auth flow for parents (currently dev-only via ManageBac OAuth).
