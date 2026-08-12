# Softball Stats

A mobile-first Vue application for live offensive softball scoring plus public player and season batting statistics, with scoring access restricted through Supabase Auth and RLS.

## Local setup

1. Install dependencies: `npm install`
2. Copy `.env.example` to `.env.local` and use the Supabase project URL and publishable key.
3. Start the app: `npm run dev`

The connected development project already has the schema and baseline roster. To rebuild a local Supabase stack from source, run `npx supabase start` followed by `npx supabase db reset` (Docker is required). The seed intentionally creates no games or statistics.

## Validation

Run `npm run lint`, `npm run typecheck`, `npm test`, `npm run format:check`, and `npm run build` before handing off changes.

Database behavior is covered by rollback-only connected fixtures in `supabase/tests/database`. The live-scoring fixture exercises recording, complete runner movement, inning transitions, scoring, undo, completion, stale-state rejection, and authorization without leaving test games behind.

See `docs/PRODUCT_SPEC.md` for product scope and `docs/DATABASE.md` for schema, security, statistics, admin enrollment, and deployment setup.
