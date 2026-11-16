# Successor draft and physical-game qualification — 2026-11-16

Run `python tools/test_successor_signature.py --flow` with Godot 4.6.3.
This selects a separate isolated test suite, not the signature-only suite.
The unchanged 47-file successor draft is restored only in a temporary project.

Verified with the native engine in headless fixed-60-step mode:

- Real successor App fresh-season handler saves and adopts its candidate.
- Each of four actual App draft-handler selections commits durably; no retained
  failed-save candidate remains. The resulting team has four players.
- A nonempty captured season creates its real pending fixture and MatchState.
- The detached native physical runner completes a full automated game through
  ordinary controllers/physics and returns an accepted, balanced successor report.
  No synthetic scores or reward grants are inserted.
- That detached game does not mutate, settle or pay the original season.
- A separate cold process reloads the drafted season through the App and can
  construct its pending playable match again.

The tightened harness logs its fresh season seed (verified run: `1794840617`),
requires a nonempty initial snapshot before comparison, and leaves generated
saves/logs outside the repository. Source inspection and audit found no
production/project changes in this increment; the default game is unchanged.

These are UI-handler and physical-domain checks, **not** visual/click acceptance,
human-control testing, completed round settlement, earned shop purchases, career,
Dynasty or a distributable build. The original development visuals and legacy
save paths remain untouched. See `SUCCESSOR_INTEGRATION_STATUS.md` for the next
integration gates; existing test filenames alone do not establish passing work.
