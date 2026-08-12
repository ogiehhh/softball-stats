import type { Session } from '@supabase/supabase-js'
import { computed, ref } from 'vue'
import { defineStore } from 'pinia'

import { supabase } from '@/lib/supabase'
import {
  fetchAdminAuthorization,
  getCurrentSession,
  signInWithPassword,
  signOut as signOutFromSupabase,
} from '@/services/authService'

export const useAuthStore = defineStore('auth', () => {
  const session = ref<Session | null>(null)
  const authorized = ref(false)
  const initialized = ref(false)
  const loading = ref(false)
  const errorMessage = ref('')
  let listenerRegistered = false

  const isAuthenticated = computed(() => Boolean(session.value?.user))
  const isAdmin = computed(() => isAuthenticated.value && authorized.value)
  const email = computed(() => session.value?.user.email ?? '')

  async function refreshAuthorization(): Promise<void> {
    authorized.value = session.value?.user
      ? await fetchAdminAuthorization(session.value.user.id)
      : false
  }

  async function initialize(): Promise<void> {
    if (initialized.value) return

    try {
      session.value = await getCurrentSession()
      await refreshAuthorization()

      if (!listenerRegistered) {
        supabase.auth.onAuthStateChange((_event, nextSession) => {
          session.value = nextSession
          void refreshAuthorization()
        })
        listenerRegistered = true
      }
    } catch (error) {
      errorMessage.value = error instanceof Error ? error.message : 'Unable to restore session.'
    } finally {
      initialized.value = true
    }
  }

  async function login(emailAddress: string, password: string): Promise<boolean> {
    loading.value = true
    errorMessage.value = ''

    try {
      session.value = await signInWithPassword(emailAddress, password)
      await refreshAuthorization()

      if (!authorized.value) {
        await signOutFromSupabase()
        session.value = null
        errorMessage.value = 'This account is authenticated but is not enrolled as an admin.'
        return false
      }

      return true
    } catch (error) {
      errorMessage.value = error instanceof Error ? error.message : 'Unable to sign in.'
      return false
    } finally {
      loading.value = false
    }
  }

  async function logout(): Promise<void> {
    await signOutFromSupabase()
    session.value = null
    authorized.value = false
  }

  return {
    session,
    initialized,
    loading,
    errorMessage,
    isAuthenticated,
    isAdmin,
    email,
    initialize,
    login,
    logout,
  }
})
