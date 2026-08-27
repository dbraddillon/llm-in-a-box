#!/usr/bin/env node
// Populates build/raw/<pack>/ from the sources listed for <pack> in
// build/manifest.generated.json (run gen-manifest.mjs first).
import { readFileSync, mkdirSync, copyFileSync, existsSync, readdirSync, writeFileSync } from 'node:fs';
import { join, dirname, basename } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const packId = process.argv[2];
if (!packId) {
  console.error('usage: fetch-pack-content.mjs <pack-dir>');
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

const packDir = join(root, 'packs', packId);
const rawDir = join(root, 'build', 'raw', packId);
mkdirSync(rawDir, { recursive: true });

function copyDir(src, dst) {
  mkdirSync(dst, { recursive: true });
  for (const entry of readdirSync(src, { withFileTypes: true })) {
    const s = join(src, entry.name);
    const d = join(dst, entry.name);
    if (entry.isDirectory()) copyDir(s, d);
    else copyFileSync(s, d);
  }
}

for (const source of pack.sources ?? []) {
  if (source.type === 'local') {
    copyDir(join(packDir, source.path), rawDir);
    console.log(`copied local source ${source.path} -> ${rawDir}`);
  } else if (source.type === 'http') {
    const dest = join(rawDir, source.filename ?? basename(source.url));
    console.log(`downloading ${source.url}`);
    const res = await fetch(source.url);
    if (!res.ok) throw new Error(`fetch failed (${res.status}): ${source.url}`);
    writeFileSync(dest, Buffer.from(await res.arrayBuffer()));
  } else {
    throw new Error(`unknown source type: ${source.type}`);
  }
}

console.log(`pack "${packId}" raw content ready at ${rawDir}`);
