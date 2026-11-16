# Successor career evidence adapters — 2026-11-16

Five inactive adapters form a separate `successor_career_v1` module. Its own
signature depends on the qualified League catalog and shared evidence validators;
there is no reverse dependency. Existing League, standalone-v7 and production
source and signatures remain unchanged, so the actual settled fixture is reused
without re-signing, outcome substitution or source migration.

## Authority boundary

`career_run_evidence.capture(checkpoint, run_id)` first restores the complete
League109 checkpoint through its full physical/history decoder. A live object,
incomplete draft or pending round is not accepted as settled evidence. It then
canonicalizes the replayed checkpoint and derives:

- Exact proposed run identity, seed, normalized League/tier and content identity.
- Full checkpoint and independent evidence-module fingerprints.
- Compact score proof, per-player performance and current Exotic correspondence.
- Ordered development/contract evidence from a complete Build replay observer,
  not just the final book's learned-ID list.

`restore(evidence)` derives everything again and compares the full envelope.
Canonical digests use full-precision JSON; equivalent integer/float JSON identity
is stable without collapsing distinct fractional values.

The supplied run ID is a proposed journal identity, not proof of an existing
owner. These adapters cannot create a career, award assets, unlock a League,
issue a completion receipt or authorize inherited Exotic history. The next owner
layer must bind this evidence to its already-established exact active run.

## Native qualification

`python tools/test_successor_signature.py --career-fixture <isolated-settled-save>`
copies the actual seed `1794845591` Dugout round/earned-pack checkpoint into a
fresh isolated test directory, then launches a separate cold process. The test
verifies:

- Full decode of three actual game results and the paid pack journal.
- Correct one-game player/Exotic correspondence, seed, League and tier.
- Ordered development replay retains the actual paid selection.
- The partial run is unfinished and cannot produce a completion receipt.
- Native and JSON input produce equivalent evidence; JSON restore recaptures it.
- Invalid run IDs, live-object input, incomplete draft, a valid actual pending
  round and an extra grant field are rejected.
- Altered seed/tier/catalog/module identity, score proof, player strikeouts,
  lesson provenance, historical Progress5 substitution and changed source result
  fail validation.
- Evidence work and rejected attempts do not mutate the source season or slot.
- Separate cold evidence restore exactly recaptures the envelope and verifies
  the original copied source-file hash is unchanged.

An initial test harness used the wrong level of the nested checkpoint envelope;
it was corrected before qualification. No validator was weakened. Private source
fixtures, evidence JSON, logs and caches are not published.

## Still open

Actual career owner/start/sync/abandon/complete behavior, persistent shared assets,
championship-derived unlocks, owned starting progression, all remaining Leagues,
Dynasty and release qualification. A one-round evidence adapter test is not proof
of any of those, or proof that a whole season can complete.
