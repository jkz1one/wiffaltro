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
