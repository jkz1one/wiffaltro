# Common V4 Standard D1: qualification only

The private `owner_store.gd::qualify_standard_d1` entry checks the exact
admitted owner and current slot before projecting an intent. It writes
nothing and has no menu, factory, or Next connection. Neither the intent nor
a detached set of title flags is a birth or restore permission.

The qualification currently targets one exact positive case: the active
ordinary side is a just-closed Standard Base champion, with all 33 actual
results admitted by the existing ordinary reader, the complete native
receipt, and the matching latest common fold from that lineage. It refuses
an in-flight save transaction, a stale or mutated owner, unrelated title,
abandoned/incomplete season, unavailable next ordinal, or existing saved
Next proposal. The projected versioned intent includes the native Standard
D1 profile, exact source close and fold, championship proof, lineage, next
ordinal and seed. A future persistence step must bind these against the
authoritative admitted season before it clears the historical close on Next.
Do not treat a captured intent dictionary from callers as evidence.

Standard keeps its empty league rules. Native D1 pricing adds 1 to a positive
reroll quote after credits; zero still costs zero. The successor human Build
and five NPC Builds already have the matching native pricing adapters. Native
Standard D1 also includes venue policy: the detached pricing smoke does not
qualify venue admission, physical results, or D1 cold saves. The Standard
tactical AI `difficulty` value is not the career tier.

## Reproduce the isolated negative and pricing smoke

Assemble a new scratch project and use Godot 4.6.3 with separate scratch HOME
and XDG data, config and cache. No title fixture or player save is used.

```sh
python3 -B tools/assemble_successor.py /new/scratch/project --dynasty-owner
godot --headless --audio-driver Dummy --path /new/scratch/project --editor --import
cp tests/successor_standard_d1_intent.gd.txt /new/scratch/intent.gd
WIFFALTRO_ISOLATED_TEST=1 WIFFALTRO_DYNASTY_ENGINEERING=1 \
  godot --headless --audio-driver Dummy --path /new/scratch/project \
  --script /new/scratch/intent.gd
```

Expect `STANDARD_D1_INTENT_NEGATIVE_AND_PRICING_PASS`. The test creates only
one isolated Standard Base draft, rejects a caller-injected title, and checks
the exact Base slot is unchanged on strict read. It separately drafts four
picks in an unsaved pricing control and checks native human and all five NPC
markets. It does not manufacture or claim a championship.

## Next positive gate

First recover a checksum-verified generated **Standard Base champion V4**
checkpoint if one exists; otherwise start the ordinary Standard Base App on
a new isolated profile and use a bounded producer like the existing Dynasty
completion runner to supply controls only. Leave the original physical
workers and settlement in charge of scores, qualify the exact live title
through native Close, and retain verified generated checkpoints by round.
A lost playoff or eliminated season is valid evidence of that outcome, not
an entitlement; do not seed scores or substitute a native synthetic unit
fixture. Once that title exists, qualify intent, private four-pick
birth/Next and cold reopen before doing a full real D1 round/shop and D1
completion. No new D1 selector access is enabled here.

## Detached native D1 reference

The additive `standard_d1_detached.gd` adapter constructs an in-memory
Standard D1 session through the existing native Standard live factory. It
derives its grant by strictly normalizing a native admission history; it
does not accept a raw grant, a title flag, or a caller-selected alternative
profile. No runtime entry, Common V4 writer, selector or Next code calls it.
A native detached session is not a Common V4 admission record or save.
The genuine Common V4 Standard Base title remains the gate for future entry.

The isolated test supplies a clearly synthetic native history only inside
`tests/successor_standard_d1_detached.gd.txt`. To reproduce, materialize the
source as above, copy the test to `detached.gd` in the scratch project and
attach it to a one-Node scene. Launch the scene with Godot 4.6.3 headless,
Dummy audio, isolated HOME/XDG roots and `WIFFALTRO_ISOLATED_TEST=1`.
Expect `STANDARD_D1_DETACHED_PASS`. No Common V4 or Original Game slot
should be present before or after.

