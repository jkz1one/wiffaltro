# Materialized live progress summary (checkpoint72)

Parent: verified checkpoint71 `9d532c44ace3c2df14861d6d2cd75d2f9076dccc`.
Status: checkpoints72 and73 were independently verified on the recovery branch.
Checkpoint72: `a8e8b65cd67a1b682ed3de08c424b930b70bd209`; checkpoint73:
`af4ed0d6aa96d47b565428ed5e35aa88db0a5771`. These are scoped performance
checkpoints, not a completed game or target-platform release.

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

## Checkpoint73: private live transaction admission

Parent72 is remotely verified at
`a8e8b65cd67a1b682ed3de08c424b930b70bd209`.
Status: all 11 final targeted regression processes and native smoke passed.
Exact11 audited files, remote parent and every published byte/hash were
independently verified at `af4ed0d6aa96d47b565428ed5e35aa88db0a5771`.

The same119 schema, save slot and frozen gameplay remain unchanged. A private
Store session now binds the strictly read owner to its exact primary bytes and
complete native raw snapshot. Preparation performs one full semantic candidate
capture, retaining its canonical payload and separate exact raw snapshot under
an opaque identity token. The App cannot supply a validated payload to this
writer. Exposed diagnostic copies are detached and carry no authority.

Raw snapshots explicitly include all six builds, player books, wallet catalogs,
hidden shop state, AI metadata, career and physical state. Named factories and
known-field allowlists refuse unknown object state. Equality preserves native
number/key types, StringName identity, typed Array/Dictionary metadata and
readonly flags. Bounded deep copying rejects arbitrary Objects and pathological
nesting. This private equality is deliberately stricter than JSON save equality.

A failed write retains the same private candidate. Saved candidates do not
become the admitted current owner until the App's original owner/lab/cleanup
checks and Store's final raw/disk checks pass. Saved retries do not rewrite or
close a replacement lab. Strict generic Store.save remains available and fully
validates its operand; successful generic saves or reads invalidate stale tokens.
No caller-controlled trust flag or alternate public payload writer was added.

The final actual Shop tests assert exactly one semantic Codec.capture during
paid-open and paid-choice handlers, and zero during exact retry. Cold reads
remain fully validated; those assertions do not claim no validation at cold.
The final same-choice handler measured 3,205ms, versus 72’s 7,572–9,996ms observed
runs. Faulted paid-open measured 2,222ms. These are shared-cloud wall-clock
observations, not controlled target-hardware benchmarks or a responsiveness pass.
Final earned cold reopen measured 1,080ms, with primary and backup unchanged.
The full paid-choice result remains byte-identical to genuine71 boundary0007
(SHA256 `72e26e0cbf762162a1e78f9ef3fccdff396dfe816ba9fb677434c92f3350fc56`).

The focused tests cover private token/owner/expected-byte identity, refusal of a
second preparation, hidden owner/candidate/AI/catalog changes, native type and
key changes, detached nested readonly copies and typed containers, external CAS
replacement, prewrite failure and exact retry, corrupted diagnostic payloads,
once-only promotion, and stale admission after generic save/read. The original
cleanup callback and fresh/import paths are rerun on the exact source. A separate
callback test reuses preserved genuine71 NPC evidence to qualify async raw pins
and retained saves without pretending another physical game was played.

Both Standard and Dugout genuine fresh creation, four choices, prewrite retry,
changed-primary refusal and separate cold reopen passed through the actual
launcher. Copied nonempty old saves remained unchanged. Explicit pristine118
import and both original file bytes were preserved. Final cleanup callback
probes and the recorded genuine NPC callback passed; the latter reproduced
its original pending snapshot bytes exactly. Native smoke is a separate gate.

Native73 used a separate isolated QA73 name and a copied genuine71 final save.
Two cold opens preserved round2, Comets at Yard Club, standings, the four-player
roster and Shop Visit1 with4 Cash and Development pack Used. Return-to-season
and clean close succeeded. The779,448-byte primary remained exactly
`72e26e0cbf762162a1e78f9ef3fccdff396dfe816ba9fb677434c92f3350fc56`.
All32 manifest source hashes still matched. Native game logs contain only known
graphics/software-renderer/audio fallback warnings, no GDScript errors. This
smoke made no purchase and played no physical match; it is not target-platform
or distributable qualification. Original QA72 source/save were untouched.

