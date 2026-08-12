<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'

import DataState from '@/components/DataState.vue'
import PageHeader from '@/components/PageHeader.vue'
import PlayEditor from '@/components/PlayEditor.vue'
import { useAsyncResource } from '@/composables/useAsyncResource'
import {
  fetchScoreGameDetails,
  finishGame,
  recordPlateAppearance,
  undoLastPlateAppearance,
} from '@/services/gameService'
import type { BaseOccupancy, RecordPlayInput } from '@/types/domain'
import { formatDate } from '@/utils/formatters'
import { DESTINATION_LABELS, RESULT_LABELS } from '@/utils/scoring'

const props = defineProps<{
  gameId: string
}>()

const router = useRouter()
const details = useAsyncResource<Awaited<ReturnType<typeof fetchScoreGameDetails>>>()
const playEditor = ref<InstanceType<typeof PlayEditor> | null>(null)
const actionLoading = ref(false)
const actionError = ref('')
const actionSuccess = ref('')
const undoDialog = ref(false)
const finishDialog = ref(false)

const currentBatterEntry = computed(() =>
  details.data.value?.lineup.find(
    (entry) => entry.batting_order === details.data.value?.state.next_batter_order,
  ),
)
const bases = computed<BaseOccupancy>(() => ({
  first: details.data.value?.state.first_base_player_id ?? null,
  second: details.data.value?.state.second_base_player_id ?? null,
  third: details.data.value?.state.third_base_player_id ?? null,
}))
const isInProgress = computed(() => details.data.value?.game.status === 'in_progress')
const latestPlay = computed(() => details.data.value?.recentPlays[0])

function playerName(playerId: string | null): string {
  if (!playerId) return 'Empty'
  return (
    details.data.value?.lineup.find((entry) => entry.player_id === playerId)?.player.display_name ??
    'Unknown player'
  )
}

function loadGame(): Promise<void> {
  return details.load(() => fetchScoreGameDetails(props.gameId))
}

function recentPlaySummary(play: NonNullable<typeof latestPlay.value>): string {
  const runs = play.runnerOutcomes.filter((outcome) => outcome.endingBase === 'home').length
  const parts = [`${play.outsRecorded} out${play.outsRecorded === 1 ? '' : 's'}`]
  if (runs) parts.push(`${runs} run${runs === 1 ? '' : 's'}`)
  if (play.rbi) parts.push(`${play.rbi} RBI`)
  return parts.join(' · ')
}

function movementSummary(play: NonNullable<typeof latestPlay.value>): string {
  return play.runnerOutcomes
    .map((outcome) => `${playerName(outcome.playerId)} → ${DESTINATION_LABELS[outcome.endingBase]}`)
    .join(', ')
}

async function recordPlay(input: RecordPlayInput): Promise<void> {
  const game = details.data.value
  if (!game || actionLoading.value) return

  actionLoading.value = true
  actionError.value = ''
  actionSuccess.value = ''
  try {
    await recordPlateAppearance(game.game.id, game.state, input)
    await loadGame()
    playEditor.value?.reset()
    actionSuccess.value = 'Play recorded.'
  } catch (error) {
    actionError.value = error instanceof Error ? error.message : 'The play was not saved.'
    await loadGame()
  } finally {
    actionLoading.value = false
  }
}

async function undoLatest(): Promise<void> {
  const game = details.data.value
  if (!game || actionLoading.value || !latestPlay.value) return

  actionLoading.value = true
  actionError.value = ''
  actionSuccess.value = ''
  try {
    await undoLastPlateAppearance(game.game.id, game.state.updated_at)
    undoDialog.value = false
    await loadGame()
    playEditor.value?.reset()
    actionSuccess.value = 'Latest play undone.'
  } catch (error) {
    undoDialog.value = false
    actionError.value = error instanceof Error ? error.message : 'The latest play was not undone.'
    await loadGame()
  } finally {
    actionLoading.value = false
  }
}

async function finishCurrentGame(): Promise<void> {
  const game = details.data.value
  if (!game || actionLoading.value) return

  actionLoading.value = true
  actionError.value = ''
  actionSuccess.value = ''
  try {
    await finishGame(game.game.id, game.state.updated_at)
    finishDialog.value = false
    await router.replace(`/seasons/${game.season.id}`)
  } catch (error) {
    finishDialog.value = false
    actionError.value = error instanceof Error ? error.message : 'The game was not finished.'
    await loadGame()
  } finally {
    actionLoading.value = false
  }
}

onMounted(loadGame)
watch(() => props.gameId, loadGame)
</script>

