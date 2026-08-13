<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute } from 'vue-router'

import DataState from '@/components/DataState.vue'
import PageHeader from '@/components/PageHeader.vue'
import PlayerRosterDialog from '@/components/PlayerRosterDialog.vue'
import { useAsyncResource } from '@/composables/useAsyncResource'
import {
  fetchManagedLeagues,
  fetchManagedSeasons,
  removePlayerFromSeason,
} from '@/services/adminService'
import { fetchSeasonRoster } from '@/services/gameService'
import type { League, ManagedSeasonSummary, Player } from '@/types/domain'

interface RosterCatalog {
  leagues: League[]
  seasons: ManagedSeasonSummary[]
}

const route = useRoute()
const catalog = useAsyncResource<RosterCatalog>()
const leagueId = ref('')
const seasonId = ref('')
const roster = ref<Player[]>([])
const rosterLoading = ref(false)
const rosterError = ref('')
const actionError = ref('')
const actionMessage = ref('')
const playerDialog = ref(false)
const pendingRemove = ref<Player | null>(null)
const removing = ref(false)

const currentSeasons = computed(() =>
  (catalog.data.value?.seasons ?? []).filter(
    (item) => item.season.active && item.league.active && item.league.id === leagueId.value,
  ),
)

async function loadCatalog(): Promise<void> {
  await catalog.load(async () => {
    const [leagues, seasons] = await Promise.all([fetchManagedLeagues(), fetchManagedSeasons()])
    return {
      leagues: leagues.filter((league) => league.active),
      seasons,
    }
  })

  if (!catalog.data.value) return
  const requestedLeague = String(route.query.league ?? '')
  const requestedSeason = String(route.query.season ?? '')
  const validLeague = catalog.data.value.leagues.some((league) => league.id === requestedLeague)
  leagueId.value = validLeague
    ? requestedLeague
    : catalog.data.value.leagues.length === 1
      ? (catalog.data.value.leagues[0]?.id ?? '')
      : ''

  const validSeason = catalog.data.value.seasons.some(
    (item) =>
      item.season.id === requestedSeason &&
      item.season.league_id === leagueId.value &&
      item.season.active,
  )
  seasonId.value = validSeason
    ? requestedSeason
    : currentSeasons.value.length === 1
      ? (currentSeasons.value[0]?.season.id ?? '')
      : ''
}

async function loadRoster(): Promise<void> {
  roster.value = []
  rosterError.value = ''
  if (!seasonId.value) return
  rosterLoading.value = true
  try {
    roster.value = await fetchSeasonRoster(seasonId.value)
  } catch (error) {
    rosterError.value = error instanceof Error ? error.message : 'Unable to load the roster.'
  } finally {
    rosterLoading.value = false
  }
}

function handlePlayerSaved(player: Player): void {
  roster.value = [...roster.value, player].sort((left, right) =>
    left.display_name.localeCompare(right.display_name),
  )
  actionError.value = ''
  actionMessage.value = `${player.display_name} was added to the roster.`
}

async function confirmRemove(): Promise<void> {
  if (!pendingRemove.value || !seasonId.value) return
  const player = pendingRemove.value
  removing.value = true
  actionError.value = ''
  actionMessage.value = ''
  try {
    await removePlayerFromSeason(seasonId.value, player.id)
    roster.value = roster.value.filter((item) => item.id !== player.id)
    pendingRemove.value = null
    actionMessage.value = `${player.display_name} was removed from this season roster.`
  } catch (error) {
    actionError.value = error instanceof Error ? error.message : 'The player was not removed.'
  } finally {
    removing.value = false
  }
}

watch(leagueId, () => {
  if (!currentSeasons.value.some((item) => item.season.id === seasonId.value)) {
    seasonId.value = ''
  }
})
watch(seasonId, loadRoster)
onMounted(loadCatalog)
</script>

