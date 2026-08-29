#!/usr/bin/env node
// Downloads the query/chunk embedding model (Xenova/all-MiniLM-L6-v2, ~90MB) into
// runtime/server/.model-cache -- the same location retrieval.mjs and build-pack.mjs
// point at. load-drive.ps1 copies that folder into every assembled box (it's inside
// runtime/server, not node_modules), so a box answers its first question without
// needing internet access. Without this step, a standalone `npm install` of
// runtime/server has an empty cache, and the first real query would silently try to
// download this same ~90MB from the internet.
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { pipeline, env } from '@huggingface/transformers';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const modelCacheDir = join(root, 'runtime', 'server', '.model-cache');

// Set as the GLOBAL env.cacheDir, not a per-call option -- verified (Docker, --network
// none) that config.json/tokenizer_config.json load via a code path that ignores the
// per-call option and always falls back to this global default. Also run a real embed
// call, not just pipeline() construction -- that's the only way to reach and warm the
// same code path a real query hits, which pipeline() construction alone doesn't touch.
env.cacheDir = modelCacheDir;

console.log(`fetching embedding model into ${modelCacheDir}...`);
const embed = await pipeline('feature-extraction', 'Xenova/all-MiniLM-L6-v2');
await embed('warm the cache', { pooling: 'mean', normalize: true });
console.log('embedding model cached.');
