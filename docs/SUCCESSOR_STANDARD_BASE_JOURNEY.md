# Standard Base physical qualification journey

This is a private QA driver, not a gameplay or save-format change. Its
starting point is a new isolated Common V4 slot through the earned-entry
preview. It uses the App's own draft, pitch/batting automation, result
capture, original NPC workers and normal round settlement. It supplies
inputs, never scores, reports, Cash, championship records or rights.

Prepare `tools/assemble_successor.py /new/scratch/project --dynasty-owner`
from verified source. Normally import it in Godot 4.6.3, then copy
`tests/successor_standard_base_journey.gd.txt` into that scratch project as
`qa.gd`, attached to a one-Node `qa.tscn`. Use a fresh disposable
HOME/XDG_DATA_HOME/XDG_CONFIG_HOME/XDG_CACHE_HOME and set
`WIFFALTRO_ISOLATED_TEST=1`, `WIFFALTRO_DYNASTY_ENGINEERING=1`, and
`WIFFALTRO_EARNED_LEAGUES_PREVIEW=1`. An Original Game or occupied birth
slot is refused. Launch the test scene using:

```sh
godot --headless --audio-driver Dummy --fixed-fps 60 \
  --path /new/scratch/project res://qa.tscn -- birth 42
```

With the same isolated profile, use `-- step <exact-current-primary-sha256>`
in a new Godot process per action. After each successful write require a
`STANDARD_BASE_STEP` marker, an exact previous-primary backup and the
append-only `user://standard-base-steps` copy before using the new primary
digest. Do not advance past a failed or unaudited checkpoint. At a settled
frontier use `-- cold <sha256>` in a separate process to verify the actual
scores, physical reports and strict read without a write. Fixed FPS is
for reproducibility; it does not measure performance on a player's Mac.

## Continue towards a real title

Resume from the latest verified settled synthetic pair, not from an
original player save. Continue in bounded batches, preferably one settled
round per backup. The test's `step` mode reports complete rather than
starting another game at a terminal frontier. At 33 actual results the
planned `close` mode uses the normal close path and checks whether the
same-lineage Standard D1 intent qualifies. The seed-42 no-title path is
verified below; a positive title is not. If the club is eliminated or loses, keep the real
finish and do not claim an earned title. Review actual standings and tune
human-side automation inputs or draft strategy for a new explicitly seeded
run only if needed; never alter recorded results to make a title.

Keep raw saves and scratch imports out of Git. Before substantial further
play, verify any generated receipt/slot archive in the approved project
backup tree. An exact genuine closed Standard Base championship is the
positive prerequisite for the separate Standard D1 start effort.

## Verified first round

At source `097caca9407e854ae8ae17251338df05b2a84d43`, the seed-42 App
created Standard Base and saved four actual draft picks. Fixture 0 finished
6–5 to the human away club. Two distinct original worker processes supplied
fixtures 1 (away 9, home 10) and 2 (away 15, home 12). A later process
settled the three results and left no pending reports. A read-only audit
matched one exact reward per participating club (six awards total), verified
the backup chain back to birth and verified the Original Game slot remained
absent. A separate strictly reopening process saw 3 results, 1 human result,
2 NPC reports and did not write either slot.

- Settled primary: `2592c2da63d9ebbaf593d586343d88fc84f459009da4f06eb1994dc67ecf6172`.
- Exact preceding primary / settled backup: `d3f8e33dfde6de061a15cb727ef1177f76329be35c033f333e95e1204593e621`.

This qualifies one headless physical round, not a Standard title, D1
admission, a shop purchase, or a native playtest.

## Completed seed-42 no-title control

Round 10 cold verified 30 actual regular-season games and a 5–5 record.
Yard Club was the third seed. It lost its managed semifinal 2–11 to the
Rivets while the original worker produced a 17–4 Comets win over the Kites.
A read-only cold projection required neutral NPC-only fixture 32 before the
semifinal round could settle. The original worker produced the Rivets'
11–1 final win over the Comets. The terminal cold verify saw all 33 results,
11 managed human-side games and 22 NPC reports, with all 66 club rewards
matched to game winners. No synthetic score or automatic title was supplied.

The separate native Close paid exactly 72 Club Bucks (65 for the semifinal
finish, 7 for the record, no first-title bonus). A read-only audit confirmed
the entire Ordinary match payload is unchanged, and its backup is the actual
terminal primary. Standard D1 qualification refused this finish immediately.
A separate cold process reopened the identical 72-Club-Buck close, found no
human title or D1 access, and checked both repeated App Close and direct native
Store Close leave the primary and backup unchanged. No Next was created.

For the repeat/cold check, copy
`tests/successor_standard_base_eliminated_cold.gd.txt` to a scratch
`eliminated-cold.gd`. Run the isolated Godot editor against the same project
using `--headless --audio-driver Dummy --path <project> --script <scratch script> -- <closed-sha> <terminal-sha>`
with only the verified generated closed pair in the disposable profile.
Expect `STANDARD_BASE_ELIMINATED_COLD_PASS`.

- Closed primary: `1a226548fad8932770868dcb286d1466a30976d571c2238ed78964fefb02b082`.
- Terminal primary / exact closed backup: `427deabb3f82a95afe829323955cea7ad39d36067078686d522268cc1bc91293`.

This is a complete physical Standard Base proof and an explicit negative
control for unlocking D1 without a championship. The separate champion
entitlement and playable D1 still need actual positive evidence.
