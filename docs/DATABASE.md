# Database design

The schema is defined by the ordered SQL files in `supabase/migrations`. The idempotent development seed creates only a baseline league, season, and roster; it never creates games or statistics.

## Relationships

```text
leagues 1 ── * seasons 1 ── * games 1 ── * plate_appearances
                   │             │                    │
                   │             ├── 1 game_states    └── * runner_advancements
                   │             └── * game_lineup
                   │                       │
                   └── * season_players ───┘
                              │
                              * players (global)
```

## Tables

- `players` — one global person. `display_name` is generated from first/last names.
- `leagues` — distinct team/league context with a URL-safe unique slug.
- `seasons` — league-specific season and optional date range, with separate completed and
  recoverably archived lifecycle metadata.
- `season_players` — composite-key roster membership; prevents duplicate membership.
- `games` — scheduled/draft, in-progress, or completed game with optional final score.
- `game_lineup` — fixed batting order. Composite foreign keys require lineup players to be on the season roster, and each player/order may appear once per game.
- `plate_appearances` — ordered source-of-truth batting events with inning, outs, result, and RBI. A composite foreign key requires the batter to be in the game's lineup.
- `runner_advancements` — normalized per-play runner movement from batter/first/second/third to first/second/third/home/out. `ending_base = 'home'` is the source of truth for runs.
- `game_states` — one mutable resume snapshot per game: inning, outs, next batting-order position, and occupied bases. Base occupants must be in that game's lineup.
- `admin_users` — explicit allowlist keyed to `auth.users`. Authenticated users are not admins merely because they have an account.

All primary identifiers are UUIDs. Update triggers maintain `updated_at` fields. Foreign keys use restrictive/cascading behavior chosen to protect global players and remove game-owned children together.

`leagues`, `seasons`, and `games` also carry nullable `archived_at` and `archived_by`
metadata. These columns implement recoverable deletion; archive actions do not remove or rewrite
descendant rows. Seasons additionally carry `completed_at` and `completed_by`; completion is a
historical state, not deletion.

## Recoverable archives

The admin UI labels the archive action as **Delete**, but the application never hard-deletes a
league, season, or game. Six authenticated, admin-only `SECURITY INVOKER` RPCs form the archive
write boundary:

- `archive_game` and `restore_game`
- `archive_season` and `restore_season`
- `archive_league` and `restore_league`

Archiving a game hides it from normal queries, in-progress lists, scoring, and statistics while preserving its lineup, events, runner movements, score, and exact resume snapshot. Restoring it clears only its archive metadata, so an in-progress game resumes at the same inning, outs, bases, and batter.

Archiving a season suppresses that season, its games, and its statistics without rewriting child
rows. Its current/completed state is preserved through restore. Archiving a league suppresses the
league and all descendant seasons, games, and statistics without changing archive metadata on
those descendants. Restoring a parent reveals only children that were not archived independently.

RLS uses separate visible-read and admin archive-read policies. Public and routine authenticated
reads cannot see archived branches, while an allowlisted admin can populate the Archived screen.
`DELETE` is revoked for authenticated clients on leagues, seasons, and games. Database triggers
also reject business writes and scoring-event changes against completed seasons and archived
branches. Archive RPCs revoke execution from `public` and `anon` and grant it only to
`authenticated`; each function still checks `admin_users` explicitly.

`season_batting_stats` excludes directly archived games and every game below an archived season
or league. Completed seasons are deliberately retained. `supabase/tests/database/archive_restore.sql`
and `season_management.sql` cover preservation, statistics removal/recovery, parent/child
semantics, hard-delete rejection, and authorization.

## Admin season lifecycle

`public.create_season` creates an active season for an active, visible league after normalizing
and validating its name and date range. It prevents case-insensitive duplicate names within a
league and copies the latest visible roster in that league into the new season so it is immediately
usable for game setup when a prior roster exists.

