# TinySteps — Hackathon priorities

**Demo:** Wednesday 2026-04-22. **Time remaining at writing:** ~2 days.

Anchored to the demo narrative, not the full spec. `docs/requirements/app-feature-spec.md` is the product direction; this document is the narrow slice that makes the direction credible on stage.

---

## The demo narrative (60–90 seconds)

A teacher, on stage, selects *Nursery Red* from the class picker. Holds the record button → narrates *"Amara and Maya built a tower of six blocks…"* → releases → PYP chips bloom. Switches to Photo → takes a shot → two Name Halos resolve to Amara and Maya, one yellow `?` for an unenrolled child. Attaches Amara's voice — child says *"I built it tall"*. Files. Flips to a parent-preview → Amara's journal shows the moment, teacher narration, chips, Amara's voice pull-out.

Everything below serves that 90 seconds.

---

## P0 — must demo, story breaks without it

- **Class picker** with two hardcoded classes. Not a full admin flow; enough to show the portfolio-per-class concept.
- **Capture surface** with a type strip. Only two types actually work: **Note** and **Photo**. The other four icons are visible (Image, Video, File, Website) but disabled with *"coming soon"* — they prove the portfolio concept without stealing build time.
- **The Hold gesture** — walkie-talkie press-and-hold driving STT → Ollama → PYP tags. This is the whole of Feature 1. Already validated in `Experiments/VoiceTranscript`; port the wiring.
- **Chip Bloom** animation. Skeleton chips in canonical order, bloom on dimension close. This is the 4-second perception fix and is what makes the latency feel like pacing.
- **Photo → face detection → Name Halo** for enrolled children. Three demo children with 3–5 enrolment photos each, baked into the build. Already validated in `Experiments/FaceTagging`.
- **Unknown face → yellow halo → tap to assign from roster**. The *"failure case is a feature"* moment on stage.
- **Child voice attachment** on the draft sheet of the current entry. Embedded flow only (pass phone to child, record ≤30s, attaches). No moderation queue — the teacher just files.
- **Parent preview** as a modal or segmented toggle, not a real parent role. Shows the entry rendered as a parent card with the *"In Amara's words"* treatment.
- **In-memory persistence** is fine. SwiftData if easy; skip CloudKit entirely.

---

## P1 — makes the demo more credible if time allows

- **Name extraction from the Note transcript** → pre-attributes children before face ID runs. This is the "both signals agree" moment; it's cheap (fuzzy match + Metaphone, already specced) and lands well.
- **Tap-to-edit chips** (remove one, add one from a dimension picker). Proves *"the teacher has final say"* in Q&A.
- **Confidence line** ("pretty sure" / "worth a check" / "I might be off here") beneath the chip row.
- **Review tab** with a single bulk-publish button. Can be a one-screen stub. Even a crude version sells the end-of-day story.
- **One extra content type wired end-to-end** — Website is cheapest (paste URL, show link preview, run auto-tag on a typed description). Proves the portfolio concept isn't vaporware.
- **Text fallback** on the Note type (type a transcript, skip STT). Critical stage-safety if the venue mic is noisy.
- **Ollama prewarm + version probe** on app launch. Prevents the first-capture cold-load from eating 20 seconds on stage.

---

## P2 — roadmap talking points, not built

Name them in the pitch, don't build:

- Multi-guardian / multi-class / dual-role switching.
- Multi-language translation, code-switch handling.
- Digital passport export (PDF/JSON).
- File, Video, Image (library pick) content types.
- Onboarding, join codes, share links, pairing gate.
- Moderation queue, consent affirmations logged.
- Notifications / daily digest.
- Offline retry queue (`pendingRetag`).
- Settings, re-enrolment nags, correction accrual.
- Dual-role in-app chip.
- CloudKit sharing — parents see nothing real until post-hackathon.

---

## Explicit non-goals for the hackathon

- **No real parent account or device.** Parent preview is faked.
- **No auth, no sign-in.** The app opens straight into the teacher view.
- **No admin setup flow.** Classes and roster are baked into the build.
- **No persistence across app launches.** Captures live in memory.
- **No speaker diarisation, no on-device retraining, no federated anything.**
- **No polish on non-demo surfaces.** Class tab and enrolment flow can be crude.

---

## Risks + hedges

| Risk | Hedge |
|---|---|
| Venue LAN flaky → Ollama unreachable | Bring a travel router; rehearse on it; show the `Tags catching up…` fallback as a *feature*, not a failure |
| First-capture cold-load > 10s | Prewarm on app launch; keep Ollama box warm between rehearsal and demo |
| Face ID false positive on stage | Use three known-good demo photos rehearsed end-to-end; avoid novel lighting |
| iOS Simulator mic dead | Demo on real iPhone 15 Pro, not the sim. Keep the text fallback wired for absolute safety |
| Stage audio drowns narration | Bring a Lavalier; rehearse at venue noise level |
| Child voice clip doesn't play back | Test playback on the demo device; don't trust that recording and playback both work if only recording was tested |

---

## The one thing to build first tomorrow morning

The **capture surface with Note + Hold + Chip Bloom end-to-end**, rendering against the real Ollama box. If that's solid by midday Tuesday, everything else is additive. If it's not, the demo has no core, and every other feature is stranded.