## Frozen 75 endurance: correctness is not responsiveness

The isolated current-Dynasty endurance run reached seven settled rounds with
21 actual results (seven human, fourteen NPC) before the 76 checkpoint audit.
Every boundary retained its raw physical result, predecessor, paired save and
separate-process admission. The round-seven save was 5,034,148 bytes. This is
not a completed-season, natural-terminal, or carried-next-season result.

A controlled fixed-60 headless experiment compared the same preserved actual
NPC request and predecessor with the normal run. The recursive report diff had
one differing leaf, `physical.elapsed`; scores, plays, workload, accounting and
profile results matched. The fixed-60 run took 17,780 ms. This permits faster
functional endurance, not a player-build setting change or realtime/native
performance claim. The complete duration difference remains in private evidence.

Measured blocking costs grew with the current-season payload:

| Save boundary | Paid pack open | Paid choice | Cold admission |
| --- | ---: | ---: | ---: |
| Round 3, approximately 2.20 MB | 6,707 ms | 7,538 ms | 2,994–3,912 ms |
| Later approximately 3.58 MB save | 9,028 ms | 9,417 ms | approximately 4,300–4,700 ms |

These are shared engineering-environment measurements, not target hardware
benchmarks. Explicitly overlapped native/diagnostic intervals are excluded from
the timing claims. Functional outcomes passed; these blocking times do **not**
qualify acceptable responsiveness.

Read-only call-path review found seven full-owner raw snapshots and six raw
comparisons per successful paid transaction, plus strict candidate capture/validation and
multiple serialization passes. Native shop refresh additionally forks a build
twice per visible quote. Planned optimization must retain exact hidden-state,
disk-CAS, retry and post-cleanup callback checks. Combining only synchronous
Store-owned preparation and initial write, and comparing live state directly
against private snapshots, are bounded candidates; neither is implemented or
performance-qualified by this checkpoint. Removing gameplay depth or discarding
required outcome evidence is not the proposed remedy.

## Checkpoint77: preserve save authority without repeated deep copies

Parent76 is verified at `d69e8d08d14d959a0148e732f21f2c8fe605e965`.
This increment changes only three runtime files in the existing Dynasty family.
A direct live-graph/private-snapshot comparator replaces redundant detached
captures. It retains native key/value types, typed and readonly container
metadata, exact factories/known fields, hidden catalogs and AI state, finite
numbers, and the original global depth/node limits including virtual wrappers.

A Store-owned synchronous prepare-and-write path removes only the two immediate
rechecks with no intervening callback. Later retries, disk compare-and-swap and
readback, and post-cleanup owner/candidate checks remain strict. Diagnostic
snapshots are detached copies materialized only when requested. No save schema,
physics, economy, reports, planned feature, or historical evidence was removed.

Paired sequential measurements use the same genuine nine-round Dynasty save:
6,381,991 bytes, 27 results and nine human games. Full result main/backup files
for import, paid pack reveal, paid choice and separate cold reopen are identical
between76 and77. Final save:6,386,308 bytes, SHA256
`cca8677714c7e5eafdd57f07cd882b5a39c72ba32a01c8dced8e13e22988224c`.

- Paid pack confirmation including refresh:16.103s to7.939s (50.7% reduction).
- Paid choice including refresh:17.024s to8.778s (48.4% reduction).
- Full initial Shop refresh:17.092s to9.318s (45.5% reduction).
- Final strict cold read:7.543s to7.844s; no improvement claim.

These are one sequential sample per action on shared cloud hardware, not a
statistical or target-device benchmark. Eight-to-nine-second paid actions and
cold loading are still too slow for final responsiveness. Shop preview work and
remaining semantic capture/serialization remain follow-up targets, not excuses
to prune the game or bypass validation.

Final focused CLI gates cover independent frozen-comparator adversarial parity,
actual fresh four-pick creation and separate cold, hidden owner/session changes,
cleanup callbacks, busy barriers, detached diagnostics, close/Next cancellation,
stale disks and identities, prewrite failure/exact retry, and duplicate actions.
Earlier test-harness parse failures are retained separately and are not counted
as successful runs. Native shop qualification is recorded in the family's
qualification document. This is not full Dynasty, all-league, or release proof.
