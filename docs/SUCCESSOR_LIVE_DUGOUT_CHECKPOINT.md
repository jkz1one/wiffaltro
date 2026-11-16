# Live Dugout round and persistence checkpoint — 2026-11-16

This increment advances the experimental League namespace to explicit live
Dugout tier0. It is not career or Dynasty integration. Historical production and
standalone-v7 source/readers remain byte-for-byte unchanged. Closed admission108
source and isolated evidence remain preserved at commit
`7de276a0435dcb8168e12997b279e417eaef4db5`; they are not migrated or reinterpreted.
The old closed-admission test is historical to that checkpoint.

## Explicit contracts

- Outer/admission109, Build109/base45, Development9/base1, pitch content7.
- Format `successor-dugout-live-v7-r1`, purpose `live_dugout_season_v7_r1`.
- Separate slot `user://successor-dugout-live-v7-r1.json` and explicit boolean
  `league_live: true`; closed creation grants no live-save authority.
- Physical report30 with resolver `physical-successor-dugout-v7-r1` combines
  current pitch proof with replayed League ownership/capacity. It cannot be
  replaced by historical report27 or a client-supplied capacity number.
- Career, owner grants, inventory domains, venues and Dynasty stay unadmitted.
- The decoder validates the settled prefix before using its detached League
  pending fork. It does not use the standalone-only shortcut or recursively
  restore the same pending checkpoint. Full ownership/replay/recapture checks
  and JSON rule canonicalization remain in force.

Seven additive presentation files preserve the original full shop and game
visuals while routing this domain's constructor, capture and transactions.
The match-capture predicate also requires the actual match's League rules to
match its season. Original development assets and the frozen authored pitch/style
provider are unchanged.

## Native checks

Godot 4.6.3, fresh isolated projects and user-data directories:

`python tools/test_successor_signature.py --dugout`
- Fresh live creation and four draft choices, each resumed through JSON replay.
- Actual next-match construction and detached physical request with Dugout rules.
- Wrong League/catalog and unreplayed capacity rejected.
- Old108, standalone and downgraded live-flag envelopes rejected.
- Durable save plus separate cold exact recapture; standalone slot bytes and
  readability preserved.

`python tools/test_successor_signature.py --dugout-round`
- Seed `1794844660`: actual human-side physics, driven through native live
  controllers by the test automation, followed by normal outro/capture.
- Human result saved before rewards; a separate process reopens this pending
  checkpoint before running two actual AI fixtures.
- Both actual AI reports are report30 and checkpointed before settlement.
- Three-game settlement, score-matched human earnings and one receipt for each
  of all five AI clubs. Repeated resume is inert.
- Generated pack purchased from actual earned cash; exactly one development level
  applied, duplicate selection inert; separate cold settled/purchased reopen.
- No fabricated score, reward, offer, price or player profile funds this route.

`--dugout-pending-fixture <isolated-one-AI-save>` copies a retained byte-exact
checkpoint from that actual round into another isolated directory. It checks:
- Exact pending capture equals the durable slot.
- Speculative settlement reaches the remaining fixture without changing the
  original season or slot.
- Historical-report and ownership tampering fail through full Codec restore,
  not merely a shallow report validator; failed replay leaves the original intact.
- Separate cold process exactly reopens the same actual pending checkpoint.

The test evidence monitor copied pending checkpoints only from the isolated test
slot, never from an owner's saves. Raw evidence and saves are excluded from GitHub.

## Open gates

This qualifies one live Dugout round and earned pack, not a whole League,
all shop branches, career unlocks, Dynasty, character tuning, visual/input
playtesting or a distributable build. Synchronous validation still affects UI
latency. The remaining planned depth is retained; these gates are not treated as
optional merely to deliver an earlier build.
