# Changes

## September 9, 2026 — Simpler stats and corrected third-out scoring

- Removed HBP from scoring choices, statistics tables, and CSV exports. Old recorded events remain preserved for historical accuracy; the retired event displays as “Reached base” in play history. New HBP submissions are rejected by the scoring service.
- Batting tables now open in **Simple** view: Player, **AVG, OBP, RBIs, HRs**. Switch to **Advanced** to see the full remaining statistics. CSV downloads match the selected view.
- Advanced tables, including the Players page, begin with **AVG, SLG, OBP** immediately after the player name.
- On a play that makes the third out, surviving runners default to their **same base**, with no automatic runs or RBI. This also applies when selecting a runner out turns a play into an inning-ending double play. Select **Run** afterward to credit a run that counted before the third out.
- Corrected the September 9 game against **Back Door Sliders from 11 runs to 9**. The first-inning third-out groundout incorrectly credited Justin King with a run and Lucas Feinstein with an RBI. The fifth-inning third-out groundout incorrectly credited Michael Kula with a run and Andrew Cronin with an RBI. Removed those two runs and two RBI; all 35 plate appearances and the original hits/outs remain intact.

### Verification

- Lint, TypeScript validation, production build, formatting, and 32 tests passed.
- Database regression checks cover held runners, inning transitions, explicit run/RBI overrides, undo, and rejection of the retired result. Fixtures roll back all test data.
- The corrected game has **9 stored runs, 9 run events, and 9 RBI**. Season and career statistics read the corrected events.
- Browser checks cover the default Simple view, Advanced column order, and the corrected public game score.

### Release details

The scoring migration is `supabase/migrations/20260910033353_retire_hbp_and_support_third_out_holds.sql`. The guarded, repeatable game correction is recorded separately in `supabase/repairs/20260909_back_door_sliders_runs.sql`; it validates the reviewed opponent, date, plays, and totals before changing anything. Historical database fields remain for compatibility and correct historical OBP calculations.
