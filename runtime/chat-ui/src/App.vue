<script setup>
import { ref } from 'vue';

const messages = ref([]);
const input = ref('');
const sending = ref(false);

async function send() {
  const text = input.value.trim();
  if (!text || sending.value) return;
  messages.value.push({ role: 'user', text });
  input.value = '';
  sending.value = true;
  try {
    const res = await fetch('/api/chat', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ message: text }),
    });
    const data = await res.json();
    messages.value.push({
      role: 'assistant',
      text: data.answer ?? data.error ?? '(no response)',
      sources: data.sources ?? [],
    });
  } catch (err) {
    messages.value.push({ role: 'assistant', text: `Error: ${err.message}`, sources: [] });
  } finally {
    sending.value = false;
  }
}
</script>

<template>
  <main>
    <h1>LLM in a Box</h1>
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
.log { min-height: 200px; border: 1px solid #ccc; padding: 1rem; margin-bottom: 1rem; }
.user { color: #333; }
.assistant { color: #0a5; }
form { display: flex; gap: 0.5rem; }
input { flex: 1; padding: 0.5rem; }
</style>
