# Actual returning-recruit qualification harness

This additive inactive test uses unchanged General114 engines. It is not a Dynasty
integration, completed season or playable release. The bounded six-round sequence
and separate final cold verification have now
passed; scope and prior failures are recorded below.

## Actual sequence required

- Standard seed 66, four natural first offers: Ari Banks, Robin Sage, Mika Reed,
  Quinn Riley. No generated offers, money, results or saves are injected.
- Complete the first actual human and two NPC games; buy the naturally generated
  8 Cash stat pack and upgrade Mika with an eligible original stat card.
- Complete three rounds, sign natural fresh Kit Rowan for 24 Cash in Mika's place.
- Complete five rounds, sign natural returning Mika for his original 20 Cash
  contract in Kit's place. Require Mika's exact developed profile, not catchup.
- Complete the sixth actual round with Mika returned; independently reopen the
  saved state in a new process and verify exact canonical recapture.

The stock forecast is synthetic planning, not earned gameplay evidence. Actual
rosters, offers, prices and funds are asserted; there is no fallback stock. Even
six losses supply enough ordinary earned Cash for the stated purchases.

## Boundaries and safety

`tools/test_successor_signature.py --returning-recruit` creates an isolated project,
HOME/XDG state and saves. Each invocation handles birth/draft, one round, or one
shop sequence. Every durable action is archived without overwriting either JSON
or metadata; both are checked by readback. Intermediate boundaries within a batch
are not advertised as separate cold reopens. Final verification is separate cold.

`--returning-recruit-resume-stage PATH` requires identical source and resumes only
that isolated stage. A crash after an operation save but before its immutable
proof sidecar is written intentionally fails closed; arbitrary interrupted-proof
recovery is not promised. Existing owner saves are never opened.

Both recruit signings exercise real quote/Cancel/OK, a prewrite failure, unchanged
owner/lineup/primary/backup during failure, retained candidate, and exact retry.
Repeated commands must not charge twice or recruit again. The original General
handled-ID route may rotate `.bak` on a duplicate; this known limitation is not
represented as disk-write idempotence. Existing source is unchanged.

All six clubs' actual fixture rewards and bank journals are compared. Historical
rosters must show Kit only in games four and five, and Mika in game six. Exact
stored profiles/contracts remain identity-bound; no release Cash or development
transfer is allowed. A forged returning replacement must fail strict restore.

## Evidence status

Native import and actual seed-66 birth/four first-offer draft passed with the
final test source. The subsequent actual gameplay sequence is running; release,
return, round-six use and final cold remain unqualified. An initial isolated stage imported successfully
and was intentionally stopped while adding stronger live-definition assertions;
its evidence is retained and is not a gameplay pass. Full fresh/recruit/return,
round-six, and final-cold assertions must complete before claiming qualification.

### Bounded Cancel timing correction

The first actual run settled three rounds (nine results) and purchased an earned
8 Cash Pitching upgrade for Mika. The natural visit-three Kit quote was correct.
Its first Cancel check failed only because native dialog hiding is deferred:
pending command, owner, canonical state, primary and backup were unchanged.
A separate isolated diagnostic confirmed all six predicates after at most three
process frames, exited successfully before purchase, and verified all 6,476 files
in the original stage unchanged. The original failure is retained.

The test now awaits that bounded hide and propagates the coroutine through its
shop sequence. No product code, save identity, assertions or source fixtures were
weakened. Continuation uses a separate clone with identical production source and
copied earned evidence, replacing only this test script. Three rounds are not
replayed merely to correct a UI timing assertion. Recruitment remains unqualified
until the actual sequence passes.

## Verified final native outcome

The unchanged General engine at `f78b3b481bd54420b79f0f4ca02d19020054e677`
and corrected test at `ca7292931cc92de5bc3414a5b02a92c982ad33a4` completed
the actual seed-66 sequence. Six human games and twelve NPC games settled.
The naturally generated 8-Cash Pitching upgrade stayed attached to Mika through
the paid 24-Cash Kit replacement and natural 20-Cash Mika return. Kit appeared
only in games four/five, and returned Mika actually played game six. Both original
contracts, exact developed profile, lineup position and historical appearances
remained identity-bound; no release Cash or development transfer was granted.

Both real signings passed quote, bounded Cancel, prewrite refusal preserving old
state/lineup/primary/backup, retained candidate and exact retry. All six clubs'
six fixture rewards and complete bank journals matched independent replay.

An environment restart interrupted the first final cold attempt after the
completed sequence had been durably archived. Its primary exactly matched the
archived boundary; unchanged source resumed without losing earned work. The
subsequent dedicated final cold process exited successfully, verified exact
canonical recapture and rejected a forged returning replacement. Final boundary
42 has 18 results, six human games, no pending jobs, and SHA-256
`3c455e114023b5caa87491bc767b1f7cce595a3b2a1729759145a83ac7f5782d`.
Original Cancel-failure evidence and interrupted logs remain preserved.

This qualifies the six-round standalone recruiting/save path only. It does not
qualify a complete season, owned career continuation, Dynasty, final visual/audio
acceptance or a distributable. Original character tuning remains unchanged.
