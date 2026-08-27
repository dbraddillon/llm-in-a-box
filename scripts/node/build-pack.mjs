#!/usr/bin/env node
// Chunks everything in build/raw/<pack>/ and embeds it into build/index/<pack>.sqlite.
// Embedding model: Xenova/all-MiniLM-L6-v2 (384-dim, ~90MB, runs on CPU via ONNX).
// Retrieval at runtime re-embeds the query with the same model and does a brute-force
// cosine scan -- fine up to tens of thousands of chunks, which covers a curated pack.
// Swap in sqlite-vec or an ANN index later if a pack outgrows that.
import { readFileSync, readdirSync, existsSync, mkdirSync } from 'node:fs';
import { join, dirname, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import Database from 'better-sqlite3';
import { pipeline } from '@xenova/transformers';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const packId = process.argv[2];
if (!packId) {
  console.error('usage: build-pack.mjs <pack-dir>');
  process.exit(1);
}

const manifestPath = join(root, 'build', 'manifest.generated.json');
if (!existsSync(manifestPath)) {
  console.error('build/manifest.generated.json missing -- run gen-manifest.mjs first');
  process.exit(1);
}
const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
const pack = manifest.packs.find((p) => p.dir === packId);
if (!pack) {
  console.error(`unknown pack '${packId}'. Known: ${manifest.packs.map((p) => p.dir).join(', ')}`);
  process.exit(1);
}

const rawDir = join(root, 'build', 'raw', packId);
if (!existsSync(rawDir)) {
  console.error(`no raw content at ${rawDir} -- run fetch-content first`);
  process.exit(1);
}

const MAX_CHARS = pack.chunk?.max_chars ?? 1200;
const OVERLAP = pack.chunk?.overlap_chars ?? 160;

function walk(dir) {
  let out = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const p = join(dir, entry.name);
    if (entry.isDirectory()) out = out.concat(walk(p));
    else if (entry.name.endsWith('.txt') || entry.name.endsWith('.md')) out.push(p);
  }
  return out;
}

function chunkText(text) {
  const chunks = [];
  let start = 0;
  while (start < text.length) {
    const end = Math.min(start + MAX_CHARS, text.length);
    chunks.push(text.slice(start, end).trim());
    if (end === text.length) break;
    start = end - OVERLAP;
  }
  return chunks.filter((c) => c.length > 0);
}

console.log('loading embedding model (Xenova/all-MiniLM-L6-v2)...');
const embed = await pipeline('feature-extraction', 'Xenova/all-MiniLM-L6-v2');

const indexDir = join(root, 'build', 'index');
mkdirSync(indexDir, { recursive: true });
const dbPath = join(indexDir, `${packId}.sqlite`);
const db = new Database(dbPath);
db.exec(`
  DROP TABLE IF EXISTS chunks;
  CREATE TABLE chunks (
    id INTEGER PRIMARY KEY,
    source TEXT NOT NULL,
    text TEXT NOT NULL,
    embedding BLOB NOT NULL
  );
`);
const insert = db.prepare('INSERT INTO chunks (source, text, embedding) VALUES (?, ?, ?)');

const files = walk(rawDir);
let total = 0;
for (const file of files) {
  const text = readFileSync(file, 'utf8');
  const source = relative(rawDir, file);
  for (const chunk of chunkText(text)) {
    const output = await embed(chunk, { pooling: 'mean', normalize: true });
    const vec = Float32Array.from(output.data);
    insert.run(source, chunk, Buffer.from(vec.buffer));
    total++;
  }
}

db.close();
console.log(`pack "${packId}": ${total} chunk(s) from ${files.length} file(s) -> ${dbPath}`);
