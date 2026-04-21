# Live Capture — Feature Requirements

**Feature:** Voice observation → on-device transcript → local-LAN LLM tags → PYP-shaped journal entry.
**Demo beat:** Research §8 Beat 1 — *"the teacher's 15-second observation"*.
**Status:** End-to-end path runs in `Experiments/VoiceTranscript/`. Streaming UI live. Tag accuracy validated in exp-03; see `docs/experiments/experiment-03-pyp-capture-and-tagging.md` and `docs/experiments/results/exp-03/`.
**Owner:** TinySteps engineering.
**For:** Hackathon demo, Wednesday 2026-04-22.

---

## 1. Purpose & positioning

A teacher taps record, speaks one sentence — *"Amara built a tower of six blocks and counted them in Somali and English, then knocked it down and laughed"* — releases. A few seconds later the screen shows the transcript as-captured alongside tag chips against the PYP framework. One tap files it.

Beat 1 exists to make one concrete, on-stage claim: **the single largest labour cost in early-years — writing observations — collapses from 10 minutes of typing to 15 seconds of talking**, with tag selection handled by a model that runs on a local machine the setting owns. This is the pitch's labour-saver and its framing hook. Everything else in the demo rides on it.

The feature is load-bearing in three ways:

1. **Labour saver.** Time on admin is the top teacher-retention friction in every UK/EU nursery study we read. The pitch opens here because the saving is quantifiable and visceral.
2. **"AI serving the teacher, not replacing them."** The teacher still writes the observation (by voice). The AI drafts and tags. The teacher reviews and edits. This framing is what gets past ethics sceptics.
3. **Local-first proof point.** The transcript never leaves the setting's network. The model runs on a mini-PC the nursery owns. This is the plausible answer to *"you're putting children's utterances into ChatGPT"* and to the biometrics/profiling concerns under GDPR Art. 9.

All three framings must survive Q&A.

---

## 2. Demo storyboard — what happens on stage

From research §8 Beat 1, made concrete against the current build:

1. Teacher opens the app → **Live capture** tab.
2. Teacher taps **Record**, speaks the 15-second observation, taps **Stop**.
3. Transcript fills in as speech recognition runs on-device. No network used for STT.
4. The app sends the transcript to the local Ollama server over the venue's LAN. Tag chips begin streaming in: transdisciplinary theme lands first, then key concepts, ATL skill clusters, learner-profile attributes, all within ~4 seconds.
5. When streaming completes, confidence and latency badges appear underneath (e.g. `confidence 0.82 · 3842 ms total, 612 ms TTFT`).
6. Teacher taps **File** (not yet wired; see §11). Observation lands in Amara's journal.

**Fallback path (mic fails / Simulator / loud venue):** the view has a visible `TextEditor` labelled *"Type or paste transcript (bypasses mic)"* plus a **Use u01 sample** button. Drafting + tagging path is identical to the mic path. This is a deliberate stage-safety feature — see §13 success criteria.

**Streaming toggle:** the engine-label row has a small `stream` switch. On for demo (<1s TTFT with progressive chip fill). Off as a stage-safety fallback (single ~4s spinner then everything appears).

**Integration with other beats:**

| Integration | Touch point |
|---|---|
| Face tagging (Feature 2) | Photos filed by face tagging attach to the in-progress observation for each matched child. The journal entry is the destination. |
| Multi-guardian sharing | The filed journal entry inherits the child's share permissions; both parents see it per their locale. |
| Offline behaviour | STT is fully on-device. LLM tagging requires LAN reachability to the local Ollama box; if offline, the observation is stored as transcript-only and re-tagged when connectivity returns. |
| Data export | The PDF/JSON export includes `transcript`, `tags`, `confidence`, `evidenceSpans`. Does **not** include the raw audio waveform. |

---

## 3. Privacy invariants (non-negotiable)

These sit as verbatim comment blocks at the top of `SpeechTranscriber.swift`, `OllamaDraftingEngine.swift`, and the `DebugConfig.swift` prompt declaration.

1. **Audio never leaves the device.** `SFSpeechAudioBufferRecognitionRequest.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition` is set. We degrade gracefully on devices that don't support it but we do not silently route audio to Apple's servers for transcription.
2. **Audio is not persisted.** The `AVAudioEngine` tap feeds the recognition request directly; there is no file write, no in-memory buffer retained past the recognition result, no debug waveform capture in production builds.
3. **Transcripts leave the device only over the school's LAN, only to a server the school runs.** The `selectedEngine` config points at a local IP on the school's wifi. No third-party cloud LLM is configured for production use.
4. **The Foundation Models engine is on-device too.** If we switch to Apple Intelligence (e.g. for air-gapped demos), inference runs through `LanguageModelSession`, which Apple defines as on-device first, Private Cloud Compute fallback. We opt out of PCC fallback in production (config TBD — flag as post-hackathon, see §12).
5. **No telemetry on this subsystem.** No MetricKit, no third-party SDKs, no server-side logging of prompts. The `BatchRunner` CSV writer exists for experimentation only and is not compiled into the shipping app.
6. **Prompts and transcripts are not logged in release builds.** The `[ollama raw]` / `[stream]` prints in `OllamaDraftingEngine.swift` are debug-only; wrap them in `#if DEBUG` before shipping.

**Compliance framing for Q&A:**

- **"Where does the child's voice go?"** — On-device for transcription (Apple Speech framework). The transcript (text) is sent to a local LLM running on a machine the setting owns, over the setting's own wifi. No audio is transmitted anywhere. No text is transmitted outside the setting's LAN.
- **"What about GDPR / DSGVO?"** — Transcripts are personal data. Storage is local-only by default; the setting is the data controller for its own records, same as paper journals today. When a parent exports (Beat 5), the transcript and its derivatives are included; when a parent deletes, they are deleted.
- **"Biometrics?"** — Not applicable to Beat 1. Voice is not used for identification. The Speech framework produces text and discards the audio. See Beat 2 (face tagging) for biometric posture.
- **"What if the Ollama box goes down?"** — The transcript is still captured and stored. Tagging is deferred until the box is back. The teacher can also type tags manually (post-hackathon — see §11).

