import { createRouter, createWebHistory } from 'vue-router'

import { useAuthStore } from '@/stores/auth'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  scrollBehavior: () => ({ top: 0 }),
  routes: [
    {
      path: '/',
      name: 'home',
      component: () => import('@/views/HomeView.vue'),
    },
    {
      path: '/leagues/:leagueSlug',
      name: 'league',
      component: () => import('@/views/LeagueView.vue'),
      props: true,
    },
    {
      path: '/seasons/:seasonId',
      name: 'season',
      component: () => import('@/views/SeasonView.vue'),
      props: true,
    },
    {
      path: '/players',
      name: 'players',
      component: () => import('@/views/PlayersView.vue'),
    },
    {
      path: '/players/:playerId',
      name: 'player',
      component: () => import('@/views/PlayerView.vue'),
      props: true,
    },
    {
      path: '/admin/login',
      name: 'admin-login',
      component: () => import('@/views/AdminLoginView.vue'),
    },
    {
      path: '/admin',
      name: 'admin',
      component: () => import('@/views/AdminDashboardView.vue'),
      meta: { requiresAdmin: true },
    },
    {
      path: '/admin/games/new',
      name: 'admin-new-game',
      component: () => import('@/views/AdminNewGameView.vue'),
      meta: { requiresAdmin: true },
    },
    {
      path: '/admin/games',
      name: 'admin-games',
      component: () => import('@/views/AdminGamesView.vue'),
      meta: { requiresAdmin: true },
    },
    {
      path: '/admin/leagues',
      name: 'admin-leagues',
      component: () => import('@/views/AdminLeaguesView.vue'),
      meta: { requiresAdmin: true },
    },
    {
      path: '/admin/archived',
      name: 'admin-archived',
      component: () => import('@/views/AdminArchivedView.vue'),
      meta: { requiresAdmin: true },
    },
    {
      path: '/admin/games/:gameId/score',
      name: 'admin-score-game',
      component: () => import('@/views/AdminScoreGameView.vue'),
      props: true,
      meta: { requiresAdmin: true },
    },
    {
      path: '/:pathMatch(.*)*',
      name: 'not-found',
      component: () => import('@/views/NotFoundView.vue'),
    },
  ],
})

router.beforeEach(async (to) => {
  const auth = useAuthStore()
  await auth.initialize()

  if (to.meta.requiresAdmin && !auth.isAdmin) {
    return {
      name: 'admin-login',
      query: { redirect: to.fullPath },
    }
  }

  if (to.name === 'admin-login' && auth.isAdmin) {
    return { name: 'admin' }
  }

  return true
})

export default router
