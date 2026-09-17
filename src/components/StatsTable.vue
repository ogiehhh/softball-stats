<script setup lang="ts">
import { computed, ref, watch } from 'vue'

import type { SeasonBattingStats } from '@/types/domain'
import {
  formatStatistic,
  sortStatistics,
  simpleStatisticColumns,
  statisticColumns,
  statisticsToCsv,
  type StatisticSortKey,
} from '@/utils/statisticsTable'

const props = withDefaults(
  defineProps<{
    rows: SeasonBattingStats[]
    linkPlayers?: boolean
    downloadFilename?: string
  }>(),
  {
    downloadFilename: 'softball-batting-stats.csv',
  },
)

const sortKey = ref<StatisticSortKey>('ops')
const view = ref<'simple' | 'advanced'>('simple')
const visibleColumns = computed(() =>
  view.value === 'simple' ? simpleStatisticColumns : statisticColumns,
)
watch(view, () => {
  if (
    sortKey.value !== 'player_name' &&
    !visibleColumns.value.some((column) => column.key === sortKey.value)
  ) {
    sortKey.value = 'ops'
    sortDirection.value = 'desc'
  }
})
const sortDirection = ref<'asc' | 'desc'>('desc')
const sortedRows = computed(() => sortStatistics(props.rows, sortKey.value, sortDirection.value))

function changeSort(key: StatisticSortKey): void {
  if (sortKey.value === key) {
    sortDirection.value = sortDirection.value === 'asc' ? 'desc' : 'asc'
    return
  }
  sortKey.value = key
  sortDirection.value = key === 'player_name' ? 'asc' : 'desc'
}

function sortIcon(key: StatisticSortKey): string {
  if (sortKey.value !== key) return 'mdi-unfold-more-horizontal'
  return sortDirection.value === 'asc' ? 'mdi-arrow-up' : 'mdi-arrow-down'
}

function ariaSort(key: StatisticSortKey): 'ascending' | 'descending' | 'none' {
  if (sortKey.value !== key) return 'none'
  return sortDirection.value === 'asc' ? 'ascending' : 'descending'
}

function downloadCsv(): void {
  const blob = new Blob(['\ufeff', statisticsToCsv(sortedRows.value, visibleColumns.value)], {
    type: 'text/csv;charset=utf-8',
  })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = props.downloadFilename
  link.style.display = 'none'
  document.body.append(link)
  link.click()
  link.remove()
  window.setTimeout(() => URL.revokeObjectURL(url), 0)
}
</script>

<template>
  <div>
    <div class="table-tools">
      <v-btn-toggle v-model="view" mandatory divided density="compact" aria-label="Statistics view">
        <v-btn value="simple" :aria-pressed="view === 'simple'">Simple</v-btn>
        <v-btn value="advanced" :aria-pressed="view === 'advanced'">Advanced</v-btn>
      </v-btn-toggle>
      <span>Click a column heading to sort.</span>
      <v-btn
        color="primary"
        prepend-icon="mdi-download"
        size="small"
        variant="outlined"
        @click="downloadCsv"
      >
        Download CSV
      </v-btn>
    </div>

    <div class="table-frame surface-border">
      <v-table
        class="stats-table"
        :class="{ 'stats-table-advanced': view === 'advanced' }"
        density="compact"
      >
        <thead>
          <tr>
            <th class="player-column" :aria-sort="ariaSort('player_name')">
              <button type="button" @click="changeSort('player_name')">
                Player
                <v-icon :icon="sortIcon('player_name')" size="14" />
              </button>
            </th>
            <th
              v-for="column in visibleColumns"
              :key="column.key"
              :aria-sort="ariaSort(column.key)"
              class="text-end"
            >
              <button type="button" @click="changeSort(column.key)">
                {{ column.label }}
                <v-icon :icon="sortIcon(column.key)" size="14" />
              </button>
            </th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="row in sortedRows" :key="`${row.season_id}-${row.player_id}`">
            <td class="player-column font-weight-bold">
              <RouterLink v-if="linkPlayers" :to="`/players/${row.player_id}`" class="player-link">
                {{ row.player_name }}
              </RouterLink>
              <span v-else>{{ row.player_name }}</span>
            </td>
            <td v-for="column in visibleColumns" :key="column.key" class="text-end stat-number">
              {{ formatStatistic(row, column) }}
            </td>
          </tr>
        </tbody>
      </v-table>
    </div>
  </div>
</template>

<style scoped>
.table-tools {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  flex-wrap: wrap;
  margin-bottom: 8px;
}
.table-tools span {
  color: rgba(var(--v-theme-on-background), 0.68);
  font-size: 0.75rem;
}
.table-frame {
  overflow-x: auto;
  border-radius: 6px;
  background: rgb(var(--v-theme-surface));
}
.stats-table {
  width: 100%;
}
.stats-table:not(.stats-table-advanced) :deep(table) {
  table-layout: fixed;
}
.stats-table:not(.stats-table-advanced) .player-column {
  width: 32%;
  min-width: 0;
}
.stats-table:not(.stats-table-advanced) td {
  padding-inline: 6px;
}
.stats-table:not(.stats-table-advanced) th button {
  padding-inline: 3px;
  gap: 0;
}
.stats-table-advanced {
  min-width: 1260px;
}
.stats-table th {
  padding: 0;
  color: rgba(var(--v-theme-on-surface), 0.76);
  font-size: 0.66rem;
  font-weight: 800;
  letter-spacing: 0.05em;
}
.stats-table th button {
  display: inline-flex;
  width: 100%;
  min-height: 38px;
  align-items: center;
  justify-content: flex-end;
  gap: 2px;
  padding: 0 8px;
  color: inherit;
  font: inherit;
  letter-spacing: inherit;
}
.stats-table th button:hover,
.stats-table th button:focus-visible {
  color: rgb(var(--v-theme-primary));
}
.stats-table td {
  height: 38px;
  font-size: 0.78rem;
}
.player-column {
  position: sticky;
  left: 0;
  z-index: 1;
  min-width: 150px;
  background: rgb(var(--v-theme-surface));
  border-right: 1px solid rgba(var(--v-theme-on-surface), 0.1);
}
thead .player-column {
  z-index: 2;
  background: rgb(var(--v-theme-surface-variant));
}
thead .player-column button {
  justify-content: flex-start;
}
.player-link {
  color: rgb(var(--v-theme-secondary));
}
.player-link:hover {
  text-decoration: underline;
}
@media (max-width: 599px) {
  .table-tools {
    align-items: flex-start;
    flex-direction: column;
  }
}
</style>
