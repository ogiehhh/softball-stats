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
  <div v-if="loading" class="state-wrap" aria-live="polite">
    <v-progress-circular color="primary" indeterminate size="26" width="3" />
    <span>Loading…</span>
  </div>

  <v-alert v-else-if="error" border="start" color="error" variant="tonal">
    <div class="mb-2">{{ error }}</div>
    <v-btn color="error" size="small" variant="outlined" @click="$emit('retry')">Retry</v-btn>
  </v-alert>

  <div v-else-if="empty" class="empty-state">
    <strong>{{ emptyTitle ?? 'Nothing here yet.' }}</strong>
    <p v-if="emptyMessage">{{ emptyMessage }}</p>
  </div>

  <slot v-else />
</template>

<style scoped>
.state-wrap {
  display: flex;
  min-height: 110px;
  align-items: center;
  justify-content: center;
  gap: 10px;
  color: rgba(var(--v-theme-on-background), 0.74);
  font-size: 0.88rem;
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
