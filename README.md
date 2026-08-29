# llm-in-a-box

Offline "LLM in a box": a small quantized chat model plus a locally-built vector
index of content you choose, packaged into one self-contained folder you can copy to
a machine with no internet connection and no install step, and just run.

Point it at survival guides, a manual set, internal docs, whatever — it answers
questions using only that content, with source attribution, entirely offline.

## What it does

1. You pick some content (a folder of files, or a URL) and describe it in a
   `pack.yaml`.
2. `build-pack` chunks that content and embeds it into a local SQLite vector index —
   no external API calls, embeddings run on-device.
3. You pick a small GGUF chat model from a curated list and download it once.
4. `load-drive` bundles the index, the model, a per-platform `llama.cpp` runtime
   binary, and a small retrieval+chat web server into one output folder.
5. Copy that folder anywhere — a USB drive, an air-gapped laptop — and double-click
   the launcher. It starts a local chat UI in your browser backed by the model and
   the index, with zero network access required.

## What it can do

- **Retrieval-augmented chat** — every answer is grounded in the loaded content pack
  and cited by source file/chunk, not the model's own training data.
- **Streaming responses** — tokens stream to the UI as the model generates them, not
  a buffered dump at the end.
- **Multi-turn conversation** — the chat remembers prior turns in the same session
  (last 16), so follow-up questions work.
- **Persisted chat history** — survives a page reload (`localStorage`), plus Export
  (plain-text transcript) and Clear.
- **Multiple content packs and models** — `pack.yaml` per content set,
  `models/manifest.yaml` lists small (~2GB, CPU-only) instruct models to choose
  from; swap either independently of the other.
- **Runs on Windows, macOS (Apple Silicon), and Linux** without code changes — the
  loader auto-detects the current platform and fetches the matching `llama-server`
  binary.
- **No install step on the target machine** — the assembled output folder is
  self-contained (its own `node_modules`, its own model file, its own runtime
  binary). The machine you hand it to needs nothing preinstalled.

## Quick start

```powershell
./setup.ps1                                                       # one-time: install JS deps
./scripts/fetch-model.ps1 -Model qwen2.5-3b-instruct-q4            # ~2GB download
./scripts/fetch-runtime.ps1                                        # llama-server for this machine
./scripts/build-pack.ps1 -Pack survival-sample                     # builds the included smoke-test pack
./scripts/load-drive.ps1 -Packs survival-sample -Model qwen2.5-3b-instruct-q4 -Output ./out/box
```

Then open `./out/box`, run `launch.cmd` (Windows) or `./launch.sh` (Mac/Linux), and
open http://127.0.0.1:7860. `survival-sample` is a one-file placeholder pack meant to
prove the pipeline works — swap in real content before you rely on it (see below).

## Loading more content

Content lives in `packs/<name>/pack.yaml`. Minimal example:

```yaml
id: my-pack
label: "My Pack"
sources:
  - type: local        # or: type: http
    path: ./fixtures    # a folder, for type: local
chunk:
  max_chars: 1200
  overlap_chars: 160
```

- `.txt`, `.md`, `.pdf`, `.html`/`.htm`, and `.epub` are all supported extraction
  formats.
- `type: local` reads from a folder on disk; `type: http` fetches from a URL.
- Run `./scripts/fetch-content.ps1 -Pack my-pack` (only needed for `http` sources)
  then `./scripts/build-pack.ps1 -Pack my-pack` to chunk and embed it into
  `build/index/my-pack.sqlite`.
- Pass multiple `-Packs` (comma or array) to `load-drive.ps1` to bundle more than one
  pack into the same box.
- **Before pointing a pack at content you don't personally own** — read
  `docs/content-sourcing.md` first. Public domain (US government works), permissively
  licensed (CC-BY, CC0), or your own material is fine; scraping paywalled/ToS-restricted
  content is not, even if it's technically reachable.

## Two ways to build a box

**Config files + scripts** (shown above) — edit `pack.yaml` /
`models/manifest.yaml` by hand, run the `.ps1` scripts directly. Full control,
scriptable, no server running.

**Builder wizard UI** — a small dev-only web app that wraps the same YAML files and
scripts with a form and a "run this step" button, streaming script output live. It
can't do anything the scripts above can't do by hand — it's a friendlier front end
over identical state.

```powershell
cd builder
npm run dev        # http://127.0.0.1:5173
```

## Where it's been tested

As of 2026-08-28, the full pipeline — fetch model, fetch runtime, build a pack, load
a drive, launch it from a path outside the repo, ask a real question, get a correctly
sourced streamed answer — has been run end-to-end for real on all three target
platforms:

| Platform | Status |
|---|---|
| Windows (win-x64) | ✅ verified |
| Linux (linux-x64, Ubuntu) | ✅ verified |
| macOS (macos-arm64, Apple Silicon) | ✅ verified |

Only real content pack tested so far is the included one-file `survival-sample`
smoke-test fixture — good for proving the pipeline works, not yet validated against a
large real pack (retrieval quality with more than one chunk is untested). See
`docs/01-architecture.md` for the full breakdown of what's verified vs. still
outstanding (no reranking yet, HTML extraction is a plain tag-stripper, one dependency
chain with no clean upstream fix yet).

## Repo layout

- `packs/<name>/pack.yaml` — source of truth for one content pack.
- `models/manifest.yaml` — curated list of small GGUF chat models.
- `scripts/` — single-command pwsh entry points (`.ps1`); actual chunk/embed logic is
  in `scripts/node/*.mjs`.
- `build/` — gitignored. Raw fetched content + built `.sqlite` indexes.
- `runtime/` — everything that ships to the offline box: retrieval+chat server, chat
  UI, launcher scripts. Self-contained.
- `builder/` — dev-machine-only wizard UI described above.

See `docs/01-architecture.md` for design rationale and a detailed, dated log of
what's been verified vs. still outstanding.
