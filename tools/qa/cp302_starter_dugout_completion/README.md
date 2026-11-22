# CP302: finish an actual Starter Dugout career

This harness uses official Godot 4.6.3 and the release template with the
normal Starter feature, custom user-data dir, and actual App methods. Only
the disposable QA export includes the driver. There's no player-facing
adoption or Next route. The existing native Standard physical driver is
used unchanged (actual batting, pitching, NPC simulation and settlement;
no supplied scores, reports or reward commands).

1. Run `python3 tools/qa/cp302_starter_dugout_completion/build.py <official editor> <official template archive>`.
2. In a new subdirectory of that QA root, copy the exact generated CP301
   one-pick primary and prior backup into
   `data/WiffaltroStarterBeta-v1/wiffaltro-common-career-v4.json{,.bak}`.
   The source pins are defined in the probe. Never use personal/original saves.
3. Run `bash tools/qa/cp302_starter_dugout_completion/step.sh <root> <stage> round <exact-primary-SHA>`.
   One invocation goes to the next native settled boundary and leaves exact
   primary+backup at every action. Continue the same owner from the verified
   resulting SHA. The settled checkpoint is also copied locally under
   `starter-dugout-steps` before continuing.
4. Once the actual active career has all 33 results (no pending report),
   use `close` with its exact SHA. Reopen the new closed primary in a
   freshly staged profile only using `cold` and its exact SHA.

Complete closure is for the typed Starter archive only. The regular
schedule, playoff seeding, final participants, outcomes and title/credits
are authored by the native rules. All six independent game-reward maps
must correspond to actual winners and the prior Standard archive must
remain available. Private archived formats are still Abandon-only;
further-season rollover is intentionally not part of this check.

Run `python3 tools/qa/cp302_starter_dugout_completion/audit_terminal.py <exact-active-COMPLETE> <exact-closed>` independently of the engine. The auditor derives the native regular standings tie-break, semifinals, neutral final, player/NPC partition, all 66 bank receipts and Base close payout from the observed scores. It also compares the entire current match payload and earlier archived source before and after Close, and reports 20 MiB legacy chain headroom.
