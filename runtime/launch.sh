#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LLAMA_BIN="$HERE/bin/llama-server"
MODEL="$HERE/model/model.gguf"

if [ ! -x "$LLAMA_BIN" ]; then
  echo "llama-server binary not found at $LLAMA_BIN"
  echo "This box was assembled without a model runtime binary bundled -- see README.md."
  exit 1
fi

"$LLAMA_BIN" -m "$MODEL" --port 8080 &
LLAMA_PID=$!
trap 'kill $LLAMA_PID' EXIT
sleep 2
node "$HERE/server/index.mjs"