The sample seed 39201 uses the same owned Backyard home descriptor as its
native Base counterpart. D1's separately assigned five NPC venues are
AC-02, AY-02, AY-03, AC-01 and AE-01 by club index 1–5 (two backyard,
one expanded, two club). The neutral-final recipe is Grand I with the exact
`standard-d1-season` selection, distinct from Base's selection (not a
different Grand stadium level). It checks four native draft choices,
human market 0 and all five NPC market 12 D1 pricing policies, unchanged
tactical difficulty, and refusal of no-title/wrong-profile/foreign-grant
cases. This is a detached native reference, not a rendered match,
Common V4 D1 start/persistence, shop purchase or unlock proof.

### Exact native fixture identity and the Common V4 bridge

The detached adapter can now observe one versioned identity for an exact
native scheduled fixture: the schedule row, field ID, canonical venue
key, and native request key. It verifies the detached context and
reconstructs those values from the native runtime. A JSON round trip,
a self-consistent caller hash, or the detached grant cannot qualify
Common V4. The test checks actual authored home and away fixtures, rejects
changed version/field/venue/request/fixture/tier, and confirms a substituted
detached SeasonState is refused by the existing Common V4 capture and
writer. A not-yet-scheduled neutral final is refused, not treated as a
playoff fixture. No legacy stadium or request dialect was changed.

The next integration should be a **new Standard D1 Common V4 draft/first
round envelope**, not another detached descriptor. Bind its tier and prior
championship to the exact matched Common V4 owner at normal Next, retain
the proof at ordinal transition, and reconstruct the admitted home/away/
final venue policy from that frozen start. Admit only this new envelope
in the materialized ordinary codec. The existing Common V4 request builder
must consume the same canonical field and venue when issuing the successor
pitch-catalog request and when matching the worker report; do not use the
older detached native request digest as a fallback. Verify a genuine D1
draft and strict cold reopen, then actual human and worker games, one
shop price and exact settlement/cold. Keep Base, legacy reads and public
selector closed to D1 until those gates pass.

## Authoritative Common V4 transition envelope, still write-closed

`OwnerStore.prepare_standard_d1_transition` is read-only. It requires the
exact admitted live owner, current slot bytes and no retained write, then
uses the Standard D1 intent's same-lineage championship verification. It
freezes the ordinary Common V4 projected start together with a versioned
entitlement: prior close ID, fold, exact native championship receipt and
proof, new ordinal, seed and authored Standard D1 profile. The nested
start digest and sequence must match the retained fold. The CP174 Base
start schema and normal next-season operation are unchanged.

An envelope can be shape-valid without being authorized. The Store
comparison rederives it from the actual matched owner, never from a
caller claim. A synthetic, structurally valid champion sample is tested
as a non-authoritative input; direct proposal/capture/write still fail.
The current Common V4 ordinary codec admits no such start and no Next
transition has been enabled. Positive authority still requires an actual
same-lineage Standard Base championship.

To reproduce the boundary, copy
`tests/successor_standard_d1_transition.gd.txt` to a scratch Node scene
in the Common V4 assembly. Run with Godot 4.6.3 and the same isolated
flags as the intent test. Expect
`STANDARD_D1_TRANSITION_SHAPE_AND_NO_WRITE_PASS`. The only created save
is an ordinary Base draft; the synthetic D1 envelope never writes.

For the later physical adoption, the Common App must expect the authored
D1 venue rather than empty ordinary stadium, and pass the season into its
worker field lookup. The General physical request builder still rejects
nonempty stadium. Report114 wrap can produce a venue entry that its
validator rejects, and the ordinary cold report shape still requires
no-venue keys. Keep existing Base114 exactly unchanged: use a separately
versioned D1 successor request/report/cold path binding field and
canonical venue. The native `src/tests/standard_d1_physical_pending.gd`
away-yard assertions are a field oracle, not authority to accept native
Report17 as Common V4 evidence.

## Materialized Standard D1 draft, production admission still closed