---

## 4. Functional requirements

### 4.1 Record & transcribe

- Teacher opens **Live capture** tab. First record tap triggers speech + microphone permission request (one-shot, not on view appear — avoids NavigationStack transition races).
- Tap **Record** → audio engine + `SFSpeechRecognitionTask` start. Partial transcripts render live (best-effort; final transcript is what we tag against).
- Tap **Stop** → engine stops, request ends, final transcript settles within ~300ms.
- If no speech was detected, show an inline error with the underlying recognition error if any. Do not crash, do not silently fail.

**Audio session + engine setup** (exact calls are load-bearing — see gotchas in §10):

- `AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: .duckOthers)` then `setActive(true, options: .notifyOthersOnDeactivation)`. `.measurement` mode (not `.default`) gives a flat, unprocessed input suitable for recognition; `.duckOthers` avoids venue-audio collisions on demo day.
- `audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputNode.outputFormat(forBus: 0))` — 1024 is the chunk granularity feeding `SFSpeechAudioBufferRecognitionRequest.append(_:)`. Changing this requires re-measuring recognition latency.
- `SFSpeechAudioBufferRecognitionRequest.shouldReportPartialResults = true` for live fill. `requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition` — never unconditionally `true` (see §10 gotcha 7).
- On `stop()`: `audioEngine.stop()` → `request?.endAudio()` → **`try? await Task.sleep(for: .milliseconds(300))`** → `teardown()`. The sleep lets Apple's recognizer finalise the partial transcript into `bestTranscription.formattedString` before the tap is removed. Skipping it chops the tail of the last utterance.

### 4.2 Tag & draft

- On successful transcript, phase transitions to `.tagging`. Engine is constructed lazily per run.
- Transcript + compressed PYP prompt go to `OllamaDraftingEngine.draftStream(from:)`. The engine streams NDJSON chunks from the local Ollama `/api/chat` endpoint with `format` set to the JSON schema for `ObservationDraft`.
- As chunks arrive, `extractPartialTags` best-effort-parses the growing JSON and yields `PartialTagBundle` updates to the UI. Tag chips fade in as each dimension closes in the JSON (theme → keyConcepts → atlSkills → learnerProfile).
- Partial-tag emissions are **de-duplicated against the last yielded bundle** (`partial != lastEmitted`) — prevents UI thrashing as the regex re-matches identical values on every chunk.
- On completion, the final chunk carries a `DraftResult` with `observation: ObservationDraft`, `ttftMs`, `totalMs`. Chip opacity jumps from 10% to 15% to mark the terminal state; confidence and latency badges appear.

**Prewarm (`OllamaDraftingEngine.prewarm()`)** runs on engine construction and does two things in order:

1. Calls `GET /api/version` and logs the returned version string alongside the host URL. Review-Q5 breadcrumb — version mismatches between dev and demo boxes are the most common silent regression.
2. Fires a throwaway `/api/chat` with one user message `"ok"` and the real schema. This warms the KV cache and forces the model to be loaded in memory.

The first in-app user request still pays the model load on the very first run after an Ollama restart; on demo day the box must be kept warm between rehearsal and show.

**HTTP timeout is model-aware** (`OllamaDraftingEngine.timeout(for:)`):

- `70b` / `72b` in the model name → 180s
- `20b` / `22b` / `24b` / `26b` / `27b` / `30b` / `32b` / `34b` / `35b` → 120s
- else → 60s

The cold load of a 35B-class MoE over local SSD routinely takes over a minute. The URL session is configured with **both** `timeoutIntervalForRequest` and `timeoutIntervalForResource` set to this value — both are required for correct long-running semantics; setting only one lets the other clip the request mid-stream.

### 4.3 File to journal *(MVP scope cut, see §11)*

Not in the hackathon MVP. The demo ends at the tagged journal entry on-screen. Filing to a persistent `Child.journal` via SwiftData is §11 post-hackathon work.

### 4.4 Text input fallback

- Always available below the recording controls.
- **Tag from text** button runs the identical drafting pipeline against the text box contents.
- **Use u01 sample** button fills the text box with the canonical exp-03 u01 utterance. Used as stage-safety during demo rehearsal and as a deterministic probe during development.

### 4.5 Engine selection (dev-only)

- `DebugConfig.selectedEngine` picks between `.foundationModels` (Apple Intelligence), `.ollama(model:)` (local LAN), `.lmStudio(model:)` (local LAN, OpenAI-compatible). **Not a runtime toggle.** Compile-time switch, rebuild to change.
- `DebugConfig.taxonomyChoice` picks between `.eyfs` and `.pyp`. Production default is `.pyp`. The `.eyfs` path is retained for exp-01 reproducibility only — see the comment in `DebugConfig.swift`.
- `DebugConfig.useStreaming` seeds the UI toggle default. The in-view `stream` switch lets rehearsal flip modes without a rebuild.
- `DebugConfig.ollamaSampling` is a compile-time property (default `.qwen3Structured(seed: 42)`). To change seed or preset requires rebuild.
- `DebugConfig.ollamaThink` defaults to `false`. Set to `nil` to omit the field entirely (model default); `true` re-enables chain-of-thought with the 2–3× latency cost.

**LM Studio / OpenAI-compatible** (`OpenAICompatibleAPI` / `OpenAICompatibleDraftingEngine`):

