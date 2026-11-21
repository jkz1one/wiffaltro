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

## Actual Season 2 completion, payout and purchase

The pinned Linux headless journey reached 33 physical results: 12 managed
player-side games driven by native input automation and 21 CPU reports. No
score or Club Bucks were supplied to the save. The club went 6–4, earned the
top seed, won the semifinal 4–3 and lost the neutral-site final 3–4. The
read-only end-to-end check confirms all 66 club/game reward events, one per
participating club for each physical result with exact win/loss parity.

Using the actual App, the 33-game active owner closed as runner-up for 104
Club Bucks: 95 for the finish and 9 for the six regular wins, with no title
bonus. Its archive includes one new completed receipt and the preceding
abandoned zero-credit opening. Cold reopening preserved the exact receipt
and both slots; a repeated close was refused without a write. The prior
terminal save was retained as the exact backup. Both terminal and closed
synthetic pairs were backed up privately and independently downloaded and
verified.

An isolated CP166 copy of that closed save then passed the existing
Workshop buy and cold modes: Cancel did not write, Confirm encountered a
deliberately blocked save, Retry promoted the same candidate and debited
35 Club Bucks once (104 → 69). The native journal created one extra ST-079
copy; no new field layout was applied. Repeated purchase was refused and a
fresh process reopened the purchase and refused forged purchase metadata.
No Original Game save or parked Ordinary payload was changed.

The read-only tool `verify_successor_dynasty_paid_completion.py` compares
the independently retained synthetic terminal, closed, paid and optional
carried stages, including exact backup parity and all 66 per-club results.
Run with `--synthetic-test-only` and `--help` for exact paired arguments.
The tool does not run gameplay or grant money. Preserve raw game evidence
only in the approved private project tree, not the repo.

This covers the native headless earned purchase, not a rendered controller
playthrough, a player-driven full season, or all difficulties. The separate
free starter-chair layout and native collision proof remain distinct from
the paid copy. Do not infer a verified Pool purchase in Dynasty or native
Mac behavior from this qualification.

An actual confirmed **Next** carried that same paid copy, the completed
receipt and the remaining 69 Club Bucks into Season 3. The active season
starts with zero results. Cold reopen did not rotate either slot, charge
again, or change the parked Ordinary payload. The prior Next proposal is
exactly the later backup. The chair remains owned, not placed.

For the separate native carry check, attach
`tests/successor_dynasty_paid_chair_next.gd.txt` to an isolated Node scene
of the CP166 assembly. Run the actual closed-and-paid pair with
`-- next <paid-primary-sha> <absolute-immutable-paid-primary>`, then use its
confirmed successor in a fresh process with
`-- cold <carried-primary-sha> <absolute-immutable-paid-primary>`.
Both require the engineering and isolated flags. Keep archives separate
from the active disposable profile. The source paid primary is
`30ca1ee00572a2ab90c58c6f38ed38f1bd1bbf33ff362c94b57a199cfcbc6bee`;
the observed Season 3 primary is
`380c36d8e16adec04f8a14625fcb71da88c4a58c65ff6a65dc04dc7cfecce598`.
