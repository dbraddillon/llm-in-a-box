<script setup></script>

<template>
  <div class="empty-state">
    <svg class="spark" width="28" height="28" viewBox="0 0 16 16" fill="none" aria-hidden="true">
      <circle cx="8" cy="8" r="6.5" stroke="currentColor" stroke-width="1" />
      <path d="M5.3 10.7 10.7 5.3" stroke="currentColor" stroke-width="1" stroke-linecap="round" />
    </svg>
    <p>Ask about the content loaded on this box.</p>
  </div>
</template>

<style scoped>
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 14px;
  color: var(--text-mute);
}

.spark {
  color: var(--text-mute);
}

.empty-state p {
  margin: 0;
  font-size: 14px;
}
</style>
