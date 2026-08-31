# llm-in-a-box

Offline "LLM in a box": a small quantized chat model + a locally-built vector index of
curated content, packaged so the whole thing can be copied to an offline machine and
run with no internet and no install step. A pack's content source can point at any
local folder of already-downloaded content instead of re-fetching it.

## How it fits together

- **`packs/<name>/pack.yaml`** — source of truth for one content pack: where its raw
  content comes from, how to chunk it.
- **`models/manifest.yaml`** — curated list of small GGUF chat models to choose from.
- **`scripts/`** — single-command pwsh entry points. The actual chunk/embed work
  happens in `scripts/node/*.mjs`; the `.ps1` files are thin wrappers.
- **`build/`** — gitignored. Raw fetched content + built `.sqlite` vector indexes, one
  per pack, plus `manifest.generated.json` (the one source of truth everything else
  reads instead of re-parsing YAML).
- **`runtime/`** — everything that ships to the offline drive: retrieval+chat server,
  chat UI, launcher. Self-contained, no dependency on the rest of the repo.
- **`builder/`** — dev-machine-only wizard UI. Thin wrapper around the same YAML files
  and pwsh scripts — it can't do anything you couldn't do by hand-editing
  `pack.yaml`/`models/manifest.yaml` and running the scripts directly.

## Common commands

```powershell
# one-time: install JS deps for scripts/runtime/builder (npm workspaces)
./setup.ps1

# regenerate build/manifest.generated.json from packs/*/pack.yaml + models/manifest.yaml
node ./scripts/node/gen-manifest.mjs

# download a pack's raw content into build/raw/<pack>
./scripts/fetch-content.ps1 -Pack survival-sample

# chunk + embed a pack into build/index/<pack>.sqlite
./scripts/build-pack.ps1 -Pack survival-sample

# download a model from models/manifest.yaml into models/cache/
./scripts/fetch-model.ps1 -Model qwen2.5-3b-instruct-q4

# download llama-server for this machine's platform (auto-detected) into runtime-bin/
./scripts/fetch-runtime.ps1

# cache the query/chunk embedding model into runtime/server/.model-cache -- required
# before load-drive.ps1, or the assembled box can't answer its first question offline
# (build-pack.ps1 also warms this as a side effect, so it's often already done)
./scripts/fetch-embedder.ps1

# assemble runtime + chosen packs + chosen model + platform runtime binary into one folder
./scripts/load-drive.ps1 -Packs survival-sample -Model qwen2.5-3b-instruct-q4 -Output ./out/box

# zip that folder for handing off to another machine
./scripts/package-output.ps1 -Path ./out/box

# smoke-test an assembled output folder (file presence, not that it actually runs)
./scripts/verify-drive.ps1 -Path ./out/box

# prove a box actually answers a question with zero network access (Docker,
# --network none) -- requires Docker; assembles its own box, so run it standalone,
# not against ./out/box
./scripts/verify-offline.ps1 -Model qwen2.5-3b-instruct-q4

# run the build wizard UI (dev machine only, http://127.0.0.1:5173)
cd builder; npm run dev
```

## Status

Full pipeline verified end to end and cross-platform as of 2026-08-28: real content
(incl. PDF/HTML/epub) fetched, chunked, embedded; a real `llama-server` binary and a
real model fetched; a box assembled and run from a path completely outside the repo,
answering a real question correctly with source attribution and streaming — on all
three canonical dev machines (win-x64, linux-x64, macos-arm64), not just one. Chat UI
restyled as a Grok-style shell. Multi-turn conversation memory shipped (`/api/chat`
now takes prior turns, not just the current question). Repo is public, Dependabot
enabled (0 open alerts as of 2026-08-29).

**2026-08-29 correction:** those "offline" verifications above never actually tested
without a network connection — all three machines had live internet, which silently
masked a real bug (a shipped box needed internet on its first query for the embedding
model). Fixed and this time verified for real, in a Docker container with
`--network none`, on win-x64/linux-x64 only so far — macos-arm64 not yet re-confirmed
under the fix. See `docs/01-architecture.md`'s dated entry for the full story,
including a second unrelated bug the same test caught (a Windows-cross-fetched Linux
runtime was silently missing shared libraries).

**2026-08-30 addendum — Raspberry Pi scoped, not yet real-hardware-tested:** before
buying a Pi, used Docker's `--platform linux/arm64` QEMU emulation to check the
linux-arm64 path. Confirmed `better-sqlite3`/`onnxruntime-node` have prebuilt
aarch64-linux bindings and `llama-server` runs clean on stock Raspberry Pi OS
("Trixie," Debian 13). A first-pass recommendation to install Ubuntu Server instead
was wrong — based on stale knowledge that Raspberry Pi OS still defaults to Debian
12; it moved to Trixie in October 2025 — corrected same session. Pi 5 (8GB) ordered;
real hardware test still pending. Full detail: `docs/01-architecture.md`'s
2026-08-30 entry, setup checklist in `docs/dev-machine-setup.md`.

See `docs/01-architecture.md` for exactly what's been tested vs. what's still
missing (reranking, a real content pack instead of the smoke-test fixture, etc.), and
`docs/content-sourcing.md` before pointing a pack at content you don't have rights to.
