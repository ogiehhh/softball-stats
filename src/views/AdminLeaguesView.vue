<script setup lang="ts">
import { onMounted, ref } from 'vue'

import DataState from '@/components/DataState.vue'
import PageHeader from '@/components/PageHeader.vue'
import { useAsyncResource } from '@/composables/useAsyncResource'
import { archiveLeague, fetchManagedLeagues } from '@/services/adminService'
import type { League } from '@/types/domain'

const leagues = useAsyncResource<League[]>()
const pendingDelete = ref<League | null>(null)
const actionLoading = ref(false)
const actionMessage = ref('')
const actionError = ref('')

function loadLeagues(): Promise<void> {
  return leagues.load(fetchManagedLeagues)
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
    />

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
