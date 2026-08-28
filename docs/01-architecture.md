# Architecture

## Pipeline

```
packs/<id>/pack.yaml --fetch-content--> build/raw/<id>/ --build-pack--> build/index/<id>.sqlite
models/manifest.yaml --fetch-model--> models/cache/<file>.gguf
ggml-org/llama.cpp releases --fetch-runtime--> runtime-bin/<platform>/
(index files + model + runtime bin + runtime/) --load-drive--> out/<box>/ --package-output--> out/<box>.zip
```

## Why these choices

- **Embeddings:** `Xenova/all-MiniLM-L6-v2` via `@xenova/transformers` (transformers.js).
  Runs fully in Node via ONNX — no Python, no GPU. ~90MB, downloaded once and cached by
  transformers.js on first use.
- **Vector store:** one flat SQLite file per pack (`better-sqlite3`), brute-force
  cosine scan at query time. Fine up to tens of thousands of chunks — a curated pack
  won't get near that. Swap in `sqlite-vec` or an ANN index later if a pack outgrows
  it; not needed yet.
- **Content extraction:** `.txt`/`.md` read as-is, `.pdf` via `pdf-parse`, `.html`/`.htm`
  via `node-html-parser` scoped to `<body>` with `script`/`style`/`nav`/`header`/`footer`
  stripped first. The HTML path is a tag-stripper, not a Readability-style boilerplate
  remover — fine for a single article/page, noisier on a nav-heavy full-site scrape.
  See `content-sourcing.md` for what's reasonable to point these at.
- **Chat model runtime:** llama.cpp's `llama-server` binary, OpenAI-compatible
  `/v1/chat/completions` endpoint, fetched per-platform from `ggml-org/llama.cpp`'s
  GitHub releases (CPU-only build, no CUDA/Vulkan/ROCm). The runtime Node server proxies
  to it and injects retrieved chunks into the prompt (basic RAG, no reranking).
- **`fetch-runtime.ps1` resolves the latest release rather than hardcoding a version** —
  same reasoning as Prepper's `kiwix` source type resolving from the OPDS catalog instead
  of a dated URL. llama.cpp ships build-numbered releases (`b10664`, ...) always flagged
  as GitHub prereleases; there's no semver "latest", so the script walks `/releases` and
  takes the first (most recent) entry.
