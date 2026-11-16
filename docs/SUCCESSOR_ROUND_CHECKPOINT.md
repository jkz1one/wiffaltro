# Successor actual round and earned purchase checkpoint — 2026-11-16

This test-only increment leaves all game source and original development visuals
unchanged. Run `python tools/test_successor_signature.py --round` with Godot 4.6.3.
The runner restores the inactive drafts only into a disposable isolated project;
HOME and XDG directories are isolated and original saves are never opened.

## Verified behavior

Seed `1794841964` passed in a fresh native process, followed by a separate cold
process reopening the durable save:

- Fresh App creation and four actual draft callbacks.
- Actual human-fixture physics through the live match route, driven by the native
  automation controller, plus two actual AI fixtures. No score was fabricated.
- Captured human report checkpoint with no premature payout; each AI report is
  checkpointed before final settlement.
- Three game results, one human result, empty pending round, one score-matched
  human reward and one receipt for each of all five AI clubs.
- Repeated round resume does not change the captured season.
- A generated pack is purchased with the actual earned cash through the App
  transaction callback. A legal generated selection increases development by
  exactly one level and advances the development-book revision once.
- Repeated selection grants nothing twice.
- Cold reopen retains the settled round and used pack and constructs the next
  fixture.

The harness waits for normal match introduction before installing automation.
Because the automation controller suppresses the human outro, the harness removes
it only after actual GAME_END and invokes the ordinary outro transition before
capturing the result. Two earlier harness attempts failed on introduction/outro
coordination, not game outcomes; their isolated evidence was retained. The first
corrected run also passed before assertions were strengthened for exact growth,
all AI clubs and score-matched payout.

## Evidence boundary

This proves one native three-game round and one earned pack transaction, not a
whole season, Dynasty, career integration, full shop modal interaction, visual
playtesting, crash/power-loss atomicity or a distributable build. The test label
“atomic round settlement” concerns the normal in-memory/persisted transition;
it is not a fault-injection result. Generated saves and logs remain outside the
source repository and are not part of this checkpoint. Older isolated successor
fixtures are preserved rather than migrated. Historical live source is unchanged.
