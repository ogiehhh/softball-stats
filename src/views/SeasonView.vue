<script setup lang="ts">
import { computed, onMounted, watch } from 'vue'

import DataState from '@/components/DataState.vue'
import PageHeader from '@/components/PageHeader.vue'
import StatsTable from '@/components/StatsTable.vue'
import { useAsyncResource } from '@/composables/useAsyncResource'
import {
  fetchGamesForSeason,
  fetchLeague,
  fetchSeason,
  fetchSeasonStatistics,
} from '@/services/dataService'
import type { Game, League, Season, SeasonBattingStats } from '@/types/domain'
import { formatDate, statusLabel } from '@/utils/formatters'
import { safeDownloadFilename } from '@/utils/statisticsTable'

const props = defineProps<{ seasonId: string }>()

interface SeasonPageData {
  season: Season
  league: League
  games: Game[]
  stats: SeasonBattingStats[]
}

const page = useAsyncResource<SeasonPageData>()
const leagueBack = computed(() =>
  page.data.value ? `/leagues/${page.data.value.league.slug}` : '/',
)

function load(): Promise<void> {
  return page.load(async () => {
    const season = await fetchSeason(props.seasonId)
    const [games, stats] = await Promise.all([
      fetchGamesForSeason(season.id),
      fetchSeasonStatistics(season.id),
    ])
    const league = await fetchLeague(season.league_id)
    return { season, league, games, stats }
  })
}

onMounted(load)
watch(() => props.seasonId, load)
</script>

<template>
  <main class="page-shell">
    <DataState :error="page.error.value" :loading="page.loading.value" @retry="load">
      <template v-if="page.data.value">
        <PageHeader :back-to="leagueBack" :title="page.data.value.season.name">
          <div class="season-meta">
            {{ page.data.value.league.name }} ·
            {{ formatDate(page.data.value.season.start_date) }}–{{
              formatDate(page.data.value.season.end_date)
            }}
            <span>· {{ page.data.value.games.length }} games</span>
            <span v-if="!page.data.value.season.active">· Completed</span>
          </div>
        </PageHeader>

        <section class="section-block" aria-labelledby="games-heading">
          <h2 id="games-heading" class="section-title">Games</h2>

          <DataState
            :empty="page.data.value.games.length === 0"
            empty-title="No games."
            :loading="false"
          >
            <div class="game-list">
              <div v-for="game in page.data.value.games" :key="game.id" class="game-row">
                <time :datetime="game.played_at">{{ formatDate(game.played_at) }}</time>
                <strong>vs. {{ game.opponent }}</strong>
                <span class="game-result">
                  <small>{{ statusLabel(game.status) }}</small>
                  <b v-if="game.team_score !== null">
                    {{ game.team_score
                    }}<template v-if="game.opponent_score !== null"
                      >–{{ game.opponent_score }}</template
                    >
                  </b>
                </span>
              </div>
            </div>
          </DataState>
        </section>

        <section aria-labelledby="stats-heading">
          <div class="section-heading">
            <h2 id="stats-heading" class="section-title">Batting</h2>
            <span>{{ page.data.value.stats.length }} players</span>
          </div>

          <DataState
            :empty="page.data.value.stats.length === 0"
            empty-title="No batting stats."
            :loading="false"
          >
            <StatsTable
              :download-filename="
                safeDownloadFilename(
                  `${page.data.value.league.name} ${page.data.value.season.name} batting stats`,
                )
              "
              :rows="page.data.value.stats"
              link-players
            />
          </DataState>
        </section>
      </template>
    </DataState>
  </main>
</template>

<style scoped>
.season-meta {
  margin-top: 6px;
  color: rgba(var(--v-theme-on-background), 0.74);
  font-size: 0.86rem;
}

.section-block {
  margin-bottom: 32px;
}

.section-title {
  margin: 0 0 9px;
}

.game-list {
  border-top: 1px solid rgba(var(--v-theme-on-background), 0.16);
}

.game-row {
  display: grid;
  min-height: 58px;
  align-items: center;
  border-bottom: 1px solid rgba(var(--v-theme-on-background), 0.16);
  grid-template-columns: 96px minmax(0, 1fr) auto;
  gap: 12px;
}

.game-row time,
.game-result small {
  color: rgba(var(--v-theme-on-background), 0.74);
  font-size: 0.76rem;
}

.game-row > strong {
  overflow: hidden;
  color: rgb(var(--v-theme-on-background));
  font-size: 0.9rem;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.game-result {
  display: flex;
  align-items: center;
  gap: 10px;
}

.game-result b {
  color: rgb(var(--v-theme-on-background));
  font-size: 1rem;
  font-variant-numeric: tabular-nums;
}

.section-heading {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 16px;
}

.section-heading > span {
  color: rgba(var(--v-theme-on-background), 0.74);
  font-size: 0.75rem;
}

@media (max-width: 599px) {
  .game-row {
    grid-template-columns: 70px minmax(0, 1fr) auto;
    gap: 8px;
  }

  .game-result small {
    display: none;
  }
}
</style>
