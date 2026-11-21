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
