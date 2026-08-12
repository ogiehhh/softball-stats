<script setup lang="ts">
import { onMounted } from 'vue'

import DataState from '@/components/DataState.vue'
import { useAsyncResource } from '@/composables/useAsyncResource'
import { fetchLeagues, fetchSeasonsForLeague } from '@/services/dataService'
import type { League, Season } from '@/types/domain'

interface LeagueDirectoryItem {
  league: League
  seasons: Season[]
}

const directory = useAsyncResource<LeagueDirectoryItem[]>()

function loadLeagues(): Promise<void> {
  return directory.load(async () => {
    const leagues = await fetchLeagues()
    return Promise.all(
      leagues.map(async (league) => ({
        league,
        seasons: await fetchSeasonsForLeague(league.id),
      })),
    )
  })
}

onMounted(loadLeagues)
</script>

<template>
  <main class="page-shell home-shell">
    <h1>Softball Stats</h1>

    <section aria-labelledby="leagues-heading" class="mt-7">
      <h2 id="leagues-heading">Leagues</h2>

      <DataState
        :empty="directory.data.value?.length === 0"
        empty-title="No leagues."
        :error="directory.error.value"
        :loading="directory.loading.value"
        @retry="loadLeagues"
      >
        <div class="league-list">
          <RouterLink
            v-for="item in directory.data.value"
            :key="item.league.id"
            class="league-row"
            :to="`/leagues/${item.league.slug}`"
          >
            <span>
              <strong>{{ item.league.name }}</strong>
              <small v-if="item.seasons.length">
                {{ item.seasons.map((season) => season.name).join(' · ') }}
              </small>
              <small v-else>No seasons</small>
            </span>
            <v-icon icon="mdi-chevron-right" size="20" />
          </RouterLink>
        </div>
      </DataState>
    </section>
  </main>
</template>

<style scoped>
.home-shell {
  max-width: 760px;
}

h1 {
  margin: 0;
  color: rgb(var(--v-theme-on-background));
  font-size: clamp(1.9rem, 8vw, 2.6rem);
  font-weight: 820;
  letter-spacing: -0.04em;
}

h2 {
  margin: 0 0 8px;
  color: rgba(var(--v-theme-on-background), 0.74);
  font-size: 0.75rem;
  font-weight: 750;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.league-list {
  border-top: 1px solid rgba(var(--v-theme-on-background), 0.16);
}

.league-row {
  display: flex;
  min-height: 72px;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  border-bottom: 1px solid rgba(var(--v-theme-on-background), 0.16);
}

.league-row > span {
  display: flex;
  min-width: 0;
  flex-direction: column;
}

.league-row strong {
  color: rgb(var(--v-theme-on-background));
  font-size: 1.05rem;
}

.league-row small {
  margin-top: 2px;
  color: rgba(var(--v-theme-on-background), 0.74);
}

.league-row:hover strong,
.league-row:focus-visible strong {
  color: rgb(var(--v-theme-primary));
}
</style>