- **Scripts are pwsh (PowerShell 7), not Windows PowerShell** — pwsh runs on all three
  dev machines. They also avoid PS7-only syntax (`?.`, `??`) so they still work under
  Windows PowerShell 5.1 as a fallback (verified on the machine this was scaffolded on,
  which doesn't have `pwsh` installed).
- **`load-drive.ps1` auto-detects the current platform** (`Get-CurrentPlatform` in
  `_common.ps1`) to pick which cached runtime binary and DLL set to bundle, so the same
  command works unmodified on any of the three dev machines. Override with `-Platform`
  to assemble a box for a different target than the machine you're building on.
- **Sharing content with Prepper:** a pack's source can be `type: local` pointing at a
  path under a Prepper checkout's `content/` folder, reusing already-downloaded bytes
  without coupling the two repos' build systems or config formats.
- **One source of truth for "what packs/models exist":** `gen-manifest.mjs` is the only
  place that parses `pack.yaml`/`models/manifest.yaml`. Everything downstream (the
  other build scripts, the pwsh wrappers, the wizard) reads
  `build/manifest.generated.json` instead of re-parsing YAML itself.

## What's real vs. stubbed right now

**Real, tested end to end (not just written) as of 2026-08-27:**
- `gen-manifest.mjs`, `fetch-pack-content.mjs`, `build-pack.mjs` — including `.pdf`
  and `.html` extraction, verified against a real Edge-generated PDF and an HTML
  fixture with nav/header/footer/script correctly stripped.
- `fetch-model.ps1` — all three `models/manifest.yaml` entries HEAD-checked and
  resolving; the Qwen2.5-3B entry fetched for real (1.95GB).
- `fetch-runtime.ps1` — fetched a real `llama-server` (win-x64, build b10664) from the
  live `ggml-org/llama.cpp` release feed and confirmed it runs (`--version`).
- `load-drive.ps1`, `verify-drive.ps1`, `package-output.ps1`.
- **Cross-platform full end-to-end chat (2026-08-27 night / 2026-08-28 early AM):**
  repo cloned fresh and the whole pipeline (`fetch-model`, `fetch-runtime`,
  `load-drive.ps1`, launch, real chat question) run for real on:
  - **win-x64** (this dev machine) — see below.
  - **linux-x64 (Ubuntu 24.04, home server)** — assembled box at
    `~/llm-box-linux-test`; `llama.log` shows a real answered prompt (239 tokens in,
    85 out, ~12.8s). Confirmed 2026-08-28 by reading that box's actual logs over SSH,
    not by recalling a prior session's summary.
  - **macos-arm64 (Mac Mini)** — now also fully confirmed (closed same day, 2026-08-28):
    assembled a box at `~/llm-mac-test-box`, launched `llama-server` + the runtime
    server, sent a real `/api/chat` question, got a correctly-sourced answer back.
    Gotcha worth remembering: Homebrew-installed `pwsh`/`node` aren't on `PATH` for a
    non-interactive `ssh host "cmd"` invocation, only for a login shell — use
    `ssh host "zsh -l -c 'cmd'"` or full binary paths, or it'll falsely look like
    the tools aren't installed.

All three canonical dev machines (win-x64, linux-x64, macos-arm64) are now confirmed
at the same level: assemble + launch + real answered question.
- **win-x64 full end-to-end chat:** assembled box run from a path completely outside
  the repo (proving it's actually portable, not just working because Node's module
  resolution found the repo's root `node_modules`): `llama-server` + the runtime Node server both
  started, and `/api/chat` returned a correct answer with source attribution for a
  real question against the `survival-sample` pack.
- Builder wizard: manifest listing, streaming script output over SSE, and the
  fetch-runtime button are real.

**Two real bugs found and fixed during that end-to-end test, worth knowing about if
something similar breaks again:**
1. `llama-server.exe` is a ~9KB launcher that dynamically loads ~50 sibling DLLs
   (`ggml-cpu-*.dll` per CPU-feature variant, `llama-server-impl.dll`, `mtmd.dll`, ...)
   from the same directory. Both `fetch-runtime.ps1` and `load-drive.ps1` originally
   copied only the single exe — fixed to copy the whole extracted/cached directory.
   `Get-NetTCPConnection`/silent-exit with no output was the symptom; running the exe
   from Git Bash surfaced the real `error while loading shared libraries` message that
   Windows' own exit-code reporting didn't show clearly.
2. `runtime/server`'s dependencies (`express`, `better-sqlite3`, `@xenova/transformers`)
   are hoisted into the repo root's `node_modules` by npm workspaces during dev. A
   naive copy of `runtime/server/` into an output folder looked like it worked when
   tested *inside* the repo tree (Node's module resolution walks up and finds the root
   `node_modules` by accident) but would fail on a genuinely separate machine.
   `load-drive.ps1` now runs a standalone `npm install --omit=dev` inside the output's
   `server/` folder so it carries its own `node_modules`.

**Streaming responses (2026-08-27):** `/api/chat` now proxies `llama-server`'s SSE
stream token-by-token instead of buffering the full completion — verified for real
with a timestamped chunk log (70 chunks over ~7.8s, arriving at generation pace, not
one dump at the end). Sources travel in an `x-sources` response header (URL-encoded
JSON) since the body is now plain streamed text, not a JSON envelope. Client side
(`App.vue`) reads via `response.body.getReader()`; note the fix needed there — mutate
the message object *as read back out of* `messages.value` after pushing, not the plain
object reference from before the push, or Vue's reactivity won't see the incremental
updates.

**Chat history (2026-08-27):** persisted to `localStorage` (`llm-in-a-box-chat` key),
plus Export (downloads a plain-text transcript) and Clear buttons. Persistence writes
happen at message boundaries (after the user's message, and again once a streamed
answer finishes), not on every token — a deep watch would fire a synchronous
localStorage write per token during streaming, which is real jank for no benefit.
Verified in an actual browser via Puppeteer: history survives a full page reload (not
just SPA in-memory state), Export produces a correctly formatted transcript, Clear
empties state/localStorage and disables both buttons. Deliberately did **not** add
multi-conversation management (named threads, a switcher UI) — one persisted
conversation covers the actual use case; that would be scope the tool doesn't need.

**Chat UI restyle (2026-08-28):** `runtime/chat-ui` rebuilt as a Grok-style chat shell
— split into `Sidebar`/`Composer`/`UserBubble`/`AssistantTurn`/`EmptyState` components,
near-black design tokens, self-hosted Sora + IBM Plex Mono (`woff2` bundled via Vite,
not a Google Fonts `<link>` — this ships to a machine with no internet), markdown
rendering for assistant text via `marked` + `DOMPurify`. Visual/interaction pass only —
`/api/chat`, streaming, localStorage history, export/clear all unchanged. Verified in
an actual browser (Chrome via `npm run dev`): empty state, composer, sidebar
recent-query list, and the inline muted-red error path (no `llama-server` running, so
the network-failure branch) all render as expected. Empty-state composer position was
reported "weirdly low" on first real look and fixed same day (two independent
`flex:1` regions each centering their own content, replaced with one centered block).
The mark glyph (a "+" rotated 45°, i.e. an X) was reported confusing — read as a
cancel/close icon — and fixed to a single diagonal slash-in-circle. **Now** also
verified against a real streamed answer on both win-x64 and macos-arm64: correct
markdown rendering, correct source-chip attribution (`placeholder.txt`, since the
loaded pack is the smoke-test fixture, not real content). Mobile drawer breakpoint
(`768px`) still isn't visually confirmed — the sandboxed browser wouldn't resize below
its host window size — but it's a standard `translateX` drawer pattern.

**Multi-turn conversation (2026-08-28):** `/api/chat` now accepts a `history` array
(prior `{role, text}` turns, sent by the client from its own `messages` state) and
folds it into the prompt as plain dialogue, ahead of the current
Context+Question-wrapped turn. Capped at the last 16 turns. Prior turns are sent as
plain text, **not** re-wrapped with their original retrieved context — that context
was only needed once, to ground the answer when it was first given; resending it
every turn would bloat the prompt for no benefit. Verified for real: asked it to
remember an arbitrary fact ("My name is Zorblatt") in turn one, then asked "what's my
name?" in turn two with no matching content in the retrieved chunks — it answered
correctly from history alone. Note: a 3B quantized model isn't perfectly reliable at
this on every sample (one early test with the identical prompt shape failed, a retry
succeeded) — the mechanism works, but don't expect research-grade reliability out of
a model this size.

**Not yet done:**
- No reranking / dedup of retrieved chunks.
- HTML extraction is a tag-stripper, not a Readability-style extractor — will include
  boilerplate (sidebars, related-links blocks, etc.) that isn't inside the excluded
  tags on more complex real-world pages than the test fixture.
- **Dependency security (2026-08-28):** Dependabot enabled on the repo. `vite` bumped
  5.4 → 6.4.3 (closed 3 alerts, dev-server-only, both workspaces verified still
  build/run). Remaining: a `protobufjs`/`sharp` chain transitive via
  `@xenova/transformers@2.17.2`, which is already the latest published version and
  still pins vulnerable `onnxruntime-web`/`sharp`. `npm audit fix --force` "fixes" this
  by *downgrading* to `@xenova/transformers@1.4.2` — not a real fix, just an older
  release — so left alone. Real fix is migrating to the maintained successor
  `@huggingface/transformers`, which touches `retrieval.mjs`/`build-pack.mjs` and needs
  its own verification pass against the embedding pipeline before committing to it.
- `chat-ui`'s Vite dev proxy target (`127.0.0.1:7860`) already matches
  `runtime/server`'s actual port — the "points at the old port" note this used to say
  was stale, corrected 2026-08-28. Still not live-reload-tested via `npm run dev`
  against a running dev-mode `llama-server`, though — all real-backend verification so
  far has gone through the built `dist` + assembled box, not the Vite dev server's
  proxy.
- Only real content pack loaded/tested is `survival-sample`, a one-file smoke-test
  fixture (`packs/survival-sample/fixtures/placeholder.txt`) — one chunk, so
  retrieval relevance and multi-chunk source attribution are both untested against
  anything real.