The real materialized ordinary Runtime now constructs and drafts the D1
successor build under the versioned transition envelope. It records the
career tier in the existing progress row, while Standard's league-rules
dictionary stays empty and tactical difficulty stays unchanged. The
ordinary codec has a separate, explicit draft format with the same
canonical state/build reader and a bounded replay of up to four visible
draft picks. It retains the complete transition envelope and rejects
changed proof, foreign draft order, and any game history. It also refuses
a D1-priced Standard build relabeled as an ordinary Base envelope.

This version is deliberately playable only as a draft in the isolated QA
driver. The normal Common V4 reader/scope, legacy reader, save writer,
match start, physical settlement and shop reject it; no selector or
Next path calls the new factory. Native venues remain a separate physical
adoption step and this draft does not assert rendered field behavior.

For the smoke, assemble Common V4, stage
`tests/successor_standard_d1_transition.gd.txt` at `res://transition.gd`,
and attach `tests/successor_standard_d1_materialized_draft.gd.txt`
(as `res://materialized.gd`) to a scratch one-Node scene. Run Godot 4.6.3
headless with the isolated and engineering flags. Invoke `-- draft`
then `-- cold` in a separate process with the same disposable profile.
Both report the exact test JSON digest. The QA JSON is separate from the
game slot; the synthetic history is used only to test deterministic draft
serialization. It never writes a Common V4 or Original Game save.

**Store adoption:** once a genuine same-lineage championship can be
admitted, the native Next producer must obtain the transition from the
matched Store owner and write the D1 draft plus its versioned lineage
transition as one CAS operation. Strict cold must requalify the archived,
authoritative Standard Base championship evidence before invoking the new
draft reader; the embedded shape-valid score summary and digest are not
sufficient, and the rotating `.bak` is not a durable proof store.
Carry only the validated proof required to replay that admission (retain the
canonical closed source until a smaller exact proof is validated). Reject
fabricated and wrong-lineage proof on read/write and independently verify
the same closed source across the real four-pick saved successor. Only
after this establishes real custody should the previously documented
D1-specific venue/report path enable the first physical round.

### Exact closed-source witness

The private Store proof builder verifies the admitted in-memory owner and
the exact current bytes (including a second match after compression). It
returns only a proof bundle, never a write ticket. The bundle carries a
versioned Base64 DEFLATE frame with the exact closed Common V4 source, its
byte length, and its SHA-256. The reader caps the encoded field at 8 MiB
and output at 64 MiB before decoding/inflation, verifies exact decoded
size and digest, replays through the same strict `Owner.restore` used by
the normal Store, and rederives the title, receipt, lineage and next-start
basis. A witnessed D1 draft is accepted only if its whole transition
exactly matches that result. A valid digest is not evidence of a title.

The next Store increment can write this witness and D1 draft together as
one private, versioned CAS transition. It must call this strict witnessed
draft reader, not the draft-only QA reader, for cold admission and retain
the exact witness alongside later active drafts. No path reads a backup
as the witness, creates a Store slot with a witness, or adds a selector
here. A genuine Standard Base champion is still needed to qualify
positive end-to-end custody. During cold replay, both current and any
parked session in the retained source receive the original strict
validation; no performance claims about a title or paused side follow
from the semifinal control.

To reproduce the negative control, assemble Common V4 and stage
`successor_standard_d1_transition.gd.txt` at `res://transition.gd`; attach
`successor_standard_d1_closed_witness.gd.txt` to a one-Node scratch scene.
Use only a copy of the audited CP170 generated closed Base pair in an
isolated profile. Run the scene in separate processes with `-- replay`
and `-- matched`, with isolated and engineering flags. The first reports
exact source size, witness size and strict cold replay milliseconds. The
second reports separate normal Store cold and already-admitted match
denial timings; neither run modifies the source or predecessor.

