<script setup lang="ts">
import { computed, onMounted, watch } from 'vue'

import DataState from '@/components/DataState.vue'
import PageHeader from '@/components/PageHeader.vue'
import { useAsyncResource } from '@/composables/useAsyncResource'
import { fetchPlayer, fetchPlayerSeasonStatistics } from '@/services/dataService'
import type { Player, SeasonBattingStats } from '@/types/domain'
import { formatRate } from '@/utils/formatters'
import { aggregateSeasonStats } from '@/utils/statistics'

const props = defineProps<{ playerId: string }>()

interface PlayerPageData {
  player: Player
  seasons: SeasonBattingStats[]
}

const page = useAsyncResource<PlayerPageData>()
const career = computed(() => aggregateSeasonStats(page.data.value?.seasons ?? []))

const careerCounts = computed(() => [
  ['G', career.value.games],
  ['PA', career.value.plate_appearances],
  ['AB', career.value.at_bats],
  ['H', career.value.hits],
  ['HR', career.value.home_runs],
  ['R', career.value.runs],
  ['RBI', career.value.rbi],
  ['BB', career.value.walks],
])

const careerRates = computed(() => [
  ['AVG', formatRate(career.value.batting_average)],
  ['OBP', formatRate(career.value.on_base_percentage)],
  ['SLG', formatRate(career.value.slugging_percentage)],
  ['OPS', formatRate(career.value.ops)],
])

function load(): Promise<void> {
  return page.load(async () => {
    const [player, seasons] = await Promise.all([
      fetchPlayer(props.playerId),
      fetchPlayerSeasonStatistics(props.playerId),
    ])
    return { player, seasons }
  })
}

onMounted(load)
watch(() => props.playerId, load)
</script>

<template>
  <main class="page-shell player-shell">
    <DataState :error="page.error.value" :loading="page.loading.value" @retry="load">
      <template v-if="page.data.value">
        <PageHeader back-to="/players" :title="page.data.value.player.display_name" />

        <section aria-labelledby="career-heading" class="career-section">
          <h2 id="career-heading" class="section-label">Career</h2>
          <div class="career-grid counts-grid">
            <div v-for="item in careerCounts" :key="String(item[0])">
              <strong>{{ item[1] }}</strong
              ><small>{{ item[0] }}</small>
            </div>
          </div>
          <div class="career-grid rates-grid">
            <div v-for="item in careerRates" :key="String(item[0])">
              <strong>{{ item[1] }}</strong
              ><small>{{ item[0] }}</small>
            </div>
          </div>
        </section>

        <section aria-labelledby="seasons-heading" class="mt-8">
          <h2 id="seasons-heading" class="section-label">Seasons</h2>

          <DataState
            :empty="page.data.value.seasons.length === 0"
            empty-title="No recorded seasons."
            :loading="false"
          >
            <div class="season-list">
              <RouterLink
                v-for="line in page.data.value.seasons"
                :key="line.season_id"
                class="season-row"
                :to="`/seasons/${line.season_id}`"
              >
                <div class="season-name">
                  <strong>{{ line.season_name }}</strong>
                  <small>{{ line.league_name }}</small>
                </div>
                <div class="season-stats">
                  <span
                    ><b>{{ line.games }}</b
                    ><small>G</small></span
                  >
                  <span
                    ><b>{{ line.plate_appearances }}</b
                    ><small>PA</small></span
                  >
                  <span
                    ><b>{{ line.hits }}</b
                    ><small>H</small></span
                  >
                  <span
                    ><b>{{ line.rbi }}</b
                    ><small>RBI</small></span
                  >
                  <span
                    ><b>{{ formatRate(line.batting_average) }}</b
                    ><small>AVG</small></span
                  >
                  <span
                    ><b>{{ formatRate(line.ops) }}</b
                    ><small>OPS</small></span
                  >
                </div>
              </RouterLink>
            </div>
          </DataState>
        </section>
      </template>
    </DataState>
  </main>
</template>

<style scoped>
.player-shell {
  max-width: 860px;
}

.section-label {
  margin: 0 0 9px;
  color: rgba(var(--v-theme-on-background), 0.74);
  font-size: 0.72rem;
  font-weight: 750;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.career-section {
  padding: 14px 0;
  border-top: 1px solid rgba(var(--v-theme-on-background), 0.16);
  border-bottom: 1px solid rgba(var(--v-theme-on-background), 0.16);
}

.career-grid {
  display: grid;
}

.counts-grid {
  grid-template-columns: repeat(8, 1fr);
}

.rates-grid {
  margin-top: 14px;
  padding-top: 14px;
  border-top: 1px solid rgba(var(--v-theme-on-background), 0.12);
  grid-template-columns: repeat(4, 1fr);
}

.career-grid > div,
.season-stats span {
  display: flex;
  min-width: 0;
  flex-direction: column;
}

.career-grid strong {
  color: rgb(var(--v-theme-on-background));
  font-size: clamp(1rem, 4vw, 1.35rem);
  font-variant-numeric: tabular-nums;
}

.career-grid small,
.season-stats small {
  color: rgba(var(--v-theme-on-background), 0.68);
  font-size: 0.62rem;
  font-weight: 750;
}

.season-list {
  border-top: 1px solid rgba(var(--v-theme-on-background), 0.16);
}

.season-row {
  display: grid;
  min-height: 72px;
  align-items: center;
  border-bottom: 1px solid rgba(var(--v-theme-on-background), 0.16);
  grid-template-columns: minmax(120px, 1fr) 2fr;
  gap: 20px;
}

.season-name {
  display: flex;
  flex-direction: column;
}

.season-name strong {
  color: rgb(var(--v-theme-on-background));
}

.season-name small {
  color: rgba(var(--v-theme-on-background), 0.74);
}

.season-stats {
  display: grid;
  grid-template-columns: repeat(6, 1fr);
  gap: 8px;
}

.season-stats b {
  color: rgb(var(--v-theme-on-background));
  font-size: 0.86rem;
  font-variant-numeric: tabular-nums;
}

@media (max-width: 599px) {
  .counts-grid {
    grid-template-columns: repeat(4, 1fr);
    row-gap: 14px;
  }

  .season-row {
    padding: 12px 0;
    grid-template-columns: 1fr;
    gap: 9px;
  }
}
</style>
