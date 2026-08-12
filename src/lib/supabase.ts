import { createClient } from '@supabase/supabase-js'

import type { Database } from '@/types/database.generated'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL?.trim()
const supabasePublishableKey = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY?.trim()

export const isSupabaseConfigured = Boolean(supabaseUrl && supabasePublishableKey)

export const supabase = createClient<Database>(
  supabaseUrl || 'http://127.0.0.1:54321',
  supabasePublishableKey || 'missing-publishable-key',
  {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true,
    },
  },
)