Measured on the Linux x86_64 cloud sandbox (reported AMD EPYC 9V74,
9 available logical CPUs), Godot 4.6.3 official headless: the exact
7,701,400-byte closed semifinal source produced an 889,044-byte witness
JSON. Strict cold witness replay took 24,452 ms; the separate fresh
process normal Store read of the same source took 26,425 ms. The three
warm matched/incorrect-request denial probes together took 805 ms.
These are single runs on a non-champion fixture, not a production target.

Keep this replay off the interactive UI frame. Admit once per exact
profile/slot revision at cold load and reuse only an in-process object
admission invalidated by a changed primary, failed CAS, or changed
candidate; do not persist or accept a replay-success flag. Future
performance work can separately qualify a versioned smaller replay
source against the authoritative full cold path before changing it.

### Off-frame source-engineering process

The private Common V4 source-engineering controller can run the same
strict current-slot proof replay in a separate headless process. It
reuses the fixed per-token JSON job transport and the same Godot
executable; no Godot API is called from a new thread. The controller
supplies the exact current primary digest and a seed, not an arbitrary
path. The worker reads that same fixed slot read-only, checks the digest,
builds the bounded witness, runs strict replay and rederives eligibility.
The controller polls while the parent loop stays live, matches the exact
versioned request, checks the current slot revision again and requires
the expected child exit status. Cancellation and timeout discard the
result and stop the child; completed/cancelled jobs clean transient files.

This checkpoint exposes only a diagnostic refusal after a valid strict
replay of an ineligible source. It has no code that publishes a
successful eligibility grant, reads an archived future D1 owner slot,
or mutates a career. It rejects a positive JSON claim even if the
envelope shape is plausible. Do not treat editable job files as
authoritative evidence or use this as a trusted-cache mechanism.
A later private positive Store path needs a genuine title and a reviewed
successful child result channel bound to the exact request and input
revision; the parent must remain the only writer. The source-only worker
has no packaged launch dispatch or public menu binding.

For QA, assemble Common V4 and attach
`successor_standard_d1_witness_process.gd.txt` to a scratch scene. Use
separate process invocations with the isolated and engineering flags
and an isolated copy of the generated CP170 closed semifinal pair.
The QA modes are `-- replay`, `-- cancel`, `-- forged`, and `-- stale`.
The stale case temporarily moves only the disposable test primary and
restores it before the final hash checks.

### Private App cold check

With `WIFFALTRO_STANDARD_D1_CHECK=1` in the source editor engineering
route, an unloaded App with an existing Common V4 primary shows
**Private Standard D1 Championship Check**. It is separate from
**Continue Saved Career**; default, packaged and legacy launch behavior
is unchanged. The App starts the worker directly, temporarily replaces
the cold menu controls with a cancel button, and displays refusal, stale
or cancellation notices. It never loads an owner, calls normal Store
restore, or unlocks/starts D1 from this action. Closing the window first
cancels the worker and then uses the normal quit action.

For headless App QA, stage
`successor_standard_d1_app_witness.gd.txt` as a one-Node scratch scene
in a Common V4 assembly. Copy the audited generated CP170 closed Base
pair into a disposable profile and enable the isolated and engineering
flags. Run five separate invocations with `-- cancel`, `-- close`,
`-- refused`, `-- stale`, and `-- normal`; turn the extra check
flag off for the last invocation. The runner dispatches actual App
button signals, menu render, and the standard window-close notification
(only the final quit action is intercepted). Normal Continue separately
checks the existing strict Base admission.

For positive consumption, replace editable reply files with a private,
bounded, length-framed stream from the exact child launched with Godot
4.6's nonblocking [process pipe](https://docs.godotengine.org/en/4.6/classes/class_os.html#class-os-method-execute-with-pipe).
Drain stdout and stderr while the child runs, verify exit status and
exact version/nonce/slot revision/seed/basis, reject extra frames, and
expire the single-use admission on cancellation, timeout, App close,
owner replacement or changed slot bytes. No result is durable and
editable saves still require fresh strict replay. The parent alone
performs the final exact-revision CAS after deterministic D1 structural
hydration; it must not run a second full owner replay on the menu frame.
The pipe and a real title's successful private Store consumption still
require validation before this can write a draft or grant access.

