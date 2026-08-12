<script setup lang="ts">
defineProps<{
  title: string
  eyebrow?: string
  description?: string
  backTo?: string
}>()
</script>

<template>
  <header class="page-header">
    <v-btn
      v-if="backTo"
      :to="backTo"
      class="back-link"
      color="primary"
      prepend-icon="mdi-arrow-left"
      size="small"
      variant="text"
    >
      Back
    </v-btn>
    <div v-if="eyebrow" class="eyebrow mb-1">{{ eyebrow }}</div>
    <h1>{{ title }}</h1>
    <p v-if="description">{{ description }}</p>
    <slot />
  </header>
</template>

<style scoped>
.page-header {
  max-width: 760px;
  margin-bottom: 22px;
}

.back-link {
  min-width: 0;
  margin: 0 0 10px -8px;
  padding-inline: 8px;
}

h1 {
  margin: 0;
  color: rgb(var(--v-theme-on-background));
  font-size: clamp(1.75rem, 7vw, 2.45rem);
  font-weight: 820;
  letter-spacing: -0.035em;
  line-height: 1.1;
}

p {
  max-width: 680px;
  margin: 7px 0 0;
  color: rgba(var(--v-theme-on-background), 0.74);
  font-size: 0.92rem;
  line-height: 1.5;
}
</style>
