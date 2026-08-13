<script setup lang="ts">
defineProps<{
  loading: boolean
  error?: string
  empty?: boolean
  emptyTitle?: string
  emptyMessage?: string
}>()

defineEmits<{
  retry: []
}>()
</script>

<template>
  <div class="data-state" :aria-busy="loading">
    <v-alert v-if="!loading && error" border="start" color="error" variant="tonal">
      <div class="mb-2">{{ error }}</div>
      <v-btn color="error" size="small" variant="outlined" @click="$emit('retry')">Retry</v-btn>
    </v-alert>

    <div v-else-if="!loading && empty" class="empty-state">
      <strong>{{ emptyTitle ?? 'Nothing here yet.' }}</strong>
      <p v-if="emptyMessage">{{ emptyMessage }}</p>
    </div>

    <slot v-else />

    <div v-if="loading" class="loading-overlay" aria-live="polite" role="status">
      <div class="loading-card">
        <v-progress-circular color="primary" indeterminate size="28" width="3" />
        <span>Loading&hellip;</span>
      </div>
    </div>
  </div>
</template>

<style scoped>
.data-state {
  position: relative;
}

.loading-overlay {
  position: fixed;
  z-index: 1000;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(var(--v-theme-background), 0.52);
  backdrop-filter: blur(1.5px);
  cursor: wait;
}

.loading-card {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 14px 18px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.14);
  border-radius: 999px;
  background: rgba(var(--v-theme-surface), 0.94);
  box-shadow: 0 10px 30px rgba(0, 0, 0, 0.22);
  color: rgba(var(--v-theme-on-surface), 0.82);
  font-size: 0.88rem;
  font-weight: 700;
}

.empty-state {
  padding: 24px 0;
  color: rgb(var(--v-theme-on-background));
}

.empty-state p {
  margin: 4px 0 0;
  color: rgba(var(--v-theme-on-background), 0.74);
  font-size: 0.88rem;
}
</style>
