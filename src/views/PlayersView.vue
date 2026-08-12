<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'

import DataState from '@/components/DataState.vue'
import PageHeader from '@/components/PageHeader.vue'
import { useAsyncResource } from '@/composables/useAsyncResource'
import { fetchPlayers } from '@/services/dataService'

const query = ref('')
const players = useAsyncResource<Awaited<ReturnType<typeof fetchPlayers>>>()

const filteredPlayers = computed(() => {
  const term = query.value.trim().toLocaleLowerCase()
  if (!term) return players.data.value ?? []
  return (players.data.value ?? []).filter((player) =>
    player.display_name.toLocaleLowerCase().includes(term),
  )
})

function load(): Promise<void> {
  return players.load(fetchPlayers)
}

onMounted(load)
</script>

<template>
  <main class="page-shell players-shell">
    <PageHeader title="Players" />

    <v-text-field
      v-model="query"
      aria-label="Search players"
      class="search-field mb-4"
      clearable
      density="compact"
      label="Search"
      prepend-inner-icon="mdi-magnify"
    />

    <DataState
      :empty="players.data.value?.length === 0"
      empty-title="No players."
      :error="players.error.value"
      :loading="players.loading.value"
      @retry="load"
    >
      <div v-if="filteredPlayers.length" class="player-list">
        <RouterLink
          v-for="player in filteredPlayers"
          :key="player.id"
          class="player-row"
          :to="`/players/${player.id}`"
        >
          <strong>{{ player.display_name }}</strong>
          <v-icon icon="mdi-chevron-right" size="20" />
        </RouterLink>
      </div>

      <div v-else class="empty-search">No matching players.</div>
    </DataState>
  </main>
</template>

<style scoped>
.players-shell {
  max-width: 760px;
}

.search-field {
  max-width: 420px;
}

.player-list {
  border-top: 1px solid rgba(var(--v-theme-on-background), 0.16);
}

.player-row {
  display: flex;
  min-height: 56px;
  align-items: center;
  justify-content: space-between;
  border-bottom: 1px solid rgba(var(--v-theme-on-background), 0.16);
}

.player-row strong {
  color: rgb(var(--v-theme-on-background));
  font-size: 0.94rem;
}

.empty-search {
  padding: 20px 0;
  color: rgba(var(--v-theme-on-background), 0.74);
}
</style>
