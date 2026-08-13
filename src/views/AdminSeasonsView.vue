<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'

import DataState from '@/components/DataState.vue'
import PageHeader from '@/components/PageHeader.vue'
import { useAsyncResource } from '@/composables/useAsyncResource'
import {
  archiveSeason,
  completeSeason,
  createSeason,
  fetchManagedLeagues,
  fetchManagedSeasons,
  reopenSeason,
} from '@/services/adminService'
import type { League, ManagedSeasonSummary } from '@/types/domain'
import { formatDate } from '@/utils/formatters'

const seasons = useAsyncResource<ManagedSeasonSummary[]>()
const leagues = ref<League[]>([])
const createDialog = ref(false)
const leagueId = ref('')
const seasonName = ref('')
const startDate = ref('')
const endDate = ref('')
const createLoading = ref(false)
const createError = ref('')
const pendingComplete = ref<ManagedSeasonSummary | null>(null)
const pendingDelete = ref<ManagedSeasonSummary | null>(null)
const actionLoading = ref('')
const actionMessage = ref('')
const actionError = ref('')

const currentSeasons = computed(() =>
  (seasons.data.value ?? []).filter((item) => item.season.active),
)
const pastSeasons = computed(() => (seasons.data.value ?? []).filter((item) => !item.season.active))
const canCreate = computed(() => {
  const nameLength = seasonName.value.trim().length
  const datesValid = !startDate.value || !endDate.value || endDate.value >= startDate.value
  return Boolean(leagueId.value && nameLength > 0 && nameLength <= 100 && datesValid)
})

function dateRange(item: ManagedSeasonSummary): string {
  const { start_date: start, end_date: end } = item.season
  if (!start && !end) return 'Dates not set'
  if (!end) return 'Starts ' + formatDate(start)
  if (!start) return 'Ends ' + formatDate(end)
  return formatDate(start) + ' – ' + formatDate(end)
}

async function loadSeasons(): Promise<void> {
  await seasons.load(async () => {
    const [seasonRows, leagueRows] = await Promise.all([
      fetchManagedSeasons(),
      fetchManagedLeagues(),
    ])
    leagues.value = leagueRows.filter((league) => league.active)
    return seasonRows
  })
}

function openCreateDialog(): void {
  leagueId.value = leagues.value.length === 1 ? (leagues.value[0]?.id ?? '') : ''
  seasonName.value = ''
  startDate.value = ''
  endDate.value = ''
  createError.value = ''
  createDialog.value = true
}

async function submitSeason(): Promise<void> {
  if (!canCreate.value) {
    createError.value =
      startDate.value && endDate.value && endDate.value < startDate.value
        ? 'The end date cannot be before the start date.'
        : 'Choose a league and enter a season name of 100 characters or fewer.'
    return
  }

  createLoading.value = true
  createError.value = ''
  actionMessage.value = ''
  actionError.value = ''
  const createdName = seasonName.value.trim()
  try {
    await createSeason(leagueId.value, createdName, startDate.value || null, endDate.value || null)
    createDialog.value = false
    actionMessage.value = createdName + ' was created with the league’s latest roster.'
    await loadSeasons()
  } catch (error) {
    createError.value = error instanceof Error ? error.message : 'The season was not created.'
  } finally {
    createLoading.value = false
  }
}

async function confirmComplete(): Promise<void> {
  if (!pendingComplete.value) return
  const item = pendingComplete.value
  actionLoading.value = 'complete:' + item.season.id
  actionMessage.value = ''
  actionError.value = ''
  try {
    await completeSeason(item.season.id)
    pendingComplete.value = null
    actionMessage.value =
      item.season.name + ' is now in Past seasons. Its stats remain in history and all-time totals.'
    await loadSeasons()
  } catch (error) {
    actionError.value = error instanceof Error ? error.message : 'The season was not completed.'
  } finally {
    actionLoading.value = ''
  }
}

