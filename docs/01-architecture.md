# Architecture

## Pipeline

```
packs/<id>/pack.yaml --fetch-content--> build/raw/<id>/ --build-pack--> build/index/<id>.sqlite
models/manifest.yaml --fetch-model--> models/cache/<file>.gguf
ggml-org/llama.cpp releases --fetch-runtime--> runtime-bin/<platform>/
Xenova/all-MiniLM-L6-v2 --fetch-embedder--> runtime/server/.model-cache/
(index files + model + runtime bin + runtime/, including .model-cache) --load-drive--> out/<box>/ --package-output--> out/<box>.zip
```

## Why these choices

- **Embeddings:** `Xenova/all-MiniLM-L6-v2` via `@huggingface/transformers`
  (transformers.js). Runs fully in Node via ONNX — no Python, no GPU. ~90MB.
  `retrieval.mjs`, `build-pack.mjs`, and `fetch-embedder.mjs` all set the **global**
  `env.cacheDir` to `runtime/server/.model-cache` (relative to `retrieval.mjs`'s own
  file location, so it resolves correctly whether that file is sitting in the dev
  tree or a shipped box) instead of the library's default — which lives inside
  `node_modules/@huggingface/transformers` and would be empty on a shipped box's
  standalone `npm install`, silently requiring internet on the first real query.
  Global `env.cacheDir`, not `pipeline()`'s per-call `cache_dir` option — the latter
  looked sufficient (model/tokenizer binaries loaded from it fine) but
  `config.json`/`tokenizer_config.json` load through an internal code path
  (`get_model_files` → `get_config`) that doesn't forward the per-call option and
  always falls back to the global default, so a per-call-only fix still crashed on
  the first real query with no other symptom until actually tested offline. See the
  dated entry below.
- **Vector store:** one flat SQLite file per pack (`better-sqlite3`), brute-force
  cosine scan at query time. Fine up to tens of thousands of chunks — a curated pack
  won't get near that. Swap in `sqlite-vec` or an ANN index later if a pack outgrows
  it; not needed yet.
- **Content extraction:** `.txt`/`.md` read as-is, `.pdf` via `pdf-parse`, `.html`/`.htm`
  via `node-html-parser` scoped to `<body>` with `script`/`style`/`nav`/`header`/`footer`
  stripped first. The HTML path is a tag-stripper, not a Readability-style boilerplate
  remover — fine for a single article/page, noisier on a nav-heavy full-site scrape.
  `.epub` is unzipped with `adm-zip`, its `container.xml`/`.opf` walked with
  `fast-xml-parser` to get manifest + spine order, then each chapter (itself XHTML)
  reuses the same tag-strip as the HTML path. Chapter order comes from the spine, not
  manifest order — epub authoring tools don't guarantee those match.
  See `content-sourcing.md` for what's reasonable to point these at.
- **Chat model runtime:** llama.cpp's `llama-server` binary, OpenAI-compatible
  `/v1/chat/completions` endpoint, fetched per-platform from `ggml-org/llama.cpp`'s
  GitHub releases (CPU-only build, no CUDA/Vulkan/ROCm). The runtime Node server proxies
  to it and injects retrieved chunks into the prompt (basic RAG, no reranking).
- **`fetch-runtime.ps1` resolves the latest release rather than hardcoding a version** —
  llama.cpp ships build-numbered releases (`b10664`, ...) always flagged as GitHub
  prereleases; there's no semver "latest", so the script walks `/releases` and takes
  the first (most recent) entry.
