import type { Session } from '@supabase/supabase-js'

import { isSupabaseConfigured, supabase } from '@/lib/supabase'

export async function getCurrentSession(): Promise<Session | null> {
  if (!isSupabaseConfigured) return null

  const { data, error } = await supabase.auth.getSession()
  if (error) throw error
  return data.session
}

export async function signInWithPassword(email: string, password: string): Promise<Session> {
  if (!isSupabaseConfigured) {
    throw new Error('Supabase is not configured. Add the public project values to .env.local.')
  }

  const { data, error } = await supabase.auth.signInWithPassword({ email, password })
  if (error) throw error
  if (!data.session) throw new Error('Supabase did not return a session.')
  return data.session
}

export async function signOut(): Promise<void> {
  const { error } = await supabase.auth.signOut()
  if (error) throw error
}

export async function fetchAdminAuthorization(userId: string): Promise<boolean> {
  const { data, error } = await supabase
    .from('admin_users')
    .select('user_id')
    .eq('user_id', userId)
    .maybeSingle()

  if (error) throw error
  return Boolean(data)
}
