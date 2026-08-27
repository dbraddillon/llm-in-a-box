<script setup>
import { ref, onMounted } from 'vue';

const STORAGE_KEY = 'llm-in-a-box-chat';

const messages = ref([]);
const input = ref('');
const sending = ref(false);

onMounted(() => {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved) messages.value = JSON.parse(saved);
  } catch {
    // corrupt/unavailable storage -- start fresh rather than block the UI on it
  }
});

// Persisted explicitly at message boundaries (not via a deep watch) -- a streaming
// answer mutates .text dozens of times a second and a synchronous localStorage write
// on every token would add real jank for no benefit.
function persist() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(messages.value));
}

function clearHistory() {
  messages.value = [];
  localStorage.removeItem(STORAGE_KEY);
}

function exportHistory() {
  const lines = ['LLM in a Box -- conversation export', `Exported: ${new Date().toISOString()}`, ''];
  for (const m of messages.value) {
    lines.push(m.role === 'user' ? 'You:' : 'Assistant:');
    lines.push(m.text);
    if (m.sources?.length) lines.push(`(sources: ${m.sources.join(', ')})`);
    lines.push('', '---', '');
  }
  const blob = new Blob([lines.join('\n')], { type: 'text/plain' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `llm-in-a-box-chat-${Date.now()}.txt`;
  a.click();
  URL.revokeObjectURL(url);
}

async function send() {
  const text = input.value.trim();
  if (!text || sending.value) return;
  messages.value.push({ role: 'user', text });
  input.value = '';
  sending.value = true;
  persist();

  // Grab the item back out of the reactive array rather than keeping the plain object
  // we just pushed -- mutating the raw object directly wouldn't trigger re-renders,
  // since Vue's reactivity tracks access through the array's proxy, not the object
  // reference we happened to create it with.
  messages.value.push({ role: 'assistant', text: '', sources: [] });
  const assistantMsg = messages.value[messages.value.length - 1];

  try {
    const res = await fetch('/api/chat', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ message: text }),
    });

    if (!res.ok || !res.body) {
      const data = await res.json().catch(() => ({}));
      assistantMsg.text = data.error ?? `Error: HTTP ${res.status}`;
      return;
    }

    const sourcesHeader = res.headers.get('x-sources');
    if (sourcesHeader) assistantMsg.sources = JSON.parse(decodeURIComponent(sourcesHeader));

    const reader = res.body.getReader();
    const decoder = new TextDecoder();
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      assistantMsg.text += decoder.decode(value, { stream: true });
    }
  } catch (err) {
    assistantMsg.text = `Error: ${err.message}`;
  } finally {
    sending.value = false;
    persist();
  }
}
</script>

<template>
  <main>
    <div class="header-row">
      <h1>LLM in a Box</h1>
      <div class="actions">
        <button type="button" @click="exportHistory" :disabled="!messages.length">Export</button>
        <button type="button" @click="clearHistory" :disabled="!messages.length">Clear</button>
      </div>
    </div>
    <div class="log">
      <p v-for="(m, i) in messages" :key="i" :class="m.role">
        <strong>{{ m.role }}:</strong> {{ m.text }}
        <em v-if="m.sources?.length">— sources: {{ m.sources.join(', ') }}</em>
      </p>
    </div>
    <form @submit.prevent="send">
      <input v-model="input" :disabled="sending" placeholder="Ask about the loaded content..." />
      <button :disabled="sending">Send</button>
    </form>
  </main>
</template>

<style>
body { font-family: system-ui, sans-serif; max-width: 640px; margin: 2rem auto; }
.header-row { display: flex; align-items: center; justify-content: space-between; }
.actions { display: flex; gap: 0.5rem; }
.actions button { font-size: 0.85rem; padding: 0.3rem 0.6rem; }
.log { min-height: 200px; border: 1px solid #ccc; padding: 1rem; margin-bottom: 1rem; }
.user { color: #333; }
.assistant { color: #0a5; }
form { display: flex; gap: 0.5rem; }
input { flex: 1; padding: 0.5rem; }
</style>
