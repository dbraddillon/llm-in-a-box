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

  try {
    const llamaRes = await fetch(`${LLAMA_SERVER_URL}/v1/chat/completions`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ messages: prompt, stream: false }),
    });
    if (!llamaRes.ok) {
      return res.status(502).json({ error: `llama-server error (${llamaRes.status})` });
    }
    const data = await llamaRes.json();
    res.json({
      answer: data.choices?.[0]?.message?.content ?? '(no answer)',
      sources: hits.map((h) => h.source),
    });
  } catch (err) {
    res.status(502).json({ error: `could not reach llama-server at ${LLAMA_SERVER_URL}: ${err.message}` });
  }
});

const port = process.env.PORT ?? 7860;
app.listen(port, () => console.log(`llm-in-a-box runtime server on http://127.0.0.1:${port}`));
