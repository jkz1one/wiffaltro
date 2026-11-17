# Additive reroll App route: qualification pending

The separate entry inherits the original General114 App and visuals. Only reroll
commands use the fixed transaction helper; every other shop operation delegates
to the existing implementation. Neither General114 source/catalog/save identity
nor the checkpoint37 transaction helper is changed.

The wrapper pins the original owner, lab identity/state and full owner capture,
then calls the synchronous transaction under a busy guard. A returned candidate
is retained even if it could not be saved; no automatic retry is attempted. A
saved candidate is marked already durable before invoking the inherited guarded
cleanup/promotion, so it is not saved a second time. Retained failure uses the
ordinary retry path and the exact candidate, not a recomputed purchase.

## Repeat-command defect found

The original Build returns an unchanged fork when an identical command ID has
already been applied. Passing that fork through either original App saving or
the initial wrapper writes the same primary again and rotates the post-purchase
primary over the previous backup. Cash is not charged twice, but backup history
changes. Actual native reference and initial-wrapper tests failed the explicit
backup-preservation assertion. Their failed evidence is preserved, not a pass.
The bounded wrapper correction rejects previously handled reroll IDs before
persistence. Frozen reference behavior remains unchanged, including for other
operations. This is not a claim that all reference duplicate-command paths are
fixed.

## Qualification boundary

Godot 4.6.3 actual App confirmation/cancel, success, failed-write retention,
exact retry, duplicate protection and separate-process cold reopen pass. The
wrapper success and fault routes exactly match the reference first-purchase
payload, Cash, price, revision, reroll count and first-backup SHA. The reference
control separately reproduces its known duplicate-backup defect; it is not a
reference duplicate-correctness pass.

The final fault test removes its injected obstruction before probing owner/lab
identity guards, so those probes can discriminate a missing guard. It also checks
retained exit blocking, cancel backup invariance and held authored Resource
invariance. Earlier fault probes behind the obstruction are not used as proof.
Success/reference tests use byte-identical final App code; their only test-source
difference is the later move within the fault-only branch.
Tests use copied authentic earned Standard shop data, not fabricated Cash or
stock. Single synchronous confirmation timings under concurrent test load are
diagnostic only, not a hardware benchmark or general player-latency guarantee.
Script-driven real dialog actions are not native visual playtesting. Other shop
operations, leagues and owned/Dynasty workflows are not newly qualified here.

One concurrent-load first-confirm diagnostic measured 31.819 seconds for the
wrapper versus 48.538 seconds for the reference on the same earned 4-Cash reroll.
This single comparison is not a general speedup guarantee or final performance
acceptance. Retained ordinary retry still uses the unchanged full Save path.
