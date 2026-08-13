<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'

import DataState from '@/components/DataState.vue'
import PageHeader from '@/components/PageHeader.vue'
import StatsTable from '@/components/StatsTable.vue'
import { useAsyncResource } from '@/composables/useAsyncResource'
import { fetchAllSeasonStatistics, fetchPlayers } from '@/services/dataService'
import type { Player, SeasonBattingStats } from '@/types/domain'
import { formatRate } from '@/utils/formatters'
import { aggregatePlayerStatistics } from '@/utils/statistics'
import type { StatisticValueKey } from '@/utils/statisticsTable'

interface PlayersPageData {
  players: Player[]
  stats: SeasonBattingStats[]
}

interface LeaderboardOption {
  title: string
  value: StatisticValueKey
  rate?: boolean
}

const leaderboardOptions: LeaderboardOption[] = [
  { title: 'Hits', value: 'hits' },
  { title: 'Home runs', value: 'home_runs' },
  { title: 'Runs', value: 'runs' },
  { title: 'Runs batted in', value: 'rbi' },
  { title: 'Batting average', value: 'batting_average', rate: true },
  { title: 'On-base percentage', value: 'on_base_percentage', rate: true },
  { title: 'Slugging percentage', value: 'slugging_percentage', rate: true },
  { title: 'OPS', value: 'ops', rate: true },
  { title: 'Doubles', value: 'doubles' },
  { title: 'Triples', value: 'triples' },
  { title: 'Walks', value: 'walks' },
  { title: 'Total bases', value: 'total_bases' },
]

const query = ref('')
const selectedScope = ref('all-time')
const selectedStat = ref<StatisticValueKey>('hits')
const page = useAsyncResource<PlayersPageData>()

const filteredPlayers = computed(() => {
  const term = query.value.trim().toLocaleLowerCase()
  if (!term) return page.data.value?.players ?? []
  return (page.data.value?.players ?? []).filter((player) =>
    player.display_name.toLocaleLowerCase().includes(term),
  )
})

const allTimeStats = computed(() => aggregatePlayerStatistics(page.data.value?.stats ?? []))

const scopeOptions = computed(() => {
  const uniqueSeasons = new Map<string, { title: string; value: string }>()
  for (const row of page.data.value?.stats ?? []) {
    if (!uniqueSeasons.has(row.season_id)) {
      uniqueSeasons.set(row.season_id, {
        title: `${row.league_name} — ${row.season_name}`,
        value: row.season_id,
      })
    }
  }
  return [
    { title: 'All time — all leagues', value: 'all-time' },
    ...Array.from(uniqueSeasons.values()).sort((left, right) =>
      left.title.localeCompare(right.title),
    ),
  ]
})

const selectedLeaderboard = computed(() => {
  const rows =
    selectedScope.value === 'all-time'
      ? allTimeStats.value
      : (page.data.value?.stats ?? []).filter((row) => row.season_id === selectedScope.value)
  return [...rows]
    .filter((row) => {
      if (
        selectedStat.value === 'batting_average' ||
        selectedStat.value === 'slugging_percentage'
      ) {
        return row.at_bats > 0
      }
      return row.plate_appearances > 0
    })
    .sort(
      (left, right) =>
        right[selectedStat.value] - left[selectedStat.value] ||
        right.plate_appearances - left.plate_appearances ||
        left.player_name.localeCompare(right.player_name),
    )
    .slice(0, 3)
})

const selectedOption = computed(() =>
  leaderboardOptions.find((option) => option.value === selectedStat.value),
)

function leaderValue(row: SeasonBattingStats): string | number {
  const value = row[selectedStat.value]
  return selectedOption.value?.rate ? formatRate(value) : value
}

function load(): Promise<void> {
  return page.load(async () => {
    const [players, stats] = await Promise.all([fetchPlayers(), fetchAllSeasonStatistics()])
    return { players, stats }
  })
}

onMounted(load)
</script>

