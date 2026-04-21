# TinySteps — Teacher + Parent App Feature Spec

One iOS app, two roles. **Teachers** capture evidence of learning into a **class portfolio**; **Parents** consume their child's journal — a parent-side view derived from the entries in the portfolio that concern their child. The role is determined at pairing time (join code vs share link, see *First-run and onboarding*) and drives which tabs and chrome are shown — but it is one binary, one App Store listing, one install. A person who holds both roles (e.g. a teacher whose child attends the same setting) switches between them in-app rather than installing twice.

The primary organising concept is the **portfolio per class**. A teacher selects a class at the top of the app (persistent class picker on every teacher-facing tab) and everything they see — captures so far today, the review queue, the roster — is scoped to that class. A teacher who teaches multiple classes flips between them with one tap; the currently selected class is the one a new capture is filed into.

---

## Product posture

TinySteps is the story of a three-year-old's week, told in a teacher's own words, landing in a parent's hand. That is the emotional centre and every UI decision should be measured against it. Concretely, that means:

- **Warm over clinical.** Soft rounded shapes, generous leading, large hit targets. Copy is in the first person where the teacher speaks ("I saw Amara…") and in the child's name where possible ("Amara's journal", not "Child #14"). Avoid dashboard language (no "metrics", "entries logged", "activity graph"). Timestamps are relative and human — *this morning*, *yesterday at snack time* — never ISO strings.
- **Confident defaults, not configuration.** A nursery teacher holding a child with one hand does not want a settings drawer. Opinions are baked in (record gesture, default locale, chip order). The settings screen is short enough that no teacher scrolls it in a normal week.
- **Calm under latency.** Nothing flashes. No spinners without a shape. Four seconds of tagging should feel like the app is *listening back*, not *thinking*. See "Pacing and latency perception" below.
- **Respect, not compliance.** Safeguarding gates for child voice are framed as *asking the child* rather than *protecting the institution*. The teacher should feel like the app is on the child's side.
- **Apple, not Pro.** The reference visual register is Fitness / Journal / Notes — not Logic / Final Cut. Density is low. Chrome gets out of the way. Photos are the hero; chips are the supporting cast.

These aren't decoration. Every downstream feature decision in this document should trace back to one of these five.

---

## The portfolio and its content types

The portfolio is the unit of work. Every capture becomes a **portfolio entry** filed into the currently selected class. Entries are typed — six types in total — and a single portfolio holds entries of any mixture of types interleaved chronologically.

### The six content types

