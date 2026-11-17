# Additive round-batched full-season continuation harness

This changes test orchestration only. The frozen Owner112 engine and original
per-fixture terminal-season harness are unchanged. The new scene cold-loads an
exact copied earned boundary once, then keeps the same real App alive through at
most one settlement or terminal completion. Every production clone, replay,
pending projection, save, backup and readback still runs. No scores, cash or
completed results are supplied by the test.

The complete action-branch body is byte-identical to the frozen harness.
Original terminal prewrite-failure/exact-retry and terminal verification helpers
are inherited unchanged. Each durable boundary retains the original assertions
and independently archives exact primary bytes plus read-back metadata. Both
snapshot and metadata destinations must be absent. Input bytes remain immutable.
Eight boundaries bound one invocation; failure leaves all prior archives intact.

## Coverage and continuation contract

Previous per-fixture cold evidence remains valid. New coverage is explicitly:
cold entry at each round boundary; same-App execution with individually checked
durable saves inside the round; separate original terminal cold verification.
Do not describe newly batched intermediate fixtures as independently cold-opened.

In a normal four-boundary round this can remove three App/full cold-reload and
engine-startup operations. No elapsed saving is measured yet, and it removes no
production save validation or actual gameplay.

The runner accepts only a copied isolated earned archive from full-season-evidence
or batch-season-evidence. It records source stage/index/SHA256, starts a separate
isolated user tree, and emits one BATCH_STEP_DONE per durable boundary. Continue
only from the latest fully recorded archive in a new invocation; never replay
earned games or infer a boundary from an incomplete log. A completed terminal
automatically invokes the original verify-terminal scene in a separate process.

## Current verification boundary

Native Godot 4.6.3 import passes. Exact action-branch comparison, manifest hashes,
Python compilation and diff checks pass. All 6,174 preexisting frozen engine
source files in the initial continuation stage match the original stage byte for
byte. The first actual batch completed ninth-round settlement: 27 results, nine
human results and no pending work, including duplicate-settlement rejection. Its
output SHA256 is ec85dc732facda3e365538558614f509b0316a6b23f690432432997aa7dd7cb5.
That first batch contained only one boundary, not a multi-boundary qualification.
The next batch cold-loaded that archive and has saved/archived actual human
fixture27 pending, without premature settlement or reward. It continues NPC work;
its first marker still describes nine settled human results, not ten settlements.

The handoff used actual boundary0030 (NPC26), whose immutable checkpoint SHA256
is dd38cdf9cc9a82f393e61f4a7cbf9a44c11d5fd98af9b482a31129ea529fb1b6.
The redundant old process was intentionally interrupted during its next cold
reload. Its primary remained exactly0030, with no0031 archive or temporary file.
Original evidence and saves remain preserved. Remaining NPC work/tenth-round
settlement, playoffs, terminal fault/retry and final cold checks are not yet
claimed passed. No full-season, next-owner positive birth or Dynasty qualification
follows from these intermediate milestones.
