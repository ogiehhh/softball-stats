<script setup lang="ts">
import { computed, ref, watch } from 'vue'

import type {
  BaseDestination,
  BaseOccupancy,
  GameLineupEntry,
  PlateAppearanceResult,
  Player,
  RecordPlayInput,
  RunnerOutcome,
} from '@/types/domain'
import {
  allowedDestinations,
  countOuts,
  countRuns,
  createDefaultRunnerOutcomes,
  defaultRbi,
  DESTINATION_LABELS,
  RESULT_LABELS,
  validateRunnerOutcomes,
} from '@/utils/scoring'

const props = defineProps<{
  batter: Player
  battingOrder: number
  bases: BaseOccupancy
  currentOuts: number
  lineup: GameLineupEntry[]
  submitting: boolean
}>()

const emit = defineEmits<{
  submit: [input: RecordPlayInput]
}>()

interface ResultGroup {
  label: string
  results: PlateAppearanceResult[]
}

const resultGroups: ResultGroup[] = [
  { label: 'Hit', results: ['single', 'double', 'triple', 'home_run'] },
  {
    label: 'Reach',
    results: ['walk', 'hit_by_pitch', 'fielders_choice', 'reached_on_error'],
  },
  {
    label: 'Out',
    results: ['strikeout', 'groundout', 'flyout', 'lineout', 'popout', 'sacrifice_fly'],
  },
]

const BUTTON_LABELS: Record<PlateAppearanceResult, string> = {
  single: '1B',
  double: '2B',
  triple: '3B',
  home_run: 'HR',
  walk: 'BB',
  hit_by_pitch: 'HBP',
  fielders_choice: 'FC',
  reached_on_error: 'ROE',
  strikeout: 'K',
  groundout: 'Groundout',
  flyout: 'Flyout',
  lineout: 'Lineout',
  popout: 'Popout',
  sacrifice_fly: 'Sac Fly',
}

const selectedResult = ref<PlateAppearanceResult | null>(null)
const outcomes = ref<RunnerOutcome[]>([])
const rbi = ref(0)

const outsRecorded = computed(() => countOuts(outcomes.value))
const runsScored = computed(() => countRuns(outcomes.value))
const validationMessage = computed(() =>
  selectedResult.value
    ? validateRunnerOutcomes(outcomes.value, props.currentOuts, rbi.value)
    : 'Choose a result.',
)
const canSubmit = computed(
  () => Boolean(selectedResult.value) && !validationMessage.value && !props.submitting,
)

const playSummary = computed(() => {
  if (!selectedResult.value) return ''
  const runs = runsScored.value === 1 ? '1 run' : `${runsScored.value} runs`
  const outs = outsRecorded.value === 1 ? '1 out' : `${outsRecorded.value} outs`
  return `${RESULT_LABELS[selectedResult.value]} · ${runs} · ${outs} · ${rbi.value} RBI`
})

function reset(): void {
  selectedResult.value = null
  outcomes.value = []
  rbi.value = 0
}

function chooseResult(result: PlateAppearanceResult): void {
  selectedResult.value = result
  outcomes.value = createDefaultRunnerOutcomes(result, props.batter.id, props.bases)
  rbi.value = defaultRbi(result, outcomes.value)
}

function playerName(playerId: string): string {
  return (
    props.lineup.find((entry) => entry.player_id === playerId)?.player.display_name ??
    'Unknown player'
  )
}

function originLabel(outcome: RunnerOutcome): string {
  if (outcome.startingBase === 'batter') return 'Batter'
  return DESTINATION_LABELS[outcome.startingBase]
}

function changeDestination(outcome: RunnerOutcome, destination: BaseDestination): void {
  if (!selectedResult.value) return
  const usedDefault = rbi.value === defaultRbi(selectedResult.value, outcomes.value)
  outcome.endingBase = destination
  rbi.value = usedDefault
    ? defaultRbi(selectedResult.value, outcomes.value)
    : Math.min(rbi.value, runsScored.value)
}

function changeRbi(amount: number): void {
  rbi.value = Math.max(0, Math.min(runsScored.value, rbi.value + amount))
}

function submit(): void {
  if (!canSubmit.value || !selectedResult.value) return
  emit('submit', {
    result: selectedResult.value,
    rbi: rbi.value,
    runnerOutcomes: outcomes.value.map((outcome) => ({ ...outcome })),
  })
}

watch(() => [props.batter.id, props.bases.first, props.bases.second, props.bases.third], reset)

defineExpose({ reset })
</script>

