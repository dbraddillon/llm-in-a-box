# Architecture

## Pipeline

```
packs/<id>/pack.yaml --fetch-content--> build/raw/<id>/ --build-pack--> build/index/<id>.sqlite
models/manifest.yaml --fetch-model--> models/cache/<file>.gguf
(index files + model + runtime/) --load-drive--> out/<box>/ --package-output--> out/<box>.zip
```

## Why these choices

- **Embeddings:** `Xenova/all-MiniLM-L6-v2` via `@xenova/transformers` (transformers.js).
  Runs fully in Node via ONNX — no Python, no GPU. ~90MB, downloaded once and cached by
  transformers.js on first use.
- **Vector store:** one flat SQLite file per pack (`better-sqlite3`), brute-force
  cosine scan at query time. Fine up to tens of thousands of chunks — a curated pack
  won't get near that. Swap in `sqlite-vec` or an ANN index later if a pack outgrows
  it; not needed yet.
- **Chat model runtime:** llama.cpp's `llama-server` binary, OpenAI-compatible
  `/v1/chat/completions` endpoint. The runtime Node server proxies to it and injects
  retrieved chunks into the prompt (basic RAG, no reranking).
- **Scripts are pwsh (PowerShell 7), not Windows PowerShell** — pwsh runs on all three
  dev machines. Mac/Linux need `pwsh` installed; see `dev-machine-setup.md`.
- **Sharing content with Prepper:** a pack's source can be `type: local` pointing at a
  path under a Prepper checkout's `content/` folder, reusing already-downloaded bytes
  without coupling the two repos' build systems or config formats.
- **One source of truth for "what packs/models exist":** `gen-manifest.mjs` is the only
  place that parses `pack.yaml`/`models/manifest.yaml`. Everything downstream (the
  other build scripts, the pwsh wrappers, the wizard) reads
  `build/manifest.generated.json` instead of re-parsing YAML itself.

## What's real vs. stubbed right now

**Real and runnable (exercised against the `survival-sample` pack's fixture text):**
- `gen-manifest.mjs`, `fetch-pack-content.mjs`, `build-pack.mjs`
- `fetch-model.ps1`, `load-drive.ps1`, `package-output.ps1`, `verify-drive.ps1`
- `runtime/server` retrieval logic + `chat-ui` (needs a real `llama-server` binary +
  model present to actually answer a question)
- Builder wizard: manifest listing and streaming script output over SSE are real

**Not yet done:**
- No `llama-server` binary is fetched or bundled anywhere. `load-drive.ps1` leaves
  `<output>/bin/` empty and prints a warning; `verify-drive.ps1` flags it too. Next
  step: a `fetch-runtime.ps1` that pulls a prebuilt `llama-server` release per platform
  (win-x64 / mac-arm64 / linux-x64), same pattern as `fetch-model.ps1`.
- `models/manifest.yaml` URLs are best-effort pointers to well-known GGUF repos on
  Hugging Face, not verified against the live repos — confirm the exact
  repo/filename before the first real `fetch-model.ps1` run.
- No streaming in the chat UI — responses come back all at once, not token by token.
- No reranking / dedup of retrieved chunks, no multi-turn conversation history sent to
  the model (each question is answered independently).
- `npm audit` currently reports a critical/high chain (`protobufjs`, `sharp`) pulled in
  transitively by `@xenova/transformers`'s ONNX runtime deps. Low real risk here since
  this only runs locally at build time, not as an exposed service, but worth checking
  before this dependency tree ships anywhere more exposed than a dev machine.
