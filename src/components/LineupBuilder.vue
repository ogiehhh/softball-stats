<script setup lang="ts">
import { computed } from 'vue'

import type { Player } from '@/types/domain'
import { addPlayerToLineup, moveLineupPlayer, removePlayerFromLineup } from '@/utils/lineup'

const props = defineProps<{
  roster: Player[]
  modelValue: Player[]
  disabled?: boolean
}>()

const emit = defineEmits<{
  'update:modelValue': [players: Player[]]
}>()

const availablePlayers = computed(() => {
  const selectedIds = new Set(props.modelValue.map((player) => player.id))
  return props.roster.filter((player) => !selectedIds.has(player.id))
})

function add(player: Player): void {
  emit('update:modelValue', addPlayerToLineup(props.modelValue, player))
}

function remove(playerId: string): void {
  emit('update:modelValue', removePlayerFromLineup(props.modelValue, playerId))
}

function move(index: number, direction: -1 | 1): void {
  emit('update:modelValue', moveLineupPlayer(props.modelValue, index, index + direction))
}
</script>

<template>
  <section>
    <div class="section-heading">
      <h2 class="section-title mb-0">Lineup</h2>
      <span>{{ modelValue.length }} selected</span>
    </div>

    <p v-if="modelValue.length === 0" class="empty-copy">Add at least one player.</p>

    <div class="lineup-list">
      <div v-for="(player, index) in modelValue" :key="player.id" class="lineup-row">
        <span class="order-number">{{ index + 1 }}</span>
        <strong>{{ player.display_name }}</strong>
        <div class="row-actions">
          <v-btn
            :aria-label="`Move ${player.display_name} up`"
            :disabled="disabled || index === 0"
            icon="mdi-chevron-up"
            size="x-small"
            variant="text"
            @click="move(index, -1)"
          />
          <v-btn
            :aria-label="`Move ${player.display_name} down`"
            :disabled="disabled || index === modelValue.length - 1"
            icon="mdi-chevron-down"
            size="x-small"
            variant="text"
            @click="move(index, 1)"
          />
          <v-btn
            :aria-label="`Remove ${player.display_name}`"
            color="error"
            :disabled="disabled"
            icon="mdi-close"
            size="x-small"
            variant="text"
            @click="remove(player.id)"
          />
        </div>
      </div>
    </div>

    <h3 class="roster-title">Available players</h3>
    <p v-if="roster.length === 0" class="empty-copy">No active players.</p>
    <p v-else-if="availablePlayers.length === 0" class="empty-copy">All players selected.</p>
    <div v-else class="available-list">
      <div v-for="player in availablePlayers" :key="player.id" class="available-row">
        <strong>{{ player.display_name }}</strong>
        <v-btn
          :aria-label="`Add ${player.display_name}`"
          color="primary"
          :disabled="disabled"
          size="small"
          variant="text"
          @click="add(player)"
        >
          Add
        </v-btn>
      </div>
    </div>
  </section>
</template>

<style scoped>
.lineup-list,
.available-list {
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.16);
}

.section-heading {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  margin-bottom: 10px;
}

.section-heading span,
.empty-copy {
  color: rgba(var(--v-theme-on-surface), 0.74);
  font-size: 0.82rem;
}

.empty-copy {
  margin: 10px 0 20px;
}

.lineup-row,
.available-row {
  display: flex;
  min-height: 48px;
  align-items: center;
  gap: 10px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.16);
}

.lineup-row strong,
.available-row strong {
  min-width: 0;
  flex: 1;
  font-size: 0.9rem;
}

.order-number {
  width: 22px;
  color: rgba(var(--v-theme-on-surface), 0.74);
  font-size: 0.8rem;
  text-align: center;
}

.row-actions {
  display: flex;
  margin-right: -8px;
}

.roster-title {
  margin: 24px 0 10px;
  color: rgba(var(--v-theme-on-surface), 0.74);
  font-size: 0.72rem;
  font-weight: 800;
  letter-spacing: 0.07em;
  text-transform: uppercase;
}
</style>
