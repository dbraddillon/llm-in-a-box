import Database from 'better-sqlite3';
import { pipeline } from '@huggingface/transformers';

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
