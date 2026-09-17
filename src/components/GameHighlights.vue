<script setup lang="ts">
import { ref, watch } from 'vue'
import type { Game } from '@/types/domain'
import { fetchGameHighlights } from '@/services/dataService'
import type { GameHighlight } from '@/utils/gameHighlights'
import { formatDate } from '@/utils/formatters'

const props = defineProps<{ game: Game }>()
const open = ref(false)
const loading = ref(false)
const error = ref(false)
const highlights = ref<GameHighlight[]>([])
let request = 0

async function load() {
  const current = ++request
  highlights.value = []
  error.value = false
  open.value = false
  loading.value = props.game.status === 'completed'
  if (!loading.value) return
  try {
    const result = await fetchGameHighlights(props.game.id)
    if (current === request) highlights.value = result
  } catch {
    if (current === request) error.value = true
  } finally {
    if (current === request) loading.value = false
  }
}
watch(() => [props.game.id, props.game.status, props.game.updated_at], load, { immediate: true })
</script>

<template>
  <div class="game-highlights">
    <template v-if="game.status === 'completed'">
      <span v-if="loading" class="muted" role="status">Finding MVP…</span>
      <template v-else-if="error">
        <span class="muted">Highlights unavailable</span>
        <v-btn size="small" variant="text" @click="load">Retry</v-btn>
      </template>
      <template v-else-if="highlights.length">
        <span class="mvp">MVP: {{ highlights[0]?.player_name }}</span>
        <v-btn
          size="small"
          variant="outlined"
          color="primary"
          :aria-label="`Highlights vs. ${game.opponent} on ${formatDate(game.played_at)}`"
          @click="open = true"
          >Highlights</v-btn
        >
      </template>
      <span v-else class="muted">No recorded highlights</span>
    </template>
    <v-dialog v-model="open" max-width="520" :aria-labelledby="`game-highlights-${game.id}`">
      <v-card>
        <v-card-title :id="`game-highlights-${game.id}`">Game highlights</v-card-title>
        <v-card-text>
          <p class="muted">vs. {{ game.opponent }} · {{ formatDate(game.played_at) }}</p>
          <ol class="highlight-list">
            <li v-for="(highlight, index) in highlights" :key="highlight.player_id">
              <strong>{{ index === 0 ? 'MVP: ' : '' }}{{ highlight.player_name }}</strong>
              <p>{{ highlight.summary }}</p>
            </li>
          </ol>
          <p class="muted ranking-note">
            Ranked by total bases + walks + hit by pitches + runs + RBIs. Ties use OPS, then player
            name.
          </p>
        </v-card-text>
        <v-card-actions><v-spacer /><v-btn @click="open = false">Close</v-btn></v-card-actions>
      </v-card>
    </v-dialog>
  </div>
</template>

<style scoped>
.game-highlights {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 10px;
  flex-wrap: wrap;
}
.mvp {
  color: rgb(var(--v-theme-primary));
  font-size: 0.8rem;
  font-weight: 700;
}
.muted {
  color: rgba(var(--v-theme-on-surface), 0.7);
  font-size: 0.78rem;
}
.highlight-list {
  padding-left: 22px;
  margin: 20px 0;
}
.highlight-list li {
  padding: 10px 0;
}
.highlight-list p {
  margin-top: 5px;
  font-size: 0.9rem;
}
.ranking-note {
  line-height: 1.5;
}
@media (max-width: 599px) {
  .game-highlights {
    justify-content: flex-start;
  }
}
</style>