- **Scripts are pwsh (PowerShell 7), not Windows PowerShell** — pwsh runs on all three
  dev machines. They also avoid PS7-only syntax (`?.`, `??`) so they still work under
  Windows PowerShell 5.1 as a fallback (verified on the machine this was scaffolded on,
  which doesn't have `pwsh` installed).
- **`load-drive.ps1` auto-detects the current platform** (`Get-CurrentPlatform` in
  `_common.ps1`) to pick which cached runtime binary and DLL set to bundle, so the same
  command works unmodified on any of the three dev machines. Override with `-Platform`
  to assemble a box for a different target than the machine you're building on.
- **Reusing already-downloaded content:** a pack's source can be `type: local` pointing
  at any folder of already-downloaded files, without needing its own fetch/build
  system to have produced them.
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
2. `runtime/server`'s dependencies (`express`, `better-sqlite3`, `@huggingface/transformers`)
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
  build/run). Migrated `@xenova/transformers@2.17.2` (abandoned, last release, still
  pinned a vulnerable `protobufjs`/`sharp`/`adm-zip` chain — 12 Dependabot alerts, 1
  critical/6 high/5 moderate) to the maintained successor `@huggingface/transformers`
  in both `retrieval.mjs` and `build-pack.mjs` — API is identical
  (`pipeline('feature-extraction', 'Xenova/all-MiniLM-L6-v2')`), no logic changes
  needed. Closed 8 of 12 alerts outright; the remaining `sharp`/`adm-zip` transitive
  pins (still capped below the patched version by their own parent packages'
  ranges) are forced to the patched versions via root-level `npm overrides` — added
  to **both** the root `package.json` (covers the dev workspace install) and
  `runtime/server/package.json` (covers `load-drive.ps1`'s standalone
  `npm install` into the shipped box's `server/` folder, which does not inherit
  workspace-root config) — verified both resolve to the patched versions after a
  clean install. `npm audit` now reports 0 vulnerabilities. Verified for real, not
  just installed: rebuilt `survival-sample`'s index with the new library, assembled a
  box, launched it, and asked a real question — correct sourced answer came back
  unchanged, confirming the embedding pipeline behaves the same under the new
  library.
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
- **`.epub` support (2026-08-28):** `build-pack.mjs` now extracts `.epub` files
  (`adm-zip` + `fast-xml-parser` to walk `container.xml`/the `.opf` manifest+spine,
  then the existing HTML tag-strip per chapter). Verified for real: built a synthetic
  two-chapter epub (spine order deliberately different from manifest order, plus
  `nav`/`header`/`footer` noise in one chapter), ran it through `build-pack.mjs` for
  real, confirmed the resulting chunk has both chapters in spine order with the
  noise stripped, and confirmed retrieval (`retrieval.mjs`) finds the right chapter
  for a query. Not yet tested against a real-world epub from an actual publisher —
  those can have messier markup (multiple rootfiles, non-XHTML manifest items,
  `linear="no"` spine items) than the synthetic fixture covers.
