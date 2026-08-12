<script setup lang="ts">
import { computed } from 'vue'
import { useDisplay } from 'vuetify'

import { useAuthStore } from '@/stores/auth'

const { mdAndUp } = useDisplay()
const auth = useAuthStore()

const navItems = [
  { title: 'Leagues', icon: 'mdi-format-list-bulleted', to: '/' },
  { title: 'Players', icon: 'mdi-account-multiple-outline', to: '/players' },
]

const adminDestination = computed(() => (auth.isAdmin ? '/admin' : '/admin/login'))
</script>

<template>
  <v-app>
    <v-app-bar border="b" color="surface" height="56" flat>
      <v-app-bar-title>
        <RouterLink class="brand-link" to="/">Softball Stats</RouterLink>
      </v-app-bar-title>

      <template v-if="mdAndUp">
        <v-btn v-for="item in navItems" :key="item.to" :to="item.to" variant="text">
          {{ item.title }}
        </v-btn>
        <v-btn :to="adminDestination" variant="text">Admin</v-btn>
      </template>
    </v-app-bar>

    <v-main>
      <RouterView />
    </v-main>

    <v-bottom-navigation v-if="!mdAndUp" color="primary" grow height="58">
      <v-btn v-for="item in navItems" :key="item.to" :to="item.to">
        <v-icon :icon="item.icon" size="20" />
        <span>{{ item.title }}</span>
      </v-btn>
      <v-btn :to="adminDestination">
        <v-icon icon="mdi-lock-outline" size="20" />
        <span>Admin</span>
      </v-btn>
    </v-bottom-navigation>
  </v-app>
</template>

<style scoped>
.brand-link {
  color: rgb(var(--v-theme-on-surface));
  font-size: 1rem;
  font-weight: 800;
  letter-spacing: -0.02em;
}
</style>
