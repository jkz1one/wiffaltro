# Integrated Dynasty: first Workshop save boundary

This is a draft-only source milestone for the private Common V4 route. An
eligible Dynasty player can save the starter backstop chair at Primary
Receiver before their first pick, or between Close and a Next proposal.
It costs nothing and explicitly does not change the field. No Apply button,
paid catalog, Club Buck grant, or Dynasty match geometry is enabled here.

The only new wire data is an optional Dynasty-lineage-bound starter layout.
When absent, the exact prior V4 shape is unchanged. The dedicated Common V4
Store operation derives a native starter copy and validates the draft in a
detached, zero-credit construction ledger. The live session, parked session,
and all other saved data stay unchanged. Generic candidate edits and unbound
legacy writers cannot introduce or erase the draft. This route never calls
the Original Game save writer.

## Native checks

The source-assembled project ran the actual App and Store in headless Godot
4.6.3 under a disposable profile. The Workshop save, exact retry, Continue,
and mode switch tests emitted signals on the existing controls; this is not
a rendered clicking or input-device qualification.

- A fresh Dynasty starts without the optional field. A blocked save retains
  the same candidate, original primary and backup; the exact retry promotes
  once and backs up the predecessor. Stale inputs, a forged unpaid copy,
  a wrong lineage, and generic introduction or erasure were refused.
- A cold process reopened before first pick without writing. Four normal
  picks restored the existing switch eligibility. Creating a separate
  Standard session, drafting four players and resuming Dynasty preserved
  both exact session payloads and the Workshop draft. A second cold process
  reopened without applying the draft or changing either slot.
- A separate copied, previously verified synthetic career had one settled
  Dynasty round, an earned shop purchase and a parked ordinary session.
  The regular-season draft command was refused. Abandon/Close admitted the
  draft; Prepare Next and Next carried it into Season 2 with four players,
  zero new results and the ordinary snapshot unchanged. A cold process
  reopened Season 2 with no field projection and no writes.
- A disposable Original Game sentinel stayed byte-for-byte unchanged.

To reproduce the first path, assemble using `tools/assemble_successor.py`
with the `--dynasty-owner` flag. Copy
`tests/successor_dynasty_workshop_draft.gd.txt` into the scratch project as a
`.gd` and attach it to a one-node test scene. Start that test scene in
separate headless processes with the same isolated HOME and XDG roots,
`WIFFALTRO_DYNASTY_ENGINEERING=1`, `WIFFALTRO_ISOLATED_TEST=1`, and
arguments `-- write`, `-- cold-switch`, then `-- cold-final`. For the second
path use a different profile and copy only the CP153 synthetic paid V4
primary (SHA-256
`79b38f481620246343830f84647c86d8de0c5b522bd0dba5bbde242640217e7f`)
to its V4 slot, put a disposable sentinel in the ordinary legacy path, then
run `-- closed-write` and `-- closed-cold`. No release or bundled fixture
is implied.

Paid workshop work must use authenticated completed Dynasty receipts, not
seasonal shop Cash, cumulative wins (which also include playoffs and abandoned
seasons), or the Original Game ledger. Preserve validated Close receipts
before Next clears its single last-close slot. Applying the layout and binding
it to actual home fixtures will require a compatible request, report and
settlement path, not loosening the existing validators.

## Retain Dynasty's close receipts before Next

The Common V4 Close operation now preserves a Dynasty-only, lineage-bound
history alongside the current session. It retains one contiguous compact score
proof per new close: a completed season carries the exact native award receipt;
an abandoned season carries no receipt. Existing V4 saves still read without
the optional field. If the history starts on an older career, the previous
Dynasty-local completed count, balance and title status are an opening
reconciliation only. No old receipts are fabricated or credited by this feature.

The history checks native schedule and finish, regular-season wins, award math,
one-time first title, contiguous ordinals and exact agreement with the local
Dynasty ledger. A still-closed live season must also match the source digest,
prior balance and actual score proof. After Next, the retained score proofs
validate consistency; they are not archived physical match reports. New rows
are issued only by the existing strict Close path. The archive is bounded by
the existing 1,024-run limit, not full playable save snapshots. No wallet,
purchase, field apply, or new unlock consumes this history yet.

The native test `tests/successor_dynasty_workshop_close_history.gd.txt` uses
the same one-node scene setup as above. In an isolated test process, `vectors`
checks explicitly synthetic receipt math/first title and rejects malformed
records, wrong lineage, duplicate or missing ordinal continuity, repeated
bonus, paid abandon and mismatched totals. On a separate copy of the same
CP153 played fixture, `abandon` exercises actual Close, duplicate refusal,
tamper rejection and Next. Then `cold` reopens in a fresh process and checks
the retained zero-credit entry, unchanged parked ordinary session at Next,
and untouched Original Game path. The earlier Workshop tests were also rerun.

A naturally completed terminal Dynasty save is still needed to qualify a
positive completion award through the new archive. The older exact 33-game
fixture is mentioned in the historical qualification notes; its save bytes
were not available in the local and private backup sources checked. These
tests do not substitute a synthetic win for that end-to-end proof.

## Extra starter-chair purchase

After closing Dynasty, before preparing Next, the Workshop can offer one
additional backstop chair (ST-079) for 35 Club Bucks. The confirm dialog defaults
to Cancel and pins the exact owner, session and save bytes. The purchase places
nothing on the field and leaves the existing starter draft untouched.

Only admitted Dynasty close rows fund it. Abandoned rows carry zero credit.
Pre-archive opening totals are visible to the existing career ledger, not
spendable as receipt-backed Workshop funds. The purchase stores the exact
archive prefix and original purchase epoch, so future Close rows cannot fund
an earlier purchase. The native ledger replays the one-copy purchase; the V4
writer preserves the previous save as backup and changes only the optional
chair metadata. Old V4 saves without that metadata retain their original shape.

`tests/successor_dynasty_workshop_chair.gd.txt` is an isolated Godot scene
script. Copy it to a scratch assembly as a Node script and attach it to a
scratch scene. Run `policy` for native price/funding vectors (synthetic, not
earned season evidence); use `refuse` with a real abandoned Dynasty save and
`active` with a real active Dynasty save. An authenticated completed-and-closed
Dynasty save with at least 35 recorded Club Bucks is needed for `buy`, followed
by separate-process `cold` on the same isolated copy. These check Cancel,
obstructed write, exact retry, one debit/copy, repeat refusal and cold
validation. They are not proof of a playable stadium or later purchases.
