import express from 'express';
import { readdirSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { openIndex, search } from './retrieval.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..');
const indexDir = join(root, 'index');
const staticDir = join(root, 'chat-ui', 'dist');
const LLAMA_SERVER_URL = process.env.LLAMA_SERVER_URL ?? 'http://127.0.0.1:8080';

let chunks = [];
if (existsSync(indexDir)) {
  for (const file of readdirSync(indexDir)) {
    if (file.endsWith('.sqlite')) {
      chunks = chunks.concat(openIndex(join(indexDir, file)));
    }
  }
}
console.log(`loaded ${chunks.length} chunk(s) from ${indexDir}`);

const app = express();
app.use(express.json());
app.use(express.static(staticDir));

app.get('/api/health', (_req, res) => res.json({ ok: true, chunks: chunks.length }));

app.post('/api/chat', async (req, res) => {
  const { message } = req.body;
  if (!message) return res.status(400).json({ error: 'message required' });

  const hits = await search(chunks, message, 5);
  const context = hits.map((h) => `[${h.source}] ${h.text}`).join('\n\n');
  const prompt = [
    {
      role: 'system',
      content: 'Answer only from the provided context. If the context does not cover the question, say so.',
    },
    { role: 'user', content: `Context:\n${context}\n\nQuestion: ${message}` },
  ];

  let llamaRes;
  try {
    llamaRes = await fetch(`${LLAMA_SERVER_URL}/v1/chat/completions`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ messages: prompt, stream: true }),
    });
  } catch (err) {
    return res.status(502).json({ error: `could not reach llama-server at ${LLAMA_SERVER_URL}: ${err.message}` });
  }
  if (!llamaRes.ok || !llamaRes.body) {
    return res.status(502).json({ error: `llama-server error (${llamaRes.status})` });
  }

  // Sources are known before the model starts generating -- carry them in a header so
  // the body can just be raw answer text, streamed straight through as it's produced.
  res.writeHead(200, {
    'content-type': 'text/plain; charset=utf-8',
    'x-sources': encodeURIComponent(JSON.stringify(hits.map((h) => h.source))),
  });

  const reader = llamaRes.body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    const events = buffer.split('\n\n');
    buffer = events.pop(); // last element may be a not-yet-complete event
    for (const event of events) {
      const dataLine = event.split('\n').find((l) => l.startsWith('data:'));
      if (!dataLine) continue;
      const payload = dataLine.slice(5).trim();
      if (payload === '[DONE]') continue;
      try {
        const delta = JSON.parse(payload).choices?.[0]?.delta?.content;
        if (delta) res.write(delta);
      } catch {
        // partial/malformed SSE frame -- skip rather than crash the stream
      }
    }
  }
  res.end();
});

const port = process.env.PORT ?? 7860;
app.listen(port, () => console.log(`llm-in-a-box runtime server on http://127.0.0.1:${port}`));
