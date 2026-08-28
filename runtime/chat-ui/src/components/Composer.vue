<script setup>
import { ref, watch, nextTick } from 'vue';

const props = defineProps({
  modelValue: { type: String, default: '' },
  sending: { type: Boolean, default: false },
});
const emit = defineEmits(['update:modelValue', 'submit']);

const textareaRef = ref(null);

function resize() {
  const el = textareaRef.value;
  if (!el) return;
  el.style.height = 'auto';
  el.style.height = Math.min(el.scrollHeight, 200) + 'px';
}

function onInput(event) {
  emit('update:modelValue', event.target.value);
  resize();
}

function onKeydown(event) {
  if (event.key === 'Enter' && !event.shiftKey) {
    event.preventDefault();
    submit();
  }
}

function submit() {
  if (!props.modelValue.trim() || props.sending) return;
  emit('submit');
}

// Reset height once the field is cleared after send.
watch(
  () => props.modelValue,
  async (value) => {
    if (value === '') {
      await nextTick();
      resize();
    }
  }
);
</script>

<template>
  <form class="composer" @submit.prevent="submit">
    <button type="button" class="attach" disabled title="Attachments not available in this build">
      <svg width="16" height="16" viewBox="0 0 16 16" fill="none" aria-hidden="true">
        <path d="M8 3v10M3 8h10" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" />
      </svg>
    </button>

    <textarea
      ref="textareaRef"
      :value="modelValue"
      rows="1"
      placeholder="What do you want to know?"
      :disabled="sending"
      aria-label="Search"
      @input="onInput"
      @keydown="onKeydown"
    ></textarea>

    <button
      type="submit"
      class="send"
      :class="{ active: modelValue.trim().length > 0 }"
      :disabled="sending || !modelValue.trim()"
      aria-label="Send"
    >
      <svg width="15" height="15" viewBox="0 0 16 16" fill="none" aria-hidden="true">
        <path
          d="M8 13V3M3.5 7.5 8 3l4.5 4.5"
          stroke="currentColor"
          stroke-width="1.6"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
      </svg>
    </button>
  </form>
</template>

<style scoped>
.composer {
  display: flex;
  align-items: flex-end;
  gap: 8px;
  background: var(--card);
  border: 1px solid var(--hairline-soft);
  border-radius: var(--radius-lg);
  padding: 8px 8px 8px 10px;
}

.attach,
.send {
  flex-shrink: 0;
  width: 32px;
  height: 32px;
  border-radius: 999px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--text-mute);
  transition: background var(--motion-fast) var(--ease-out), color var(--motion-fast) var(--ease-out);
}

.attach:not(:disabled):hover {
  background: var(--hover);
  color: var(--text-body);
}

.attach:disabled {
  opacity: 0.35;
}

textarea {
  flex: 1;
  resize: none;
  border: none;
  background: transparent;
  color: var(--text-primary);
  font-family: var(--font-ui);
  font-size: 15px;
  line-height: 1.5;
  padding: 6px 2px;
  max-height: 200px;
}

textarea::placeholder {
  color: var(--text-mute);
}

textarea:focus {
  outline: none;
}

textarea:disabled {
  opacity: 0.6;
}

.send {
  background: var(--hover);
  color: var(--text-mute);
}

.send.active {
  background: var(--accent);
  color: #0a0a0a;
}

.send:disabled {
  cursor: default;
}
</style>
