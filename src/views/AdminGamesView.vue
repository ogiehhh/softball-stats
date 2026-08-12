<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'

import DataState from '@/components/DataState.vue'
import PageHeader from '@/components/PageHeader.vue'
import { useAsyncResource } from '@/composables/useAsyncResource'
import { archiveGame, fetchManagedGames } from '@/services/adminService'
import type { ManagedGameSummary } from '@/types/domain'
import { formatDate, statusLabel } from '@/utils/formatters'

const games = useAsyncResource<ManagedGameSummary[]>()
const pendingDelete = ref<ManagedGameSummary | null>(null)
const actionLoading = ref(false)
const actionMessage = ref('')
const actionError = ref('')

const inProgressGames = computed(() =>
  (games.data.value ?? []).filter((item) => item.game.status === 'in_progress'),
)
const completedGames = computed(() =>
  (games.data.value ?? []).filter((item) => item.game.status === 'completed'),
)

function loadGames(): Promise<void> {
  return games.load(fetchManagedGames)
}

async function confirmDelete(): Promise<void> {
  if (!pendingDelete.value) return
  actionLoading.value = true
  actionError.value = ''
  actionMessage.value = ''
  try {
    await archiveGame(pendingDelete.value.game.id)
    actionMessage.value = `Game vs. ${pendingDelete.value.game.opponent} was deleted. You can restore it from Archived.`
    pendingDelete.value = null
    await loadGames()
  } catch (error) {
    actionError.value = error instanceof Error ? error.message : 'The game was not deleted.'
  } finally {
    actionLoading.value = false
  }
}

onMounted(loadGames)
</script>

<template>
  <main class="page-shell management-shell">
    <PageHeader back-to="/admin" title="Games" description="Manage current and completed games." />

    <v-alert v-if="actionMessage" class="mb-4" color="success" closable variant="tonal">
      {{ actionMessage }}
    </v-alert>
    <v-alert v-if="actionError" class="mb-4" color="error" closable variant="tonal">
      {{ actionError }}
    </v-alert>

    <DataState
      :empty="games.data.value?.length === 0"
      empty-title="No games to manage."
      :error="games.error.value"
      :loading="games.loading.value"
      @retry="loadGames"
    >
      <section v-if="inProgressGames.length" aria-labelledby="current-games-heading">
        <h2 id="current-games-heading" class="section-title">In progress</h2>
        <div class="management-list">
          <article v-for="item in inProgressGames" :key="item.game.id" class="management-row">
            <div class="row-copy">
              <h3>vs. {{ item.game.opponent }}</h3>
              <p>
                {{ item.league.name }} · {{ item.season.name }} ·
                {{ formatDate(item.game.played_at) }}
              </p>
            </div>
            <div class="row-actions">
              <v-btn color="primary" size="small" :to="`/admin/games/${item.game.id}/score`"
                >Resume</v-btn
              >
              <v-btn color="error" size="small" variant="outlined" @click="pendingDelete = item"
                >Delete</v-btn
              >
            </div>
          </article>
        </div>
      </section>

      <section
        v-if="completedGames.length"
        class="completed-section"
        aria-labelledby="completed-games-heading"
      >
        <h2 id="completed-games-heading" class="section-title">Completed</h2>
        <div class="management-list">
          <article v-for="item in completedGames" :key="item.game.id" class="management-row">
            <div class="row-copy">
              <h3>vs. {{ item.game.opponent }}</h3>
              <p>
                {{ item.league.name }} · {{ item.season.name }} ·
                {{ formatDate(item.game.played_at) }} · {{ statusLabel(item.game.status) }}
              </p>
            </div>
            <v-btn color="error" size="small" variant="outlined" @click="pendingDelete = item"
              >Delete</v-btn
            >
          </article>
        </div>
      </section>
    </DataState>

    <v-dialog
      :model-value="Boolean(pendingDelete)"
      max-width="460"
      @update:model-value="!$event && !actionLoading && (pendingDelete = null)"
    >
      <v-card>
        <v-card-title>Delete this game?</v-card-title>
        <v-card-text>
          The game and its plays will be hidden from stats and scoring. You can restore it later.
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn :disabled="actionLoading" variant="text" @click="pendingDelete = null"
            >Cancel</v-btn
          >
          <v-btn color="error" :loading="actionLoading" @click="confirmDelete">Delete game</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </main>
</template>

<style scoped>
.management-shell {
  max-width: 900px;
}
.completed-section {
  margin-top: 30px;
}
.management-list {
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.16);
}
.management-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 18px;
  padding: 16px 0;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.16);
}
.row-copy {
  min-width: 0;
}
.row-copy h3 {
  margin: 0;
  color: rgb(var(--v-theme-on-surface));
  font-size: 1rem;
  font-weight: 750;
}
.row-copy p {
  margin: 4px 0 0;
  color: rgba(var(--v-theme-on-surface), 0.74);
  font-size: 0.84rem;
  line-height: 1.45;
}
.row-actions {
  display: flex;
  flex-shrink: 0;
  gap: 8px;
}
@media (max-width: 599px) {
  .management-row {
    align-items: flex-start;
    flex-direction: column;
  }
  .row-actions {
    width: 100%;
  }
  .row-actions :deep(.v-btn) {
    flex: 1;
  }
}
</style>