`complete_season` changes the season from current to historical only when every visible game is
completed. A completed season no longer appears in scorer season choices, but its public season
page and per-season statistics remain intact. Its counts continue to participate in league and
career aggregation. Because every row in `season_batting_stats` remains keyed by `season_id`,
historical events never leak into a different current season's statistics. `reopen_season` clears
the completion metadata and makes the season available for new games again.

All five season lifecycle RPCs—create, complete, reopen, archive, and restore—use invoker security,
an empty `search_path`, an explicit `admin_users` check, and authenticated-only execution grants.
`supabase/tests/database/season_management.sql` verifies roster carry-forward, date and duplicate
validation, unfinished-game protection, current-vs-historical statistic isolation, league all-time
contribution, archive/restore behavior, reopening, hard-delete denial, and anonymous/non-admin
denial.

## Admin roster management

Players are global records and `season_players` is the roster membership boundary. The admin UI
supports two explicit add paths: `create_player_for_season` creates one normalized player and its
season membership atomically, while `add_existing_player_to_season` reuses a global player so
career totals remain attached to one identity. A case-insensitive unique player-name index prevents
accidental duplicate identities.

`remove_player_from_season` removes only the membership. It preserves the global player and rejects
removal if the player appears in any game lineup for that season, ensuring historical games and
statistics cannot be orphaned. All three RPCs accept only a current, visible season in an active,
visible league, use invoker security and an empty `search_path`, explicitly check `admin_users`, and
grant execution only to authenticated users. `supabase/tests/database/roster_management.sql`
verifies atomic creation, existing-player reuse, duplicate protection, safe removal, history
protection, and anonymous/non-admin denial.

## Admin league creation

`public.create_league` is the write boundary for adding a league. It normalizes whitespace, limits names to 100 characters, rejects case-insensitive duplicates (including archived leagues that should be restored), and generates a unique URL-safe slug. New leagues are active and unarchived by default.

The function is `SECURITY INVOKER`, explicitly checks `auth.uid()` against `admin_users`, uses an empty controlled `search_path`, revokes execution from `public` and `anon`, and grants execution only to `authenticated`. The underlying insert remains subject to the existing admin-only RLS policy.

`supabase/tests/database/league_management.sql` verifies creation and slug collision handling, duplicate rejection, archive visibility in scorer-style queries, restore behavior, and anonymous/non-admin denial. Like the other connected database tests, it rolls back every fixture.

## Live-resume tradeoff

Plate appearances and runner advancements remain the historical source of truth. Replaying those events can audit or rebuild game state. `game_states` intentionally duplicates only the small amount of volatile state needed for an immediate phone refresh: inning, outs, next batter, and the three bases. Future scoring writes should update the event rows and snapshot in one database transaction/RPC so they cannot diverge. This is simpler and more reliable on a phone than replaying the full game after every refresh, without storing derived career totals.

## Atomic game initialization

`public.create_game_with_lineup` is the single write boundary for starting a game. One call validates the active league/season relationship, requires a non-empty and duplicate-free lineup, confirms every player belongs to the season roster, and then creates the `games`, ordered `game_lineup`, and `game_states` rows in one PostgreSQL transaction. Any validation or insert failure rolls back the entire call.

New games start with status `in_progress`, inning 1, 0 outs, batting-order position 1, and all three bases empty. The returned game UUID is used for the admin score route. That route reads `game_states` from Supabase rather than treating browser state as authoritative.

The function is `SECURITY INVOKER`, so the existing table grants and RLS policies continue to govern every insert. It also explicitly requires `auth.uid()` to be enrolled in `admin_users`, uses an empty controlled `search_path`, revokes execution from `public` and `anon`, and grants execution only to `authenticated`. The browser uses only the publishable key.

`supabase/tests/database/game_initialization.sql` exercises valid admin initialization, the exact initial snapshot and lineup order, anonymous and authenticated non-admin rejection, roster and duplicate validation, empty-lineup validation, and the absence of partial records after failures. Each successful test write is rolled back.