### Private positive-capable pipe

On the Linux source-editor route, the verified child executable now
receives the canonical request on its command line (format, nonce, fixed
slot digest and seed only; never save bytes). The parent uses directly
attached nonblocking stdout/stderr pipes rather than any result file.
It accepts exactly one canonical response frame (16 KiB total cap),
matching request plus exit code, no extra data or stderr, and a still
matching primary revision. A qualified frame must also pass the existing
transition contract and retain the exact seed. The App holds it only for
one private, 30-second, generation- and byte-revision-bound handoff;
another check, restore, navigation into another career, or window close
discards it. No consumer currently writes a draft or exposes D1.

The shaped positive protocol fixture is parser-only, does not come from
a title, and never enters the App or Save Store. The actual replay
fixture remains the generated eliminated Standard Base slot for which
the separate worker can only refuse. Test that a planted, well-formed
legacy reply file plus dead worker cannot qualify, as well as stale,
duplicate, oversized and wrong-nonce cases. A genuine title must still
qualify the positive transition in-process before adding the parent-only
Store CAS. The retained closed witness must be persisted atomically
with the ensuing private draft and verified again on future cold loads.

### Materialized opening-away physical preview

The isolated D1 QA can draft four authored players through the
successor runtime, replay that exact draft, and prepare fixture 0
only when the player club is scheduled away. The live materialized
match constructor supplies the team builds and successor pitch
catalog. A separate native venue context derives assignments from the
retained career ordinal, seed, and authored schedule; the local
materialized ledger's internal run number is not the venue ordinal.
The preview mounts the normal Pitch/Bat Lab against that exact
fixture, and uses the Common human evidence capture with the bound
venue and pitch catalog rechecked at the actual match outro. Native
detached report 17 is not used.

For QA, assemble the private Common V4 sources, stage the transition
QA helper at `res://transition.gd`, and attach
`successor_standard_d1_opening.gd.txt` to a one-Node scratch scene.
Use an empty disposable save profile with the isolated and engineering
flags, Godot 4.6.3, and `--headless --audio-driver Dummy --fixed-fps 60`.
For this isolated source-only test, copy the exact tracked stock
`project.godot` into the scratch assembly and select the QA scene
explicitly; the source gate must pass with no code or pin substitutions.
The regular additive launcher config changes the raw project bytes and
its AE-01 mount refused the unchanged native gate. This is not
qualification for the integrated launcher or exported package.

The prior-title shape is synthetic and cannot authorize or save;
physics, output score, and evidence are real. The test compares the
same seed/ordinal/fixture venue key to the independent native CP174
oracle and rejects Base, wrong fixture, unfinished and wrong-venue
capture. That oracle had native run ordinal 3, which only the QA
fixture mirrors; a run-2 preflight correctly produced a different key.
The adapter derives the ordinal from the validated transition, never
from that fixture constant. No retired source, slot or public path is changed. The default smoke
stops at the first completed native plate appearance and checks that
no result can be captured before the outro; `-- full` is an optional
long running capture probe. Source-headless step wall time is not
native frame rate, package timing, or device performance.

First cold/worker bridge: define a distinct Standard D1 Common pending
format only after a genuine title can admit the prior-witness and
draft. Bind its captured human row to this exact field/venue and
catalog. Derive each NPC field from the same venue epoch rather than
supplying a saved layout. Add a D1 successor request/report dialect for
venue-bearing NPC reports and independently cold-check the complete
receipt before the existing transaction settles it. Do not pass the
native Report17 or venue-bearing data through ordinary Base Report114.

A separately instrumented source run completed this same opening matchup
5–3 on AE-01, with 168 releases and the Common human evidence hash
`cce442be3809cbd16b9caaaa18d45def076c6802b462842d555141f07131cc2f`.
The final recorded sample was 13,700 physics ticks, with about 209 seconds
of loop time after setup on the headless Linux worker. The test's regular
bounding mode independently completed the first plate appearance in 353
ticks. This was source gameplay and capture only: no save, NPC round
settlement, playable public D1, packaged startup, or Mac performance result.

