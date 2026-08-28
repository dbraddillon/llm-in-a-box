<script setup></script>

<template>
  <div class="empty-state">
    <svg class="spark" width="28" height="28" viewBox="0 0 16 16" fill="none" aria-hidden="true">
      <circle cx="8" cy="8" r="6.5" stroke="currentColor" stroke-width="1" />
      <path d="M8 4.5v7M4.5 8h7" stroke="currentColor" stroke-width="1" transform="rotate(45 8 8)" />
    </svg>
    <p>Ask about the content loaded on this box.</p>
  </div>
</template>

<style scoped>
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 14px;
  color: var(--text-mute);
  flex: 1.6;
}

.spark {
  color: var(--text-mute);
}

.empty-state p {
  margin: 0;
  font-size: 14px;
}
</style>
