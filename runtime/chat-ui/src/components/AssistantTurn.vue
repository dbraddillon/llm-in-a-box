<script setup>
import { computed } from 'vue';
import { marked } from 'marked';
import DOMPurify from 'dompurify';

const props = defineProps({
  text: { type: String, default: '' },
  sources: { type: Array, default: () => [] },
  pending: { type: Boolean, default: false },
  error: { type: Boolean, default: false },
});

marked.setOptions({ breaks: true });

const html = computed(() => {
  if (!props.text) return '';
  return DOMPurify.sanitize(marked.parse(props.text));
});
</script>

<template>
  <div class="assistant-turn">
    <svg class="mark" width="16" height="16" viewBox="0 0 16 16" fill="none" aria-hidden="true">
      <circle cx="8" cy="8" r="6.5" stroke="currentColor" stroke-width="1.1" />
      <path d="M5.3 10.7 10.7 5.3" stroke="currentColor" stroke-width="1.1" stroke-linecap="round" />
    </svg>

    <div class="assistant-body">
      <div v-if="pending && !text" class="pulse" aria-label="Thinking">
        <span></span><span></span><span></span>
      </div>
      <p v-else-if="error" class="error-text">{{ text }}</p>
      <div v-else class="markdown" v-html="html"></div>

      <div v-if="sources.length" class="sources">
        <span v-for="s in sources" :key="s" class="source-chip">{{ s }}</span>
      </div>
    </div>
  </div>
</template>

<style scoped>
.assistant-turn {
  display: flex;
  gap: 12px;
  align-items: flex-start;
}

.mark {
  flex-shrink: 0;
  margin-top: 3px;
  color: var(--text-mute);
}

.assistant-body {
  min-width: 0;
  flex: 1;
}

.pulse {
  display: flex;
  gap: 4px;
  padding: 4px 0;
}

.pulse span {
  width: 6px;
  height: 6px;
  border-radius: 999px;
  background: var(--text-mute);
  animation: pulse 1.1s ease-in-out infinite;
}

.pulse span:nth-child(2) {
  animation-delay: 0.15s;
}
.pulse span:nth-child(3) {
  animation-delay: 0.3s;
}

@keyframes pulse {
  0%,
  80%,
  100% {
    opacity: 0.25;
    transform: scale(0.85);
  }
  40% {
    opacity: 1;
    transform: scale(1);
  }
}

.error-text {
  margin: 0;
  color: var(--danger);
}

.sources {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-top: 12px;
}

.source-chip {
  font-family: var(--font-mono);
  font-size: 12px;
  letter-spacing: 0.01em;
  color: var(--text-mute);
  background: var(--canvas-elevated);
  border: 1px solid var(--hairline-soft);
  border-radius: var(--radius-sm);
  padding: 3px 8px;
}

.markdown {
  color: var(--text-body);
}

.markdown :deep(p) {
  margin: 0 0 12px;
}
.markdown :deep(p:last-child) {
  margin-bottom: 0;
}
.markdown :deep(h1),
.markdown :deep(h2),
.markdown :deep(h3) {
  color: var(--text-primary);
  margin: 20px 0 10px;
  line-height: 1.3;
}
.markdown :deep(h1:first-child),
.markdown :deep(h2:first-child),
.markdown :deep(h3:first-child) {
  margin-top: 0;
}
.markdown :deep(ul),
.markdown :deep(ol) {
  margin: 0 0 12px;
  padding-left: 22px;
}
.markdown :deep(li) {
  margin: 4px 0;
}
.markdown :deep(a) {
  color: var(--text-primary);
  text-decoration: underline;
  text-decoration-color: var(--hairline);
  text-underline-offset: 2px;
}
.markdown :deep(code) {
  font-family: var(--font-mono);
  font-size: 0.87em;
  background: var(--canvas-elevated);
  border: 1px solid var(--hairline-soft);
  border-radius: 4px;
  padding: 1px 5px;
}
.markdown :deep(pre) {
  background: var(--canvas-elevated);
  border: 1px solid var(--hairline-soft);
  border-radius: var(--radius-sm);
  padding: 12px 14px;
  overflow-x: auto;
  margin: 0 0 12px;
}
.markdown :deep(pre code) {
  background: none;
  border: none;
  padding: 0;
}
.markdown :deep(blockquote) {
  margin: 0 0 12px;
  padding-left: 12px;
  border-left: 2px solid var(--hairline);
  color: var(--text-mute);
}
</style>
