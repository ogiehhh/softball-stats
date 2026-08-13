<script setup lang="ts">
import { computed, ref, watch } from 'vue'

import { addExistingPlayerToSeason, createPlayerForSeason } from '@/services/adminService'
import { fetchPlayer, fetchPlayers } from '@/services/dataService'
import type { Player } from '@/types/domain'

const props = defineProps<{
  modelValue: boolean
  seasonId: string
  rosterPlayerIds: string[]
}>()

const emit = defineEmits<{
  'update:modelValue': [open: boolean]
  saved: [player: Player]
}>()

const mode = ref<'existing' | 'new'>('existing')
const allPlayers = ref<Player[]>([])
const playerId = ref('')
const playerName = ref('')
const loadingPlayers = ref(false)
const saving = ref(false)
const errorMessage = ref('')

const availablePlayers = computed(() => {
  const rosterIds = new Set(props.rosterPlayerIds)
  return allPlayers.value.filter((player) => !rosterIds.has(player.id))
})

const canSave = computed(
  () =>
    !saving.value &&
    Boolean(
      props.seasonId &&
      (mode.value === 'existing' ? playerId.value : playerName.value.trim().length > 0),
    ),
)

function reset(): void {
  mode.value = 'existing'
  playerId.value = ''
  playerName.value = ''
  errorMessage.value = ''
}

function close(): void {
  if (!saving.value) emit('update:modelValue', false)
}

async function loadPlayers(): Promise<void> {
  loadingPlayers.value = true
  errorMessage.value = ''
  try {
    allPlayers.value = await fetchPlayers()
    if (availablePlayers.value.length === 0) mode.value = 'new'
  } catch (error) {
    errorMessage.value = error instanceof Error ? error.message : 'Unable to load players.'
  } finally {
    loadingPlayers.value = false
  }
}

async function save(): Promise<void> {
  if (!canSave.value) return
  saving.value = true
  errorMessage.value = ''
  try {
    const savedPlayerId =
      mode.value === 'existing'
        ? playerId.value
        : await createPlayerForSeason(props.seasonId, playerName.value.trim())

    if (mode.value === 'existing') {
      await addExistingPlayerToSeason(props.seasonId, savedPlayerId)
    }

    const player = await fetchPlayer(savedPlayerId)
    emit('saved', player)
    emit('update:modelValue', false)
  } catch (error) {
    errorMessage.value = error instanceof Error ? error.message : 'The player was not added.'
  } finally {
    saving.value = false
  }
}

watch(
  () => props.modelValue,
  (open) => {
    if (!open) return
    reset()
    void loadPlayers()
  },
)
</script>

<template>
  <v-dialog
    :model-value="modelValue"
    max-width="540"
    :persistent="saving"
    @update:model-value="!$event && close()"
  >
    <v-card>
      <form @submit.prevent="save">
        <v-card-title>Add player to roster</v-card-title>
        <v-card-text>
          <p class="dialog-copy">
            Reuse the same player record if they have played in another league so their all-time
            statistics stay together.
          </p>

          <v-btn-toggle v-model="mode" class="mode-toggle" color="primary" mandatory>
            <v-btn value="existing">Played in another league</v-btn>
            <v-btn value="new">New player</v-btn>
          </v-btn-toggle>

          <v-alert v-if="errorMessage" class="mb-4" color="error" variant="tonal">
            {{ errorMessage }}
          </v-alert>

          <v-autocomplete
            v-if="mode === 'existing'"
            v-model="playerId"
            :items="availablePlayers"
            item-title="display_name"
            item-value="id"
            label="Player"
            :loading="loadingPlayers"
            no-data-text="No other active players found"
            variant="outlined"
          />
          <v-text-field
            v-else
            v-model="playerName"
            autofocus
            counter="100"
            label="Player name"
            maxlength="100"
            placeholder="First and last name"
            variant="outlined"
          />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn :disabled="saving" variant="text" @click="close">Cancel</v-btn>
          <v-btn color="primary" :disabled="!canSave" :loading="saving" type="submit">
            Add player
          </v-btn>
        </v-card-actions>
      </form>
    </v-card>
  </v-dialog>
</template>

<style scoped>
.dialog-copy {
  margin: 0 0 16px;
  color: rgba(var(--v-theme-on-surface), 0.74);
  font-size: 0.86rem;
  line-height: 1.5;
}

.mode-toggle {
  display: grid;
  width: 100%;
  margin-bottom: 18px;
  grid-template-columns: 1fr 1fr;
}

.mode-toggle :deep(.v-btn) {
  min-height: 44px;
  white-space: normal;
}
</style>