| Type | What it holds | Description field | Typical capture surface |
|---|---|---|---|
| **Note** *(also called Observation)* | Free text written or voice-dictated by the teacher | The text **is** the content; there is no separate description | Walkie-talkie record, or text entry |
| **Photo** | A photo taken in-app | Optional free text beneath | In-app camera; face detection runs after capture |
| **Image** | An image picked from the photo library (not taken in-app) | Optional free text beneath | iOS PhotosPicker |
| **Video** | Short video clip (recorded in-app or picked from library) | Optional free text beneath | Camera or picker |
| **File** | A document attachment (PDF, worksheet, scanned page, child's drawing scan) | Optional free text beneath | iOS document picker / share extension |
| **Website** | A URL to something external the teacher wants to reference (a resource, a shared gallery, a parent-visible link) | Optional free text beneath | Paste / share extension |

Every entry has a **description**. For a **Note / Observation** the description *is* the body (there is no other content — the text is the entry). For the other five types, the description is an optional text field that sits beneath the media. The same auto-tag pipeline runs on whichever description text exists: *Note text → tags*, or *Photo caption → tags*, or *Website paragraph → tags*. The tagging does not know or care which type produced the text; the PYP framework applies to evidence of learning, not to storage format.

Four things are cross-cutting:

- **Auto-tagging** (PYP chips against the description) runs on any type whose description is non-empty. See *Description & auto-tagging*.
- **Face detection** runs only on **Photo** captures — not on Image (library pick, no faces assumed), not on Video, not on File. When face detection matches enrolled children, those children are attributed to the entry so the entry reaches their parent feed. See *Photo face detection*.
- **Child voice** can be attached to **any** portfolio entry — a Note reflecting on a drawing, a Photo of the water tray, a Video of a block tower, a Website the child wanted to share. Voice is an attachment, not a type. See *Child voice attachment*.
- **Child attribution** — every entry is attributed to one or more children in the class. Face detection does this automatically for Photos; for every other type the teacher picks from the roster (with recent-children pinned at the top). Multi-child attribution is first-class on every type.

### The capture surface

One screen, **Capture**, that adapts to the selected type. The screen has three regions:

1. **Type strip** at the top — six small icons for the six types (Note, Photo, Image, Video, File, Website). Note is selected by default. Tapping a different icon swaps the middle region's controls.
2. **Type-specific middle region** — for Note this is the walkie-talkie record button and a text editor; for Photo this is the camera viewfinder; for Image/Video/File this is the native picker trigger; for Website it is a paste-URL field with share-extension fallback.
3. **Common footer** — description field (absent for Note because the content *is* the description), child attribution row, attach-child-voice button, File button.

The Note type's walkie-talkie gesture remains the signature fast path for *"grab this moment before it's gone"*, because dictating a short sentence is the fastest six-second capture any adult can do. The other five types trade speed for fidelity — a photo takes ~4 seconds to compose, a document pick takes ~6, a URL paste takes ~3. The UI does not try to pretend they are all as fast as the walkie-talkie; it just makes each one optimal for its own shape.

### The draft sheet

After any type is captured, the user lands on a **draft sheet** — the shared post-capture surface. Regardless of type, the draft sheet shows:

- The captured media (text for Note, image for Photo/Image, player for Video, document thumbnail for File, favicon+title for Website).
- The description field (primary for non-Note types; hidden for Note since the text is already showing).
- The chip rail (auto-tags on the description — *The Chip Bloom*, see micro-interactions).
- The children attributed to the entry.
- The *"Attach <child>'s voice"* action, visible once at least one child is attributed.
- The File button (primary), Discard (secondary).

The draft sheet is where the three cross-cutting features (auto-tagging, face attribution, child voice) meet — no matter which of the six types the teacher started with.

**Tradeoff flagged:** surfacing six types as equal peers costs vertical space (the type strip is always visible on capture) and adds a decision step for teachers who only ever use Note. We accept both because the portfolio concept is load-bearing for the product — a teacher's class portfolio must be able to include the child's drawing (File), the photo of the water tray (Photo), the link to the science video the class watched (Website), not only voice notes. Hiding the non-Note types behind a *"+"* menu would be kinder in the short term and wrong in the long term.

---

## Signature micro-interactions

Three named interactions that carry the product's feel. Each is small enough to build in a day and load-bearing enough to be worth naming.

### 1. The Hold *(Note capture)*

The primary record gesture for the Note content type. Press and hold the record button; speak while holding; release to finalise. Mid-hold, the button swells ~1.15× and the app's entire background softens to a very low-contrast warm blur. The transcript fills in underneath in real time. On release, the button snaps back to rest size with a single soft haptic (`UIImpactFeedbackGenerator(.soft)`), and the chip rail underneath begins to populate from left to right.

This is the one gesture the teacher will perform several times an hour. It must feel physical. It must be obvious the mic is live without looking. The background softening is the cue, not a recording light — a teacher's eyes are on the child, not the phone.

If the hold duration is under 300ms, the gesture converts to tap-to-toggle (see *Description & auto-tagging*). The teacher does not have to choose a mode; the gesture chooses for them.

The Hold is specific to Note capture. The other five content types do not use a press-and-hold — each has its own natural capture affordance (shutter for Photo, picker sheet for Image/Video/File, paste for Website).

### 2. The Chip Bloom *(cross-type, runs on any description)*

Any content type whose description has text gets auto-tagged. Tagging latency is ~4s — long enough to feel broken if handled as a spinner. Instead: the moment the description is committed (Hold release for a Note; *"Save description"* tap for everything else), a row of four dim **chip skeletons** appears (one per PYP dimension, in the canonical order: theme, concepts, ATL, profile). Each skeleton is the size of the chip that will replace it. As the JSON streams and each dimension closes, the corresponding skeleton *blooms* — fades from 10% opacity to full, with the chip text cross-fading in. When all four bloom, a single confidence line appears underneath: *"pretty sure"* / *"worth a check"* / *"I might be off here"* (mapped from `confidence` buckets, never a raw number in the teacher view).

The point of named skeletons: the user sees the shape of the answer before the content arrives, so 4s of waiting feels like 4s of *reading back* rather than 4s of blank screen. The chips are the shape of listening.

Because the Chip Bloom runs on every type that carries a description, the teacher quickly learns that *writing or speaking a sentence about any artefact* gets that artefact tagged against PYP. The behaviour is one; only the input is typed.

### 3. The Name Halo *(Photo only)*

When a face in a **Photo** capture is matched to an enrolled child, the bounding box is not a hard green rectangle — it's a soft *halo* that pulses once, then dims to a thin outline with the child's first name below in the app's accent colour. Unmatched faces get a yellow `?` halo instead of a hard alert box.

This is deliberately *not* a security camera aesthetic. A three-year-old seeing their face surrounded by a soft warm ring with their name under it is a moment. A three-year-old seeing a green rectangle is a thing they don't recognise as them.

The halo appears only on Photos taken in-app. Library-picked Images do not run face detection (we don't know who was present; they could be historical, a parent's photo, a screenshot — the teacher attributes manually from the roster). Video face detection is post-MVP.

Tradeoff flagged: the halo is slightly less precise than a rectangle for ambiguous faces (partial occlusion, profile). If the teacher needs to see the exact bounds, tap-and-hold on a face reveals the underlying `VNFaceObservation` rectangle. Default is the halo.

---

## Information architecture

One app, two role-driven tab bars. The tab bar is swapped at launch based on the account's role; the role is fixed per account, set at pairing (see *First-run and onboarding*). Below the tab bar, chrome, type register, and copy tone also swap — see *Voice, copy, and accessibility*.

### Class picker (teacher role, global)

Every teacher-facing tab has a **class picker** as a persistent header: a pill at the top-left showing the currently selected class's name, tappable to switch. The picker is the scope of everything below — captures, drafts, roster, portfolio timeline, enrolment nags. Teachers who teach a single class see the pill as a passive label and rarely tap it; teachers who teach two or more (common in settings with mixed-age rooms or job-share contracts) flip between classes with one tap and a short cross-fade.

Behaviourally, switching class:

- Cancels any in-progress capture draft (with a one-tap *"Keep as draft in <old class>"* option surfaced as a toast — never lose the teacher's words).
- Re-scopes Today, Review, and Class tabs to the newly selected portfolio.
- Preserves the current tab (if you were on Review for class A, switching puts you on Review for class B, not back to Today).
- Has no confirmation modal. Switching class is not a destructive action.

Settings of multiple classes are held together in a single account; there is no *"switch setting"* above the class picker (a teacher works at one setting per account — multiple settings require multiple accounts, same as Slack workspaces). This keeps the header to one level of nesting.

### Teacher role — three tabs, no more

- **Today** (landing). Above the fold: the capture surface for the selected class (type strip + capture controls). Below: a chronological strip of today's portfolio entries, typed — each entry shows a tiny type-icon (speech-bubble, camera, image, film, doc, link) alongside its chips and attributed children. Tapping any entry opens its draft sheet (if unfiled) or its portfolio view (if filed). This tab is the answer to *"where am I in the app"* — the teacher always returns here.
- **Review** (badge shows unpublished draft count for the selected class). The end-of-day queue of drafts to confirm and publish. See "End-of-day review queue" below.
- **Class** (roster for the selected class). Per-child pages with their portfolio-to-date, enrolment status, parent contact. Used for enrolment, corrections, and occasionally to look at a child's own journal in the same form the parent will see.

No "Settings" tab. Settings live behind a gear on the **Class** tab header, because settings are a weekly-or-less concern. There is no "Notifications" tab, "Analytics" tab, or "Profile" tab. If a feature does not fit in Today / Review / Class, it does not ship.

**Parent role** — two tabs:

- **Journal** (landing). The child's timeline, newest-first. One child per parent account is the default; the two-child case gets a segmented control at the top.
- **About <child>** — enrolment photos (for reassurance), the setting's contact, export button, delete-my-data button. Quiet, one-screen.

The parent role has no "Home", no "Dashboard", no "Insights". A parent is not a user of a tool; they are reading their child's diary.

**Dual-role users.** A teacher whose own child attends the same setting signs in twice on one device — once as teacher, once as parent — using the same app. A small role chip at the top of the Today / Journal tab shows the current role and opens a quick-swap menu on tap (*"Switch to Amara's journal"* / *"Switch to Nursery View"*). The swap is instant; data for each role is held in distinct CloudKit zones, and the face-ID model container (which is teacher-only) is never addressable from the parent role. Only 1-2% of accounts are dual-role, but getting this right is the difference between *"I have to install it twice"* and *"oh, it just knows."*

---

## First-run and onboarding

### Teacher first-run

The nursery's designated admin sets up the setting once. Individual teachers then join an existing setting rather than standing one up.

**Admin path (once per setting):**
1. Create the setting. Name it. Pick locales the setting will operate in (affects STT and parent translation later).
2. Add the local-LAN Ollama box address. A *"test connection"* button runs the prewarm and reports the model version. If it fails, the setting is created anyway in *"Apple Intelligence fallback"* mode with a persistent nudge banner.
3. Draft the class roster — names + photos for face enrolment. Can be deferred; a setting with no roster still captures, it just cannot attribute. The admin sees an onboarding checklist (in the **Class** tab, not as a modal) with *"Add children (0/14)"*, *"Invite teachers"*, *"Invite parents"* — greyed as they complete.

**Teacher path:**
1. Open the app, enter setting join code (6 characters, one-shot, expires in 24h).
2. Permissions asked in natural order as they become relevant — **not** all up front. Mic on first record tap. Camera on first photo. Photos library on first enrolment. No cold-start permission wall.
3. First capture is an onboarding moment. A ghost hint reads *"Hold the button and describe what you saw"* under the record control; it dismisses permanently on first successful capture.

A teacher's cold-start state (setting configured, no captures yet): the **Today** tab shows a single soft illustration and the copy *"Nothing captured yet today. Press and hold to record what you saw."* The Review tab shows *"Nothing to review — everything's up to date."* (see Empty states below).

### Parent first-run

Parents are invited by a teacher per child — never sign up themselves.

1. Teacher taps *"Invite parent"* on a child in the **Class** tab → generates a one-time CloudKit share link + 6-digit backup code, sent via the setting's existing comms channel (email, WhatsApp, Brightwheel, whatever — we do not build that; we produce the link and code). The teacher verbally confirms the parent received it.
2. Parent installs the app, opens the link (or enters the code). App asks for the child's first name as a *confirmation step* — the parent typing "Amara" matches what the teacher enrolled, and if it doesn't, the pairing fails closed. This is a deliberate friction: we never want a parent seeing the wrong child.
3. Consent affirmations: *"I agree my child's observations may include voice clips in their own words"*, separately toggleable. Defaults to off; teacher is prompted at capture time for children whose parent hasn't ticked this.
4. Locale selection for translation of transcripts. Multi-language households: a parent can tick *more than one* target locale. Transcripts render translated; the untranslated source is always visible on long-press.

Cold-start state (paired, zero observations): the **Journal** tab shows *"Amara's journey starts here. Their teacher will share the first moment soon."* plus the enrolment photos as a quiet montage. No empty gridlines, no call to action the parent can't act on.

**Tradeoff flagged:** demanding the child's first name at pairing adds one step. We accept it because a wrong pairing is a safeguarding event and must be structurally prevented.

---

## Moment-of-use context

The teacher is on the floor. A child is on their lap. The phone is in one hand, held near the body, not at arm's length. The other hand is holding the child, a crayon, or a juice cup. Ambient noise is 60-75 dB of other children. The moment the teacher wants to capture lasts six to ten seconds; if they can't start recording within three seconds, the moment is gone.

**Design consequences:**

- **All primary controls are within thumb-reach of a one-handed right or left grip.** The record button is centred and lives in the bottom safe-area inset. The photo and child-voice buttons sit either side of it, *not* above, so a thumb can strafe across without re-gripping. Switching hands is covered by the symmetric layout, not a setting.
- **No modal confirm on common actions.** Record, stop, file draft — none prompt. The teacher is holding a child. A *"Are you sure?"* is a dropped child.
- **Interruption tolerance.** Any recording in progress survives a backgrounding, a lock, an accidental home-bar swipe. Returning to the app within 30s resumes the recording view with the transcript intact; beyond 30s, the recording is auto-finalised and appears as a draft in Review. The teacher never loses words.
- **Low visual load.** The capture surface during recording shows three things: the live transcript, the mic-level pulse, and the stop/release affordance. Everything else is dimmed.
- **Large tap targets.** Minimum 56pt for the primary record control, 44pt for anything else. Chips are 36pt tall but their tap target extends 8pt above and below.
- **Quiet sound design.** The app makes exactly two sounds by default: a soft chime on successful file, and a slightly softer chime on Review-queue publish. No tick on record start — the haptic does that job without announcing to the class that the teacher is recording.
- **Screen-off capture** (post-MVP, flag for roadmap). Hold-to-record should work from the lock screen via Control Center widget. Noted not scoped.

---

## Feature 1 — Description & auto-tagging

**Scope:** every portfolio entry carries a description. For the Note content type the description *is* the entry (there is no other content); for the other five types (Photo, Image, Video, File, Website) the description is an optional free-text field beneath the media. The same auto-tag pipeline runs on any description that has text — the tagger does not know or care which type produced the text. One feature, five visible entry points.

**User flow (the Note case — fastest path):** Teacher opens Capture tab → Note is selected by default → engages the record control → narrates 10–30s observation (*"Amara built a tower of six blocks and counted them in Somali and English…"*) → releases → transcript appears → within ~4s the chip rail resolves: PYP tags + confidence + student names pre-attributed.

**User flow (the non-Note case):** Teacher picks the content type (Photo / Image / Video / File / Website), captures the media, then writes or dictates a description beneath it. The same chip rail resolves on the same pipeline.

**Two capture gestures for Note text, one pipeline:**

- **Tap-to-toggle** — tap **Record**, speak, tap **Stop**. Hands-free after the first tap; suits longer narrations and moments where the teacher can't hold the phone (e.g. pen-and-paper observation at the same time).
- **Walkie-talkie / push-to-talk** — press and hold the record button, speak while holding, release to finalise. Familiar gesture from voice-message UIs and actual walkie-talkies; reads as "quick grab a moment" and naturally caps the recording length to the hold duration. Default behaviour when the teacher holds the button for >300ms before releasing; a quick tap still toggles into tap-to-toggle mode.

Both gestures drive the same `SpeechTranscriber.start()` / `stop()` path; only the UI control differs. Partial transcripts render live during either. A visible mic-level indicator pulses while recording so the teacher can tell the mic is live without looking at the transcript.

**Dictating a description on a non-Note type** uses the same Hold gesture on a smaller *"dictate description"* button sitting to the right of the description field. The transcript writes into the description field; the teacher can edit before committing. This preserves the fast-path for any type — a teacher can take a photo and Hold-to-dictate its caption in under ten seconds.

Accessibility: VoiceOver announces "Recording" on start and "Stopped, tagging" on release. The walkie-talkie button is also activatable via VoiceOver direct-touch — a VoiceOver user performs the same press-and-hold gesture. A settings toggle pins the control to tap-to-toggle only, for users with motor conditions where sustained press is uncomfortable.

Always-available **text fallback** (type or paste) runs the identical drafting path — demo stage-safety + simulator workaround, and the primary input for teachers who prefer typing or who work in a quiet setting where dictation feels intrusive.

### Pacing and latency perception

Total tagging time is ~4s P50. That is long enough that any naïve spinner will feel wrong. The perception design for the tagging window:

- **t=0 (release):** haptic pulse, button snaps back, transcript remains on screen in full, four chip skeletons appear underneath in canonical dimension order.
- **t < 400ms:** STT finalises; transcript settles. If the model had audible hesitations, the skeleton breathes slightly (subtle opacity oscillation between 8% and 14%) to signal *"still listening back"*.
- **t ~500ms (TTFT):** first JSON key arrives. Theme chip blooms. This is the first promise-kept moment.
- **t ~1.5s:** key concepts row blooms.
- **t ~2.5s:** ATL skills row blooms.
- **t ~3.5s:** learner profile row blooms.
- **t ~4s:** confidence line appears. Chip opacity jumps from 85% to 100% to mark terminal state. The **File** button becomes primary (was secondary while tagging).

The progression is load-bearing — it turns latency into pacing. If the model regresses and TTFT goes above ~1.2s, the skeleton should shift to a gentle longitudinal shimmer rather than blooming a chip with stale data. Do not bloom partial chips.

**If streaming breaks** (venue LAN flaky, model reloading), the skeletons stay in their breathing state and after 8s a single line appears: *"Taking a moment — keep going, I'll catch up"* with the draft available to file anyway as transcript-only (`pendingRetag = true`). The teacher is never blocked by tagging.

### Speech-to-text (on-device)

- `SFSpeechRecognizer`, locale-configurable (`en-GB` default; picker for `en-US`, `de-DE`).
- `SFSpeechAudioBufferRecognitionRequest.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition` — **gate on capability check**; setting `true` on unsupported devices yields silent zero output.
- `AVAudioEngine` tap → request directly. No file write, no retained buffer. Audio never persisted.
- Partial transcripts render live; final transcript settles ~300ms after `Stop`.
- `SpeechTranscriber` must be a `nonisolated final class` with state in `OSAllocatedUnfairLock<State>`. Swift 6's MainActor default + AVFoundation callbacks on arbitrary queues = `unsafeForcedSync` runtime trap. Do **not** retrofit `@Observable` onto it. Don't use `NSLock` in async contexts either — banned in Swift 6.

### Tag & name extraction (local-LAN LLM)

- Engine: **Ollama `qwen3.5:35b-a3b`** (MoE, 3B active) on a mini-PC on the setting's LAN. Validated Jaccard 0.750 on held-out corpus.
- Fallback: Apple Intelligence via `LanguageModelSession` (Foundation Models). Accuracy drops ~35%; keep as compile-time option for settings without a LAN box.
- `POST /api/chat` with `stream=true`, `format=ObservationDraftSchema.schema()`, `think: false` (2–3× speedup, no accuracy loss).
- **Sampling preset (structured):** `temperature 0.3, top_p 0.8, top_k 20, min_p 0, presence_penalty 0, repeat_penalty 1.1, seed 42`. **Never use `presence_penalty ≥ 1`** with `format` — it penalises `"`, `{`, `:`, `,` and JSON collapses into pseudo-kv garbage.
- **Streaming transport:** implement `URLSessionDataDelegate.urlSession(_:dataTask:didReceive:)`, buffer, split on `\n`. Do **not** use `URLSession.bytes(for:).lines` — it buffers the whole chunked response on iOS 17/18, so streaming looks broken.
- Stream yields *accumulated* content string on each NDJSON chunk; a regex-based progressive parser extracts tag dimensions as the JSON grows.
- Prewarm the engine on construction (throwaway `/api/chat` call) to amortise cold model load.

### JSON schema (structured output)

```
{
  draft: string (2-4 past-tense sentences),
  tags: {
    transdisciplinaryTheme: enum PYPTheme,        // exactly one
    keyConcepts: array<enum PYPKeyConcept>,
    atlSkills:   array<enum PYPATLSkillCluster>,
    learnerProfile: array<enum PYPLearnerProfile> // maxItems: 2
  },
  confidence: number 0..1,
  evidenceSpans: array<{ tag, quote (minLength 3) }>
}
```

- `additionalProperties: false` at every object level (prevents invented fields).
- **Field order is load-bearing** for progressive streaming — `draft` must be first, then `tags` (with its dimensions in the order above), then `confidence`, then `evidenceSpans`. Re-ordering silently breaks chip-by-chip rendering without breaking final decode.
- `evidenceSpans[].quote` `minLength: 3` blocks one-char "evidence."
- Post-decode normaliser maps `text → quote`, drops items missing `tag` or `quote`. Ollama enforces the top-level shape only; the model still drifts on array items.

### PYP taxonomy prompt

- Compressed, one-line-per-tag, ~2k tokens, educator-facing language (not IB-official wording).
- Structure: **rules → trap example → taxonomy reference**.
- The trap example (*"She was lovely today"* → empty tags, low confidence) is what earns 2/2 on sentiment-only utterances. Without it, the model hallucinates tags on vibes. Any prompt change regression-tests against the held-out corpus.

### Student name extraction (Note + description text)

- Run **locally in Swift**, not in the LLM prompt — avoids the model inventing off-roster names.
- Named-entity pass over the description text → fuzzy match against the selected class's roster (≤30 names), case-insensitive, **Metaphone/Soundex phonetic fallback** for accents and STT misrecognitions.
- Applies to any description, not just Notes — if a teacher's Photo caption reads *"Anna and Maya sorting the leaves"*, the two names are pre-attributed just as they would be from a Note.
- No confident match → open picker with full roster for the selected class, recent-children pinned top.
- When the description text *and* Photo face detection (Feature 2) both fire, agreement is automatic; disagreement surfaces both signals as a teacher-decision moment.

### Performance targets

| Metric | Target |
|---|---|
| TTFT | < 1s |
| Total (transcript → final tags) | < 5s P50, < 8s P95 |
| STT lag after Stop | < 400ms |
| Chip first-render | < 1.5s |

---

## Feature 2 — Photo face detection

**Scope:** face detection runs on **Photo** content-type captures only — photos taken through the in-app camera at capture time. It does not run on library-picked Images (we don't know who was present; a library photo could be historical, a parent's family photo, or a screenshot — teachers attribute Image entries manually). Video face detection is roadmap, not MVP. Other content types (Note, File, Website) obviously have no faces to detect.

**User flow:** Per-child one-time enrolment (3–5 photos, done through the Class tab). At capture time, teacher chooses the **Photo** content type → frames the shot → taps the shutter → faces are detected → each matched face gets a soft *Name Halo* (see signature micro-interactions) labelled with the child's first name; unmatched faces get a yellow `?` halo → teacher taps **File**, photo is routed into each recognised child's portfolio view for the parent feed. `?` halo → picker to attribute manually from the class roster; that attribution can feed future enrolments.

Face attribution is one of two signals that decide which children a portfolio entry reaches. The other is name extraction from description text (see Feature 1 / *Student name extraction*). When both signals exist for the same Photo — a teacher captions the shot *"Anna and Maya with the leaves"* and face detection matches Anna and Maya — they agree and confirm each other. When they disagree, the draft sheet surfaces both sets and asks the teacher to reconcile.

### Pipeline

```
UIImage
  → FaceCropper.fixedOrientation      (bake EXIF rotation into pixels)
  → FaceAligner.alignAll              (VNDetectFaceLandmarksRequest;
                                       similarity transform → 112×112 BGR canvas)
  → MLFaceEmbedder.embed (TaskGroup)  (Core ML MLFeatureValue(cgImage:constraint:))
  → 512-d Float32 unit-L2-normalised
  → IdentityMatcher.bestMatch         (min d² across enrolled vectors)
  → Threshold.label                   (matched / unknown)
  → UI overlay on original photo
```

- Run per-face embedding in a `TaskGroup`. Dispatch the whole pipeline via `Task.detached(priority: .userInitiated)` — Vision/Core ML calls are `nonisolated`; never block the main actor.

### Model

- **AdaFace IR-18** (MIT, VGGFace2 checkpoint for hackathon; WebFace4M for production). Bundled as `FaceEmbedder.mlpackage`, ~45 MB FP16.
- Input: 112×112 BGR. **Normalisation `(x/127.5) - 1` is baked into the Core ML model at conversion time** — Swift just passes a raw `CGImage` via `MLFeatureValue(cgImage:constraint:)`; Core ML handles channel swap + preprocessing.
- Output: 512-d, unit-normalised by the model, re-normalised on our side for API uniformity.
- `MLFaceEmbedder` auto-discovers vector length at load time — swap backbones by dropping a new `.mlpackage` in the bundle + clearing enrolments.
- Neural Engine preferred (confirmed via `revision=1001` log line).

### Storage

```swift
@Model
final class EnrolledIdentity {
    var id: UUID
    var name: String           // mirrors Student.name at enrolment
    var embeddings: Data       // Float32 array, N × 512
    var embeddingCount: Int
    var elementType: Int       // VNElementType.float.rawValue = 1
    var vectorLength: Int      // 512 for AdaFace IR-18
    var updatedAt: Date
}
```

- **Separate `ModelContainer`** from the rest of the app.
- `ModelConfiguration(..., cloudKitDatabase: .none)` — never sync embeddings.
- File protection `.completeUntilFirstUserAuthentication`.
- `CustomStringConvertible` returns dimensions + `updatedAt` only; never the raw bytes.
- ~10 KB per child; negligible.

### Enrolment rules

- 3–5 photos via iOS `PhotosPicker` (`maxSelectionCount: 5, matching: .images`).
- One face per photo (largest + warn if multiple; skip + warn if zero).
- Quality heuristic: compute pairwise d² across the N reference embeddings; if any pair > 2× median, warn *"these photos look very different — recapture?"* (warn, don't block).
- Photos held in memory only. Released as soon as the embedding is produced.

### Threshold

- **Pick per-corpus**, don't hard-code. Algorithm: sweep `linspace(min(d²), max(d²), 200)`, pick the largest threshold with `FP = 0` and `TP > 0`; ties break to smaller (conservative).
- Stored in a `Configuration` entity, not in code — allows A/B.
- Experiment reference value: `d² = 1.48`; real app must re-pick on real corpus.
- **`VNFeaturePrintObservation.computeDistance` returns squared Euclidean** — label everything `d²` (not `L2`) across columns, UI chips, and logs. A new distance metric means re-auditing this.

### Correction & re-enrolment

- Wrong match → "Not `<name>`" → picker. Correction stored; model is **not** retrained in MVP.
- After 3 corrections on the same child, suggest re-enrolment.
- Recommended cadence: termly (3×/year for nursery). Soft nag after 4 months.

### Performance targets

| Metric | Target | Measured |
|---|---|---|
| Cold model load | < 500ms | ~200ms (iPhone 15 Pro) |
| Per-face embed | < 100ms | ~50ms |
| 3-face end-to-end | < 500ms | P50 29ms, P95 60ms |
| Bundle size | < 60MB | 45MB |

### Known limits (Q&A-ready)

- Public face-ID models are trained on adults; accuracy on under-5s is lower. Answer: termly re-enrolment + low-friction `?` chip. **Never pitch 95% recall**; pitch *"auto-matches most, chip for the rest."*
- Profile / occlusion / strong lighting mismatch degrade accuracy. Chip flow *is* the feature, not a failure.
- "Zero false positives" is a property of the chosen threshold on the chosen corpus, not a guarantee.

### UX surface for face ID

The match view is the **Name Halo** (see signature micro-interactions). Below the photo, a row of small avatar bubbles shows every child the app thinks is in the frame. Unmatched faces show as avatar bubbles with a dashed yellow outline and a `?` in place of the name.

**Enrolment flow tone.** Enrolment is a moment where the app asks the teacher to do real work (take 3-5 photos of a child). The copy should read as collaborative: *"Let's teach the app what Amara looks like."* Not *"Enrol biometric identity."* The enrolment screen is a single card with a big photo well and a count (*"2 of 5 photos added"*) rather than a form. The quality warning ("these photos look very different — recapture?") is framed as a suggestion with a *"use them anyway"* escape hatch, because the teacher knows the child and the app doesn't.

**Enrolment empty state.** A child with no enrolled face in the roster shows a soft warm placeholder avatar and the tap-target *"Add photos so Amara gets tagged automatically"*. This is the only surface that nags; it never nags in capture flow, because a teacher who's capturing can't stop to enrol.

**Re-enrolment nag.** After three corrections on one child, the next time the teacher opens that child's page, a gentle card appears at the top: *"Amara's looking a little different lately — want to refresh their photos?"* Dismissable for a week. Never blocks capture.

---

## Feature 3 — Child Voice

**Why it matters:** every competitor treats the child as a *subject*, not a contributor. Adding child voice cleanly is both a pedagogy story and a compliance-readiness signal — the single sharpest differentiator for parent-facing pitch.

**Scope:** child voice is an **attachment**, not a content type. It can be attached to **any** portfolio entry — a Note reflecting on what just happened, a Photo of the water tray, a Video of a block tower, a File containing a scan of the child's drawing, a Website the child wanted to share, or a standalone reflection Note created just to hold the child's voice. The *"Attach <child>'s voice"* action appears on the draft sheet of every type as soon as at least one child is attributed to the entry.

### Capture flows

**Embedded (the common case)** — immediately after capturing any type, while the draft sheet is open, tap **"<name>'s voice"**. Pass phone to child. Record ≤ 30s of their own narration. Audio attaches to the current in-progress entry.

**After the fact** — open any already-filed entry from Today or the child's portfolio, tap the *"Attach <child>'s voice"* action at the bottom. Recording attaches to the existing entry and re-publishes. Useful when the child is not nearby at capture time but wants to add their voice at group-reflection time later.

**Standalone** — create a new entry (typically a Note) whose whole purpose is to hold the child's voice. The Note text can be empty; the child's voice *is* the content. These appear in the parent journal with the *"In Amara's words"* treatment and no teacher narration on top.

### Safeguarding as respect, not compliance

Every safeguarding feature in this section is a compliance requirement, but the *framing* of each one in the UI is that the app is on the child's side. Punitive tone here reads as the app distrusting the teacher; the teacher disengages; child voice stops happening. So:

- **Ask the child, not the app.** The "second tap" is a button labelled *"Amara said yes"* rather than *"Confirm consent"*. The teacher is mediating the child's assent to being recorded, which is true to the pedagogy of PYP voice-and-agency. The gate is identical to a compliance second-tap; the framing teaches.
- **The child holds the mic.** When the child-voice flow starts, the app visually hands over — the record control slides into the centre of the screen, the teacher chrome dims, the button grows ~1.4× and shows a cartoon microphone glyph instead of the teacher's dot. This signals to any adult watching (parent, inspector, another teacher) that the child is the subject. It also signals to the child that *this is for them*.
- **Moderation queue, but not as a gate.** Child voice clips land in the **Review** queue with a distinct chip — *"In Amara's words — needs a quick listen"*. The teacher re-listens before publish. This is framed as *"quick listen"* rather than *"approval"* — a ritual of care, not a censorship step. The teacher can publish without re-listening, but the UI nudges them to do it. A publishing teacher who skipped the listen sees a faint *"Published without review"* tag on the entry in their own Review history — their record, not shared with the parent.
- **Retention** — configurable per setting; default *"until the child leaves the school"*, with an explicit family-initiated delete option. The delete option is surfaced in the parent's **About <child>** tab as *"Remove Amara's voice recordings"* — not buried in settings. The setting's retention default is shown to parents at pairing time in plain English, not as a policy PDF.
- **Transcription is opt-in per setting.** Some safeguarding leads will want audio only, no searchable text. The choice is presented at setting setup as *"Do you want to transcribe what children say?"* with a one-sentence explanation of the tradeoff (*"searchable for you, and translatable for parents, but the child's exact words live in text as well as audio"*).
- **Parent-consent affirmation** logged (timestamp, not the audio) at pairing and surfaced to the teacher at capture time. A teacher about to record child voice for a child whose parent hasn't consented sees the button **disabled** with a one-line note: *"Amara's parent hasn't ticked this yet — want to ask them?"* and a share-link shortcut to re-send the consent prompt. This is the compliance enforcement; framing it as *"want to ask them?"* keeps the teacher in the loop rather than hitting a wall.
- **Every safeguarding action is reversible.** A published child-voice clip can be un-published from the journal entry; a retained clip can be deleted; a transcribed clip can have its transcript hidden. Reversibility is itself a safeguarding feature — it's how the app respects the fact that a three-year-old's assent today is not the same as their assent at seven.

### Parent-side highlight — "In Amara's words"

Child voice is the feature that, more than any other, makes the parent cry. The treatment has to earn that.

- A child-voice clip renders as a pull-out card sized larger than the surrounding teacher-observation card, with the child's avatar on the left and the waveform as a soft horizontal pulse, not a spiky audio-editor trace. The header reads *"In Amara's words"* in the app's accent colour. There is no *"Play"* button — tapping anywhere on the card plays inline, with a circular progress ring around the avatar.
- Clips autoplay **only** when the parent has explicitly scrolled them into full view and held there for 1.5s. Never on open. Never on notification. A parent at a bus stop does not want their child's voice broadcast from their phone.
- Transcripts appear under the waveform in italic, slightly smaller, in the child's exact words (not cleaned up). Misrecognitions are left in place — the imperfection is the point. Long-press reveals the untranslated source if the parent is reading a translation.
- Per-guardian locale translation of transcripts (if opt-in) is a rendering concern, not a data concern — **the untranslated transcript is the source of truth**.

### Scope cuts for MVP

- **No speaker diarisation** in teacher+child mixed recordings. The teacher narrates one thing, the child narrates another; they are separate recordings on the same entry.
- **No on-device retraining.** Face-ID corrections are stored but don't improve models yet.
- **No child voice on Video.** A Video already carries audio; a separate child-voice attachment on a Video is confusing. If the teacher wants the child's voice in the recording, they just record the child; attachment is blocked at UI level for Video captures. (Can be revisited.)

---

## End-of-day review queue

Captures during the day are intentionally fast and forgiving; the trade is that most of them land as *drafts* rather than published entries. The **Review** tab is where a teacher closes the loop at the end of the session — usually a 10-minute window while children are napping or being picked up.

### Design intent

Reviewing is the only part of the day where the teacher is *at a desk*, so Review is the one surface that can afford slightly higher density. But the register is still calm: a reading list, not an inbox. Each draft is a card; cards stack vertically in chronological order; the teacher works top-to-bottom and the queue empties.

### Card anatomy

Each draft card is **type-aware** — it renders whichever content the entry holds. In order:

1. **Type pill** — a small pill at the top-left: *"Note"*, *"Photo"*, *"Image"*, *"Video"*, *"File"*, *"Website"*. Single-word badge. This anchors the teacher's mental model of what kind of thing they're reviewing.
2. **Hero** — the entry's content, rendered appropriately:
   - **Note** — the dictated/typed text as the hero, in the warm serif reading style. Tappable; long-press to edit inline.
   - **Photo / Image** — the image full-width and tall enough to recognise the child.
   - **Video** — the poster frame with a play affordance; tapping opens the inline player.
   - **File** — a document thumbnail (first page preview for PDFs, generic file glyph otherwise) with the filename beneath.
   - **Website** — the favicon, page title, and host, rendered as an Apple-Messages-style link preview.
3. **Description** — the description text below the hero (Note entries have no separate description because the hero text *is* the description). Tappable; long-press to edit inline.
4. **Chip row** — the four PYP dimensions, chips tappable to edit (tap to remove, `+` to add from a dimension-scoped picker). Confidence is shown as a soft word ("worth a check", "pretty sure"), not a number. Appears only if the description has text.
5. **Attributed children** — avatar row of every child attached (face detection + name extraction union). A child can be removed with a swipe on their avatar.
6. **Child voice badge** — if a child-voice clip is attached, a *"In Amara's words — 18s"* strip with inline play.
7. **Action row** — **Publish**, **Save for later**, **Delete**. Publish is the primary button. Delete confirms.

Filtering: a small type-filter strip at the top of Review (same icons as the Capture type strip) lets the teacher scope Review to a single type if the day produced a lot of one kind of entry — e.g. *"just review today's Photos"*. Default is everything.

### Bulk publish, gentle

A small *"Publish all ready"* button at the top of the Review tab publishes every draft where the teacher has at least looked at the card (tracked by scroll-into-view for ≥ 1s). Drafts the teacher hasn't looked at are skipped — the bulk button never publishes unseen work. A confirmation toast says *"Published 7 moments from today"*; no modal.

**Tradeoff flagged:** bulk publish is fast but weakens the *"teacher reviewed each one"* claim. We mitigate with the scroll-into-view gate, but accept that a teacher scrolling fast will publish lightly-reviewed drafts. We believe this is still better than fully-unreviewed captures auto-publishing immediately — a deliberate MVP choice to put the queue between capture and parent.

### Empty state

*"Nothing to review. Nice work today."* with a small illustration. This is the only surface in the app that says "nice work" to the teacher. It matters.

### Pending-retag items

Drafts captured offline have a soft *"Tags catching up…"* banner on the card; tapping the card locally re-runs tagging if LAN is now available. The teacher never has to think about which are pending — they're interleaved chronologically with everything else.

### Corrections as a dialogue, not labour

When a teacher changes a tag, fixes a misidentified face, or edits a transcript, the app treats it as *teaching*, but never asks the teacher to confirm that framing. No *"Thank you for the correction!"*, no "training" language. The correction just takes effect, with a soft undo available for 10s.

Under the hood (post-MVP), corrections accumulate as per-setting signal for prompt adjustments and re-enrolment prompts. A teacher is never told their corrections are *"improving the model"* — the benefit accrues silently. The perception is that the app got a little better; the teacher is not doing data-labelling work for free.

**The one exception** is face ID re-enrolment: after three corrections on one child, the app asks once, explicitly, with the *"Amara's looking a little different lately"* copy. That's the only place the correction loop is visible.

---

## Parent experience

The parent role is quieter software than the teacher role — a different skin and a different register on top of the same app, not a different product. It exists to make a parent feel their child is seen. Everything below is in service of that.

### The journal

Default view: reverse-chronological feed of **moments**, each moment a card. A moment is a parent-side rendering of a portfolio entry that includes their child (attributed by face detection, name extraction, or manual tag). Cards are large (one at a time fills most of the screen on an iPhone 15), because a parent reads slowly and emotionally, not like a social feed. No infinite scroll pagination UI — just more cards as they scroll, no *"Load more"*.

Cards are **type-aware** on the parent side too — different content types get different hero treatments, but the overall card shape and register are consistent so the feed reads as *one stream of Amara's week*, not six separate streams:

- **Note (text observation)** — the teacher's narration as the hero, rendered in the warm serif. No top image; the text breathes.
- **Photo / Image** — the image full-bleed at the top, the teacher's description (if any) beneath it in the same warm serif.
- **Video** — the poster frame with a soft play affordance at the top, description beneath. Video plays inline with tap, never autoplays.
- **File** — an opening-page preview (PDFs) or generic doc glyph with the filename, description beneath. Tap to preview in Quick Look. Parents can download a copy.
- **Website** — a rich link preview (favicon + title + summary) at the top, description beneath. Tapping opens the URL in in-app Safari, not the system browser, so the parent returns to the journal on close.

Every card also contains:

- **Attribution** — *"— Priya, Thursday morning"*: teacher's first name, relative time.
- **Chips** — the PYP tags below, styled as soft pills in the taxonomy's colours. Tapping a chip opens a one-screen explainer: *"'How we express ourselves' — one of six frameworks the nursery uses to describe learning. This means Amara was using creativity, language, or art to share something."* This is the parent's first exposure to PYP; the explainer must be in plain English, not IB-official wording.
- **Child voice** — if a clip is attached, the pull-out card described in Feature 3 sits below the chips. A **standalone child-voice entry** (a Note whose content is just the voice) promotes the voice card to the hero position — no teacher narration on top, just the child's ring.
- **Like** — a small *"Like"* heart at the corner of the card. Taps send a private signal to the teacher — not public, not shared with the child — that the parent saw and appreciated this moment. The teacher sees hearts aggregated on their Review tab, not per-moment live, to avoid performance anxiety.

### Notifications, anti-fatigue

Parents should hear from the app often enough to feel connected, rarely enough to not silence it.

- **Daily digest, not per-capture.** A single push at the end of the setting's day (configurable per setting, default 17:00 local): *"3 new moments from Amara today."* Tapping opens the feed at the top.
- **Child-voice clip → its own quieter push.** *"Amara wanted to tell you something."* This push is per-clip, never batched, because it's the high-signal moment the parent should open the app for.
- **No push on tag changes, edits, re-tags, corrections.** The parent never sees *"Priya updated a moment from Tuesday."* — that's teacher plumbing.
- **No engagement nags.** The app never pushes *"You haven't opened TinySteps in a week"*. A disengaged parent is still the parent; we do not chase.

### Multi-language households

The setting operates in one or more languages; the family might speak a different one at home. The parent's locale picker allows **multiple target locales** — a household where one parent speaks English and the other Urdu can set both, and transcripts render with a small language toggle chip per card.

- Translation happens on-device via Apple's Translation framework where available, with the untranslated source always one long-press away.
- The **child-voice clip transcript** is never auto-translated. A child's own words in their own language belong to the child; the parent sees the original, and an opt-in *"Translate this"* button appears beneath. This is both a pedagogical choice (the child's language is the child's) and a safeguarding choice (translation can change meaning, and the record-of-truth is the original).
- If a transcript has a code-switch that the translator cannot handle (common in the corpus — *"counted them in Somali and English"*), untranslated spans are rendered in italic with a subtle underline; tapping shows *"This part of what Amara said wasn't translated — their teacher left it in the original."* This turns a translation limit into a moment of cultural recognition.

### Multi-guardian, per-guardian

One child may have multiple guardians — co-parents, grandparents, a key worker at an external agency. Each gets their own CloudKit share + locale + consent posture. A grandparent's instance never needs to see a field that says *"grandparent"* — from their perspective they are *a* guardian.

Deletes are scoped per-guardian on *their* device, never cascading to the child's journal globally. Only the setting's teacher (and the nominal primary guardian, post-MVP) can delete from source.

### Export and delete

**Export** lives at the top of **About <child>**. One tap produces a PDF (for printing or email) + a JSON file (for future portability), zipped and shared via the OS share sheet. The PDF is designed — it's a *yearbook page* feel, not a compliance dump. Photos, transcripts, chips; no latency badges, no confidence scores, no internal IDs.

**Delete my child's data** is surfaced in the same view, one tap, confirmed with the child's first name typed in. This is the one confirmation-by-typing in the entire app — because deletion is the one truly irreversible act. Delete removes the child's record from the parent's local store and triggers a signed request to the setting to delete server-side; the teacher sees a Review card the next day: *"Amara's family has asked for their data to be removed. Confirm?"* with setting-policy guidance.

Embeddings are **never** part of export (enforced by unit test; see privacy invariants).

### Parent empty states

- **Pre-pairing**, even after install: a single card *"Let your setting know you've installed the app — they'll send you an invite."* with a *"How do I get an invite?"* link that opens a plain-language page.
- **Paired, zero observations**: *"Amara's journey starts here"* + enrolment photos as a quiet montage.
- **Paired, last observation was > 7 days ago**: no visible state change. We do not suggest the teacher is late. The parent knows their child was at the setting; we trust that.

---

## Empty, loading, and permission states

A survey of the states the app actually lives in day-to-day. These are often shipped as afterthoughts; naming them up front keeps them from being afterthoughts.

### Empty states

| Surface | State | Treatment |
|---|---|---|
| Teacher **Today** tab, zero captures | Morning, pre-capture | Big record button, ghost hint *"Hold the button and describe what you saw"*; no illustration. |
| Teacher **Review** tab, zero drafts | After a publish sweep | Single illustration + *"Nothing to review. Nice work today."* |
| Teacher **Class** tab, zero children | New setting, no roster yet | Onboarding checklist card at top: *"Add children to start capturing"*. |
| Child page, zero enrolment photos | Never enrolled | Soft avatar placeholder + *"Add photos so Amara gets tagged automatically"*. One tap opens `PhotosPicker`. |
| Child page, zero observations | New child | *"Amara's journey starts here."* — mirrors parent-side copy. |
| Parent journal, zero observations | Paired, pre-first-observation | Enrolment photo montage + *"Amara's journey starts here"*. |
| Parent journal, zero observations, > 1 week | Setting quiet | Identical to above. We do not shame the setting. |

### Loading states

- **STT partial transcript** renders live as it arrives; no loading shape — the text itself is the loader.
- **Tagging (~4s)** uses the Chip Bloom pattern described above. No spinner.
- **Face ID (~500ms)** uses the Name Halo pulse as both loading and terminal state — the halo pulses once on match, dims on settled.
- **Journal scroll**: cards skeleton-render with the hero photo area as a soft blur of the dominant colour once the image loads low-res, then resolve to full-res.

### Permission states

Permissions are requested *just in time*, not front-loaded:

| Permission | Requested when | Denial behaviour |
|---|---|---|
| Microphone | First Note record tap (or first *"dictate description"* on any non-Note type) | Inline error on the capture surface: *"I can't hear anything — check Settings > TinySteps > Microphone."* Text fallback becomes primary. |
| Speech recognition | First record tap (same prompt as mic) | Same inline error; text fallback works. |
| Camera | First **Photo** or in-app **Video** capture | Inline; the Photo / Video type icon in the Capture type strip shows a small lock glyph with *"Turn on Camera in Settings to take Photos."* |
| Photo Library | First **Image** or **Video**-from-library pick, or first face enrolment photo selection | Inline; the picker sheet shows an empty state with a deep-link to Settings. |
| Files (document picker) | First **File** attachment | System picker handles its own permission prompt; no app-side error. |
| Notifications (parent role) | After first moment lands | Soft ask with *"We'll let you know when there's a new moment from Amara — once a day, never more."* Denial: the app works silently. |

No permission wall on launch. Ever.

### Error states

- **Mic unavailable / no speech detected** — inline, warm tone: *"I didn't catch anything — want to try again, or type it?"* Tap-to-type opens the text fallback.
- **Tagging failed (LAN unreachable)** — draft saves anyway with *"Tags catching up…"* badge. A teacher-facing card on the Review tab surfaces the connection state *"Tagging is offline — reconnect to the nursery wifi to catch up"*. Never modal.
- **Face ID mismatch suspected** (confidence below threshold) — the halo renders in a softer ambiguous colour with a *"Is this <name>?"* tap target that opens a picker. No red, no alert.
- **Child-voice consent missing** — button disabled, as above. Never hard error.
- **Pairing mismatch (wrong child name)** — parent pairing fails closed with *"That doesn't match — please check with your setting."* No retry counter displayed; three wrong attempts locks the code for the setting to re-issue.

---

## Cross-cutting architecture

### App topology

- **Single iOS app, role-driven UI.** One target, one binary, one App Store listing. The role is resolved at sign-in and drives the tab bar (Today / Review / Class for teachers; Journal / About for parents), chrome, and copy register. No per-role build forks.
- **Teacher surface:** Capture tab, enrolment flow, review queue, class roster.
- **Parent surface:** per-child journal timeline, child-voice spotlight, export.
- **Role determination:** a join code (teacher) or a CloudKit share link + backup code (parent) establishes the account's role at pairing time. Roles are per-account, not per-device — a dual-role user (e.g. a teacher whose child attends the same setting) signs in with two accounts on one device and uses the in-app role chip to switch.
- **Shared backbone:** SwiftData locally, CloudKit sharing per child for parent visibility. Teacher-only data (face-ID embeddings, class roster, setting config) lives in a zone not shared to parents.
- **Face ID uses its own `ModelContainer` with `cloudKitDatabase: .none`** — embeddings never sync. The parent role has no code path that addresses this container. Portfolio entries of every content type use the main CloudKit-shared container.

### Privacy invariants (code-level, load-bearing in Q&A)

1. Audio is never persisted or transmitted. On-device STT only.
2. Transcripts leave the device **only** over the setting's LAN, **only** to a server the setting owns.
3. Face embeddings are `Data`, stored locally, never `Codable` into any export, never in CloudKit.
4. No raw embeddings in logs. `CustomStringConvertible` exposes dimensions + `updatedAt` only.
5. No telemetry / MetricKit / third-party SDKs on STT, drafting, or face-ID subsystems.
6. Debug `print` calls wrapped in `#if DEBUG` before shipping.
7. **Embeddings excluded from export** — enforced by a unit test that round-trips a fake family and asserts no `embeddings` bytes in the JSON or PDF output.

These live as verbatim comment blocks at the top of `SpeechTranscriber.swift`, `OllamaDraftingEngine.swift`, `EnrolledIdentity.swift`, `ModelContainer+FaceID.swift`.

### Offline behaviour

- STT works offline (on-device).
- Face-ID works offline (on-device).
- LLM tagging requires LAN reach to the Ollama box. Offline capture stores `draft = transcript`, `tags = empty`, `confidence = 0`, `pendingRetag = true`; background task re-tags when connectivity returns. Visible badge in the journal.

### Error states

- Mic permission denied / no speech → inline error with underlying recogniser message.
- Ollama unreachable → visible error with `NSURLError` text; retry on next record.
- Schema decode failure after normaliser → prefix of raw body in error (≤500 chars); indicates prompt/model regression.
- Zero faces in photo → fallback to single-child picker.

---

## Voice, copy, and accessibility

### Copy register

One writer should own all user-facing strings in the app. A sample lexicon to anchor the register:

| Instead of | Write |
|---|---|
| "Create a new observation" | "Record what you saw" |
| "Tag selection" | "What was this about?" |
| "Confidence: 0.82" | "Pretty sure" |
| "Biometric enrolment" | "Teach the app who Amara is" |
| "Consent required" | "Amara's parent hasn't ticked this yet" |
| "Delete this record?" | "Remove this moment from Amara's journal?" |
| "Export data" | "Download Amara's journal" |
| "Model unavailable" | "Tags catching up…" |
| "Invalid input" | "Let's try that again" |
| "Permission denied" | "I can't hear anything — check Settings" |

The teacher surface is written for teachers (slightly more direct, task-oriented). The parent surface is written in a warmer, slower register — first person where the teacher speaks, third person everywhere else, child's name often. Same app, different voice.

### Accessibility (beyond VoiceOver notes)

- **Dynamic Type.** All text scales to XXL. No hard-coded font sizes. Card layouts use vertical rhythm that survives re-flow.
- **Reduce Motion.** Honoured app-wide. The Chip Bloom degrades to a cross-fade; the Hold's button swell degrades to a colour shift; the halo's pulse becomes a static outline. None of the micro-interactions *require* motion to convey state.
- **Colour contrast.** WCAG AA as a floor; the child-voice pull-out card and the File primary button are AAA. PYP chip colours are validated against the palette's own backgrounds, not the system default.
- **Voice Control + Switch Control.** Record control is reachable via both. *"Tap Record"*, *"Hold Record"* and *"Stop"* are all labelled commands.
- **Left-handed and right-handed symmetry.** Primary controls are centred. Gesture directions that aren't symmetric (swipe-to-remove a child avatar) are available as an explicit tap affordance too.
- **Hearing-impaired teachers.** The mic-level pulse is primarily visual and always on during recording. Live transcript is the secondary confirmation. No audio-only cues on state changes.
- **Parent accessibility.** In the parent role, the child-voice card shows the transcript with toggleable captions; translation is a first-class feature, not an accommodation. Export PDFs are tagged (accessible structure) so VoiceOver can read them in full.

---

## Tradeoffs we made on purpose

Naming the tradeoffs here so the next reviewer doesn't try to "fix" a deliberate choice.

1. **Single capture surface instead of per-feature screens.** Slower to demo any single feature in isolation; faster for the teacher in the moment. Net: worth it.
2. **Bulk publish with a scroll-gate.** Weakens per-moment review compared to forced-individual publish; faster end-of-day sweep. Mitigated by the scroll-into-view check; accepted.
3. **Name Halo instead of bounding rectangle.** Slightly less precise for ambiguous faces; massively warmer. Long-press reveals rectangle for the rare case it matters.
4. **Typed child-name confirmation at parent pairing.** One extra step during onboarding; structural prevention of wrong-child pairing. Accepted — safeguarding.
5. **Four-second tagging shown as Chip Bloom, not spinner.** Doesn't hide latency, turns it into pacing. Risks feeling "slow but deliberately so"; we prefer this to "the app froze for a moment".
6. **No engagement-style push notifications for parents.** Lower engagement metrics; higher trust. The app is not a social app.
7. **Corrections are silent.** The teacher doesn't feel like a data-labeller; the "the model learns" story is harder to pitch to buyers. Accepted — the teacher's daily feel wins over the sales deck.
8. **Child voice transcripts auto-translate = off by default.** The parent sees the child's actual words in the child's actual language. Slightly less accessible across language gaps; much more honest.
9. **No settings tab.** Power users can't reconfigure; new users don't get buried. Accepted — this is a deliberate Apple-shaped choice, not a Pro-app choice.
10. **Six content types surfaced as peers on the capture surface.** Adds a decision step for teachers who only ever use Note; costs vertical space on the capture screen. Burying the non-Note types behind a *"+"* menu would be kinder in the short term and wrong in the long term — the portfolio concept requires the teacher to know they can include a drawing, a link, a document. Accepted.
11. **Class picker is always on — even for single-class teachers.** Wastes a few pixels of header for the ~60% of teachers who teach one class. Accepted because the class is the scope of the portfolio; hiding it in a single-class case would make the multi-class case feel like a surprise *"new thing"* the first time it appears, instead of a natural switch.
12. **Face detection runs on Photo only, not on Image (library pick).** The library could technically be run through face ID too. We don't: a library photo is context we don't have — it could be historical, a parent's family photo sideloaded for context, a screenshot of a worksheet. Running face ID on ambiguous inputs degrades the precision of the matched set. Teachers attribute library Images manually. Accepted.
13. **No child-voice attachment on Video.** A Video already carries audio; a separate child-voice attachment on a Video is confusing to both the teacher (which audio is "the child"?) and the parent. Blocked at UI level for Video entries. Can be revisited post-MVP.

---

## Engineering gotchas — do not rediscover

These cost ~15+ engineering hours each in the experiments.

1. **MLMultiArray FP16-as-FP32 reinterpret.** FP16-compiled Core ML models report `dataType == .float32` but store half-floats. `dataPointer.assumingMemoryBound(to: Float.self)` returns bit-garbage with structural zeros in the first few dimensions. **Rule:** always read via `mlArray[i].floatValue`; no pointer casts.
2. **`CIImage` + Vision landmarks are bottom-left origin.** Stay bottom-left end-to-end. No post-y-flip on outputs. Canonical anchors flipped to bottom-left at compile time.
3. **`URLSession.bytes(for:).lines` buffers the full chunked response on iOS 17/18** — one callback at end, streaming appears broken. Use `URLSessionDataDelegate.didReceive(data:)` + manual `\n` split.
4. **Swift 6 MainActor + AVFoundation/Speech callbacks = `unsafeForcedSync` trap.** Speech/audio subsystems must be `nonisolated final class` with `OSAllocatedUnfairLock<State>`. Don't put `@Observable` on them. Don't use `NSLock` in async code — banned.
5. **`presence_penalty ≥ 1` breaks structured JSON output.** Penalises `"`, `{`, `:`, `,`. Use the structured preset (`presence_penalty = 0`) with `format`.
6. **iOS Simulator CoreAudio reconfig loop** — mic tap installs but never delivers buffers. Sim-only. Use text fallback on sim; validate voice on real device.
7. **`requiresOnDeviceRecognition = true` on unsupported devices = silent zero output.** Gate on `recognizer.supportsOnDeviceRecognition`.
8. **Xcode 16 file-system-synchronized groups flatten the bundle.** `Bundle.url(..., subdirectory:)` returns nil even if the file is bundled. Keep resources at bundle root.
9. **Schema field order is load-bearing for progressive streaming.** `draft` before `tags` before `confidence` before `evidenceSpans`. Re-ordering silently breaks chip-by-chip animation without breaking final decode.
10. **`VNFeaturePrintObservation.computeDistance` returns squared Euclidean (d²), not L2.** Label consistently everywhere; re-audit on any metric/model change.
11. **Ollama `format` enforces top-level shape only.** The model still drifts on array items (`text` instead of `quote`; missing fields). Keep a normalisation pass.
12. **`coremltools` can't convert `raise` / `assert` from scripted PyTorch models** (PReLU / BN training-mode checks leak into the graph). Fix: `jit.freeze` + `optimize_for_inference` collapses those branches before re-tracing.
