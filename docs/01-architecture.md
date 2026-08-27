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
- **Full end-to-end chat**, assembled box run from a path completely outside the repo
  (proving it's actually portable, not just working because Node's module resolution
  found the repo's root `node_modules`): `llama-server` + the runtime Node server both
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

**Not yet done:**
- No streaming in the chat UI — responses come back all at once, not token by token.
- No reranking / dedup of retrieved chunks, no multi-turn conversation history sent to
  the model (each question is answered independently).
- HTML extraction is a tag-stripper, not a Readability-style extractor — will include
  boilerplate (sidebars, related-links blocks, etc.) that isn't inside the excluded
  tags on more complex real-world pages than the test fixture.
- `npm audit` currently reports a critical/high chain (`protobufjs`, `sharp`) pulled in
  transitively by `@xenova/transformers`'s ONNX runtime deps. Low real risk here since
  this only runs locally at build time, not as an exposed service, but worth checking
  before this dependency tree ships anywhere more exposed than a dev machine.
- `chat-ui`'s Vite dev proxy still points at the old `runtime/server` port — fine for
  `npm run build` + assembled-box usage, just not live-reload-tested against a running
  dev-mode `llama-server`.