<template>
  <main class="page-shell score-shell">
    <DataState :error="details.error.value" :loading="details.loading.value" @retry="loadGame">
      <template v-if="details.data.value">
        <PageHeader back-to="/admin" :title="`vs. ${details.data.value.game.opponent}`">
          <p class="game-meta">
            {{ details.data.value.league.name }} · {{ details.data.value.season.name }} ·
            {{ formatDate(details.data.value.game.played_at) }}
          </p>
        </PageHeader>

        <div class="game-state" aria-label="Current game state">
          <div>
            <span>Team</span><strong>{{ details.data.value.game.team_score ?? 0 }}</strong>
          </div>
          <div>
            <span>Inning</span><strong>{{ details.data.value.state.inning }}</strong>
          </div>
          <div>
            <span>Outs</span><strong>{{ details.data.value.state.outs }}</strong>
          </div>
          <div>
            <span>Batting</span><strong>#{{ details.data.value.state.next_batter_order }}</strong>
          </div>
        </div>

        <v-alert
          v-if="actionError"
          class="mt-4"
          closable
          color="error"
          variant="tonal"
          @click:close="actionError = ''"
        >
          {{ actionError }}
        </v-alert>
        <v-alert
          v-if="actionSuccess"
          class="mt-4"
          closable
          color="success"
          variant="tonal"
          @click:close="actionSuccess = ''"
        >
          {{ actionSuccess }}
        </v-alert>

        <div v-if="!isInProgress" class="completed-row">
          <span>Game completed.</span>
          <v-btn :to="`/seasons/${details.data.value.season.id}`" size="small" variant="text">
            View stats
          </v-btn>
        </div>

        <div class="bases-row" aria-label="Current runners">
          <div :class="{ occupied: details.data.value.state.third_base_player_id }">
            <span>3B</span
            ><strong>{{ playerName(details.data.value.state.third_base_player_id) }}</strong>
          </div>
          <div :class="{ occupied: details.data.value.state.second_base_player_id }">
            <span>2B</span
            ><strong>{{ playerName(details.data.value.state.second_base_player_id) }}</strong>
          </div>
          <div :class="{ occupied: details.data.value.state.first_base_player_id }">
            <span>1B</span
            ><strong>{{ playerName(details.data.value.state.first_base_player_id) }}</strong>
          </div>
        </div>

        <div class="scoring-layout">
          <div class="main-column">
            <PlayEditor
              v-if="isInProgress && currentBatterEntry"
              ref="playEditor"
              :bases="bases"
              :batter="currentBatterEntry.player"
              :batting-order="currentBatterEntry.batting_order"
              :current-outs="details.data.value.state.outs"
              :lineup="details.data.value.lineup"
              :submitting="actionLoading"
              @submit="recordPlay"
            />
          </div>

          <aside class="side-column">
            <section class="side-section" aria-labelledby="recent-heading">
              <div class="side-heading">
                <h2 id="recent-heading">Recent plays</h2>
                <v-btn
                  v-if="isInProgress && latestPlay"
                  color="error"
                  :disabled="actionLoading"
                  size="small"
                  variant="text"
                  @click="undoDialog = true"
                >
                  Undo
                </v-btn>
              </div>

              <div v-if="details.data.value.recentPlays.length" class="recent-list">
                <article v-for="play in details.data.value.recentPlays" :key="play.id">
                  <div class="recent-heading">
                    <span>#{{ play.sequenceNo }} · Inn. {{ play.inning }}</span>
                    <strong>{{ RESULT_LABELS[play.result] }}</strong>
                  </div>
                  <h3>{{ play.batter.display_name }}</h3>
                  <p>{{ recentPlaySummary(play) }}</p>
                  <small>{{ movementSummary(play) }}</small>
                </article>
              </div>
              <p v-else class="empty-copy">No plays yet.</p>
            </section>

            <section class="side-section" aria-labelledby="lineup-heading">
              <h2 id="lineup-heading">Lineup</h2>
              <ol class="lineup-list">
                <li
                  v-for="entry in details.data.value.lineup"
                  :key="entry.player_id"
                  :class="{
                    current: entry.batting_order === details.data.value.state.next_batter_order,
                  }"
                >
                  <span>{{ entry.batting_order }}</span>
                  <strong>{{ entry.player.display_name }}</strong>
                  <small v-if="entry.batting_order === details.data.value.state.next_batter_order"
                    >At bat</small
                  >
                </li>
              </ol>
            </section>

            <v-btn
              v-if="isInProgress"
              block
              :disabled="actionLoading"
              variant="outlined"
              @click="finishDialog = true"
            >
              Finish game
            </v-btn>
          </aside>
        </div>

        <v-dialog v-model="undoDialog" max-width="400">
          <v-card>
            <v-card-title>Undo latest play?</v-card-title>
            <v-card-text v-if="latestPlay">
              #{{ latestPlay.sequenceNo }} {{ latestPlay.batter.display_name }} —
              {{ RESULT_LABELS[latestPlay.result] }}
            </v-card-text>
            <v-card-actions>
              <v-spacer />
              <v-btn :disabled="actionLoading" variant="text" @click="undoDialog = false"
                >Cancel</v-btn
              >
              <v-btn color="error" :loading="actionLoading" @click="undoLatest">Undo</v-btn>
            </v-card-actions>
          </v-card>
        </v-dialog>

        <v-dialog v-model="finishDialog" max-width="400">
          <v-card>
            <v-card-title>Finish game?</v-card-title>
            <v-card-text
              >This stops scoring. Team score:
              {{ details.data.value.game.team_score ?? 0 }}.</v-card-text
            >
            <v-card-actions>
              <v-spacer />
              <v-btn :disabled="actionLoading" variant="text" @click="finishDialog = false"
                >Cancel</v-btn
              >
              <v-btn color="primary" :loading="actionLoading" @click="finishCurrentGame"
                >Finish</v-btn
              >
            </v-card-actions>
          </v-card>
        </v-dialog>
      </template>
    </DataState>
  </main>
