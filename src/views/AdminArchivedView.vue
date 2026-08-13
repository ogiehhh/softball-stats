<script setup lang="ts">
import { onMounted, ref } from 'vue'

import DataState from '@/components/DataState.vue'
import PageHeader from '@/components/PageHeader.vue'
import { useAsyncResource } from '@/composables/useAsyncResource'
import {
  fetchArchivedGames,
  fetchArchivedLeagues,
  fetchArchivedSeasons,
  restoreGame,
  restoreLeague,
  restoreSeason,
} from '@/services/adminService'
import type { League, ManagedGameSummary, ManagedSeasonSummary } from '@/types/domain'
import { formatDate } from '@/utils/formatters'

interface ArchivedData {
  leagues: League[]
  seasons: ManagedSeasonSummary[]
  games: ManagedGameSummary[]
}

const archived = useAsyncResource<ArchivedData>()
const actionLoading = ref('')
const actionMessage = ref('')
const actionError = ref('')

function loadArchived(): Promise<void> {
  return archived.load(async () => {
    const [leagues, seasons, games] = await Promise.all([
      fetchArchivedLeagues(),
      fetchArchivedSeasons(),
      fetchArchivedGames(),
    ])
    return { leagues, seasons, games }
  })
}

async function runRestore(
  kind: 'game' | 'league' | 'season',
  id: string,
  name: string,
): Promise<void> {
  actionLoading.value = `${kind}:${id}`
  actionMessage.value = ''
  actionError.value = ''
  try {
    if (kind === 'game') await restoreGame(id)
    else if (kind === 'season') await restoreSeason(id)
    else await restoreLeague(id)
    actionMessage.value = `${name} was restored.`
    await loadArchived()
  } catch (error) {
    actionError.value = error instanceof Error ? error.message : 'The item was not restored.'
  } finally {
    actionLoading.value = ''
  }
}

onMounted(loadArchived)
</script>

<template>
  <main class="page-shell management-shell">
    <PageHeader
      back-to="/admin"
      title="Archived"
      description="Restore deleted games, seasons, and leagues without losing history."
    />

    <v-alert v-if="actionMessage" class="mb-4" color="success" closable variant="tonal">{{
      actionMessage
    }}</v-alert>
    <v-alert v-if="actionError" class="mb-4" color="error" closable variant="tonal">{{
      actionError
    }}</v-alert>

    <DataState
      :empty="
        Boolean(
          archived.data.value &&
          !archived.data.value.leagues.length &&
          !archived.data.value.seasons.length &&
          !archived.data.value.games.length,
        )
      "
      empty-title="Nothing is archived."
      :error="archived.error.value"
      :loading="archived.loading.value"
      @retry="loadArchived"
    >
      <section
        v-if="archived.data.value?.leagues.length"
        aria-labelledby="archived-leagues-heading"
      >
        <h2 id="archived-leagues-heading" class="section-title">Leagues</h2>
        <div class="management-list">
          <article
            v-for="league in archived.data.value.leagues"
            :key="league.id"
            class="management-row"
          >
            <div class="row-copy">
              <h3>{{ league.name }}</h3>
              <p>Deleted {{ formatDate(league.archived_at) }}</p>
            </div>
            <v-btn
              color="primary"
              size="small"
              variant="outlined"
              :loading="actionLoading === `league:${league.id}`"
              @click="runRestore('league', league.id, league.name)"
              >Restore</v-btn
            >
          </article>
        </div>
      </section>

      <section
        v-if="archived.data.value?.seasons.length"
        class="item-section"
        aria-labelledby="archived-seasons-heading"
      >
        <h2 id="archived-seasons-heading" class="section-title">Seasons</h2>
        <div class="management-list">
          <article
            v-for="item in archived.data.value.seasons"
            :key="item.season.id"
            class="management-row"
          >
            <div class="row-copy">
              <h3>{{ item.season.name }}</h3>
              <p>{{ item.league.name }} · Deleted {{ formatDate(item.season.archived_at) }}</p>
              <p v-if="item.league.archived_at" class="parent-note">Restore the league first.</p>
            </div>
            <v-btn
              color="primary"
              size="small"
              variant="outlined"
              :disabled="Boolean(item.league.archived_at)"
              :loading="actionLoading === 'season:' + item.season.id"
              @click="runRestore('season', item.season.id, item.season.name)"
              >Restore</v-btn
            >
          </article>
        </div>
      </section>

      <section
        v-if="archived.data.value?.games.length"
        class="item-section"
        aria-labelledby="archived-games-heading"
      >
        <h2 id="archived-games-heading" class="section-title">Games</h2>
        <div class="management-list">
          <article
            v-for="item in archived.data.value.games"
            :key="item.game.id"
            class="management-row"
          >
            <div class="row-copy">
              <h3>vs. {{ item.game.opponent }}</h3>
              <p>
                {{ item.league.name }} · {{ item.season.name }} ·
                {{ formatDate(item.game.played_at) }}
              </p>
              <p v-if="item.league.archived_at" class="parent-note">Restore the league first.</p>
              <p v-else-if="item.season.archived_at" class="parent-note">
                Restore the season first.
              </p>
            </div>
            <v-btn
              color="primary"
              size="small"
              variant="outlined"
              :disabled="Boolean(item.league.archived_at || item.season.archived_at)"
              :loading="actionLoading === `game:${item.game.id}`"
              @click="runRestore('game', item.game.id, `Game vs. ${item.game.opponent}`)"
              >Restore</v-btn
            >
          </article>
        </div>
      </section>
    </DataState>
  </main>
</template>

<style scoped>
.management-shell {
  max-width: 900px;
}
.item-section {
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
.row-copy .parent-note {
  color: rgb(var(--v-theme-warning));
  font-weight: 700;
}
@media (max-width: 599px) {
  .management-row {
    align-items: flex-start;
  }
}
</style>
