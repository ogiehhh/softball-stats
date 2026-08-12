<script setup lang="ts">
import { onMounted } from 'vue'
import { useRouter } from 'vue-router'

import DataState from '@/components/DataState.vue'
import PageHeader from '@/components/PageHeader.vue'
import { useAsyncResource } from '@/composables/useAsyncResource'
import { fetchInProgressGames } from '@/services/gameService'
import { useAuthStore } from '@/stores/auth'
import { formatDate } from '@/utils/formatters'

const auth = useAuthStore()
const router = useRouter()
const games = useAsyncResource<Awaited<ReturnType<typeof fetchInProgressGames>>>()

function loadGames(): Promise<void> {
  return games.load(fetchInProgressGames)
}

async function logout(): Promise<void> {
  await auth.logout()
  await router.replace('/')
}

onMounted(loadGames)
</script>

<template>
  <main class="page-shell admin-shell">
    <PageHeader title="Admin">
      <div class="mt-4">
        <v-btn color="primary" to="/admin/games/new">Record New Game</v-btn>
      </div>
    </PageHeader>

    <section aria-labelledby="in-progress-heading">
      <div class="section-heading">
        <h2 id="in-progress-heading" class="section-title mb-0">In-progress games</h2>
        <span v-if="games.data.value" class="count">{{ games.data.value.length }}</span>
      </div>

      <DataState
        :empty="games.data.value?.length === 0"
        empty-title="No in-progress games."
        :error="games.error.value"
        :loading="games.loading.value"
        @retry="loadGames"
      >
        <div class="game-list">
          <article v-for="item in games.data.value" :key="item.game.id" class="game-row">
            <div class="game-copy">
              <h3>vs. {{ item.game.opponent }}</h3>
              <p>
                {{ item.league.name }} · {{ item.season.name }} ·
                {{ formatDate(item.game.played_at) }}
              </p>
              <p>
                Inning {{ item.state.inning }} · {{ item.state.outs }} outs · Batter #{{
                  item.state.next_batter_order
                }}
              </p>
            </div>
            <v-btn color="primary" :to="`/admin/games/${item.game.id}/score`">Resume</v-btn>
          </article>
        </div>
      </DataState>
    </section>

    <nav class="management-nav" aria-label="Admin management">
      <router-link to="/admin/games">
        <span><strong>Games</strong><small>Current and completed games</small></span>
        <v-icon icon="mdi-chevron-right" />
      </router-link>
      <router-link to="/admin/leagues">
        <span><strong>Leagues</strong><small>Active league records</small></span>
        <v-icon icon="mdi-chevron-right" />
      </router-link>
      <router-link to="/admin/archived">
        <span><strong>Archived</strong><small>Restore deleted games and leagues</small></span>
        <v-icon icon="mdi-chevron-right" />
      </router-link>
    </nav>

    <div class="account-row">
      <div>
        <span>Signed in as</span>
        <strong>{{ auth.email }}</strong>
      </div>
      <v-btn size="small" variant="text" @click="logout">Sign out</v-btn>
    </div>
  </main>
</template>

<style scoped>
.admin-shell {
  max-width: 880px;
}

.section-heading {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  margin-bottom: 12px;
}

.count {
  color: rgba(var(--v-theme-on-surface), 0.74);
  font-size: 0.85rem;
}

.game-list {
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.16);
}

.game-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 16px 0;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.16);
}

.game-copy {
  min-width: 0;
}

.game-copy h3 {
  color: rgb(var(--v-theme-on-surface));
  font-size: 1rem;
  font-weight: 750;
}

.game-copy p {
  margin: 3px 0 0;
  color: rgba(var(--v-theme-on-surface), 0.74);
  font-size: 0.82rem;
}

.management-nav {
  display: grid;
  margin-top: 32px;
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.16);
}

.management-nav a {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 15px 2px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.16);
  color: rgb(var(--v-theme-on-surface));
  text-decoration: none;
}

.management-nav a:hover,
.management-nav a:focus-visible {
  color: rgb(var(--v-theme-primary));
}

.management-nav span {
  display: flex;
  flex-direction: column;
}

.management-nav small {
  margin-top: 2px;
  color: rgba(var(--v-theme-on-surface), 0.72);
  font-size: 0.78rem;
}

.account-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  margin-top: 36px;
  padding-top: 16px;
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.16);
}

.account-row div {
  display: flex;
  min-width: 0;
  flex-direction: column;
  color: rgba(var(--v-theme-on-surface), 0.72);
  font-size: 0.75rem;
}

.account-row strong {
  overflow: hidden;
  color: rgb(var(--v-theme-on-surface));
  font-size: 0.85rem;
  text-overflow: ellipsis;
}

@media (max-width: 599px) {
  .game-row {
    align-items: flex-end;
  }
}
</style>
