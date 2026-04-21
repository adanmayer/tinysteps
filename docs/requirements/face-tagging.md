# Face Tagging — Feature Requirements

**Feature:** On-device face identification for auto-routing a photo to each child's journal.
**Demo beat:** Research §8 Beat 2 — *"one photo, three children"*.
**Status:** Architecture validated in `Experiments/FaceTagging` (see `docs/experiments/results/exp-02/README.md`).
**Owner:** TinySteps engineering.
**For:** Hackathon demo, Wednesday 2026-04-22.

---

## 1. Purpose & positioning

A teacher takes one photo at the water tray. Three children are in frame. The app detects each face, identifies who it is, and files the photo into each child's journal with one tap. Visibly labelled: *"runs on the device — faces never leave the phone."*

Beat 2 exists to make one concrete, on-stage claim: **the GDPR-compliant on-device face-ID the research brief calls out as an unfilled white-space (§4 gap #10) actually works on a real iPhone**. This differentiates TinySteps from every US cloud incumbent and the one EU competitor (Famly) that doesn't attempt this at all.

The feature is load-bearing for the pitch in two ways:
1. **Labour saver.** Manual child-tagging is the second-largest observation friction after typing itself (Beat 1).
2. **Privacy proof point.** Showing AI running on the device, visibly labelled, is the clearest evidence that the "EU-native, GDPR-first, on-device ML" posture is real and not marketing.

Both framings must survive demo Q&A.

---

## 2. Demo storyboard — what happens on stage

From research §8 Beat 2, made concrete:

1. Teacher (on stage, live) opens the app, **Capture** tab. Takes one photo of the water tray. Three children in frame.
2. The photo appears with three green rectangles, each labelled `<name>  d²=<value>` for matched faces. Unmatched faces get a yellow rectangle with a `?` chip.
3. Teacher taps **File**. The app visibly routes the photo into each recognised child's journal.
4. For any `?` face: teacher taps the chip, picks the child from a short picker. Next time that face appears, the system should get it right.
5. Toggle **Show origin** (optional): a small on-screen badge confirms `on-device · AdaFace IR-18`. No network traffic during the entire flow — demonstrable via Airplane Mode on (Beat 4).

**Integration with other beats:**

| Integration | Touch point |
|---|---|
| Voice observation (Feature 1) | Filing a photo attaches it to the in-progress observation for each named child. |
| Multi-guardian sharing | Only guardians with read access to a given child see that child's filed photo. Face tagging is blind to guardian permissions — enforcement is at the `CloudKit share` layer. |
| Offline behaviour | The whole face-ID pipeline runs offline. Filing works; sync to guardians is queued until reconnect. |
| Data export | **Embeddings NEVER in the export.** Filename references only. Enforce via code review. |

---

## 3. Privacy invariants (non-negotiable)

These live as comment blocks at the top of `EnrolledIdentity.swift` and `ModelContainer+FaceID.swift`, verbatim:

1. **`EnrolledIdentity.embeddings` is `Data`, stored locally only.** Not `Codable` into anything that leaves the device. No JSON export of this field anywhere.
2. **SwiftData store uses `.completeUntilFirstUserAuthentication` file protection.** Explicit at `ModelConfiguration` / store URL level.
3. **No CloudKit on this entity.** `ModelConfiguration(..., cloudKitDatabase: .none)`. Never add iCloud capability for the face-ID model container, even when the rest of the app syncs via CloudKit.
4. **No logging of raw embeddings.** `CustomStringConvertible` returns dimensions + `updatedAt` only — never the bytes. `Logger` calls log durations and shapes, never values.
5. **No analytics on the face-ID subsystem.** No MetricKit, no third-party SDKs, no telemetry pipe. The metrics harness from the experiment does not ship.
6. **Photos picked for enrolment are held in memory only.** No copy into the app container beyond the embedding. `UIImage`/`CGImage` is released as soon as the feature print is produced.

**Compliance framing for Q&A:**

- **"What about GDPR / DSGVO?"** — Face embeddings are biometric data under GDPR Art. 9. On-device storage means the app is not the data controller for transfer purposes; no lawful-basis analysis needed for processing we don't do. Parent consent is still required for enrolment (same UX flow as adding a child to the setting). EU Data Act §35 portability obligation is met — the digital passport exports observations + photos; embeddings stay out per invariant 1.
- **"What about the Biometrics-on-children rule?"** — We never send biometric data off-device. The only defensible posture under EU interpretations.
- **"Apple Intelligence / Private Cloud Compute — do you use it?"** — No, this feature runs against a bundled Core ML model. No routing to Apple servers.

---

## 4. Functional requirements

### 4.1 Enrolment

- One-time per child. Teacher opens a child's profile and taps **Teach FaceTagging**.
- Teacher picks 3–5 photos via the iOS PhotosPicker. At least one frontal, at least one under different lighting recommended (not enforced).
- System detects one face per photo. If zero faces in a photo: warn, skip. If more than one face: use the largest, warn.
- Each photo runs through the embedding pipeline. Pairwise distances across the 3–5 reference embeddings are computed; if any pair's d² is > 2× the median, warn *"these photos look very different — recapture?"* but allow save.
- On save: all N embeddings stored in SwiftData as `Data` (concatenated, min-distance strategy).

### 4.2 Identification (runtime)

- Runtime trigger: teacher takes or picks a photo in the Capture tab.
- Pipeline runs all faces in parallel (`TaskGroup`), labels each as:
  - **Matched** (green): nearest enrolled identity, d² ≤ threshold.
  - **Unknown** (yellow): d² > threshold → `?` chip.
- Labels overlay the photo. Tapping a matched rectangle opens the child's journal; tapping `?` opens a picker to assign the face to an enrolled child (or skip).

### 4.3 Correction & learning

- If a matched label is wrong, teacher taps the rectangle → *"Not <name>"* → picker. The system stores the correction but does **not** use it to retrain the on-device model in MVP (see §11).
- After 3 corrections on the same child, the app suggests re-enrolment.

### 4.4 Management

- A child's profile shows a "FaceTagging: enabled (N photos)" row. Tap to re-enrol (replace all photos) or disable (delete all embeddings).
- Deleting a child's profile deletes all embeddings along with the rest of their data. Confirm tap, 3-second undo window.

---

## 5. Technical architecture

### 5.1 Pipeline (validated in experiment)

```
UIImage from picker or camera
    ↓
FaceCropper.fixedOrientation       # bake EXIF rotation into pixel buffer
    ↓
FaceAligner.alignAll               # VNDetectFaceLandmarksRequest, one per photo
    ↓ [AlignedFace]                #   similarity transform → 112×112 BGR canvas
                                   #   all math in bottom-left origin
    ↓
MLFaceEmbedder.embed (TaskGroup)   # Core ML MLFeatureValue(cgImage:constraint:)
    ↓ FeaturePrint                 # 512-d Float32, unit-L2-normalised
    ↓
IdentityMatcher.bestMatch          # min d² across N stored enrolment vectors
    ↓
Threshold.label                    # matched / unknown label
    ↓
UI overlay on original photo
```

Every stage above is in the experiment repo and transfers verbatim. See the "What transfers" section of `docs/experiments/results/exp-02/README.md`.

### 5.2 Model

- **AdaFace IR-18** (MIT, VGGFace2 checkpoint). Bundled as `FaceEmbedder.mlpackage`, ~45 MB FP16.
- Input 112×112 BGR, `(x/127.5) - 1` normalisation **baked into the Core ML model** at conversion — Swift passes a raw `CGImage` via `MLFeatureValue(cgImage:constraint:)` and Core ML handles channel swap + preprocessing from the constraint.
- Output 512-d, already unit-normalised by the model, re-normalised on our side for API uniformity.
- Conversion script in `Experiments/FaceTagging/scripts/convert_adaface.py` — takes a `.ckpt`, produces `.mlpackage`. Re-run with a different checkpoint to swap backbones.
- **`MLFaceEmbedder` auto-discovers vector length at load time.** No code change needed to swap from a 128-d to a 512-d model; drop the new file in the bundle and delete old enrolments.

### 5.3 Storage

```swift
@Model
final class EnrolledIdentity {
    var id: UUID
    var name: String              // must match Child.name; mirrored on enrolment
    var embeddings: Data          // Float32 array, N × 512
    var embeddingCount: Int       // N = number of reference photos
    var elementType: Int          // VNElementType.float.rawValue = 1
    var vectorLength: Int         // 512 for AdaFace IR-18
    var updatedAt: Date
}
```

- **SwiftData configuration:** own `ModelContainer`, separate from the rest of the app, `cloudKitDatabase: .none`, file-protection `.completeUntilFirstUserAuthentication`.
- One row per child. ~2 KB per enrolment (5 × 512 × 4 bytes + overhead). Negligible.

### 5.4 Threshold

- Picked per corpus. Experiment's dev split produced `d² = 1.48`. **The real app must re-pick its own threshold before Beat 2 ships.**
- Picker algorithm: sweep `linspace(min(distances), max(distances), 200)`; pick the largest threshold that yields `FP = 0` with `TP > 0`. Ties broken toward smaller (conservative).
- Threshold stored in a `Configuration` entity, not hard-coded. Allows A/B if needed.

---

## 6. Performance requirements

| Metric | Target | Measured (experiment) |
|---|---|---|
| Cold-start model load | < 500 ms | ~200 ms on iPhone 15 Pro |
| Per-face embed (steady-state) | < 100 ms | ~20 ms (FaceAligner) + ~30 ms (embed) |
| 3-face end-to-end (UIImage → labels) | < 500 ms | P50 29 ms, P95 60 ms |
| Bundle size increase | < 60 MB | 45 MB (FaceEmbedder.mlpackage) |
| Storage per child (5 photos) | < 20 KB | ~10 KB |
| Neural Engine utilisation | Preferred | Confirmed (revision=1001 log line) |

Run parallelism via `TaskGroup` over per-face embed calls. Do not block the main actor — Vision/Core ML calls are `nonisolated` and run via `Task.detached(priority: .userInitiated)`.

---

## 7. UX flow — screens

### 7.1 Enrol a child's face

```
Child profile
  ↓ tap "Teach FaceTagging"
    ↓
FaceTagging enrolment sheet
  • current status: "Not enrolled" | "Enrolled with N photos on <date>"
  • [Pick 3–5 photos] → iOS PhotosPicker, maxSelectionCount: 5, matching: .images
  ↓ on pick
    ↓ (pipeline runs)
  • each photo thumbnail with status overlay: ✓ face found | ⚠ no face / multi-face
  • enrolment-quality heuristic warning if photos look too dissimilar
  • [Save enrolment]
```

Primary action is "Save". Secondary "Cancel" discards all embeddings in memory. No partial saves.

### 7.2 Identify faces in a photo

```
Capture tab — camera + library picker button
  ↓ photo selected or taken
    ↓
Identification view
  • source photo, scaledToFit
  • for each detected face: overlay rectangle
    - matched: green, "<name>  d²=X.XX"
    - unknown: yellow, "?"
  • [File photo to journals]  (primary, enabled iff ≥ 1 matched face)
  • [Add to unrecognised child]  (secondary, per yellow chip)
```

### 7.3 Correction

```
Tap any rectangle → context menu
  • "Open <name>'s journal"
  • "Not <name> — change…" → picker of enrolled children + "someone else"
```

### 7.4 Error states

- Zero faces detected: "No faces found in this photo. File to a journal manually?" → single-child picker.
- Model not loaded: "Face matching is unavailable — re-install the app." (should be unreachable in production; surface only in beta / dev builds).
- Low battery / thermal pressure: Core ML may drop to CPU; latency rises. No UI change; logged.

---

## 8. Integration requirements

### 8.1 Voice observation (Feature 1)

- After **File photo to journals**, the photo attachment is added to the in-progress observation for each matched child. If no observation is in progress for a child, the photo creates a standalone journal entry.
- Multi-guardian visibility: the photo is owned by the child, inherits the child's share permissions.

### 8.2 Multi-guardian sharing

- Face tagging has no awareness of guardians. It operates at the child level. Guardians see the photo if and only if they have read access to the child — enforced by CloudKit sharing, not by this feature.
- **Invariant:** no per-guardian threshold overrides. No per-guardian embedding copies.

### 8.3 Offline behaviour

- Entire pipeline is offline. Verified: no network calls in `FaceDetector`, `FaceAligner`, `MLFaceEmbedder`, `IdentityMatcher`. Pre-merge check: `grep -rE "URLSession|URLRequest|NSURL" FaceTagging/` returns only test files.
- Airplane mode on-stage: filing succeeds, journal entry created locally, syncs to guardians when connectivity returns.

### 8.4 Data export

- **Embeddings MUST NOT appear in the export.** Enforced in the export pipeline:
  - `PassportExporter.encode(_:)` must not have `EnrolledIdentity` as an encodable type.
  - Unit test: build a fake family with enrolled faces, export, assert no serialisation of `embeddings` bytes in either the JSON or the PDF.
- Photo references (filename path) in the export are correct. Photo *content* in the export is the original JPEG/HEIC, not the aligned 112×112 crop.

### 8.5 Parent consent

- Enrolment UX shows a one-line consent affirmation: *"I have the right to enrol this child's face on this device. Photos stay on this device and will not be uploaded."*
- Consent affirmation logged to the child's record (timestamp, not the photos themselves).
- Parent-facing copy, not teacher-facing — the teacher confirms they've received the affirmation from the parent.

---

## 9. Known limitations + Q&A framing

### 9.1 Children vs adults

Every public face-ID model is trained on adult faces. Accuracy on under-5s is lower. The experiment used adult stand-ins because parent consent for the experiment didn't warrant collecting child face data.

**Q&A answer:** *"Tested on adult stand-ins at 75% recall with zero false positives. Real-world accuracy on children will be lower because children's facial structure changes fast and is under-represented in public training sets. Our answer is termly re-enrolment — it takes under a minute per child — plus a low-friction chip flow for unmatched faces. We have not pretended otherwise in the tech memo."*

### 9.2 Lighting mismatch

Three of six dev-split failures in the experiment were due to lighting mismatch between enrolment and capture. Mitigation: the enrolment heuristic warns when reference photos are too similar. Also expected: teachers enrol in the classroom and capture in the classroom, narrowing the distribution.

### 9.3 Profile / occlusion

AdaFace degrades on strong profile or partial occlusion (hand near face, glasses). Fallback is the `?` chip, which is a product feature, not a failure. Do not pitch 95% recall; pitch "auto-matches most faces, chip for the rest."

### 9.4 False matches (zero-FP claim)

The "zero false positives" claim is measured on the experiment corpus. It is *not* a guarantee; it's a property of the chosen threshold and the corpus. Before shipping, the real app must re-measure on a real corpus and adjust the threshold.

### 9.5 "What if a photo has a child who's not enrolled?"

All unenrolled faces become `?` chips. Filing a photo with 3 enrolled + 1 unenrolled face routes to 3 journals plus shows one unassignable chip. Teacher can tap the chip to add the face to a child's future enrolment.

### 9.6 Re-enrolment cadence

Recommend: termly. 3 times a year for nursery settings. Enforced via a soft nag in the child profile after 4 months: *"It's been a while — refresh this child's face enrolment?"*

---

## 10. Engineering gotchas (from experiment — do not rediscover)

These cost ~15 engineering hours in the experiment. Bake them into the code and onboarding.

1. **MLMultiArray FP16-as-FP32 reinterpret.** FP16-compiled Core ML models report `dataType == .float32` but store half-floats. `dataPointer.assumingMemoryBound(to: Float.self)` silently returns bit-garbage with structural zeros in the first few dimensions. **Rule:** always read via `mlArray[i].floatValue` in MLFaceEmbedder; no pointer casts. Add a code comment explaining why.
2. **CIImage is bottom-left origin.** Vision landmarks are also bottom-left. Stay in that convention end-to-end. No post-y-flip on the output; canonical anchors flipped to bottom-left at compile time. `FaceAligner` does this correctly — don't refactor toward "top-left feels more natural," it does not.
3. **`VNFeaturePrintObservation.computeDistance(_:to:)` returns squared Euclidean.** Not L2. Every column labelled `d_sq`, every UI label `d²=…`. If someone writes a new distance metric or adds a different model, re-audit this.
4. **Xcode 16 file-system-synchronized groups flatten the bundle.** `Bundle.url(..., subdirectory: "testset")` returns nil even though the file is bundled. Fix: resources at bundle root, `subdirectory` parameter dropped. Any future use of `Bundle.url(...)` should check this behavior.
5. **`VNGenerateImageFeaturePrintRequest` revision 2 returns unit-normalised 768-d vectors.** Not used in the shipping Beat 2 pipeline (AdaFace replaced it), but noted because we may still use Vision feature prints elsewhere (e.g., as a lightweight pre-filter). Averaging unit vectors without re-normalisation distorts the metric space.

Additional: **`coremltools` can't convert `raise` / `assert` from scripted PyTorch models** (PReLU and BN training-mode checks leak into the scripted graph). Fix: `jit.freeze` + `optimize_for_inference` before re-tracing collapses those branches. Pattern in `scripts/convert_mobilefacenet.py`.

---

## 11. Explicit scope cuts (not in MVP)

- **No on-device retraining or fine-tuning.** Learnings from corrections are stored but do not improve the model until a future release.
- **No federated learning.** Research §5 mentions it as an emerging trend; out of hackathon scope. Revisit post-hackathon.
- **No active learning / uncertainty sampling.** Every unknown face is a chip; no prioritisation heuristics.
- **No cross-device face tagging.** Enrolments stay on the enrolling device; not synced to other teacher devices. This is a conscious constraint: CloudKit-syncing biometric data changes the compliance posture.
- **No age / gender / emotion inference.** Not relevant to Beat 2. Even if trivial to add, the compliance cost is not worth it.
- **No attendance automation via face recognition.** Adjacent use case; flagged by teacher-facing ethical concerns.
- **No "who did this?" retrospective search.** E.g., "show all photos where Amara appears" is UX-available because every photo has tags, but not surfaced as a feature in MVP.
- **Multi-photo enrolment from a single group photo.** If the teacher has a group shot of the class, we could theoretically extract one face per child in one step. Out of scope for reliability reasons.
- **Non-Apple-platform port.** Android face-ID uses a different model ecosystem (ML Kit, MediaPipe). Post-hackathon, not MVP.

---

## 12. Post-hackathon productionisation

Not blockers for Wednesday; tracked for the roadmap.

1. **Re-train AdaFace on WebFace4M.** VGGFace2 licensing is research-only; WebFace4M is commercially clean and bigger. Same conversion script. 1–2 days depending on training infra.
2. **IR-50 or larger AdaFace variant.** Expected 5–15pp recall improvement at the cost of 100 MB bundle. Quantify against real corpus before deciding.
3. **Per-identity threshold calibration.** Some children are inherently harder to separate than others; a per-child threshold could push recall higher without moving the FP rate.
4. **Termly re-enrolment nag.** Soft UX after 4 months of no re-enrolment.
5. **Safeguarding review for corrections.** If a teacher corrects a matched face repeatedly to a different child, that's a safeguarding signal. Loggable event; out of MVP scope but on roadmap.
6. **Accessibility audit.** VoiceOver-first pass on the enrolment + identification screens, WCAG 2.2 AA contrast check. Research §6 flags this as an EU Data Act / European Accessibility Act gate.
7. **Privacy audit.** Before public beta: external privacy review confirming the six invariants are actually enforced, grep of production binary for telemetry calls.

---

## 13. Success criteria for Wednesday's demo

In priority order:

1. **The demo does not crash.** One-shot rehearsal with the exact flow ≥ 3 times in the 48h before demo, one with the stage HDMI and venue wifi (even though we don't need wifi — rule out unrelated interference).
2. **Zero visible false matches during the demo.** The safest approach is to pick demo children with high-quality enrolment photos and known-good test photos. Rehearse the demo images, not novel ones.
3. **Airplane mode visibly succeeds** (integration with Beat 4). Toggle live on-stage. No spinner, no error.
4. **Privacy claim is airtight in Q&A.** The six invariants are literally true; we can point to the comment block on request.
5. **Latency is imperceptible.** On iPhone 15 Pro this is given — P95 60 ms is well below perception threshold.
6. **The `?` chip flow demos cleanly.** One face deliberately left unenrolled in a demo photo, to show the graceful-fallback UX. Rehearse the chip interaction.
7. **Narrative handoff between beats is clean.** Face tagging feeds Beat 1's journal, is filed offline in Beat 4, excluded from Beat 5's export. Speaker narrates the privacy-invariant check before moving to Beat 3.

---

## 14. References

- `docs/research.md` §8 Beat 2
- `docs/technical-considerations.md` §Beat 2
- `docs/experiments/experiment-02-on-device-face-id.md` (original experiment spec)
- `docs/experiments/results/exp-02/README.md` (experiment results + transfers list)
- `docs/experiments/results/exp-02/followups.md` (licensing, Q&A framing, skipped deliverables)
- `Experiments/FaceTagging/` (working code, conversion scripts)
