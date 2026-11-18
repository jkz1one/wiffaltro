# Materialized live progress summary (checkpoint72)

Parent: verified checkpoint71 `9d532c44ace3c2df14861d6d2cd75d2f9076dccc`.
Status: targeted final qualification and native smoke passed; remote publication pending.

## Finding and bounded correction

Profiling the genuine saved paid-reveal boundary found a hidden cost in71:
career-row derivation called the frozen general-career player-progress helper,
which reconstructed the current Build and committed development commands again.
Sponsor counts also replayed wallet commands. Earlier zero117-decoder,
zero-physics and zero-round-projector counters did not measure these calls.
Consequently,71 was not a zero-current-journal-command-replay reader.

The new `successor_live_play_v1/progress.gd` retains the exact pure game,
performance, legend and career-row output schemas. Only119 Career.sync and the
codec's expected row use it. Frozen114/117 and118 readers remain unchanged.
The119 schema, slot, atomic store and every ownership/retained-candidate guard
are unchanged. This is not a new save family or a caller-supplied trust flag.

For Standard and Dugout tier0, contracted players remain in the contract map
after release; active repertoire size never decreases; mastery never decreases;
removed recipes retain their mastery. Recruit catch-up adds no recipe identity.
The maximum known/mastery levels therefore come from the current contracted
profiles. New lessons are the sorted global union of their mastery identities
absent each player's authored baseline. Exchange moves only already-learned
recipes between contracted players, so the global union is preserved. Retraining
moves stats, not mastery. This argument does not apply to Dynasty decay and is
explicitly not used for it.

Sponsor counts use a bounded read-only projection of stock and active receipt
identities at reward boundaries. Buy/replacement, sell, inventory sale and
sponsor-set operations are covered; no wallet or development command executes.
Malformed fields are refused. Sponsor-term expiry and other league contracts are
outside this helper's scope. Other pure summaries still inspect current-season
receipts and result evidence. **No journal-read-free claim is made.**

## Evidence

- Actual genuine71 boundary0006 and0007: full new career rows equal frozen legacy
  reference rows; full materialized recaptures equal the original snapshots.
- Bounded synthetic Standard/Dugout fixtures: actual book commands cover recruit
  catch-up, learned/replaced/relearned recipes, inactive mastery, exchange and
  retraining. Explicit synthetic roster release/return preserves contracts.
  These are component tests, not newly earned gameplay.
- Malformed in-memory operand probes refused 17 sponsor-event shapes, eight
  contracted profile shapes, three non-Dictionary hidden catalog entries,
  nonstring contract identity and unsupported sponsor
  terms, without save writes or command execution.
- Actual bank-command reference tests cover sponsor buys, replacement, sales,
  combined sponsor sets and inventory sales. Reference command execution is
  confined to tests, never live summary derivation.
- The original actual Shop handler, from genuine0006 with the same card and
  recipient, produced bytes identical to genuine0007:
  `72e26e0cbf762162a1e78f9ef3fccdff396dfe816ba9fb677434c92f3350fc56`.
- Final uninstrumented copied0004 tests retain hidden-state rejection, paid-open
  prewrite failure/exact retry, no double charge, duplicate choice refusal,
  primary/backup preservation and separate cold reopen. No physics was rerun.
- Synthetic cleanup callbacks retain exact already-durable candidates on owner
  mutation or synchronous replacement-lab insertion; removal permits promotion
  without another close or write.

Instrumentation never changed hash-bound frozen source. 287 catalog-bound files
matched the71 stage byte-for-byte. New-helper call-graph inspection finds no
BuildRestore, development.commit or bank.commit calls. Frozen-method runtime
counters were unavailable without changing source identities; this limit is
explicit. Existing117 decoder/physics/projector counters remain zero on cold.

A final audit identified a hidden bank-catalog value could be a non-Dictionary
before full build validation. The receipt summary now checks the Variant type
before reading its kind; boolean, null and Array probes refuse cleanly. Final
synthetic parity, actual row/snapshot parity, same paid-choice handler and cold
regressions were rerun after this minimal guard. Earlier evidence is retained.

## Measured effect and remaining work

Same-fixture instrumented full paid-choice handler: 34,674ms before, 8,132ms after
(76.5% reduction). Cold reload: 4,480ms before, 1,356ms after. The final
uninstrumented handler measured 7,572ms; paid-reveal cold 1,011ms and final cold
1,171ms. Timing varies with the shared cloud environment. The profile preceded
an additional malformed-profile shape guard; final functional tests use that
guard. After the final hidden-catalog type guard, the same uninstrumented
choice/cold measured9,996ms/1,763ms and again produced identical bytes. These
runs are not controlled hardware benchmarks. No claim of target-hardware
performance or acceptable responsiveness.

The remaining repeated semantic captures still dominate: 9 captures in one
handler, including repeated progress/catalog validation and detached payload
walks. Further optimization is a separate increment, not an unchecked bypass.
Dynasty, terminal career integration, full-season qualification, native full
match acceptance and distributable export remain outstanding. The launcher
footer now says “Your previous saves are kept separately.”, not developer jargon.


## Native smoke

An isolated QA72 project retained the original green/gold visuals. The launcher
showed “Your previous saves are kept separately.” Cold Continue from the genuine
71 boundary0009 restored the same Round2, next fixture, standings/result and all
four roster summaries. Shop remained Visit1,4 Cash, Development pack: Used.
After the final catalog guard, a new process reopened the same saved state with
helper `55446a38fefd5cce4425fc9813d4affad38d637124c3838d2365dad9f184c54c`.
Menu exit left the779,448-byte save exactly unchanged at the SHA above.

This did not rerun a full physical match. Historical editor missing-fixture
errors and environment-specific software-renderer/dummy-audio warnings remain.
The inherited shop also retains old Working/proposal labels; those require a
later player-interface polish pass without removing features or original art.
