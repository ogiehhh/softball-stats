<script setup lang="ts">
import type { SeasonBattingStats } from '@/types/domain'
import { formatRate } from '@/utils/formatters'

defineProps<{
  rows: SeasonBattingStats[]
  linkPlayers?: boolean
}>()

const columns: Array<{ key: keyof SeasonBattingStats; label: string; rate?: boolean }> = [
  { key: 'games', label: 'G' },
  { key: 'plate_appearances', label: 'PA' },
  { key: 'at_bats', label: 'AB' },
  { key: 'hits', label: 'H' },
  { key: 'doubles', label: '2B' },
  { key: 'triples', label: '3B' },
  { key: 'home_runs', label: 'HR' },
  { key: 'runs', label: 'R' },
  { key: 'rbi', label: 'RBI' },
  { key: 'walks', label: 'BB' },
  { key: 'strikeouts', label: 'K' },
  { key: 'batting_average', label: 'AVG', rate: true },
  { key: 'on_base_percentage', label: 'OBP', rate: true },
  { key: 'slugging_percentage', label: 'SLG', rate: true },
  { key: 'ops', label: 'OPS', rate: true },
  { key: 'singles', label: '1B' },
  { key: 'hit_by_pitch', label: 'HBP' },
  { key: 'sacrifice_flies', label: 'SF' },
  { key: 'fielders_choice', label: 'FC' },
  { key: 'reached_on_error', label: 'ROE' },
  { key: 'total_bases', label: 'TB' },
]
</script>

<template>
  <div class="table-frame surface-border">
    <v-table class="stats-table" density="compact">
      <thead>
        <tr>
          <th class="player-column">Player</th>
          <th v-for="column in columns" :key="column.key" class="text-end">
            {{ column.label }}
          </th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="row in rows" :key="`${row.season_id}-${row.player_id}`">
          <td class="player-column font-weight-bold">
            <RouterLink v-if="linkPlayers" :to="`/players/${row.player_id}`" class="player-link">
              {{ row.player_name }}
            </RouterLink>
            <span v-else>{{ row.player_name }}</span>
          </td>
          <td v-for="column in columns" :key="column.key" class="text-end stat-number">
            {{ column.rate ? formatRate(Number(row[column.key])) : row[column.key] }}
          </td>
        </tr>
      </tbody>
    </v-table>
  </div>
</template>

<style scoped>
.table-frame {
  overflow-x: auto;
  border-radius: 6px;
  background: rgb(var(--v-theme-surface));
}

.stats-table {
  min-width: 1180px;
}

.stats-table th {
  color: rgba(var(--v-theme-on-surface), 0.76);
  font-size: 0.66rem;
  font-weight: 800;
  letter-spacing: 0.05em;
}

.stats-table td {
  height: 38px;
  font-size: 0.78rem;
}

.player-column {
  position: sticky;
  left: 0;
  z-index: 1;
  min-width: 132px;
  background: rgb(var(--v-theme-surface));
  border-right: 1px solid rgba(var(--v-theme-on-surface), 0.1);
}

thead .player-column {
  z-index: 2;
  background: rgb(var(--v-theme-surface-variant));
}

.player-link {
  color: rgb(var(--v-theme-secondary));
}

.player-link:hover {
  text-decoration: underline;
}
</style>
