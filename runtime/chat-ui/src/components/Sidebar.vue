<script setup>
defineProps({
  visible: { type: Boolean, default: true },
  hasMessages: { type: Boolean, default: false },
  queries: { type: Array, default: () => [] },
});
const emit = defineEmits(['new-chat', 'export', 'clear', 'jump', 'close']);
</script>

<template>
  <div class="backdrop" :class="{ show: visible }" @click="emit('close')"></div>
  <aside class="sidebar" :class="{ hidden: !visible }">
    <div class="sidebar-top">
      <div class="wordmark">
        <svg class="spark" width="18" height="18" viewBox="0 0 16 16" fill="none" aria-hidden="true">
          <circle cx="8" cy="8" r="6.5" stroke="currentColor" stroke-width="1.1" />
          <path d="M5.3 10.7 10.7 5.3" stroke="currentColor" stroke-width="1.1" stroke-linecap="round" />
        </svg>
        <span>LLM in a Box</span>
      </div>
      <button type="button" class="new-chat" @click="emit('new-chat')">
        <svg width="15" height="15" viewBox="0 0 16 16" fill="none" aria-hidden="true">
          <path d="M8 2.5v11M2.5 8h11" stroke="currentColor" stroke-width="1.3" stroke-linecap="round" />
        </svg>
        New search
      </button>
    </div>

    <div class="sidebar-recent" v-if="queries.length">
      <p class="sidebar-label">Recent</p>
      <ul>
        <li v-for="q in queries" :key="q.index">
          <button type="button" @click="emit('jump', q.index)">{{ q.text }}</button>
        </li>
      </ul>
    </div>
    <div class="sidebar-spacer" v-else></div>

    <div class="sidebar-bottom">
      <button type="button" :disabled="!hasMessages" @click="emit('export')">
        <svg width="15" height="15" viewBox="0 0 16 16" fill="none" aria-hidden="true">
          <path
            d="M8 2v7.5M5 7l3 3 3-3M3 12.5h10"
            stroke="currentColor"
            stroke-width="1.2"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        </svg>
        Export
      </button>
      <button type="button" :disabled="!hasMessages" @click="emit('clear')">
        <svg width="15" height="15" viewBox="0 0 16 16" fill="none" aria-hidden="true">
          <path
            d="M3.5 4.5h9M6.5 4.5V3a1 1 0 0 1 1-1h1a1 1 0 0 1 1 1v1.5M4.5 4.5l.6 8.2a1 1 0 0 0 1 .8h3.8a1 1 0 0 0 1-.8l.6-8.2"
            stroke="currentColor"
            stroke-width="1.2"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        </svg>
        Clear
      </button>
    </div>
  </aside>
</template>

<style scoped>
.backdrop {
  display: none;
}

.sidebar {
  width: 260px;
  flex-shrink: 0;
  background: var(--panel);
  border-right: 1px solid var(--hairline-soft);
  display: flex;
  flex-direction: column;
  padding: 16px 12px;
  margin-left: 0;
  transition: margin-left var(--motion-med) var(--ease-out);
  overflow: hidden;
}

.sidebar.hidden {
  margin-left: -260px;
}

.wordmark {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 6px 8px 16px;
  color: var(--text-primary);
  font-size: 14px;
  font-weight: 600;
}

.spark {
  color: var(--text-primary);
  flex-shrink: 0;
}

.new-chat {
  display: flex;
  align-items: center;
  gap: 8px;
  width: 100%;
  padding: 9px 10px;
  border-radius: var(--radius-sm);
  border: 1px solid var(--hairline-soft);
  color: var(--text-body);
  font-size: 13px;
  transition: background var(--motion-fast) var(--ease-out);
}

.new-chat:hover {
  background: var(--hover);
}

.sidebar-label {
  margin: 20px 0 6px;
  padding: 0 8px;
  font-size: 11px;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--text-mute);
}

.sidebar-recent {
  overflow-y: auto;
  flex: 1;
}

.sidebar-recent ul {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 1px;
}

.sidebar-recent button {
  display: block;
  width: 100%;
  padding: 7px 8px;
  border-radius: var(--radius-sm);
  text-align: left;
  font-size: 13px;
  color: var(--text-mute);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  transition: background var(--motion-fast) var(--ease-out), color var(--motion-fast) var(--ease-out);
}

.sidebar-recent button:hover {
  background: var(--hover);
  color: var(--text-body);
}

.sidebar-spacer {
  flex: 1;
}

.sidebar-bottom {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding-top: 12px;
  border-top: 1px solid var(--hairline-soft);
}

.sidebar-bottom button {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px;
  border-radius: var(--radius-sm);
  font-size: 13px;
  color: var(--text-mute);
  transition: background var(--motion-fast) var(--ease-out), color var(--motion-fast) var(--ease-out);
}

.sidebar-bottom button:not(:disabled):hover {
  background: var(--hover);
  color: var(--text-body);
}

.sidebar-bottom button:disabled {
  opacity: 0.4;
}

@media (max-width: 768px) {
  .backdrop {
    display: block;
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.5);
    z-index: 30;
    opacity: 0;
    pointer-events: none;
    transition: opacity var(--motion-med) var(--ease-out);
  }
  .backdrop.show {
    opacity: 1;
    pointer-events: auto;
  }

  .sidebar {
    position: fixed;
    inset: 0 auto 0 0;
    z-index: 40;
    margin-left: 0;
    transform: translateX(-100%);
    transition: transform var(--motion-med) var(--ease-out);
  }
  .sidebar:not(.hidden) {
    transform: translateX(0);
  }
}
</style>
