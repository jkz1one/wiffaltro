# Resumable Dynasty completion run

This is a test driver, not release gameplay changes. It runs the existing
Dynasty App from an isolated, previously verified warm save, one real
operation per cold process. An exact starting primary digest is required.
Nothing is written to the Original Game slot or the parked Ordinary
payload. No results, Club Bucks or ownership are injected.

Prepare the CP160 assembly with `tools/assemble_successor.py --dynasty-owner`.
Make a separate HOME/XDG profile and copy the verified CP156 Season 2
Round 1 pair into its Common V4 slot. The initial primary was
`99833b911cebd56d269b78ca0a641ded20d18a5495faefe9085cbd24ee931d67`,
and the backup
`7209d7658f1bb92f1e5c459896e2e9794cabe96de4f33436a2be04e4ed5e96ac`.
Copy `tests/successor_dynasty_completion_step.gd.txt` into the assembly
as a `.gd`, and attach it to a one-node test scene. Run that scene in
Godot 4.6.3 with `--headless --audio-driver Dummy --fixed-fps 60`, isolated
data roots, `WIFFALTRO_DYNASTY_ENGINEERING=1`,
`WIFFALTRO_ISOLATED_TEST=1`, and `-- step <primary-sha256>`.
The fixed 60 FPS test clock is not a target-device performance benchmark.

- With no pending result, `step` drives the real App human-side match,
  observes real physics and the authored outro, and checkpoints the actual
  result. Match automation supplies controls, not any score or report.
- With a pending result, `step` launches one original NPC worker or
  settles the round, using the regular App request, validator and writer.
- When all 33 results are settled, `step` reports readiness without
  writing. `-- close <primary-sha256>` checks the actual completion receipt
  and `-- cold <primary-sha256>` reopens it without issuing anything twice.

After every write, the test checks the exact previous primary as backup,
the parked Ordinary payload, and the Original Game slot. Accepted slots
are copied and hash-verified into an append-only checkpoint directory. The
`archive_successor_dynasty_test_checkpoint.py` tool makes a fresh audited
ZIP of only a synthetic step's primary, backup and manifest. It does not
upload or share anything. Keep raw copies out of Git; back up meaningful
checkpoints only through the user's approved private project folder and
verify the uploaded bytes before resuming a substantial run.

The first actual new game in this run was fixture 3, an 8–6 home win.
It entered the normal pending checkpoint at
`12659b23a57c7b18f1cd97649dd8b0b7afa93c9970374a24361c9a0dae25e12a`.
Neither whole-season completion nor a live paid Workshop purchase follows
from that result.

Two fresh-process worker steps admitted the actual NPC games 4 and 5.
A third process settled the round, leaving six physical results, two
human-side games, an empty pending queue and the exact settled primary
`b915d82fd82ab1c16ac8d1364469fa5166bd1e20cb379c07db5c90dc072542e2`.
Every write preserved the previous primary as backup and left both
other game slots untouched. The complete-round ZIP contains only the
two synthetic slots and a hash manifest. Remaining rounds, the terminal
payout and the purchase flow have not been run by this checkpoint.