</template>

<style scoped>
.score-shell {
  max-width: 1080px;
}

.game-meta {
  margin: 7px 0 0;
  color: rgba(var(--v-theme-on-background), 0.74);
  font-size: 0.83rem;
}

.game-state,
.bases-row {
  display: grid;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.16);
  border-radius: 10px;
  background: rgb(var(--v-theme-surface));
}

.game-state {
  grid-template-columns: repeat(4, 1fr);
}

.game-state div,
.bases-row div {
  display: flex;
  min-width: 0;
  align-items: center;
  justify-content: center;
  flex-direction: column;
}

.game-state div {
  min-height: 62px;
}

.game-state div + div,
.bases-row div + div {
  border-left: 1px solid rgba(var(--v-theme-on-surface), 0.16);
}

.game-state span,
.bases-row span {
  color: rgba(var(--v-theme-on-surface), 0.74);
  font-size: 0.63rem;
  font-weight: 800;
  letter-spacing: 0.07em;
  text-transform: uppercase;
}

.game-state strong {
  color: rgb(var(--v-theme-on-surface));
  font-size: 1.2rem;
  font-variant-numeric: tabular-nums;
}

.bases-row {
  margin: 14px 0;
  grid-template-columns: repeat(3, 1fr);
}

.bases-row div {
  min-height: 52px;
  padding: 6px;
}

.bases-row strong {
  overflow: hidden;
  max-width: 100%;
  color: rgba(var(--v-theme-on-surface), 0.64);
  font-size: 0.76rem;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.bases-row .occupied {
  background: rgba(var(--v-theme-primary), 0.13);
}

.bases-row .occupied strong {
  color: rgb(var(--v-theme-primary));
}

.completed-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-top: 14px;
  padding: 10px 12px;
  border: 1px solid rgba(var(--v-theme-success), 0.5);
  border-radius: 8px;
  color: rgb(var(--v-theme-success));
  font-size: 0.85rem;
}

.scoring-layout {
  display: grid;
  gap: 18px;
}

.main-column,
.side-column {
  min-width: 0;
}

.side-section {
  margin-bottom: 16px;
  padding: 16px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.16);
  border-radius: 10px;
  background: rgb(var(--v-theme-surface));
}

.side-section > h2,
.side-heading h2 {
  color: rgb(var(--v-theme-on-surface));
  font-size: 0.95rem;
}

.side-heading {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 8px;
}

.recent-list {
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.12);
}

.recent-list article {
  padding: 10px 0;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.12);
}

.recent-heading {
  display: flex;
  justify-content: space-between;
  gap: 8px;
  color: rgba(var(--v-theme-on-surface), 0.74);
  font-size: 0.66rem;
}

.recent-heading strong {
  color: rgb(var(--v-theme-primary));
}

.recent-list h3 {
  margin-top: 3px;
  color: rgb(var(--v-theme-on-surface));
  font-size: 0.84rem;
}

.recent-list p,
.recent-list small,
.empty-copy {
  color: rgba(var(--v-theme-on-surface), 0.74);
  font-size: 0.72rem;
}

.recent-list p {
  margin: 1px 0;
}

.recent-list small {
  display: block;
}

.empty-copy {
  margin: 8px 0 0;
}

.lineup-list {
  margin: 8px 0 0;
  padding: 0;
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.12);
  list-style: none;
}

.lineup-list li {
  display: grid;
  min-height: 39px;
  align-items: center;
  padding: 4px 0;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.12);
  grid-template-columns: 24px 1fr auto;
}

.lineup-list span,
.lineup-list small {
  color: rgba(var(--v-theme-on-surface), 0.66);
  font-size: 0.7rem;
}

.lineup-list strong {
  font-size: 0.82rem;
}

.lineup-list li.current strong,
.lineup-list li.current small {
  color: rgb(var(--v-theme-primary));
}

@media (min-width: 900px) {
  .scoring-layout {
    align-items: start;
    grid-template-columns: minmax(0, 1.6fr) minmax(260px, 0.7fr);
  }

  .side-column {
    position: sticky;
    top: 20px;
  }
}
</style>
