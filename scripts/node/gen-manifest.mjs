#!/usr/bin/env node
// Reads packs/*/pack.yaml + models/manifest.yaml, writes build/manifest.generated.json.
// This is the only place that parses the source YAML -- the pwsh scripts and the
// wizard read the generated JSON instead, so there's one place that understands the
// YAML schema and everything else can't drift out of sync with it.
import { readFileSync, writeFileSync, mkdirSync, readdirSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import yaml from 'js-yaml';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const packsDir = join(root, 'packs');
const modelsFile = join(root, 'models', 'manifest.yaml');
const outDir = join(root, 'build');
const outFile = join(outDir, 'manifest.generated.json');

function loadPacks() {
  if (!existsSync(packsDir)) return [];
  return readdirSync(packsDir, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => {
      const file = join(packsDir, d.name, 'pack.yaml');
      if (!existsSync(file)) return null;
      const pack = yaml.load(readFileSync(file, 'utf8'));
      return { ...pack, dir: d.name };
    })
    .filter(Boolean);
}

function loadModels() {
  if (!existsSync(modelsFile)) return [];
  const doc = yaml.load(readFileSync(modelsFile, 'utf8'));
  return doc.models ?? [];
}

const manifest = {
  generatedAt: new Date().toISOString(),
  packs: loadPacks(),
  models: loadModels(),
};

mkdirSync(outDir, { recursive: true });
writeFileSync(outFile, JSON.stringify(manifest, null, 2));
console.log(`wrote ${manifest.packs.length} pack(s), ${manifest.models.length} model(s) -> ${outFile}`);
