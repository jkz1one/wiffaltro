# Transaction-local recapture experiment

Inactive additive owner113, not a replacement acceptance path for existing saves.
Game109 and owners110/111/112 remain frozen. Public113 restore rejects112 envelopes;
the test's explicit old-decoder-first shadow reconstruction is not a migration API.

The one optimization is inside a single synchronous restore: the row already
derived during decoder sync can be reused for final exact recapture. Full paid
Build/physical replay, structural/progression/row validation and exact complete
envelope comparison remain. Public capture/sync remain uncached. A new context
is created and cleared for every public restore; no context is stored on the
career, season, static state, save, or between requests.

The context derives its own row, keeps detached copies, and compares complete
bounded operand bytes as well as their digest. It binds exact season/build/career
identities, original source signature, all selected row-relevant season values,
and all script-variable properties of explicitly whitelisted Build objects.
Unsupported object graphs, changed operands, depth/size limits or invalid rows
fall back to ordinary derivation. Diagnostic counters never authorize reuse.

This is a closed synchronous bridge, not a general cache for arbitrary callers
or external Resource edits. It spans no await or user callback. GDScript private
names are conventional; public restore clears any diagnostic preseeded context.
The test does not claim to fingerprint every possible external in-memory Resource
mutation outside this lifetime. Authored content is retained during the operation;
original source/signature and content validators still run.

Tests compare exact encoded output on birth, all four draft picks and an actual
paid-round fixture, then mutate contracts, book state, progression, results,
performance and roster without advancing revision. Copy poisoning, context
reset, unsupported-graph fallback and cold independent restores are covered.
Performance numbers are a small diagnostic result, not proof of responsive UI,
completed113 gameplay, completed seasons, migration or Dynasty.