- Endpoint: `POST /v1/chat/completions` (not `/v1/completions`).
- `response_format = { type: "json_schema", json_schema: { name: "observation_draft", strict: true, schema: <...> } }`. The `name` field is required; `strict: true` enforces the schema strictly (equivalent to Ollama's `format`).
- Optional `Authorization: Bearer <apiKey>` if an API key is configured.
- Streaming transport uses **Server-Sent Events** with `data:` line prefix and a `[DONE]` sentinel marking stream end. Delta content arrives on `choices[].delta.content`; reasoning models additionally emit `choices[].delta.reasoning_content`.
- Per-model timeout reuses `OllamaDraftingEngine.timeout(for:)` — the model-size heuristic is the same whether the server is Ollama or LM Studio.

**Foundation Models** (`FoundationModelsDraftingEngine`):

- A fresh `LanguageModelSession` is created for **every** `draft(from:)` call. Each utterance starts with a clean 4096-token context window; there is no multi-turn accumulation. The prewarm session is discarded after warming.
- Native streaming separation of TTFT vs total time is not exposed by the current `ResponseStream.PartiallyGenerated` API; `ttftMs == totalMs` on this path. Measurement numbers are honest but blunt.
- `AvailabilityGate` checks `SystemLanguageModel.default.availability` only when the selected engine is `.foundationModels`; Ollama and LM Studio paths bypass the gate.

---

## 5. Technical architecture

### 5.1 Pipeline (validated end-to-end)

```
Mic button
    ↓ tap
SpeechTranscriber.start()
    ↓ AVAudioEngine tap → SFSpeechAudioBufferRecognitionRequest
    ↓ partial transcripts fill @State
Stop button
    ↓ SFSpeechRecognitionTask.finalResult → final transcript
OllamaDraftingEngine.draftStream(from: transcript)
    ↓ POST /api/chat, stream=true, format=ObservationDraftSchema.schema()
OllamaAPIClient.streamChat
    ↓ URLSessionDataDelegate.didReceive(data:) (NOT bytes.lines — see §10)
    ↓ NDJSON line split → OllamaStreamChunk → accumulated content
    ↓ AsyncThrowingStream<String, Error> yield per chunk
OllamaDraftingEngine (@MainActor Task)
    ↓ extractPartialTags(from: accumulated) → PartialTagBundle?
    ↓ continuation.yield(DraftUpdate(partialTags, finalResult: nil, isReceivingStream: true))
    ↓ (end of stream) normalizeObservationDraftJSON + JSONDecoder → ObservationDraft
    ↓ continuation.yield(DraftUpdate(finalResult: DraftResult(...)))
LiveCaptureView
    ↓ @State partialTags / finalResult updates
    ↓ chip rows re-render (animated)
```

Every stage above is in the VoiceTranscript experiment and transfers verbatim into the app. Private-drafting context from exp-01 `experiment-01-private-drafting.md`; PYP reshape in exp-03.

### 5.2 Models

- **Speech recognition:** Apple Speech framework, on-device preferred. Tied to device locale; default `en-GB`. See `SpeechTranscriber.swift`.
- **Drafting / tagging:** Ollama `qwen3.5:35b-a3b` (MoE, 3B active params). Chosen in exp-01 Path B as the Pareto winner over 32B dense (0.708 Jaccard @ P50 4s vs 32B's 0.625 @ P50 9s). Subsequent prompt hill-climb (v26) raised Jaccard to 0.850 on tuning and 0.750 on held-out.
- **Foundation Models (alt path):** Apple Intelligence on-device. Used in exp-01 Path A. Failed the exp-01 accuracy gate (Jaccard 0.39, traps 0/2). Kept as a compile-time option for devices without LAN reach to the Ollama box; accuracy caveats documented in the results memo.

### 5.3 Prompt

- **System prompt:** `PYPTaxonomy.compressedPrompt`. Caveman-trimmed (explicit bullet rules, no meandering prose) after exp-03 revealed the long-form EYFS prompt wasted tokens without helping tag choice.
- **Structure:** per-dimension definitions (one line per tag, educator-facing language, not IB-official wording) → priority/disambiguation rules → tagging rules → required output shape → worked examples.
- **Critical:** field order in the JSON schema (`tags` → `confidence` → `evidenceSpans`) matches generation order. Inside `tags` the dimension order (`transdisciplinaryTheme` → `keyConcepts` → `atlSkills` → `learnerProfile`) is what `extractPartialTags` relies on for progressive chip fill. Re-ordering fields silently breaks chip-by-chip rendering without breaking final decode.
- **Rules baked into the prompt** (each earned its keep in exp-03; removing any has measured regressions — re-run the held-out corpus before touching):
  - **Theme priority when ambiguous** — the child's *primary focus* wins. A child building while chatting is `HowTheWorldWorks`, not `HowWeExpressOurselves`. A child sharing snack while discussing family is `WhoWeAre`, not `HowWeOrganizeOurselves`. Routine self-management with no other focus is `WhoWeAre`.
  - **`Function` requires verbal/cognitive engagement with purpose** — asking "what does this do", explaining a mechanism, asking why a process exists. "Child uses a tool" is mere activity and does **not** qualify.
  - **Bare teacher sentiment is never evidence for a learner-profile attribute.** When the transcript is only teacher sentiment about the child ("she was kind today", "he was really curious"), `learnerProfile` MUST be empty. This is the mechanism behind 2/2 trap refusal.
  - **Routine tool-use / motor / self-care without verbal or cognitive engagement → zero key concepts.** Empty array is the right answer, not a wrong one.
  - **Maximum two learner-profile attributes**, each justified by an `evidenceSpan` whose `quote` is copied verbatim from the transcript. `maxItems: 2` at the schema level is belt-and-suspenders.
  - **Full key names only, never shorthand.** `transdisciplinaryTheme` not `theme`; `keyConcepts` not `concepts`; `atlSkills` not `atl`; `learnerProfile` not `profile`. The normaliser (§5.4) salvages drift but the prompt explicitly forbids it so the model stops drifting in the first place.
  - **Explicit "do not produce a narrative summary — the transcript is the description; you only tag."** The previous schema's `draft` field was dropped for this reason; the prompt restates it so the model doesn't try to sneak a narrative into evidence quotes.
- **Trap example** (*"She was really lovely this morning" → empty tags, low confidence*) lives in the prompt body. Removing it measurably drops trap refusal below 2/2 on the held-out corpus.
- **Prompt density has a ceiling.** Exp-03 hill-climb showed the Pareto point at ~4–5 coordinated rule hints; adding a 6th regressed on held-out. More guidance ≠ better — over-specification causes the model to over-fit hint phrasing and fail on novel transcripts.

### 5.4 JSON schema (`ObservationDraftSchema.schema()`)

```
{
  type: object, additionalProperties: false,
  required: [tags, confidence, evidenceSpans],
  properties: {
    tags: { type: object, additionalProperties: false,
            required: [transdisciplinaryTheme, keyConcepts, atlSkills, learnerProfile],
            properties: {
      transdisciplinaryTheme: enum(PYPTheme),            // exactly one
      keyConcepts: array<enum(PYPKeyConcept)>,           // 0+
      atlSkills:   array<enum(PYPATLSkillCluster)>,      // 0+
      learnerProfile: array<enum(PYPLearnerProfile)>     // 0+, maxItems: 2
    }},
    confidence: number (0..1),
    evidenceSpans: array<{ tag: enum(allTagsUnion), quote: string, minLength: 3 }>
  }
}
```

- **No `draft` field.** Earlier revisions asked the model for a 2–4-sentence narrative in addition to the tags; it was lossy (summarised away detail), expensive in output tokens, and a hallucination surface. **The transcript is the description.** The model's only job is to tag what was said. Comment block at the top of `ObservationDraft.swift` documents this decision — do not re-add `draft` without reading it.
- `additionalProperties: false` at every object level (review B3 — models invent fields otherwise).
- `evidenceSpans[].quote` has `minLength: 3` (blocks one-character "evidence").
- `evidenceSpans[].tag` is constrained to the **union of all four dimensions' rawValues**. The four enums are disjoint by construction (theme names don't collide with concept names, etc.) so no namespace prefix is needed.
- `ObservationDraftSchema.schema()` returns a **fresh dictionary each call** rather than a static let — `[String: Any]` is not `Sendable` and the dynamic build avoids Sendable friction.
- **`tags` is required** with all four sub-dimensions required. The arrays may be empty (that's the legitimate answer for bare-sentiment traps), but the keys must be present.
- **Enum rawValues are PascalCase, no hyphens, no spaces** (`SelfManagement`, `HowTheWorldWorks`). The pipeline does not tolerate hyphenated variants at any layer — schema, prompt, normaliser, UI chips all use identical strings.
- `PYPLearnerProfile` has **10 attributes** (the IB's official 10, including `Balanced` and `Reflective`). Any shorter list is stale.

**Post-decode normalisation** (`normalizeObservationDraftJSON`) — Ollama enforces the top-level shape but the model still drifts on items. The normaliser does the following salvage, in order, before `JSONDecoder.decode`:

1. **Unwrap single-key wrappers.** If the top-level object has exactly one key from `{observation, result, data, response, output}` and its value itself looks schema-like (contains `tags` / `theme` / `concepts` / `atl` / `profile`), replace the object with the inner value.
2. **Flat-tag drift.** If `tags` is missing, scan the top level for either shorthand keys (`theme`, `concepts`, `atl`, `profile`) or canonical-but-un-nested keys (`transdisciplinaryTheme`, `keyConcepts`, `atlSkills`, `learnerProfile`), lift them into a reconstructed `tags` object, and remove them from the top level.
3. **Defaults for required fields.** `confidence = 0.5` if missing; `evidenceSpans = []` if missing. Decode succeeds with partial data so the user still sees the tags the model did emit.
4. **EvidenceSpan cleanup.** Map `text → quote`; drop any item missing `tag` or with empty `quote`; normalise each span to exactly `{tag, quote}`. Any `start`/`end`/`offset` fields the model invents are discarded.

Any schema change that touches `evidenceSpans` or the tag dimensions must re-validate this normaliser against the regression corpus.

### 5.5 Sampling (`.qwen3Structured(seed: 42)`)

```
temperature        0.3
top_p              0.8
top_k              20
min_p              0.0
presence_penalty   0.0  ← critical, see §10
repeat_penalty     1.1
seed               42
```

- `think: false` on `/api/chat` — disables chain-of-thought. Speeds up by ~2-3×, accuracy unchanged or better on our corpus.
- **Never** use `.qwen3General` with `format`: its `presence_penalty: 1.5` discourages `"`, `{`, `:`, `,` — JSON syntax collapses. See §10 and the comment in `OllamaOptions.qwen3General`.
- **`temperature: 0.3` is the empirical optimum.** The exp-03 hill-climb tested T=0.1 (too rigid — tags under-fire) and T=0.5 (too loose — over-tagging); both regressed measurably on the tuning corpus. 0.3 is locked in by data, not intuition.
- **`seed: 42` + `temperature: 0.3` + `think: false` is deterministic across runs** against a stable Ollama/model version. Any run variance observed in practice is a version-change signal — log and diff before assuming prompt regression.
- **Changing the seed requires re-validating against the held-out corpus** (§6 regression gate). Same for upgrading Ollama or the underlying Qwen model snapshot.

### 5.6 Streaming transport

- `OllamaAPIClient.streamChat` uses `URLSessionDataDelegate.urlSession(_:dataTask:didReceive:)` to buffer bytes and split on `\n` (byte `0x0A`). **Not** `URLSession.bytes(for:)`. See §10 gotcha 1.
- Streaming requests set two extra headers that matter on some networks:
  - `Accept-Encoding: identity` — disables gzip so the response isn't buffered at the transport layer waiting for a complete compressed block.
  - `Cache-Control: no-cache` — belt-and-suspenders against intermediary caches on the venue LAN.
- Stream yields the **accumulated** content string (not deltas) on every NDJSON chunk. Consumer runs a regex-based progressive parser to extract tag fields from growing JSON.
- `OllamaStreamChunk` carries `message` (with `role`, `content`, optional `thinking`) and `done`. The `thinking` sub-field is present on reasoning models even with `think: false` (it just stays empty).
- **Partial-tag regex behaviour** (`OllamaDraftingEngine.extractPartialTags`):
  - `extractStringField` (for `transdisciplinaryTheme`) requires the **closing `"`** to be present. Partial in-flight values are not surfaced — a chip appears once the full string has arrived, not character-by-character.
  - `extractStringArrayField` (for `keyConcepts` / `atlSkills` / `learnerProfile`) tolerates an unclosed `[` and returns whatever entries have fully arrived so far. An open quote without a close stops consumption (that entry is dropped until the next chunk).
  - Both extractors are tolerant of whitespace and trailing commas. Neither extracts shorthand (`theme` / `concepts` / …); salvage for shorthand drift happens at final-decode time via the normaliser, not during streaming.
- **Timing:** `firstTokenAt` is captured on the first chunk received; `ttftMs` and `totalMs` are computed as `Date().timeIntervalSince(t0) * 1000`, rounded to Int. Non-streaming `draft()` returns `ttftMs == totalMs`.
- Debug-only: the first callback and every 20th thereafter log byte/line counts, keeping stream-diagnostic output out of production.

---

## 6. Performance requirements

| Metric | Target | Measured |
|---|---|---|
| TTFT (first chunk received) | < 1s | ~0.4s against local Ollama on LAN |
| Total wall-clock (transcript → final tags) | < 8s P95 | 2-5s P50 / 6-7s P95 (cold model load up to 120s; prewarm amortises) |
| STT final transcript lag after Stop | < 400ms | ~300ms (explicit sleep before teardown) |
| Chip first-render latency | < 1.5s | ~0.5s TTFT + ~0.5s until first chip dimension closes |
| Jaccard on tuning corpus (exp-01 A, 20 utts) | ≥ 0.80 | 0.850 (v26 prompt) |
| Jaccard on held-out corpus (exp-01 B, 20 utts) | ≥ 0.65 | 0.750 (v26 prompt) |
| Trap refusal on bare-sentiment | 2/2 | 2/2 (empty concept/profile on "she was lovely today" class) |
| Description faithfulness (no invented names/actions) | 20/20 | 20/20 (manual eyeball, v26) |

Prewarm runs a throwaway `/api/chat` call on engine construction (logs Ollama version as a Q5 breadcrumb). First cold run still pays the model load if the server had it unloaded; keep the Ollama box warm pre-demo.

**Latency is flat across prompt variants.** The exp-03 hill-climb measured P50 between 3.6s and 4.9s and P95 between 4.4s and 6.0s across all 26 prompt iterations — prompt wording has negligible effect on generation time. The quality hill-climb was essentially free in latency terms; any future prompt changes that spike latency indicate a structural problem (prompt ballooning, accidental CoT), not a tuning tradeoff.

**Corpus warmup discard.** In measurement harnesses (`BatchRunner` / `eval.py`), the first corpus item is run and **discarded** from the summary. The first call after engine construction pays cold-load even after app-side prewarm — including it inflates P50/P95 by ~10%. Any latency number cited against either corpus assumes the warmup discard.

**Regression gate:** ≥ 0.65 Jaccard on the held-out corpus B, 2/2 trap refusal, zero unsupported evidence spans. Baseline (v3, no hints) was 0.658 on B — the 0.65 threshold is empirically the floor, not an arbitrary round number. Any prompt or model change below this gate does not ship.

---

## 7. UX flow — screens

### 7.1 Record an observation

```
Live capture tab
  • engine label: "Ollama/qwen3.5:35b-a3b"  +  stream toggle
  • Type-or-paste transcript  ← bypass mic entirely
    [Tag from text]   [Use u01 sample]
  • Transcript section (appears during / after recording)
  • Tagging progress: "Receiving tags…" (streaming) or "Tagging…" (non-streaming)
  • Tag chips: theme → concepts → ATL → profile, faded at 10% while in-progress, 15% on final
  • confidence badge · total ms / TTFT ms
  • [Record] / [Stop] button (safeAreaInset bottom, borderedProminent)
```

### 7.2 Error states

- Mic permission denied → error line: *"No speech detected."* with underlying recognizer error if any.
- Ollama unreachable → error line: *"Drafting failed: transport: …"* with NSURLError description. Retry by tapping Record again.
- Model still loading → spinner stays up; prewarm call warms the model on engine construction, so this only fires on the very first run after an Ollama restart.
- Schema decode failure (rare, after normalisation) → error line shows raw body prefix (≤500 chars). Indicates a model/prompt regression; escalate to engineering.

### 7.3 Streaming vs non-streaming

Streaming on (default):
- TTFT < 1s, chips appear progressively, total still ~4s.
- Toggle shows orange bolt; disabled during `.tagging` / `.recording` phases.

Streaming off:
- Spinner "Tagging…" for ~4s, then everything appears at once.
- Measurement numbers are identical — streaming changes *when* tokens arrive, not what they are. Use as stage-safety if the venue LAN is flaky and partial JSON causes parse flicker.

---

## 8. Integration requirements

### 8.1 Face tagging (Feature 2)

- After Beat 2 files a photo to a child's journal, the filing routine checks for an in-progress observation for that child (last 60s of Beat 1 activity) and attaches the photo to it. If no in-progress observation, creates a photo-only journal entry.
- Post-hackathon — see §11 filing work.

### 8.2 Multi-guardian sharing

- Beat 1's journal entry inherits the child's CloudKit share permissions. Translation is rendered per-guardian locale on read (out of Beat 1 scope).
- **Invariant:** the untranslated transcript is the source of truth. Translations are a rendering concern, not a data concern.

### 8.3 Offline behaviour

- STT is fully on-device; works offline.
- LLM tagging requires LAN reach to the Ollama box. On demo day both phone and box share the venue's wifi; airplane mode kills tagging by design.
- **Offline behaviour:** transcript is captured and stored as `transcript = <text>`, `tags = empty`, `confidence = 0`, `pendingRetag = true`. When connectivity returns, a background task re-runs tagging against the stored transcript. Flag tagged vs pending in the journal UI.
- Post-hackathon — see §11 retry queue work.

### 8.4 Data export

- Export includes: `transcript` (raw text — this is the description, no separate `draft`), `tags`, `confidence`, `evidenceSpans`, `createdAt`, `updatedAt`, `revisionCount`.
- Export does **not** include: raw audio (never persisted), intermediate partial tag bundles, prompt/model metadata (goes in a separate technical appendix if requested).
- Unit test (post-hackathon): build a fake family with 3 observations each, export, assert `audio` / `waveform` / `.wav` strings absent from the JSON and PDF.

### 8.5 Consent

- **At enrolment (teacher onboarding):** consent affirmation *"I will obtain parental consent before recording child voices. Audio is processed on this device only; transcripts are stored locally and in the setting's own system."* Acknowledgement logged with timestamp on the user record, not on every recording.
- **Per recording:** no modal (friction kills the 15-second claim). The teacher is the consent gate; per the consent language above, the teacher has already obtained parental consent at enrolment.

---

## 9. Known limitations + Q&A framing

### 9.1 Model runs on the setting's LAN, not the phone

Tagging is on-LAN, not on-device. This is a compromise: the best accuracy at the latency and quality we need requires a 35B-class MoE, which no phone runs.

**Q&A answer:** *"Speech-to-text runs on the phone, and the transcript goes to a small computer the nursery owns, sitting in the back office. Nothing goes to Apple or to us. Same model, same box, no internet needed. For settings without the box, Apple Intelligence on-device is a fallback — we measured it; accuracy drops about 35% on our corpus, so we've positioned the local box as the recommended install."*

### 9.2 Demo-day venue wifi

If venue wifi is congested or firewalled, the LAN-to-LAN path to the Ollama box fails. Mitigations:
- Bring a travel router, run a private network between phone and Ollama box.
- Pre-warm the model in the morning; keep the connection alive.
- Stage-safety: the text-input fallback bypasses STT entirely; works as a live-typing demo if the mic is flaky but tagging still works.
- If tagging also fails, the streaming toggle off path at least shows the non-streaming error more clearly.

### 9.3 PYP vs EYFS

The research brief Beat 1 copy quotes EYFS tags (*"Mathematics: Number"*, *"C&L: Speaking"*, *"PSED: Self-regulation"*). The current app emits PYP tags. The pitch narration must be updated to use PYP vocabulary (*"Transdisciplinary theme: How we express ourselves"*, etc.), or the demo narration must explain both frameworks. Decision: narrate in PYP, since that is what the app shows; explain to the audience that EYFS-equivalent mapping is one prompt-swap away.

### 9.4 Tag accuracy on novel language

Jaccard of 0.750 on held-out corpus means ~1 in 4 tag predictions is imperfect. Teachers still review and edit. Pitch this as a first-pass suggestion, not a final answer. Do not pitch "the model knows the tags"; pitch "the model gives a starting point and the teacher has final say."

**Why 0.750 and not 0.883.** The exp-03 hill-climb peaked at **v19** (0.883 on tuning corpus A, 0.750 on held-out B — a ~43% transfer of the gain over baseline). The shipping prompt **v26** scores 0.850 on A and 0.750 on B but with a ~65% transfer rate of its relative gain. v26 was chosen over v19 *because* of the transfer profile — peak tuning score is not the shipping criterion.

**Exact-match rate is the user-facing metric.** Jaccard smooths over partial overlap; the teacher sees "all my tags are right" or "one is wrong." v26 lifts exact-match from baseline 10/20 to 15/20 on tuning — a 50% relative gain, larger than the 20% Jaccard gain. Both numbers should be tracked; the ratio between them indicates whether the prompt is reducing variance or just shifting mean.

**Primary failure mode: over-tagging.** Baseline emits extra tags with high confidence — e.g. predicts `Maths:Number + PD:Fine-motor` where the gold is `Maths:Number` alone. The `minimal tag set` rule (cardinality guidance: prefer 2 tags, allow 3 rarely) directly addresses this and is load-bearing in v26.

**Secondary failure mode: under-tagging on multi-sub-tag utterances.** Some gold labels require two sub-tags of the same dimension (e.g. `Number + Numerical-patterns`). The prompt reliably captures the primary sub-tag but misses the secondary. This is a corpus-size limitation more than a prompt problem — revisit when the corpus grows past 20.

**Residual misses are genuine ambiguity, not hallucinations.** Manual review of v26's four held-out misses found that in each case the model's tag choice was defensible against a different annotator — `COEL` vs `C&L:Speaking` for the same speech act, for example. Inter-annotator agreement on the gold labels has not been measured; post-hackathon corpus expansion should include a second reviewer.

### 9.5 Transcription accuracy on child voices

Apple's speech recognition is trained mostly on adult speech. Accuracy on 3-5 year olds is lower — especially with accents, code-switching, or excited delivery. Mitigations: the teacher narrates what the child did, not what the child said, in most cases; the quoted child speech in the observation is short and high-signal.

**Q&A answer:** *"The teacher's voice is what's transcribed — not the child's. The teacher narrates: 'Amara built a tower…' That's standard adult speech and transcription is reliable. When the teacher quotes the child directly, yes, we see more errors — but the edit flow catches those."*

### 9.6 Trap behaviour

Trap refusal is a **three-layer defence**, not just a prompt trick:

1. **Prompt rule** — "bare teacher sentiment is never evidence for a learner-profile attribute; `learnerProfile` MUST be empty." Plus the explicit *"She was really lovely this morning"* trap example.
2. **Schema enforcement** — `additionalProperties: false` at every object level prevents the model from inventing a `comment` or `rationale` field as a consolation tag. `maxItems: 2` on `learnerProfile` caps the damage even if the prompt is weakened.
3. **Normaliser** — if the model does emit a malformed span (e.g. `{tag: "Caring", text: "she was kind"}` without a real transcript quote), the normaliser drops spans with empty or missing `quote`.

Remove any one layer and trap refusal can drop below 2/2. Keep the trap example in the prompt; regression test any prompt, schema, or normaliser change against the held-out corpus.

**Jaccard scoring treats empty tag sets as a perfect match** (`J(∅, ∅) = 1.0`). This is the convention used across `BatchRunner` / `eval.py` and was ratified in exp-01 review B2. It means the two bare-sentiment trap utterances contribute 1.0 each on perfect prediction rather than zero, making trap accuracy multiplicative with tag accuracy rather than penalising silence. Any new metric must preserve this convention or traps will score incorrectly.

---

## 10. Engineering gotchas (from the experiment — do not rediscover)

These cost real hours. Bake them into the code and onboarding.

1. **`URLSession.bytes(for:).lines` buffers the entire chunked response on iOS 17/18.** Streaming looks broken — one `onUpdate` callback at the end. Fix: custom `URLSessionDataDelegate` with `didReceive(data:)` + manual newline split. Confirmed on iPhone 15 simulator + real device. See `NDJSONStreamDelegate` in `OllamaAPI.swift`.
2. **Swift 6 MainActor default + Speech/AVFoundation callbacks = `unsafeForcedSync`.** `SFSpeechRecognizer` and `AVAudioEngine` fire completion callbacks on arbitrary queues. Any MainActor-isolated state those callbacks mutate trips the Swift 6 runtime's `unsafeForcedSync` check. Fix: `SpeechTranscriber` is `nonisolated final class`, state is wrapped in `OSAllocatedUnfairLock<State>`, the nested state struct is also `nonisolated`. See comment block at the top of `SpeechTranscriber.swift`.
3. **`NSLock.lock()` is banned from async contexts in Swift 6.** Trying to protect cross-queue state with `NSLock` in an `async` method fails a runtime check. Fix: `OSAllocatedUnfairLock`. Same as (2) but worth calling out separately because it's the intermediate fix that didn't work.
4. **`presence_penalty: 1.5` (qwen3General) breaks structured JSON output.** The penalty pushes the model away from `"`, `{`, `:`, `,` — JSON tokens repeat constantly, so the model emits key=value pseudo-formats instead. Every row fails to parse. Fix: `qwen3Structured` preset (presence_penalty = 0). Comment in `OllamaOptions.qwen3Structured` documents the incident.
5. **iOS Simulator CoreAudio reconfig loop.** `iOSSimulatorAudioDevice-...: Abandoning I/O cycle because reconfig pending` — mic tap installs but never delivers buffers. Not a code bug; sim-only. Mitigation: use text-input fallback on sim; validate voice on real device. Try `.playAndRecord` + `.default` instead of `.record` + `.measurement` if you must demo on sim.
6. **`requiresOnDeviceRecognition = true` on devices that don't support it → silent zero-output.** Fix: gate on `recognizer.supportsOnDeviceRecognition`; fall back to server recognition with a visible badge if we ever allow it (we don't, in production — see §3).
7. **`@Observable` + MainActor registrar touched from audio callbacks = same `unsafeForcedSync` class as (2).** Don't retrofit `@Observable` onto `SpeechTranscriber`. `LiveCaptureView` reads the final transcript after `stop()` completes, so reactive observation isn't needed.
8. **Xcode 16 file-system-synchronized groups flatten the bundle.** Same gotcha as Beat 2. Keep resources at bundle root.
9. **Field order in the JSON schema matters for progressive streaming.** `extractPartialTags` relies on `tags` arriving first (with its four sub-dimensions in the order `transdisciplinaryTheme` → `keyConcepts` → `atlSkills` → `learnerProfile`), then `confidence`, then `evidenceSpans`. Re-ordering silently breaks chip-by-chip rendering without breaking final decode. There is **no** `draft` field — the transcript is the description; re-adding `draft` means re-ordering the whole schema.
10. **Ollama `format` enforcement stops at the top-level shape.** The model still drifts on `evidenceSpans` items (`text` instead of `quote`, or missing `tag`), wraps the whole payload under a single-key container (`{"observation": {...}}`), or flattens the tag dimensions to the top level (`{theme, concepts, atl, profile, confidence, ...}`). The `normalizeObservationDraftJSON` pass salvages each of these failure modes. Any schema change that touches `tags` or `evidenceSpans` needs to re-validate the normaliser.
11. **Prompt techniques that regressed on Qwen 3.5 MoE — do not re-try without re-measuring.** During the exp-03 26-iteration hill-climb, several standard LLM-prompting techniques made accuracy *worse*: (a) worked examples (in-context full transcript→tags demonstrations, v16 / v24) regressed despite this being canonical few-shot practice; (b) self-check directives ("verify your tag list before returning", v25) caused the model to second-guess correct initial tags; (c) more than ~5 rule hints in one prompt (v10 was the sweet spot; v11, v20, v22 regressed as rules were added); (d) temperature sweeps away from 0.3 (both 0.1 and 0.5 regressed). This model prefers one-shot, density-bounded prompts. Any future prompt that re-introduces these patterns must pass the held-out regression gate.
12. **Field-name shorthand creep.** The model will drift toward `{theme, concepts, atl, profile}` if any prompt example, doc, or test fixture uses shorthand. The prompt explicitly forbids shorthand; the normaliser salvages it; keep both in place. Do not introduce shorthand into `PYPTag.swift` rawValues, `ObservationDraftSchema`, or example JSON anywhere in the codebase — it will leak into the model's output via the few-shot halo.

---

## 11. Explicit scope cuts (not in MVP)

- **No persistent filing.** The demo ends at a tagged on-screen observation. `File` button → SwiftData write → `Child.journal` is post-hackathon.
- **No offline retry queue.** Captures without LAN reach currently fail at the tagging step with a visible error. Post-hackathon: queue + background retagging.
- **No child-name detection.** Exp-03 plan calls for fuzzy-match + Metaphone against the setting's roster; not implemented yet. The model does not emit children — name extraction is the local matcher's job, post-hackathon.
- **No photo attach from Beat 1.** Beat 2 files photos to the journal, but the reverse (record an observation + attach a photo from camera) is post-hackathon.
- **No edit UI.** Teacher can't adjust tags or edit the draft in-app. Read-only display. Edits post-hackathon.
- **No translation.** Per-guardian locale rendering is Beat 3, separate feature. Beat 1's transcript is stored untranslated — it is the source of truth.
- **No audio waveform visualisation during recording.** Nice-to-have; cut for time.
- **No speaker diarisation.** The transcript attributes nothing to "teacher" vs "child". The teacher narrates; if the child's voice is audible and transcribed, it's plain text in the transcript.
- **No confidence thresholds that gate UI.** Every tag shows, regardless of confidence. The teacher judges. Post-hackathon: flag low-confidence tags visually.
- **No cross-device sync of in-progress recordings.** One teacher, one device. CloudKit sync kicks in after filing.

---

## 12. Post-hackathon productionisation

Not blockers for Wednesday; tracked for the roadmap.

1. **Persistent filing.** Wire `Observation` to SwiftData; one row per recorded observation; CloudKit-shared per child. Milestone: end of May.
2. **Offline retry queue.** `pendingRetag = true` observations are re-tagged when LAN returns; exponential backoff; visible badge in the journal.
3. **Child-name detection.** Fuzzy match + Metaphone against the setting's roster (exp-03 §6). F1 target ≥ 0.90.
4. **Edit UI.** Inline tag chips become tappable; `+` button adds a tag; long-press removes. Re-tag triggers prompt with "teacher said no to X" context.
5. **Confidence gating.** Any tag with `confidence < 0.5` rendered with a dashed border; teacher must confirm to keep it.
6. **Apple Intelligence fallback tuning.** Explicit opt-out of Private Cloud Compute (`SystemLanguageModel.default` with `PrivateCloudCompute.disabled` or equivalent — verify API). Shipping default is Ollama; FM only when Ollama unreachable.
7. **Corpus maintenance.** Quarterly re-measure on a rolling 20-utterance corpus. Regression threshold: ≥ 0.65 Jaccard on held-out, 2/2 trap refusal, zero unsupported evidence spans. Any prompt or model change must pass. Expand the corpus past 20 utterances post-hackathon — the current corpus is small enough that one reclassified gold label visibly moves the mean. Include a second annotator for inter-annotator agreement before treating any gold label as authoritative.
8. **Prompt versioning.** Tag the shipping prompt by semver (`pyp-v1.0`). Journal entries record which prompt version drafted them — important for later audits and for re-tagging history. Also record the **Ollama version + model digest** per entry; model snapshot changes are a silent drift source that seed-determinism hides.
9. **Per-setting prompt tuning.** Some settings adapt the PYP framework locally (e.g. add a specific learner-profile attribute). Future config lets settings tweak the taxonomy file without a rebuild.
10. **Prompt maintenance checklist.** Before any prompt merge: (a) run the full A+B corpora with `seed=42, temperature=0.3, think=false`; (b) verify transfer rate (gain on A should generalise at ≥ 60% to B — if not, the prompt is over-fitting); (c) check rule density — if the prompt now has >5 explicit rule hints, consider whether one rule subsumes another; (d) verify shorthand (`theme/concepts/atl/profile`) does not appear anywhere in the prompt text, including example JSON; (e) confirm the trap example is present verbatim; (f) record v+1 prompt text alongside v in `prompts/`, CSV results in `results/`.
11. **Per-dimension scoring.** The current Jaccard is computed over a flat tag union. A per-dimension breakdown (theme-only Jaccard, key-concept Jaccard, etc.) would reveal which dimensions need targeted prompt work. Requires a harness change; noted for the roadmap.
10. **Accessibility audit.** VoiceOver pass on the live capture screen. Recording button must announce state clearly. Hearing-impaired teachers need a visible waveform (nice-to-have) or mic-level indicator (MVP+).
11. **Privacy audit.** Before public beta: strip all `print("[...]")` calls; replace with OSLog at `.debug` level; grep binary for any third-party SDK traces; verify no MetricKit activation.

---

## 13. Success criteria for Wednesday's demo

In priority order:

1. **The demo does not crash.** One-shot rehearsal with the exact flow ≥ 3 times in the 48h before demo, one on venue wifi if possible. Rehearse both the mic path (real device) and the text-input fallback.
2. **TTFT < 1s, total < 5s.** Pre-warm Ollama in the morning. Leave the connection alive between rehearsal and demo. Run the u01 sample at venue in the morning as a smoke test.
3. **Tag chips appear visibly streaming, not in one burst.** This is the "oh wow" beat. If streaming breaks on stage, fall back to the non-streaming path and own the spinner — do not debug live.
4. **Mic captures the teacher's voice cleanly.** Rehearse with venue ambient noise; bring a Lavalier if needed. Stage-safety: the **Use u01 sample** path lets the demo continue if mic fails.
5. **Tag choice is plausible for the narrated observation.** Don't narrate edge cases on stage; rehearse three observations the v26 prompt has been measured on. Known-good tag outputs, known-good latency.
6. **Privacy narration is tight.** Exactly one sentence: *"Audio is transcribed on the phone. The transcript goes to a small computer the nursery owns. Nothing leaves the building."* Don't over-explain — the Q&A will go there.
7. **Narrative handoff between beats is clean.** Beat 1's journal entry is the destination Beat 2 files photos into; Beat 3 translates it; Beat 4 queues it when offline; Beat 5 exports it. Speaker names at least one handoff per beat transition.
8. **Latency badges visible on the final screen.** `confidence 0.82 · 3842 ms total, 612 ms TTFT` — the numbers are the credibility. Do not hide them behind a tap.

---

## 14. References

- `docs/research.md` §8 Beat 1 — demo storyboard
- `docs/technical-considerations.md` — architecture review
- `docs/experiments/experiment-01-path-a-review.md` — Foundation Models attempt, accuracy gate failure
- `docs/experiments/experiment-01-path-b-review.md` — Ollama shipping path
- `docs/experiments/experiment-01-private-drafting.md` — exp-01 origin brief
- `docs/experiments/experiment-03-pyp-capture-and-tagging.md` — PYP reshape spec
- `docs/experiments/exp-03-pyp-gold-decisions.md` — gold-labelling rationale
- `docs/experiments/experiment-03-review.md` — exp-03 results
- `docs/experiments/streaming-ui-spec.md` — streaming UI spec
- `docs/experiments/results/exp-01/path-b/README.md` — shipping path results memo
- `Experiments/VoiceTranscript/` — working code
- `Experiments/prompt-eval/PROGRESS.md` — 26-iteration prompt hill-climb log
- `app/docs/requirements/face-tagging.md` — sibling requirements doc (Beat 2)
