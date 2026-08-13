<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'

import DataState from '@/components/DataState.vue'
import PageHeader from '@/components/PageHeader.vue'
import { useAsyncResource } from '@/composables/useAsyncResource'
import { archiveLeague, createLeague, fetchManagedLeagues } from '@/services/adminService'
import type { League } from '@/types/domain'

const leagues = useAsyncResource<League[]>()
const pendingDelete = ref<League | null>(null)
const createDialog = ref(false)
const leagueName = ref('')
const createLoading = ref(false)
const createError = ref('')
const actionLoading = ref(false)
const actionMessage = ref('')
const actionError = ref('')
const canCreate = computed(() => {
  const nameLength = leagueName.value.trim().length
  return nameLength > 0 && nameLength <= 100 && !createLoading.value
})

function loadLeagues(): Promise<void> {
  return leagues.load(fetchManagedLeagues)
}

function openCreateDialog(): void {
  leagueName.value = ''
  createError.value = ''
  createDialog.value = true
}

async function submitLeague(): Promise<void> {
  if (!canCreate.value) {
    createError.value = 'Enter a league name of 100 characters or fewer.'
    return
  }

  createLoading.value = true
  createError.value = ''
  actionMessage.value = ''
  actionError.value = ''
  const createdName = leagueName.value.trim()
  try {
    await createLeague(createdName)
    createDialog.value = false
    leagueName.value = ''
    actionMessage.value = `${createdName} was created.`
    await loadLeagues()
  } catch (error) {
    createError.value = error instanceof Error ? error.message : 'The league was not created.'
  } finally {
    createLoading.value = false
  }
}

async function confirmDelete(): Promise<void> {
  if (!pendingDelete.value) return
  actionLoading.value = true
  actionMessage.value = ''
  actionError.value = ''
  try {
    await archiveLeague(pendingDelete.value.id)
    actionMessage.value = `${pendingDelete.value.name} was deleted. You can restore it from Archived.`
    pendingDelete.value = null
    await loadLeagues()
  } catch (error) {
    actionError.value = error instanceof Error ? error.message : 'The league was not deleted.'
  } finally {
    actionLoading.value = false
  }
}

onMounted(loadLeagues)
</script>

<template>
  <main class="page-shell management-shell">
    <PageHeader
      back-to="/admin"
      title="Leagues"
      description="Manage active leagues and their history."
    >
      <div class="mt-4">
        <v-btn color="primary" prepend-icon="mdi-plus" @click="openCreateDialog">
          New league
        </v-btn>
      </div>
    </PageHeader>

    <v-alert v-if="actionMessage" class="mb-4" color="success" closable variant="tonal">{{
      actionMessage
    }}</v-alert>
    <v-alert v-if="actionError" class="mb-4" color="error" closable variant="tonal">{{
      actionError
    }}</v-alert>

    <DataState
      :empty="leagues.data.value?.length === 0"
      empty-title="No active leagues."
      :error="leagues.error.value"
      :loading="leagues.loading.value"
      @retry="loadLeagues"
    >
      <div class="management-list">
        <article v-for="league in leagues.data.value" :key="league.id" class="management-row">
          <div class="row-copy">
            <h2>{{ league.name }}</h2>
            <p>{{ league.active ? 'Active' : 'Inactive' }}</p>
          </div>
          <v-btn color="error" size="small" variant="outlined" @click="pendingDelete = league"
            >Delete</v-btn
          >
        </article>
      </div>
    </DataState>

    <v-dialog
      v-model="createDialog"
      max-width="460"
      :persistent="createLoading"
      @update:model-value="!$event && (createError = '')"
    >
      <v-card>
        <form @submit.prevent="submitLeague">
          <v-card-title>New league</v-card-title>
          <v-card-text>
            <v-alert v-if="createError" class="mb-4" color="error" variant="tonal">
              {{ createError }}
            </v-alert>
            <v-text-field
              v-model="leagueName"
              autofocus
              counter="100"
              label="League name"
              maxlength="100"
              placeholder="Monday Rec"
            />
          </v-card-text>
          <v-card-actions>
            <v-spacer />
            <v-btn :disabled="createLoading" variant="text" @click="createDialog = false">
              Cancel
            </v-btn>
            <v-btn color="primary" :disabled="!canCreate" :loading="createLoading" type="submit">
              Create league
            </v-btn>
          </v-card-actions>
        </form>
      </v-card>
    </v-dialog>

    <v-dialog
      :model-value="Boolean(pendingDelete)"
      max-width="460"
      @update:model-value="!$event && !actionLoading && (pendingDelete = null)"
    >
      <v-card>
        <v-card-title>Delete this league?</v-card-title>
        <v-card-text>
          The league, its seasons, games, and stats will be hidden. You can restore everything
          later.
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn :disabled="actionLoading" variant="text" @click="pendingDelete = null"
            >Cancel</v-btn
          >
          <v-btn color="error" :loading="actionLoading" @click="confirmDelete">Delete league</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </main>
</template>

<style scoped>
.management-shell {
  max-width: 900px;
}
.management-list {
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.16);
}
.management-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 18px;
  padding: 18px 0;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.16);
}
.row-copy h2 {
  margin: 0;
  color: rgb(var(--v-theme-on-surface));
  font-size: 1.05rem;
  font-weight: 750;
}
.row-copy p {
  margin: 4px 0 0;
  color: rgba(var(--v-theme-on-surface), 0.74);
  font-size: 0.84rem;
}
</style>
