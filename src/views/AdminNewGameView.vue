<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'

import DataState from '@/components/DataState.vue'
import LineupBuilder from '@/components/LineupBuilder.vue'
import PageHeader from '@/components/PageHeader.vue'
import { fetchActiveSeasonsForLeague, fetchLeagues } from '@/services/dataService'
import { fetchSeasonRoster, startGame } from '@/services/gameService'
import type { League, Player, Season } from '@/types/domain'
import { validateLineupPlayerIds } from '@/utils/lineup'

const router = useRouter()

const leagues = ref<League[]>([])
const seasons = ref<Season[]>([])
const roster = ref<Player[]>([])
const lineup = ref<Player[]>([])
const leagueId = ref('')
const seasonId = ref('')
const opponent = ref('')
const gameDate = ref(localToday())
const loading = ref(true)
const loadingSeason = ref(false)
const submitting = ref(false)
const initialError = ref('')
const errorMessage = ref('')

function localToday(): string {
  const now = new Date()
  const local = new Date(now.getTime() - now.getTimezoneOffset() * 60_000)
  return local.toISOString().slice(0, 10)
}

const lineupValidation = computed(() =>
  validateLineupPlayerIds(
    lineup.value.map((player) => player.id),
    roster.value.map((player) => player.id),
  ),
)
const canStart = computed(
  () =>
    Boolean(
      leagueId.value &&
      seasonId.value &&
      opponent.value.trim() &&
      gameDate.value &&
      lineupValidation.value.valid,
    ) && !submitting.value,
)

async function loadLeagues(): Promise<void> {
  loading.value = true
  initialError.value = ''
  try {
    leagues.value = await fetchLeagues()
  } catch (error) {
    initialError.value = error instanceof Error ? error.message : 'Unable to load leagues.'
  } finally {
    loading.value = false
  }
}

watch(leagueId, async (nextLeagueId) => {
  seasonId.value = ''
  seasons.value = []
  roster.value = []
  lineup.value = []
  errorMessage.value = ''
  if (!nextLeagueId) return

  loadingSeason.value = true
  try {
    seasons.value = await fetchActiveSeasonsForLeague(nextLeagueId)
  } catch (error) {
    errorMessage.value = error instanceof Error ? error.message : 'Unable to load seasons.'
  } finally {
    loadingSeason.value = false
  }
})

watch(seasonId, async (nextSeasonId) => {
  roster.value = []
  lineup.value = []
  errorMessage.value = ''
  if (!nextSeasonId) return

  loadingSeason.value = true
  try {
    roster.value = await fetchSeasonRoster(nextSeasonId)
  } catch (error) {
    errorMessage.value = error instanceof Error ? error.message : 'Unable to load the roster.'
  } finally {
    loadingSeason.value = false
  }
})

async function submit(): Promise<void> {
  if (!canStart.value) {
    errorMessage.value =
      lineupValidation.value.message || 'Complete the league, season, opponent, date, and lineup.'
    return
  }

  submitting.value = true
  errorMessage.value = ''

  try {
    const playedAt = new Date(`${gameDate.value}T12:00:00`).toISOString()
    const gameId = await startGame(
      {
        leagueId: leagueId.value,
        seasonId: seasonId.value,
        opponent: opponent.value,
        playedAt,
        lineupPlayerIds: lineup.value.map((player) => player.id),
      },
      roster.value,
    )
    await router.replace(`/admin/games/${gameId}/score`)
  } catch (error) {
    errorMessage.value = error instanceof Error ? error.message : 'Unable to start the game.'
  } finally {
    submitting.value = false
  }
}

onMounted(loadLeagues)
</script>

<template>
  <main class="page-shell new-game-shell">
    <PageHeader back-to="/admin" title="Record New Game" />

    <DataState :error="initialError" :loading="loading" @retry="loadLeagues">
      <v-alert v-if="errorMessage" class="mb-4" color="error" variant="tonal">
        {{ errorMessage }}
      </v-alert>

      <div class="game-form">
        <div class="field-grid">
          <v-select
            v-model="leagueId"
            :disabled="submitting"
            item-title="name"
            item-value="id"
            :items="leagues"
            label="League"
            variant="outlined"
          />
          <v-select
            v-model="seasonId"
            :disabled="!leagueId || submitting"
            item-title="name"
            item-value="id"
            :items="seasons"
            label="Season"
            :loading="loadingSeason"
            no-data-text="No active seasons"
            variant="outlined"
          />
          <v-text-field
            v-model="opponent"
            autocomplete="off"
            :disabled="!seasonId || submitting"
            label="Opponent"
            maxlength="100"
            variant="outlined"
          />
          <v-text-field
            v-model="gameDate"
            :disabled="!seasonId || submitting"
            label="Game date"
            type="date"
            variant="outlined"
          />
        </div>

        <section v-if="seasonId" class="lineup-section" :aria-busy="loadingSeason">
          <LineupBuilder v-model="lineup" :disabled="submitting" :roster="roster" />
        </section>
      </div>

      <div class="start-bar">
        <v-btn
          block
          color="primary"
          :disabled="!canStart"
          :loading="submitting"
          size="large"
          @click="submit"
        >
          Start Game
        </v-btn>
      </div>
    </DataState>
  </main>
</template>

<style scoped>
.new-game-shell {
  max-width: 760px;
}

.game-form {
  padding: 20px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.16);
  border-radius: 12px;
  background: rgb(var(--v-theme-surface));
}

.field-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 4px 16px;
}

.lineup-section {
  margin-top: 8px;
  padding-top: 20px;
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.16);
}

.start-bar {
  position: sticky;
  bottom: 64px;
  z-index: 4;
  margin-top: 16px;
  padding: 8px 0;
  background: rgba(var(--v-theme-background), 0.96);
}

@media (min-width: 960px) {
  .start-bar {
    bottom: 16px;
  }
}

@media (max-width: 599px) {
  .game-form {
    padding: 16px;
  }

  .field-grid {
    grid-template-columns: 1fr;
  }
}
</style>
