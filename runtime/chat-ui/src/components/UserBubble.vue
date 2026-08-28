<script setup>
defineProps({
  text: { type: String, default: '' },
});
</script>

<template>
  <div class="user-row">
    <div class="user-bubble">{{ text }}</div>
  </div>
</template>

<style scoped>
.user-row {
  display: flex;
  justify-content: flex-end;
}

.user-bubble {
  max-width: 70%;
  background: var(--card);
  color: var(--text-primary);
  padding: 10px 16px;
  border-radius: var(--radius-lg);
  white-space: pre-wrap;
  overflow-wrap: break-word;
}
</style>
