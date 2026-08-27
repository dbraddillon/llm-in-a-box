# Dev machine setup — llm-in-a-box

Checklist for Claude (or a human) picking this repo up on a new machine.

## All platforms
- [ ] Node.js 20+ (`node --version`)
- [ ] PowerShell 7 / `pwsh` (`pwsh --version`) — `scripts/*.ps1` are pwsh, not
      Windows-only `powershell.exe`, specifically so they run on all three dev
      machines.
- [ ] `git clone` this repo, then `pwsh ./setup.ps1` to install JS deps (npm
      workspaces: `scripts/node`, `runtime/server`, `runtime/chat-ui`, `builder`)

## Windows (ThinkPad)
- Reference machine this was scaffolded on. `npm install` at root resolved cleanly,
  including `better-sqlite3`'s native binary (prebuilt, no build tools needed).
- `pwsh` is **not** installed on this machine as of the scaffold date -- only
  Windows PowerShell 5.1. The `.ps1` scripts here deliberately avoid PS7-only
  syntax (`?.`, `??`) so they run fine under 5.1 too; the builder's server
  detects `pwsh` and falls back to `powershell.exe` automatically. Install
  `pwsh` (`winget install Microsoft.PowerShell`) if/when cross-machine parity
  with mac/Linux matters more than "works today."

## macOS (MacBook Pro, arm64)
- [ ] `brew install powershell` for `pwsh`
- [ ] `better-sqlite3` and `@xenova/transformers`'s `onnxruntime-node` both ship
      prebuilt arm64 binaries — `npm install` shouldn't need Xcode command line
      tools, but if it tries to compile from source, that's the first thing to check.

## Ubuntu (ThinkPad mini)
- [ ] `sudo apt install -y powershell` (or the snap package) for `pwsh`
- [ ] Same prebuilt-binary note as macOS applies for linux-x64.

## Not yet portable
- No `llama-server` binary is bundled per-platform yet (see
  `01-architecture.md` → "what's stubbed"). Until that exists, `load-drive.ps1`
  output isn't runnable end to end on any platform — only the retrieval/index half
  is real.
