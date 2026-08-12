<script setup lang="ts">
import { onMounted, watch } from 'vue'

import DataState from '@/components/DataState.vue'
import PageHeader from '@/components/PageHeader.vue'
import { useAsyncResource } from '@/composables/useAsyncResource'
import { fetchLeagueBySlug, fetchSeasonsForLeague } from '@/services/dataService'
import type { League, Season } from '@/types/domain'
import { formatDate } from '@/utils/formatters'

const props = defineProps<{ leagueSlug: string }>()

interface LeaguePageData {
  league: League
  seasons: Season[]
}

const page = useAsyncResource<LeaguePageData>()

function load(): Promise<void> {
  return page.load(async () => {
    const league = await fetchLeagueBySlug(props.leagueSlug)
    const seasons = await fetchSeasonsForLeague(league.id)
    return { league, seasons }
  })
}

onMounted(load)
watch(() => props.leagueSlug, load)
</script>

<template>
  <main class="page-shell compact-shell">
    <DataState :error="page.error.value" :loading="page.loading.value" @retry="load">
      <template v-if="page.data.value">
        <PageHeader back-to="/" :title="page.data.value.league.name" />

        <section aria-labelledby="seasons-heading">
          <h2 id="seasons-heading" class="section-label">Seasons</h2>
          <DataState
            :empty="page.data.value.seasons.length === 0"
            empty-title="No seasons."
            :loading="false"
          >
            <div class="season-list">
              <RouterLink
                v-for="season in page.data.value.seasons"
                :key="season.id"
                class="season-row"
                :to="`/seasons/${season.id}`"
              >
                <span>
                  <strong>{{ season.name }}</strong>
                  <small>
                    {{ formatDate(season.start_date) }}
                    <template v-if="season.end_date"> – {{ formatDate(season.end_date) }}</template>
                  </small>
                </span>
                <span class="season-status">
                  <small v-if="season.active">Active</small>
                  <v-icon icon="mdi-chevron-right" size="20" />
                </span>
              </RouterLink>
            </div>
          </DataState>
        </section>
      </template>
    </DataState>
  </main>
</template>

<style scoped>
.compact-shell {
  max-width: 760px;
}

.section-label {
  margin: 0 0 8px;
  color: rgba(var(--v-theme-on-background), 0.74);
  font-size: 0.75rem;
  font-weight: 750;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.season-list {
  border-top: 1px solid rgba(var(--v-theme-on-background), 0.16);
}

.season-row {
  display: flex;
  min-height: 72px;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  border-bottom: 1px solid rgba(var(--v-theme-on-background), 0.16);
}

.season-row > span:first-child {
  display: flex;
  flex-direction: column;
}

.season-row strong {
  color: rgb(var(--v-theme-on-background));
  font-size: 1rem;
}

.season-row small {
  margin-top: 2px;
  color: rgba(var(--v-theme-on-background), 0.74);
}

.season-status {
  display: flex;
  align-items: center;
  gap: 10px;
}

.season-status small {
  color: rgb(var(--v-theme-success));
}
</style>