<template>
  <main class="page-shell roster-shell">
    <PageHeader
      back-to="/admin"
      title="Rosters"
      description="Manage players for a current league season without starting a game."
    />

    <DataState :error="catalog.error.value" :loading="catalog.loading.value" @retry="loadCatalog">
      <v-alert v-if="catalog.data.value?.leagues.length === 0" class="mb-4" variant="tonal">
        Create an active league and season before managing a roster.
      </v-alert>

      <div v-else class="selector-card">
        <v-select
          v-model="leagueId"
          :items="catalog.data.value?.leagues ?? []"
          item-title="name"
          item-value="id"
          label="League"
          variant="outlined"
        />
        <v-select
          v-model="seasonId"
          :disabled="!leagueId"
          :items="currentSeasons"
          item-title="season.name"
          item-value="season.id"
          label="Current season"
          no-data-text="No current seasons"
          variant="outlined"
        />
      </div>

      <v-alert v-if="actionMessage" class="mt-4" closable color="success" variant="tonal">
        {{ actionMessage }}
      </v-alert>
      <v-alert v-if="actionError" class="mt-4" closable color="error" variant="tonal">
        {{ actionError }}
      </v-alert>

      <section v-if="seasonId" class="roster-section" aria-labelledby="roster-heading">
        <div class="section-heading">
          <div>
            <h2 id="roster-heading" class="section-title mb-0">Season roster</h2>
            <span>{{ roster.length }} players</span>
          </div>
          <v-btn color="primary" prepend-icon="mdi-account-plus" @click="playerDialog = true">
            Add player
          </v-btn>
        </div>

        <DataState
          :empty="roster.length === 0"
          empty-title="No players on this roster."
          empty-message="Use Add player to build the roster."
          :error="rosterError"
          :loading="rosterLoading"
          @retry="loadRoster"
        >
          <div class="roster-list">
            <article v-for="player in roster" :key="player.id" class="roster-row">
              <RouterLink :to="`/players/${player.id}`">{{ player.display_name }}</RouterLink>
              <v-btn
                :aria-label="`Remove ${player.display_name} from roster`"
                color="error"
                size="small"
                variant="text"
                @click="pendingRemove = player"
              >
                Remove
              </v-btn>
            </article>
          </div>
        </DataState>
      </section>
    </DataState>

    <PlayerRosterDialog
      v-model="playerDialog"
      :roster-player-ids="roster.map((player) => player.id)"
      :season-id="seasonId"
      @saved="handlePlayerSaved"
    />

    <v-dialog
      :model-value="Boolean(pendingRemove)"
      max-width="500"
      @update:model-value="!$event && !removing && (pendingRemove = null)"
    >
      <v-card>
        <v-card-title>Remove this player?</v-card-title>
        <v-card-text>
          This only removes {{ pendingRemove?.display_name }} from the selected season roster. Their
          player record and all-time statistics remain. Players with recorded game history cannot be
          removed.
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn :disabled="removing" variant="text" @click="pendingRemove = null">Cancel</v-btn>
          <v-btn color="error" :loading="removing" @click="confirmRemove">Remove player</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </main>
</template>

<style scoped>
.roster-shell {
  max-width: 800px;
}
.selector-card {
  display: grid;
  padding: 18px 18px 2px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.16);
  border-radius: 12px;
  background: rgb(var(--v-theme-surface));
  grid-template-columns: 1fr 1fr;
  gap: 16px;
}
.roster-section {
  margin-top: 28px;
}
.section-heading,
.section-heading > div {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
}
.section-heading > div {
  align-items: flex-start;
  flex-direction: column;
  gap: 2px;
}
.section-heading span {
  color: rgba(var(--v-theme-on-background), 0.7);
  font-size: 0.8rem;
}
.roster-list {
  margin-top: 12px;
  border-top: 1px solid rgba(var(--v-theme-on-background), 0.16);
}
.roster-row {
  display: flex;
  min-height: 54px;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  border-bottom: 1px solid rgba(var(--v-theme-on-background), 0.16);
}
.roster-row a {
  color: rgb(var(--v-theme-on-background));
  font-weight: 750;
}
@media (max-width: 599px) {
  .selector-card {
    grid-template-columns: 1fr;
    gap: 0;
  }
  .section-heading {
    align-items: flex-start;
    flex-direction: column;
  }
  .section-heading :deep(.v-btn) {
    width: 100%;
  }
}
</style>
