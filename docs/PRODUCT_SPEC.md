# Softball Stats product specification

## Product goal

Softball Stats is a mobile-first personal scorekeeping and public statistics app. One authenticated, explicitly authorized admin records and edits games. Anyone with the URL can browse all public softball data without an account.

The entire product defaults to a high-readability night theme. Pages use a restrained, flat palette with strong text contrast, clear status colors, and no decorative gradients or glows. The compact scorer and management screens remain the primary mobile design target.

## Core model

- A **league** is one team/league context, such as Monday Rec or Wednesday Rec.
- A **season** belongs to one league, such as Fall 2026.
- A **player** is global. The same player record may join rosters in multiple leagues and seasons.
- A **season roster** connects global players to a season.
- A **game** belongs to a season and has one fixed batting lineup in v1.
- Each **plate appearance** is a source-of-truth scoring event.
- **Runner advancements** record movement caused by a plate appearance, including runs and outs.

## Game setup workflow

The admin selects an active league and one of its active seasons, enters the opponent and date, and builds an ordered lineup from that season's roster. Starting the game atomically creates the in-progress game, fixed lineup, and initial resume state. The admin dashboard lists in-progress games, and the admin-only score route reloads the persisted inning, outs, bases, score, and current batter after navigation or refresh.

For each plate appearance, the scorer chooses the official result and confirms where the batter and every occupied runner finished. Smart defaults cover routine hits, walks, outs, sacrifice flies, fielder's choices, and errors, but every destination remains editable for unusual plays. On an inning-ending play, surviving runners default to their starting bases; this also applies when an added runner out creates the third out. The scorer can then select Run for a run that counted before the third out. Runs and outs are derived from those destinations; RBI is separately adjustable up to the number of runs on the play.

One transactional database call selects the server-authoritative batter, locks the game and resume state, rejects stale browser state, records the plate appearance and complete runner movement, advances or wraps the batting order, clears the bases on the third out, and synchronizes the team score. Recent plays are visible during scoring. The admin can transactionally undo only the latest play or finish an in-progress game.

## Statistics

Derive statistics from plate appearances, runner movements, and lineups; never store averages or career totals on a player. Tables open in Simple view with AVG, OBP, RBIs, and HRs after Player. Advanced view begins with AVG, OBP, SLG, and OPS, followed by G, PA, AB, H, 1B, 2B, 3B, HR, BB, K, R, RBI, SF, FC, ROE, and TB. CSV downloads follow the selected view.

Supported scopes are season, league across seasons, individual player, all leagues/seasons, and career. v1 rules:

- Walk: no AB, counts as reaching base for OBP. Retired historical reach events retain their original OBP contribution but are not selectable or shown as a separate statistic.
- Sacrifice fly: no AB; included in the OBP denominator.
- Error and fielder's choice: distinct non-hit results that count as AB.
- Strikeouts and ordinary batted-ball outs count as AB.
- Divide-by-zero rates display as zero.

## Current release

The application includes the Vue/Vuetify public statistics experience, typed Supabase access, admin password login and allowlist authorization, reproducible schema/RLS, a deterministic game-free development roster, and Vercel SPA compatibility. The admin can create a game from an active season roster, order its lineup, start it atomically, score offensive plate appearances on a phone, resume after refresh, undo the latest play, and finish the game. Public season and player statistics update directly from the recorded event history.

Admin management includes focused Games, Leagues, Seasons, and Archived screens. An allowlisted
admin can create a league or season; a new season carries forward that league's latest roster. A
current season can be marked completed after its unfinished games are resolved. Completed seasons
remain public history and continue contributing to league and career totals, but do not appear in
new-game choices or alter the separate statistics of another current season. An admin can reopen a
completed season when needed.

Admins can also manage a current season roster without creating a game. Adding a player either
reuses an existing global player who appeared in another league or creates a new global player,
then adds that player to the selected season roster. The same choice is available from Available
players while building a new-game lineup; the added player is immediately available and selected.
Removing a roster membership never deletes the player and is blocked once that player has recorded
game lineup history in the season.

The Seasons admin screen also allows an admin to correct a current season's optional start and end
dates. The end date, when present with a start date, cannot precede the start date.

Each public league page lists its current and completed seasons and shows a league all-time batting
table aggregated across every visible season. Completed-season counts are included, while rates are
recalculated from the combined denominators instead of averaging season rates.

Batting tables can be sorted by player or any statistic and downloaded as a descriptive CSV with
league, season, player, count, and rate columns. CSV is the interchange format for lineup-analysis
workflows because it is compact, explicit, and directly uploadable to AI assistants. The Players
page includes all-league career totals and a Hall of Fame for a user-selected batting category
across all time or one selected league season.

Inactive players remain attached to historical games but are excluded from the public Players
directory, career table, Hall of Fame, roster choices, and new-game lineup choices.

Loading uses a translucent blocking overlay. Existing page content remains visible beneath it, but
cannot be interacted with until the operation finishes.

Delete actions are recoverable archives with confirmation: archived games disappear from normal
lists, scoring, and statistics but retain their full history and resume state; archived seasons and
leagues suppress their complete branch without rewriting children. Restore reverses only the
selected item's archive metadata and preserves independently archived descendants. Client hard
deletion is not supported.

## Explicitly out of scope for v1

- Lineup substitutions
- Pitch-by-pitch scoring
- Opponent scoring
- Pitching or fielding statistics
- Editing arbitrary historical plays or completed games
- Advanced analytics beyond the listed batting statistics
- Public registration or multiple permission tiers
- A separate application server
- Aggregate career-stat columns
