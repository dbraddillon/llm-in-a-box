# llm-in-a-box

Offline "LLM in a box": a small quantized chat model + a locally-built vector index of
curated content, packaged so the whole thing can be copied to an offline machine and
run with no internet and no install step. Sibling concept to `Prepper` (offline content
drive) — shares no code, but a pack's content source can point at a local Prepper
`content/` folder instead of re-downloading.

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

# assemble runtime + chosen packs + chosen model into one folder
./scripts/load-drive.ps1 -Packs survival-sample -Model qwen2.5-3b-instruct-q4 -Output ./out/box

# zip that folder for handing off to another machine
./scripts/package-output.ps1 -Path ./out/box

# smoke-test an assembled output folder
./scripts/verify-drive.ps1 -Path ./out/box

# run the build wizard UI (dev machine only, http://127.0.0.1:5173)
cd builder; npm run dev
```

## Status

Scaffold. The fetch/chunk/embed pipeline and the wizard's pack/model listing are real
and have been run end to end. The runtime chat server proxies to a `llama-server`
binary that isn't fetched/bundled anywhere yet. Full breakdown of real vs. stubbed in
`docs/01-architecture.md`.
