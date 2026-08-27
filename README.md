# llm-in-a-box

Offline "LLM in a box": pick some content, build a small local vector index for it,
pick a small quantized chat model, and package the two together into one folder you
can copy to an offline machine and run with no internet and no install step.

See `CLAUDE.md` for build commands and `docs/01-architecture.md` for how it fits
together and what's real vs. still stubbed.

Sibling project: **Prepper** — a much larger offline content drive this can optionally
pull raw content from.
