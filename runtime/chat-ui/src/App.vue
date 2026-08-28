<script setup>
import { ref, computed, onMounted, nextTick } from 'vue';
import Sidebar from './components/Sidebar.vue';
import Composer from './components/Composer.vue';
import UserBubble from './components/UserBubble.vue';
import AssistantTurn from './components/AssistantTurn.vue';
import EmptyState from './components/EmptyState.vue';

const STORAGE_KEY = 'llm-in-a-box-chat';

const messages = ref([]);
const input = ref('');
const sending = ref(false);
const sidebarVisible = ref(true);
const transcriptEl = ref(null);
const turnEls = ref({});
const stickToBottom = ref(true);

const recentQueries = computed(() =>
  messages.value
    .map((m, index) => ({ m, index }))
    .filter(({ m }) => m.role === 'user')
    .map(({ m, index }) => ({ index, text: m.text }))
);

onMounted(() => {
  sidebarVisible.value = window.innerWidth > 768;

  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved) messages.value = JSON.parse(saved);
  } catch {
    // corrupt/unavailable storage -- start fresh rather than block the UI on it
  }
  nextTick(scrollToBottom);
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

function jumpTo(index) {
  const el = turnEls.value[index];
  if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' });
  if (window.innerWidth <= 768) sidebarVisible.value = false;
}

function onTranscriptScroll() {
  const el = transcriptEl.value;
  if (!el) return;
  stickToBottom.value = el.scrollHeight - el.scrollTop - el.clientHeight < 80;
}

function scrollToBottom() {
  const el = transcriptEl.value;
  if (el && stickToBottom.value) el.scrollTop = el.scrollHeight;
}

async function send() {
  const text = input.value.trim();
  if (!text || sending.value) return;
  // Snapshot before pushing the new user turn, so it's exactly "everything said
  // before this question" -- the server folds it into the prompt as prior dialogue.
  const history = messages.value.map((m) => ({ role: m.role, text: m.text, error: m.error }));
  messages.value.push({ role: 'user', text });
  input.value = '';
  sending.value = true;
  stickToBottom.value = true;
  persist();
  await nextTick(scrollToBottom);

  // Grab the item back out of the reactive array rather than keeping the plain object
  // we just pushed -- mutating the raw object directly wouldn't trigger re-renders,
  // since Vue's reactivity tracks access through the array's proxy, not the object
  // reference we happened to create it with.
  messages.value.push({ role: 'assistant', text: '', sources: [], error: false });
  const assistantMsg = messages.value[messages.value.length - 1];

  try {
    const res = await fetch('/api/chat', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ message: text, history }),
    });

    if (!res.ok || !res.body) {
      const data = await res.json().catch(() => ({}));
      assistantMsg.text = data.error ?? `Error: HTTP ${res.status}`;
      assistantMsg.error = true;
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
      await nextTick(scrollToBottom);
    }
  } catch (err) {
    assistantMsg.text = `Error: ${err.message}`;
    assistantMsg.error = true;
  } finally {
    sending.value = false;
    persist();
  }
}
</script>

<template>
  <div class="shell">
    <Sidebar
      :visible="sidebarVisible"
      :has-messages="messages.length > 0"
      :queries="recentQueries"
      @new-chat="clearHistory"
      @export="exportHistory"
      @clear="clearHistory"
      @jump="jumpTo"
      @close="sidebarVisible = false"
    />

    <div class="main">
      <header class="topbar">
        <button
          type="button"
          class="sidebar-toggle"
          :aria-label="sidebarVisible ? 'Hide sidebar' : 'Show sidebar'"
          @click="sidebarVisible = !sidebarVisible"
        >
          <svg width="17" height="17" viewBox="0 0 16 16" fill="none" aria-hidden="true">
            <path
              d="M2.5 4h11M2.5 8h11M2.5 12h11"
              stroke="currentColor"
              stroke-width="1.3"
              stroke-linecap="round"
            />
          </svg>
        </button>
      </header>

      <div v-if="!messages.length" class="empty-wrap">
        <EmptyState />
        <div class="composer-inner">
          <Composer v-model="input" :sending="sending" @submit="send" />
        </div>
      </div>

      <template v-else>
        <div class="transcript" ref="transcriptEl" @scroll="onTranscriptScroll">
          <div class="transcript-inner">
            <div
              v-for="(m, i) in messages"
              :key="i"
              :ref="(el) => (turnEls[i] = el)"
              class="turn"
            >
              <UserBubble v-if="m.role === 'user'" :text="m.text" />
              <AssistantTurn
                v-else
                :text="m.text"
                :sources="m.sources"
                :error="m.error"
                :pending="sending && i === messages.length - 1"
              />
            </div>
          </div>
        </div>

        <div class="composer-dock">
          <div class="composer-inner">
            <Composer v-model="input" :sending="sending" @submit="send" />
          </div>
        </div>
      </template>
    </div>
  </div>
</template>

<style scoped>
.shell {
  display: flex;
  height: 100vh;
  background: var(--canvas);
}

.main {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
}

.topbar {
  flex-shrink: 0;
  display: flex;
  align-items: center;
  height: 48px;
  padding: 0 12px;
}

.sidebar-toggle {
  width: 34px;
  height: 34px;
  border-radius: var(--radius-sm);
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--text-mute);
  transition: background var(--motion-fast) var(--ease-out), color var(--motion-fast) var(--ease-out);
}

.sidebar-toggle:hover {
  background: var(--hover);
  color: var(--text-body);
}

.transcript {
  flex: 1;
  overflow-y: auto;
  padding: 8px 20px;
}

.transcript-inner {
  max-width: 800px;
  margin: 0 auto;
  display: flex;
  flex-direction: column;
  gap: 28px;
  padding-bottom: 12px;
}

.composer-dock {
  flex-shrink: 0;
  padding: 12px 20px 20px;
}

.empty-wrap {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 28px;
  padding: 0 20px;
  /* nudge the whole block up from dead-center so it reads closer to the
     upper-middle of the canvas rather than pinned to the exact viewport center */
  margin-bottom: 8vh;
}

.composer-inner {
  max-width: 760px;
  margin: 0 auto;
  width: 100%;
}

@media (max-width: 768px) {
  .transcript {
    padding: 8px 12px;
  }
  .composer-dock {
    padding: 10px 12px 16px;
  }
}
</style>