### Source-preserving private startup recipe

The optional assembly mode below keeps the raw authored project bytes in
the initial output and manifest, rather than rewriting the main scene.
It rejects any configuration whose SHA-256 differs from the existing
reviewed source pin. The manifest records the Original default scene
separately from the explicit private Common V4 scene. Legacy assembly
modes and the export builders are unchanged.

```sh
python tools/assemble_successor.py --dynasty-owner --preserve-authored-project "$stage"
# Use a disposable separate HOME and XDG_DATA_HOME, XDG_CONFIG_HOME, XDG_CACHE_HOME.
WIFFALTRO_DYNASTY_ENGINEERING=1 godot --path "$stage" \
  res://src/presentation/season/successor_dynasty_owner_v1/launcher.tscn
```

The default scene with no explicit scene is still Original. Explicit
Common startup with the engineering flag off refuses. The source
recipe uses the actual stock files; it does not change the stadium
guard or assert alternative reviewed hashes. The existing private
worker uses the same executable/project path with its explicit worker
scene, and a separate D1 NPC worker still needs its own dialect and
qualification. No public D1 or packaged startup change.

The QA wrapper `successor_common_authored_startup.gd.txt` extends the
opening QA harness: stage the three scripts at `res://transition.gd`,
`res://opening.gd`, and `res://startup_qa.gd` and attach the final
script to a scratch Node scene. It first starts the actual explicit
Common App scene and verifies its live menu, then finishes the first
real AE-01 plate appearance against the unchanged gate. Launch the QA
scene explicitly under the same engine/project with the headless flags
above; do not rewrite the project after assembly.

### Venue-bearing NPC workers

The first D1 source-engineering request/report path qualified
opening-round NPC fixture 1 from an exact replayable four-pick D1
draft. The same-binary child launches its explicit scene in the
source-preserving project. It independently restores the draft and
rederives the scheduled clubs, native venue epoch/field/key, engine
seed, and successor pitch catalog from that input. No arbitrary scene,
stadium snapshot, or match-state override is part of the request.

At actual game end the child uses the successor baseball core and
validates native mounted geometry, contact rows, body provenance,
rosters, pitch recipes and workload capacity, with the full request
binding retained in the separate D1 report. The shared core validator
checks the baseball facts using its existing field-neutral convention;
the outer D1 contract independently validates the actual public field
and authored geometry. No native report17 or ordinary Base114
envelope is emitted, accepted, or changed.

Assemble with `--dynasty-owner --preserve-authored-project`; mount
`successor_standard_d1_npc.gd.txt` as a scratch QA scene with the
existing transition fixture staged at `res://transition.gd`. Use the
source editor executable and an empty disposable profile. The parent
uses the existing bounded local job transport and checks the exact
request digest, worker exit, and report independently; these files are
evidence only, not writable or persistent game authority. No Common
slot, title entitlement, pending save, settlement, or selector.

The isolated child finished Comets 9–2 over Rivets at AC-02. The
accepted report contains 154 releases and aligned surface rows; eight
rows contain recorded stadium events. Its canonical evidence SHA-256
is `dcbcbf9e7a8d7c101e6cf533d7e2c17c172ce0bef0f9ef649fba429e8d741374`.
The headless Linux child took about 411 seconds including setup;
its physical loop took about 356 seconds. No target device frame rate
was measured. Altered venue, stale draft, and old/relabelled report
formats did not pass validation.

The second opening NPC fixture uses the same D1 envelope, with an
explicit fixture-ID allowlist (1 and 2 only) and a separate contact
route for fixture 2's authored AY-03 r1. Its exact scheduled teams,
draft digest, stadium key and derived seed still form the request.
The native AY-03 geometry installation and its yard-specific contact
and provenance validators are required; that is not permission to
accept a legacy Report16, a public fixture-1 report or an arbitrary
later match. The fixture-1 request and report format are unchanged.