<template>
  <section class="play-editor" aria-labelledby="batter-heading">
    <div class="batter-heading">
      <div>
        <span>At bat</span>
        <h2 id="batter-heading">#{{ battingOrder }} {{ batter.display_name }}</h2>
      </div>
      <strong>{{ currentOuts }} {{ currentOuts === 1 ? 'out' : 'outs' }}</strong>
    </div>

    <div v-for="group in resultGroups" :key="group.label" class="result-group">
      <div class="result-group-label">{{ group.label }}</div>
      <div class="result-buttons">
        <v-btn
          v-for="result in group.results"
          :key="result"
          :aria-label="RESULT_LABELS[result]"
          :aria-pressed="selectedResult === result"
          :color="selectedResult === result ? 'primary' : undefined"
          :disabled="submitting"
          min-height="46"
          :variant="selectedResult === result ? 'flat' : 'outlined'"
          @click="chooseResult(result)"
        >
          {{ BUTTON_LABELS[result] }}
        </v-btn>
      </div>
    </div>

    <template v-if="selectedResult">
      <section class="movement-section" aria-labelledby="movement-heading">
        <h3 id="movement-heading">Runners</h3>
        <div class="movement-list">
          <div v-for="outcome in outcomes" :key="outcome.playerId" class="movement-row">
            <div class="movement-person">
              <strong>{{ playerName(outcome.playerId) }}</strong>
              <span>{{ originLabel(outcome) }} →</span>
            </div>
            <div class="destination-buttons">
              <v-btn
                v-for="destination in allowedDestinations(outcome.startingBase, selectedResult)"
                :key="destination"
                :aria-label="`${playerName(outcome.playerId)} to ${DESTINATION_LABELS[destination]}`"
                :aria-pressed="outcome.endingBase === destination"
                :color="outcome.endingBase === destination ? 'primary' : undefined"
                :disabled="submitting"
                min-height="42"
                size="small"
                :variant="outcome.endingBase === destination ? 'flat' : 'text'"
                @click="changeDestination(outcome, destination)"
              >
                {{ DESTINATION_LABELS[destination] }}
              </v-btn>
            </div>
          </div>
        </div>
      </section>

      <section class="credit-section" aria-labelledby="credit-heading">
        <h3 id="credit-heading">Play totals</h3>
        <div class="credit-row">
          <div>
            <span>Runs</span><strong>{{ runsScored }}</strong>
          </div>
          <div>
            <span>Outs</span><strong>{{ outsRecorded }}</strong>
          </div>
          <div class="rbi-control">
            <span>RBI</span>
            <v-btn
              aria-label="Decrease RBI"
              :disabled="submitting || rbi === 0"
              icon="mdi-minus"
              size="x-small"
              variant="text"
              @click="changeRbi(-1)"
            />
            <strong>{{ rbi }}</strong>
            <v-btn
              aria-label="Increase RBI"
              :disabled="submitting || rbi >= runsScored"
              icon="mdi-plus"
              size="x-small"
              variant="text"
              @click="changeRbi(1)"
            />
          </div>
        </div>
      </section>

      <p v-if="validationMessage" class="validation-message">{{ validationMessage }}</p>

      <div class="record-bar">
        <span>{{ playSummary }}</span>
        <v-btn
          color="primary"
          :disabled="!canSubmit"
          :loading="submitting"
          size="large"
          @click="submit"
        >
          Record play
        </v-btn>
      </div>
    </template>
  </section>
</template>

<style scoped>
.play-editor {
  padding: 18px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.16);
  border-radius: 12px;
  background: rgb(var(--v-theme-surface));
}

.batter-heading {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  margin-bottom: 20px;
}

.batter-heading span,
.batter-heading > strong {
  color: rgba(var(--v-theme-on-surface), 0.74);
  font-size: 0.75rem;
  font-weight: 750;
}

.batter-heading h2 {
  margin-top: 2px;
  color: rgb(var(--v-theme-on-surface));
  font-size: 1.2rem;
}

.result-group + .result-group {
  margin-top: 14px;
}

.result-group-label,
.movement-section h3,
.credit-section h3 {
  margin-bottom: 7px;
  color: rgba(var(--v-theme-on-surface), 0.74);
  font-size: 0.68rem;
  font-weight: 800;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.result-buttons {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 7px;
}

.result-group:last-child .result-buttons {
  grid-template-columns: repeat(3, minmax(0, 1fr));
}

.result-buttons :deep(.v-btn) {
  padding-inline: 6px;
}

.result-buttons :deep(.v-btn__content) {
  font-size: 0.76rem;
  white-space: normal;
}

.movement-section,
.credit-section {
  margin-top: 22px;
  padding-top: 18px;
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.16);
}

.movement-list {
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.12);
}

.movement-row {
  display: grid;
  align-items: center;
  padding: 9px 0;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.12);
  gap: 8px;
  grid-template-columns: minmax(100px, 0.75fr) minmax(0, 1.25fr);
}

.movement-person {
  display: flex;
  min-width: 0;
  flex-direction: column;
}

.movement-person strong {
  overflow: hidden;
  font-size: 0.86rem;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.movement-person span {
  color: rgba(var(--v-theme-on-surface), 0.74);
  font-size: 0.72rem;
}

.destination-buttons {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 2px;
}

.credit-row {
  display: flex;
  align-items: center;
  gap: 24px;
  padding: 9px 0;
}

.credit-row > div {
  display: flex;
  align-items: center;
  gap: 7px;
}

.credit-row span {
  color: rgba(var(--v-theme-on-surface), 0.74);
  font-size: 0.72rem;
  font-weight: 700;
}

.credit-row strong {
  font-size: 1.1rem;
  font-variant-numeric: tabular-nums;
}

.validation-message {
  margin: 12px 0 0;
  color: rgb(var(--v-theme-error));
  font-size: 0.8rem;
}

.record-bar {
  position: sticky;
  bottom: 64px;
  z-index: 5;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin: 18px -10px -10px;
  padding: 10px;
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.16);
  background: rgba(var(--v-theme-surface), 0.97);
}

.record-bar span {
  color: rgba(var(--v-theme-on-surface), 0.74);
  font-size: 0.75rem;
}

@media (min-width: 960px) {
  .record-bar {
    bottom: 16px;
  }
}

@media (max-width: 479px) {
  .play-editor {
    padding: 14px;
  }

  .result-buttons,
  .result-group:last-child .result-buttons {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }

  .movement-row {
    grid-template-columns: 92px minmax(0, 1fr);
  }

  .record-bar {
    align-items: stretch;
    flex-direction: column;
  }
}
</style>