<template>
  <main class="page-shell players-shell">
    <PageHeader
      title="Players"
      description="Career records, season leaders, and player profiles."
    />

    <DataState
      :empty="page.data.value?.players.length === 0"
      empty-title="No players."
      :error="page.error.value"
      :loading="page.loading.value"
      @retry="load"
    >
      <section class="hall-section" aria-labelledby="hall-heading">
        <div class="section-heading">
          <div>
            <h2 id="hall-heading" class="section-title mb-0">Hall of Fame</h2>
            <p>Top three leaders for the category and timeframe you choose.</p>
          </div>
        </div>

        <div class="leader-filters">
          <v-select
            v-model="selectedStat"
            :items="leaderboardOptions"
            label="Statistic"
            variant="outlined"
          />
          <v-select
            v-model="selectedScope"
            :items="scopeOptions"
            label="Timeframe"
            variant="outlined"
          />
        </div>

        <div v-if="selectedLeaderboard.length" class="podium-grid">
          <RouterLink
            v-for="(row, index) in selectedLeaderboard"
            :key="row.player_id"
            class="leader-card"
            :class="`place-${index + 1}`"
            :to="`/players/${row.player_id}`"
          >
            <span class="place">#{{ index + 1 }}</span>
            <strong>{{ row.player_name }}</strong>
            <b>{{ leaderValue(row) }}</b>
          </RouterLink>
        </div>
        <div v-else class="empty-leaders">No qualifying statistics for this selection.</div>
      </section>

      <section class="all-time-section" aria-labelledby="all-time-heading">
        <div class="section-heading">
          <div>
            <h2 id="all-time-heading" class="section-title mb-0">All-time batting</h2>
            <p>Career totals across every visible league and season.</p>
          </div>
          <span>{{ allTimeStats.length }} players</span>
        </div>
        <StatsTable
          download-filename="all-time-softball-batting-stats.csv"
          :rows="allTimeStats"
          link-players
        />
      </section>

      <section class="directory-section" aria-labelledby="directory-heading">
        <div class="section-heading">
          <div>
            <h2 id="directory-heading" class="section-title mb-0">Player directory</h2>
            <p>Open a player to see their season-by-season career.</p>
          </div>
        </div>
        <v-text-field
          v-model="query"
          aria-label="Search players"
          class="search-field mb-4"
          clearable
          density="compact"
          label="Search"
          prepend-inner-icon="mdi-magnify"
        />

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
      </section>
    </DataState>
  </main>
</template>

<style scoped>
.players-shell {
  max-width: 1180px;
}
.hall-section {
  padding: 22px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.16);
  border-radius: 14px;
  background: rgb(var(--v-theme-surface));
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
  gap: 3px;
}
.section-heading p {
  margin: 0;
  color: rgba(var(--v-theme-on-background), 0.7);
  font-size: 0.84rem;
}
.hall-section .section-heading p {
  color: rgba(var(--v-theme-on-surface), 0.7);
}
.section-heading > span {
  color: rgba(var(--v-theme-on-background), 0.68);
  font-size: 0.78rem;
}
.leader-filters {
  display: grid;
  margin-top: 20px;
  grid-template-columns: minmax(180px, 0.7fr) minmax(240px, 1.3fr);
  gap: 14px;
}
.podium-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 12px;
}
.leader-card {
  display: grid;
  min-height: 118px;
  padding: 15px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.14);
  border-radius: 10px;
  background: rgba(var(--v-theme-surface-variant), 0.55);
  color: rgb(var(--v-theme-on-surface));
  grid-template-columns: auto 1fr;
  grid-template-rows: auto 1fr;
  gap: 6px 10px;
}
.leader-card:hover,
.leader-card:focus-visible {
  border-color: rgb(var(--v-theme-primary));
}
.leader-card .place {
  color: rgba(var(--v-theme-on-surface), 0.62);
  font-size: 0.75rem;
  font-weight: 800;
}
.leader-card strong {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.leader-card b {
  align-self: end;
  color: rgb(var(--v-theme-primary));
  font-size: 1.8rem;
  font-variant-numeric: tabular-nums;
  grid-column: 1 / -1;
}
.leader-card.place-1 {
  border-color: rgba(var(--v-theme-primary), 0.58);
}
.empty-leaders {
  padding: 22px 0 6px;
  color: rgba(var(--v-theme-on-surface), 0.68);
}
.all-time-section,
.directory-section {
  margin-top: 36px;
}
.all-time-section .section-heading {
  margin-bottom: 10px;
}
.search-field {
  max-width: 420px;
  margin-top: 16px;
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
@media (max-width: 699px) {
  .leader-filters,
  .podium-grid {
    grid-template-columns: 1fr;
  }
  .leader-card {
    min-height: 96px;
  }
  .hall-section {
    padding: 16px;
  }
}
</style>