The `successor_standard_d1_npc_two.gd.txt` QA scene takes the two exact
CP183 raw request/response paths as arguments. It verifies both hashes,
reconstructs the same synthetic-authority draft, revalidates fixture 1
without replaying it, then starts only real fixture 2. Cross-fixture
and venue transplants reject. No shared save or settlement is produced.
The earlier complete human run retained a digest/log, not the row;
the next human run should capture directly into an isolated pending
format once that format is ready.

### Isolated opening pending envelope

The detached `common-standard-d1-opening-pending-v1` envelope carries
the original CP176 draft, exact human capture, and the two separately
retained, ordered D1 NPC reports. The current draft is reconstructed
rather than accepted by hash alone. Each of the three fixtures derives
its exact field, venue and successor catalog again. Human evidence
must have the existing Common field-independent result/called shape
and exact rosters. The NPC reports revalidate their full baseball
core and each venue-specific contact/provenance contract. Wrong,
reordered, repeated or transplanted results are rejected.

The extra human checksum protects transport identity, not genuine-title
authority or arbitrary edited scores. The original human row originates
at the native outro and is stored separately before assembling the
pending envelope. Canonical cold validation reopens the full evidence
without admitting it through either existing game reader. The QA file
uses a new scratch-only name, a size cap, and an atomic new-file rename;
it cannot replace a career slot. No round settlement, payout, calendar
advance, normal Continue, or public D1 entry uses this envelope.

For QA, stage the existing transition and opening QA scripts as
`res://transition.gd` and `res://opening.gd` and attach
`successor_standard_d1_pending.gd.txt` to a separate scratch Node scene.
Use the authored-project assembly and isolated/engineering flags.
Pass `-- preflight <fixture1 request> <fixture1 response> <fixture2 request>
<fixture2 response>`; repeat with `full` for the one real human match
and `cold` in a distinct process with the same disposable profile.
Both worker inputs are fixed by their audited raw hashes and never
rerun in this test.

A later settlement must preflight both NPC reports (including committed
sponsor/choice policy, opening stamina and exact per-club tactics and
performance) before applying anything to a detached candidate. Existing
legacy machinery can append the first result before a later report
fails. Prove a corrupt second report leaves original pending bytes and
all six reward journals unchanged, then verify three real results and
all six rewards exactly once on the successful path. This checkpoint
does not implement or test any of that payout logic.

### Detached opening settlement

The opening projector reads the full pending evidence, preflights both
NPC reports against the exact committed sponsor/choice and tactical
policy and each player's opening workload, and only then enters the
ordinary native human result and round accounting on a fresh, detached
D1 candidate. The scoped resolver yields the two validated NPC rows
in native order, with enriched tactics and full performance. No match
is run. Native round completion, opponent accounting and progression
produce the three rows, next round and all six wallet journals. The
projector refuses anything other than one native reward per club and
preserves all other ordinary journal behavior.

The output is a separate private settled receipt, not a career
checkpoint or live title. Its cold reader rederives the exact receipt
from the immutable pending bytes instead of trusting a recorded
settled flag or fabricated balance. Passing a receipt as pending
cannot run settlement again. The test-only writer uses a new isolated
file; cancellation just drops the detached proposal; retry writes
only once. No shared Store, public Next, league admission or shop
window is enabled.

For QA, assemble with the source-preserving flags and attach
`successor_standard_d1_settlement.gd.txt` to a scratch scene. Run
`-- settle <exact CP185 pending>`, then `-- cold <exact CP185 pending>`
and `-- repeat <exact CP185 pending>` in separate processes with the
same disposable profile. The input remains read-only throughout.

### Detached opening market and checkout

