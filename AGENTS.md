# Softball Stats repository guide

## Purpose and stack

This is a mobile-first personal softball scorekeeping and public statistics app. It uses Vue 3 with Composition API and `<script setup lang="ts">`, Vite, TypeScript, Vue Router, Pinia, Vuetify, Supabase Postgres/Auth/JS, and Vercel.

## Commands

- `npm run dev` — local app
- `npm run lint` — ESLint
- `npm run typecheck` — Vue/TypeScript validation
- `npm test` — Vitest rules tests
- `npm run build` — typecheck plus production build
- `npm run format:check` — formatting check
- `npx supabase db reset` — rebuild a local Supabase database from migrations and seed

Before completing future changes, run lint, typecheck, applicable tests, and build.

## Architecture

- Views compose UI; reusable UI lives in `src/components`.
- Keep Supabase initialization only in `src/lib/supabase.ts`.
- Put domain queries/auth operations in `src/services`; do not scatter raw queries through components.
- Pinia stores durable client state such as auth. Composables hold reusable view behavior.
- Generated database types live in `src/types/database.generated.ts`; domain-facing types live in `src/types/domain.ts`.
- SQL migrations are source of truth under `supabase/migrations`; use `supabase migration new <snake_case_name>` and never rewrite an applied migration. Keep deterministic demo data in `supabase/seed.sql`.

## Security and quality rules

- Public visitors may read softball data. Only UUIDs explicitly enrolled in `public.admin_users` may write.
- Authentication alone is never authorization. Preserve RLS on every exposed table and `security_invoker` on exposed views.
- Never add public signup. Never expose a Supabase secret/service-role key; the browser may only receive the URL and publishable key via `VITE_*` environment variables.
- UI actions labeled Delete for leagues or games must call the archive RPCs. Normal queries must exclude archived games and archived league branches; never hard-delete this user data.
- Keep TypeScript strict: no unjustified `any`, validate nullable database values, and regenerate types after schema changes.
- Design for a phone first: clear touch targets, responsive layouts, horizontal handling for large stats tables, and accessible loading/error/empty states.

Product requirements are in `docs/PRODUCT_SPEC.md`; schema, statistics, resume strategy, and admin setup are in `docs/DATABASE.md`.