async function runReopen(item: ManagedSeasonSummary): Promise<void> {
  actionLoading.value = 'reopen:' + item.season.id
  actionMessage.value = ''
  actionError.value = ''
  try {
    await reopenSeason(item.season.id)
    actionMessage.value = item.season.name + ' is current again and can be used for new games.'
    await loadSeasons()
  } catch (error) {
    actionError.value = error instanceof Error ? error.message : 'The season was not reopened.'
  } finally {
    actionLoading.value = ''
  }
}

async function confirmDelete(): Promise<void> {
  if (!pendingDelete.value) return
  const item = pendingDelete.value
  actionLoading.value = 'delete:' + item.season.id
  actionMessage.value = ''
  actionError.value = ''
  try {
    await archiveSeason(item.season.id)
    pendingDelete.value = null
    actionMessage.value = item.season.name + ' was deleted. You can restore it from Archived.'
    await loadSeasons()
  } catch (error) {
    actionError.value = error instanceof Error ? error.message : 'The season was not deleted.'
  } finally {
    actionLoading.value = ''
  }
}

onMounted(loadSeasons)
</script>

<template>
  <main class="page-shell management-shell">
    <PageHeader
      back-to="/admin"
      title="Seasons"
      description="Create current seasons and keep completed seasons as league history."
    >
      <div class="mt-4">
        <v-btn
          color="primary"
          prepend-icon="mdi-plus"
          :disabled="leagues.length === 0"
          @click="openCreateDialog"
        >
          New season
        </v-btn>
      </div>
    </PageHeader>

    <v-alert v-if="!seasons.loading.value && leagues.length === 0" class="mb-4" variant="tonal">
      Create an active league before adding a season.
    </v-alert>
    <v-alert v-if="actionMessage" class="mb-4" color="success" closable variant="tonal">
      {{ actionMessage }}
    </v-alert>
    <v-alert v-if="actionError" class="mb-4" color="error" closable variant="tonal">
      {{ actionError }}
    </v-alert>

    <DataState
      :empty="seasons.data.value?.length === 0"
      empty-title="No seasons to manage."
      :error="seasons.error.value"
      :loading="seasons.loading.value"
      @retry="loadSeasons"
    >
      <section v-if="currentSeasons.length" aria-labelledby="current-seasons-heading">
        <h2 id="current-seasons-heading" class="section-title">Current</h2>
        <div class="management-list">
          <article v-for="item in currentSeasons" :key="item.season.id" class="management-row">
            <div class="row-copy">
              <h3>{{ item.season.name }}</h3>
              <p>{{ item.league.name }} · {{ dateRange(item) }}</p>
            </div>
            <div class="row-actions">
              <v-btn
                :to="`/admin/rosters?league=${item.league.id}&season=${item.season.id}`"
                size="small"
                variant="outlined"
              >
                Roster
              </v-btn>
              <v-btn
                color="primary"
                size="small"
                variant="outlined"
                @click="pendingComplete = item"
              >
                Complete
              </v-btn>
              <v-btn color="error" size="small" variant="outlined" @click="pendingDelete = item">
                Delete
              </v-btn>
            </div>
          </article>
        </div>
      </section>

      <section
        v-if="pastSeasons.length"
        class="past-section"
        aria-labelledby="past-seasons-heading"
      >
        <h2 id="past-seasons-heading" class="section-title">Past</h2>
        <div class="management-list">
          <article v-for="item in pastSeasons" :key="item.season.id" class="management-row">
            <div class="row-copy">
              <h3>{{ item.season.name }}</h3>
              <p>{{ item.league.name }} · {{ dateRange(item) }} · Completed</p>
            </div>
            <div class="row-actions">
              <v-btn
                size="small"
                variant="outlined"
                :loading="actionLoading === 'reopen:' + item.season.id"
                @click="runReopen(item)"
              >
                Reopen
              </v-btn>
              <v-btn color="error" size="small" variant="outlined" @click="pendingDelete = item">
                Delete
              </v-btn>
            </div>
          </article>
        </div>
      </section>
    </DataState>

    <v-dialog
      v-model="createDialog"
      max-width="520"
      :persistent="createLoading"
      @update:model-value="!$event && (createError = '')"
    >
      <v-card>
        <form @submit.prevent="submitSeason">
          <v-card-title>New season</v-card-title>
          <v-card-text>
            <v-alert v-if="createError" class="mb-4" color="error" variant="tonal">
              {{ createError }}
            </v-alert>
            <v-select
              v-model="leagueId"
              :items="leagues"
              item-title="name"
              item-value="id"
              label="League"
            />
            <v-text-field
              v-model="seasonName"
              autofocus
              counter="100"
              label="Season name"
              maxlength="100"
              placeholder="Fall 2026"
            />
            <div class="date-fields">
              <v-text-field v-model="startDate" label="Start date" type="date" />
              <v-text-field v-model="endDate" label="End date" type="date" />
            </div>
            <p class="form-note">
              The latest roster from this league will be copied into the new season.
            </p>
          </v-card-text>
          <v-card-actions>
            <v-spacer />
            <v-btn :disabled="createLoading" variant="text" @click="createDialog = false">
              Cancel
            </v-btn>
            <v-btn color="primary" :disabled="!canCreate" :loading="createLoading" type="submit">
              Create season
            </v-btn>
          </v-card-actions>
        </form>
      </v-card>
    </v-dialog>

    <v-dialog
      :model-value="Boolean(pendingComplete)"
      max-width="500"
      @update:model-value="!$event && !actionLoading && (pendingComplete = null)"
    >
      <v-card>
        <v-card-title>Complete this season?</v-card-title>
        <v-card-text>
          It will move to Past seasons and stop appearing when recording a new game. Its games and
          stats will remain visible and continue counting toward league and all-time totals.
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn :disabled="Boolean(actionLoading)" variant="text" @click="pendingComplete = null">
            Cancel
          </v-btn>
          <v-btn color="primary" :loading="Boolean(actionLoading)" @click="confirmComplete">
            Complete season
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-dialog
      :model-value="Boolean(pendingDelete)"
      max-width="500"
      @update:model-value="!$event && !actionLoading && (pendingDelete = null)"
    >
      <v-card>
        <v-card-title>Delete this season?</v-card-title>
        <v-card-text>
          The season, its games, and its stats will be hidden. Nothing is permanently erased, and
          you can restore it later from Archived.
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn :disabled="Boolean(actionLoading)" variant="text" @click="pendingDelete = null">
            Cancel
          </v-btn>
          <v-btn color="error" :loading="Boolean(actionLoading)" @click="confirmDelete">
            Delete season
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </main>
</template>

<style scoped>
.management-shell {
  max-width: 900px;
}
.past-section {
  margin-top: 30px;
}
.management-list {
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.16);
}
.management-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 18px;
  padding: 16px 0;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.16);
}
.row-copy {
  min-width: 0;
}
.row-copy h3 {
  margin: 0;
  color: rgb(var(--v-theme-on-surface));
  font-size: 1rem;
  font-weight: 750;
}
.row-copy p,
.form-note {
  margin: 4px 0 0;
  color: rgba(var(--v-theme-on-surface), 0.74);
  font-size: 0.84rem;
  line-height: 1.45;
}
.row-actions,
.date-fields {
  display: flex;
  gap: 8px;
}
.row-actions {
  flex-shrink: 0;
}
.date-fields > * {
  flex: 1;
}
@media (max-width: 599px) {
  .management-row {
    align-items: flex-start;
    flex-direction: column;
  }
  .row-actions {
    width: 100%;
  }
  .row-actions :deep(.v-btn) {
    flex: 1;
  }
  .date-fields {
    display: block;
  }
}
</style>