The exact prior CP185 pending input and CP186 settled receipt must both
replay before the detached shop can run. Settlement leaves visit 1 closed;
the shop invokes the normal eligibility rule and the native zero-cost
`open` transaction before deriving authored offers and pricing. The
bounded checkout accepts an exact reviewed eligible loose development card
and uses native Buy and Hold, not a new cart, a general shop API, or a
change to the Common public gate. Stale revisions, changed quotes and
same-state repeat purchases do not apply; cancellation discards the
detached candidate. Only the QA test writes an isolated receipt.
Cold replays both prior inputs, the verified native opening and the
single checkout, and compares the entire journal-backed result. All
six pre-shop reward events remain exactly once; the archived reward
balances are historical, not post-purchase balances.

Use the source-preserving assembly with a scratch scene attached to
`tests/successor_standard_d1_shop.gd.txt`. Run
`-- buy <exact CP185 pending> <exact CP186 settled>`, then independently
`-- cold <same pending> <same settled>`, with isolated and engineering
flags. No matches, native cabinet/cart UI interaction or shared slot
writes are part of this test.

The exact opening market exposed Pitching Development at 6 game Cash.
Native checkout held the card, changed Cash from 18 to 12, and consumed
its exact offer. The separate reroll comparison charged 5 game Cash
instead of the positive ordinary quote of 4; it did not affect the
purchased branch.

### Exact admitted Store preparation, not shared-slot writing

The private Common Store now has an internal D1 CAS prepare path.
It accepts only the *already admitted* owner object and its exact current
slot bytes (no caller draft, title flag or IPC packet). Existing owner,
disk bytes, raw snapshot and idle-ticket predicates must still match
after materializing the zero-pick D1 draft. The candidate uses a new
versioned dialect with the exact compressed prior Common career as its
sole source of parked state and metadata, and a canonical stamp over
the witness and draft. The stamp only detects inconsistency; it cannot
confer title. The cold replay contract independently recovers both the
prior owner and fresh D1 draft and rederives actual championship rights
with a single strict prior owner restore. Ordinary Base and legacy reads,
copies, writes and paths are unchanged.

There is deliberately no generic write ticket or D1 runtime owner binding
yet. Ordinary Continue rejects this dialect, and the existing raw guard
is not bound to its witness; replacing the active save now would make it
unreadable. The next writer
gate needs an off-frame same-binary strict reopen and safe adoption of
both verified sides without another strict prior replay on the UI frame,
plus exact candidate/slot readback and promotion. Compact IPC transition
data is not sufficient authority. No authentic title has been observed.

On the isolated exact eliminated Base/backup pair, attach the closed
witness test as before. Run `-- matched`, `-- durable`, and
`-- durable-cold` in separate processes. The first rejects the exact
eliminated owner, stale backup and absent owner at the real prepare
boundary. The latter two test canonical stamp rejection, byte-exact
retry/readback at a distinct QA path, then strict rejection of a
correctly stamped but unauthorized witness. Also run the real App
witness refusal with `WIFFALTRO_STANDARD_D1_CHECK=1`.

### Private asynchronous Continue, read-only

The D1 candidate has a fixed, bounded version prefix before its canonical
stamped payload. There were no live slots in the previous unprefixed QA
dialect. The family takes precedence over ordinary Continue: unsupported
or flag-off attempts show a read-only message; the occupied menu hides
fresh/copy/alternate launch actions, and the ordinary Store writer refuses.
Ordinary unprefixed V4 Continue is unchanged.

With the existing private Linux editor flag enabled, real Continue spawns the
same executable on the existing private pipe with a separate request purpose,
nonce and exact primary SHA. The child bounds input, checks the stamp, strictly
replays the prior owner, and rederives the D1 entitlement once. Only the
exact child may report refusal or three digest identifiers; it sends no draft,
player or parked-owner metadata. Parent revision, identity/epoch and
cancellation gates discard stale results; there is no second Store restore,
saved trust, shared writer, owner publication, or four-pick UI. Even a
qualified response currently only reports verification; it cannot arm a save.

The isolated App regression covers flag-off, unsupported version, wrong
stamp, exact stamped eliminated witness, cancellation and stale revision.
It asserts the Common primary/backup and old-format behavior remain untouched.
The digest-only positive parser sample exercises shape, not actual entitlement.
