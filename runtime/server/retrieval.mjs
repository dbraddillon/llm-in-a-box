import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import Database from 'better-sqlite3';
import { pipeline, env } from '@huggingface/transformers';

// Relative to this file, not the repo root -- this file's own location IS
// runtime/server both in the dev tree and in a shipped box (load-drive.ps1 copies
// the whole runtime/server folder as-is), so this always resolves to the cache
// scripts/node/fetch-embedder.mjs warmed and load-drive.ps1 bundled alongside it.
// Without this, the default cache dir lives inside node_modules/@huggingface/
// transformers, which is a fresh empty install on a shipped box -- meaning the
// very first query would silently try to download ~90MB from the internet.
//
// Set as the GLOBAL env.cacheDir, not just pipeline()'s per-call `cache_dir` option --
// verified (Docker container, --network none) that config.json/tokenizer_config.json
// specifically are loaded via a code path (get_model_files -> get_config) that does
// NOT forward the per-call option and always falls back to this global default. The
// per-call option alone left the box crashing offline on its first real query despite
// the rest of the model loading correctly from the bundled cache.
const MODEL_CACHE_DIR = join(dirname(fileURLToPath(import.meta.url)), '.model-cache');
env.cacheDir = MODEL_CACHE_DIR;

let embedPromise;
function getEmbedder() {
  embedPromise ??= pipeline('feature-extraction', 'Xenova/all-MiniLM-L6-v2');
  return embedPromise;
}

function cosine(a, b) {
  // Vectors are already L2-normalized at index/query time, so dot product is cosine.
  let dot = 0;
  for (let i = 0; i < a.length; i++) dot += a[i] * b[i];
  return dot;
}

export function openIndex(dbPath) {
  const db = new Database(dbPath, { readonly: true });
  const rows = db.prepare('SELECT id, source, text, embedding FROM chunks').all();
  const chunks = rows.map((r) => ({
    id: r.id,
    source: r.source,
    text: r.text,
    embedding: new Float32Array(r.embedding.buffer, r.embedding.byteOffset, r.embedding.length / 4),
  }));
  db.close();
  return chunks;
}

export async function search(chunks, query, topK = 5) {
  const embed = await getEmbedder();
  const output = await embed(query, { pooling: 'mean', normalize: true });
  const q = Float32Array.from(output.data);
  return chunks
    .map((c) => ({ ...c, score: cosine(q, c.embedding) }))
    .sort((a, b) => b.score - a.score)
    .slice(0, topK);
}
