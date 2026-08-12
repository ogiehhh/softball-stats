<script setup lang="ts">
import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()
const route = useRoute()
const router = useRouter()

const email = ref('')
const password = ref('')
const showPassword = ref(false)

async function submit(): Promise<void> {
  const success = await auth.login(email.value.trim(), password.value)
  if (success) {
    const destination = typeof route.query.redirect === 'string' ? route.query.redirect : '/admin'
    await router.replace(destination)
  }
}
</script>

<template>
  <main class="login-shell">
    <section class="login-form">
      <h1>Admin Login</h1>

      <v-alert v-if="auth.errorMessage" class="mt-4" color="error" variant="tonal">
        {{ auth.errorMessage }}
      </v-alert>

      <v-form class="mt-5" @submit.prevent="submit">
        <v-text-field
          v-model="email"
          autocomplete="username"
          label="Email"
          required
          type="email"
          variant="outlined"
        />
        <v-text-field
          v-model="password"
          :append-inner-icon="showPassword ? 'mdi-eye-off-outline' : 'mdi-eye-outline'"
          autocomplete="current-password"
          label="Password"
          required
          :type="showPassword ? 'text' : 'password'"
          variant="outlined"
          @click:append-inner="showPassword = !showPassword"
        />
        <v-btn block color="primary" :loading="auth.loading" size="large" type="submit">
          Sign in
        </v-btn>
      </v-form>

      <v-btn class="mt-3" size="small" to="/" variant="text">Back</v-btn>
    </section>
  </main>
</template>

<style scoped>
.login-shell {
  display: grid;
  min-height: calc(100vh - 56px);
  padding: 24px 16px 100px;
  place-items: center;
}

.login-form {
  width: min(400px, 100%);
  padding: 24px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.16);
  border-radius: 12px;
  background: rgb(var(--v-theme-surface));
}

h1 {
  color: rgb(var(--v-theme-on-surface));
  font-size: 1.7rem;
  letter-spacing: -0.03em;
}
</style>
