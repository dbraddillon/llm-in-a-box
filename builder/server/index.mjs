// Builder API: this is a UI wrapper only. Every endpoint here either reads the same
// generated manifest gen-manifest.mjs produces, or spawns the exact same pwsh scripts
// documented in CLAUDE.md. There is no logic here that isn't also reachable by hand.
import express from 'express';
import { spawnSync, spawn } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const app = express();
app.use(express.json());

// Prefer pwsh (PowerShell 7, cross-platform) but fall back to Windows PowerShell --
// the .ps1 scripts here intentionally avoid PS7-only syntax (?., ??) so both work.
function detectShell() {
  const probe = (cmd) => spawnSync(cmd, ['-NoProfile', '-Command', 'exit'], { stdio: 'ignore' }).status === 0;
  if (probe('pwsh')) return 'pwsh';
  if (process.platform === 'win32' && probe('powershell.exe')) return 'powershell.exe';
  return null;
}
const shell = detectShell();

function runScript(script, args, res) {
  res.writeHead(200, {
    'content-type': 'text/event-stream',
    'cache-control': 'no-cache',
    connection: 'keep-alive',
  });
  const send = (line) => res.write(`data: ${JSON.stringify(line)}\n\n`);
  if (!shell) {
    send('no pwsh or powershell.exe found on PATH -- see docs/dev-machine-setup.md');
    return res.end();
  }
  const proc = spawn(shell, ['-NoProfile', '-File', join(root, 'scripts', script), ...args], { cwd: root });
  proc.stdout.on('data', (d) => send(d.toString()));
  proc.stderr.on('data', (d) => send(d.toString()));
  proc.on('error', (err) => {
    send(`could not start ${shell}: ${err.message}`);
    res.end();
  });
  proc.on('close', (code) => {
    send(`__done__ exit ${code}`);
    res.end();
  });
}

app.get('/api/manifest', (_req, res) => {
  const gen = spawn('node', [join(root, 'scripts/node/gen-manifest.mjs')], { cwd: root });
  gen.on('close', () => {
    const manifest = JSON.parse(readFileSync(join(root, 'build/manifest.generated.json'), 'utf8'));
    res.json(manifest);
  });
});

app.get('/api/run/fetch-content', (req, res) => runScript('fetch-content.ps1', ['-Pack', req.query.pack], res));
app.get('/api/run/build-pack', (req, res) => runScript('build-pack.ps1', ['-Pack', req.query.pack], res));
app.get('/api/run/fetch-model', (req, res) => runScript('fetch-model.ps1', ['-Model', req.query.model], res));

const port = process.env.BUILDER_PORT ?? 7861;
app.listen(port, () => console.log(`builder API on http://127.0.0.1:${port}`));