- **A shipped box couldn't actually answer its first question offline (found and
  fixed 2026-08-29):** prompted by the question "can a box add new content once it's
  offline" — the direct answer is still no (the chunking/extraction toolchain in
  `scripts/node` never gets copied into `load-drive.ps1`'s output, only
  `runtime/server` does; a pre-built `.sqlite` dropped into an existing box's
  `index/` folder via USB *does* get picked up on restart, since `index.mjs` just
  globs everything there, but the box itself can't produce one) — but chasing it
  surfaced a bigger problem: **every query**, not just adding content, needed
  internet on a genuinely fresh box. `retrieval.mjs`'s embedder is a live
  `pipeline()` call, same as at build time, and a standalone `npm install` of
  `runtime/server` (what `load-drive.ps1` actually runs) starts with an empty
  model cache — confirmed by installing it fresh in an empty directory and finding
  no cache directory at all until the first call created one by reaching the
  network. The three previous "verified offline" cross-platform runs never caught
  this because all three test machines had live internet, which silently masked it.
  Fixed with `fetch-embedder.ps1`/`fetch-embedder.mjs` (new, mirrors
  `fetch-model.ps1`'s shape) pre-warming `runtime/server/.model-cache`, which
  `load-drive.ps1` now requires before assembling (same missing-prerequisite check
  pattern as the GGUF model) and bundles automatically since it's copied as part of
  `runtime/server`. Getting this actually right took two more rounds, both only
  caught by testing for real:
  1. **`pipeline()`'s per-call `cache_dir` option isn't enough** — model/tokenizer
     binaries loaded from it fine, but `config.json`/`tokenizer_config.json` load
     through `get_model_files` → `get_config`, which only forwards `{ config }` to
     the next call, silently dropping `cache_dir` and falling back to the library's
     own default. Looked completely fine until tested with no network — the config
     files fetch silently (fast, unnoticed) whenever network happens to be
     available, which is exactly the "worked in every test so far" trap this whole
     entry is about. Real fix: set the **global** `env.cacheDir`, which every
     internal code path falls back to regardless of whether `cache_dir` got
     threaded through.
  2. **Verifying "no internet" honestly needed a real network-isolated environment**,
     not just re-reading code — used `docker run --network none` (confirmed via
     `/proc/net/dev` showing only `lo`) against a real assembled box, which is what
     actually caught both the `cache_dir` bug above and, along the way, a **second,
     unrelated real bug**: `fetch-runtime.ps1 -Platform linux-x64` run *from
     Windows* produced a broken bundle, because Windows' `tar.exe` needs an
     elevated privilege to create the `.so` SONAME symlinks a Linux `llama-server`
     build ships (`libfoo.so`/`libfoo.so.0` → `libfoo.so.0.1.2`) and silently drops
     those entries instead of failing loudly. Fixed in `fetch-runtime.ps1`: after
     tar extraction, scan for versioned `.so.X.Y.Z` files and fill in any missing
     `lib.so`/`lib.so.<major>` aliases with plain file copies (works regardless of
     Windows symlink privileges, and is a no-op on a platform where tar already
     created real symlinks). Confirmed fixed with `ldd` inside the container
     (all libraries resolved) before finding the cache bug above.
  Final verification, fully real: assembled a linux-x64 box, built a Docker image
  from it (installing `runtime/server`'s deps *inside* the Linux container, since
  `better-sqlite3` ships platform-native binaries and the box's own `node_modules`
  had been installed on Windows), ran it with `--network none`, and got a correctly
  sourced answer back from a container with no network interface besides loopback.
  This ad hoc Docker harness found two real, previously-unknown bugs in a single
  run, which was reason enough to keep it: promoted to a permanent, rerunnable
  `./scripts/verify-offline.ps1 -Model <id>` (plus `offline-verify.Dockerfile` and
  `offline-verify-query.mjs`) the same day. Assembles its own box (any `-Packs`,
  defaults to `survival-sample`), targets whatever architecture the Docker daemon
  itself runs (not necessarily the host's — Docker Desktop runs a Linux VM
  regardless of host OS), confirms isolation itself by checking
  `/proc/net/dev` for a non-loopback interface rather than trusting the
  `--network none` flag blindly, and sends a real `/api/chat` request. Two
  PowerShell-specific gotchas surfaced writing it, both fixed: redirecting a native
  command's stderr (`docker rm -f ... 2>$null`) turns into a terminating error
  under this repo's `$ErrorActionPreference='Stop'` even on success — use
  `try {} catch {}` instead, never stream redirection, on any native call whose
  failure is expected/harmless; and passing a multi-line double-quoted JS string as
  a `docker exec ... node -e` argument gets its quotes mangled by PowerShell's
  native-argument marshalling — write it to a real file and exec that by path
  instead.
- **Raspberry Pi (linux-arm64) scoped, pre-hardware, via QEMU emulation
  (2026-08-30):** before buying a Pi, checked what a real one would hit using
  Docker's `--platform linux/arm64` cross-arch emulation (`docker buildx ls`
  confirmed it's already registered on this machine; `docker run --platform
  linux/arm64 ... uname -m` → `aarch64` confirms it's genuine, not just accepting
  the flag).
  - **`fetch-runtime.ps1 -Platform linux-arm64`** hit the identical Windows
    tar.exe symlink-drop bug as linux-x64 (see the entry above) — same fallback
    fixed it with no code changes needed; confirmed by inspecting
    `runtime-bin/linux-arm64/` for the filled-in `lib*.so`/`lib*.so.<major>`
    aliases. Second platform exercising the same fix is good regression coverage
    for it.
  - **`npm install --omit=dev` inside the box's `server/` folder completed clean
    under emulation** (`added 154 packages in 2m`, no compile errors) — confirms
    `better-sqlite3` and `onnxruntime-node` (pulled in via
    `@huggingface/transformers`) both ship prebuilt aarch64-linux native bindings.
    A Pi won't need build-essential/python3/node-gyp or a slow from-source
    native-module compile.
  - **`llama-server`'s `bin-ubuntu-arm64` release binary needs glibc >= 2.38**
    (`GLIBC_2.38`/`GLIBCXX_3.4.32` not found errors under a Debian 12 "bookworm"
    base, glibc 2.36). **First-pass conclusion here was wrong and got corrected
    same session** — initially assumed bookworm was still the current default
    Raspberry Pi OS and recommended installing Ubuntu Server 24.04 instead to
    route around it. That assumption was stale: **Raspberry Pi OS moved to
    "Trixie" (Debian 13) as its default in October 2025.** Checked Trixie
    directly (`debian:trixie-slim`, arm64, emulated) — glibc 2.41, and the exact
    same `llama-server` binary runs clean there once `libssl3`/`libgomp1` are
    installed, no OS substitution needed. **Actual upshot: the plain default
    Raspberry Pi OS via Raspberry Pi Imager just works** — no non-default OS
    detour, the earlier Ubuntu recommendation was unnecessary. Worth remembering
    the shape of the mistake, not just the correction: "current default" claims
    about a fast-moving external project are exactly the kind of thing that goes
    stale between training data and now and need checking, not assuming, before
    they inform a real purchase/setup decision.
  **Not yet confirmed:** the full stack (Node server + llama-server together,
  real `/api/chat` query, `--network none`) in one container on a Trixie base —
  each half is independently confirmed (Node/npm stack on bookworm above,
  `llama-server` on Trixie here) but not yet combined in a single pass; ran out
  of a reasonable time budget under QEMU emulation's overhead before finishing
  that combination. Also, emulation only proves software correctness, not real
  inference speed or RAM pressure on actual Pi silicon — that part still needs
  the hardware once it exists.
