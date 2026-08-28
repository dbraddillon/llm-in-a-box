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

## Cross-platform status
`fetch-runtime.ps1` and `load-drive.ps1` auto-detect the current platform
(`Get-CurrentPlatform` in `_common.ps1`) and fetch/bundle the matching `llama-server`
build from `ggml-org/llama.cpp`'s releases (win-x64, win-arm64, macos-arm64, macos-x64,
linux-x64, linux-arm64).

As of 2026-08-28:
- **win-x64** — full assemble + launch + real chat question, from a path outside the
  repo. Verified.
- **linux-x64 (Ubuntu, home server)** — same level of verification. A box assembled at
  `~/llm-box-linux-test` on the home server actually answered a real question
  (`llama.log`: 239 prompt tokens, 85 generated, ~12.8s). Verified.
- **macos-arm64 (Mac Mini)** — now also fully verified (2026-08-28, closed the gap
  noted earlier same day): assembled a box at `~/llm-mac-test-box`, launched
  `llama-server` + the runtime server, and sent it a real question over
  `/api/chat` — answered correctly with the right source attribution. `pwsh` and
  `node` are both installed via Homebrew but **not on the PATH for non-interactive
  SSH commands** (`ssh host "cmd"`) — only for a login shell. Invoke as
  `ssh host "zsh -l -c 'cmd'"`, or use full paths (`/opt/homebrew/bin/pwsh`,
  `/opt/homebrew/bin/node`), or you'll get a false "command not found" that looks
  like the tool isn't installed when it actually is.

All three of the repo's canonical dev machines (win-x64, linux-x64 Ubuntu, macos-arm64)
are now confirmed at the same level: assemble + launch + real answered question.
win-arm64 / linux-arm64 remain untested, no specific reason to doubt them.
- **win-arm64 / linux-arm64** — untested, no specific reason to doubt them beyond
  "nobody's tried."