## Atomic live scoring

Three `SECURITY INVOKER` RPCs form the only live-scoring write boundary:

- `record_plate_appearance` locks the game and state in a consistent order, verifies the game is in progress, rejects a stale `game_states.updated_at` token, resolves the batter and next batting-order position on the server, validates one movement for the batter and every occupied runner, inserts the plate appearance and movements, advances inning/outs/bases/order, and rebuilds `games.team_score` from movements ending at home.
- `undo_last_plate_appearance` locks the same rows, removes only the latest event, and restores inning, outs, batter position, and bases from that event's recorded pre-play origins. It then rebuilds the score from the remaining history.
- `finish_game` locks and stale-checks the game, rebuilds the final score, and moves it to `completed` so further scoring and undo calls are rejected.

Every scoring call explicitly checks `auth.uid()` against `admin_users`, uses an empty controlled `search_path`, and grants execution only to `authenticated`. Table RLS remains active because the functions use invoker security. The browser submits a complete proposed play but never chooses the batter or directly mutates scoring tables.

`supabase/tests/database/live_scoring.sql` is a rollback-only connected fixture. It covers the prescribed six-play inning, immediate statistics, stale clients, exact undo and replay, completion, a home run, error, fielder's choice, a multi-out inning transition, undo across that transition, invalid runner/RBI submissions, and anonymous/non-admin rejection.

## Statistics

`season_batting_stats` is a `security_invoker` view that exposes additive counting stats plus
zero-safe rates. It counts G from visible, non-draft game lineups, batting results from plate
appearances, and R from runner advancements ending at home. Completed seasons remain eligible;
archived season, game, and league branches do not.

The view is the reusable aggregation contract:

- Season pages filter by `season_id`.
- Player pages filter by `player_id`.
- League totals filter by `league_id`, sum the count columns across seasons, then recalculate rates from the summed denominators.
- Career totals sum count columns across every season for a player and recalculate rates. Never average per-season AVG/OBP/SLG.

The UI exposes season statistics, league all-time totals, player career/season totals, global
all-time totals, and top-three all-time or per-season leaderboards. Public batting tables support
client-side sorting and descriptive CSV export for lineup analysis.
`src/utils/statistics.ts` contains count aggregation and rate calculation used by league pages,
player profiles, and focused unit tests. `supabase/tests/database/season_stats.sql` creates an
isolated rollback-only fixture to validate the live SQL output without depending on visible
application records.

## Security model

Every public table has RLS enabled. Explicit grants expose SELECT to `anon` and `authenticated`, while visible-read policies limit normal access to non-archived data. Archive-management read policies additionally require an `admin_users` row matching `auth.uid()`. Only `authenticated` receives table write grants, and write policies require the same explicit allowlist. The admin allowlist itself only permits a signed-in user to read their own row and exposes no client-side writes.

The statistics view uses invoker security so underlying table RLS remains in force. No privileged key is used by the app.

## Admin bootstrap

The repository does not create an Auth identity because no real email/password was supplied. Complete this one-time setup in the Supabase dashboard:

1. Under Authentication → Users, create the admin user with your real email and a strong password. Do not enable in-app signup.
2. Copy that user's UUID.
3. In the SQL editor, run this while signed in as the project owner:

   ```sql
   insert into public.admin_users (user_id)
   values ('YOUR_AUTH_USER_UUID');
   ```

The admin can then use `/admin/login`. Creating any other authenticated user grants no write access.

## Environment and deployment

Local development uses an ignored `.env.local` with `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY`. Vercel needs the same two safe browser values in Development, Preview, and Production. Never configure a secret/service-role key for this frontend.

For a fresh database, apply migrations and `supabase/seed.sql` (a local `supabase db reset` does both). After schema changes, regenerate `src/types/database.generated.ts` using the Supabase type generator and run all files in `supabase/tests/database` with errors configured to stop the run.
