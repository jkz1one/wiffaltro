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

## One-game controls-only batting pilot

The separate QA script `tests/successor_standard_contact_pilot.gd.txt`
extends the scratch baseline driver. Save it as `pilot.gd`, attach it to
its own one-Node `pilot.tscn`, and launch that scene in a **new** isolated
profile. Keep the baseline as `qa.gd`; its two optional hooks do nothing
unless this specific pilot overrides them. Run `birth 42`, one opening
human/worker/worker/settlement chain, and a separate cold reopen. The
intervention is limited to the human away batting half of fixture 0.

The pilot uses the stock plate-location estimate from past visible ball
motion and the displayed count. It takes pitches clearly outside, defends
close two-strike pitches, and swings at selected on-plate reads. It changes
only the swing/take Boolean at the native input plan, not power/contact
choice, aim, timing, assigned lineup, either pitching policy, opponent
batting, rules, or resolution. It does not read the true target, actual
future crossing, umpire call or eventual outcome to make a decision.
Different inputs can change future game situations even with opponent
policy unchanged.

Both profiles began at the byte-identical seed-42 four-pick checkpoint.
The baseline driver re-ran its ordinary opener to the same prior checkpoint
hash, with the original 6–5 win. The pilot supplied 76 batting plans, 64
swings, 13 takes changed to swings and four swings changed to takes. Its
human offense had 16 hits, one home run and 10 strikeouts in 31 plate
appearances (baseline: 15 hits, no home runs and 13 strikeouts in 33 plate
appearances). However, it **lost 8–10**, so this is not a better title
strategy based on this pilot. The two original NPC reports matched the
baseline exactly; the round settled with six correct rewards and cold
reopened without rewriting either slot.

Pilot settled primary: `cfdc3f23b7034a29555fc9c1da76a52978969714c8af30f07394416bc81e4727`.
Backup: `2ac1c0cadf07fb3475af11a00eeb0f52e78ebc936a237aaba8dd2e2bda9b8dbd`.
Do not continue a full pilot season solely on this result.

## Separate seed-42 stock-controls draft pilot

Copy `tests/successor_standard_draft_pilot.gd.txt` to `draft.gd` next to
the scratch `qa.gd` and attach it to a separate one-Node `draft.tscn`.
Use a new isolated profile with `birth 42`. The baseline hook still
returns the first offer and reproduced its exact prior four-pick
checkpoint. The pilot chooses only current authored offers through the
App, and uses unmodified MatchAutomation for all game controls. It runs
without the batting experiment. No lineup setter is used.

The four picks in their authored slots were Val Morgan, Dakota Wells,
Emery Lane and Casey Rivers. Val has control 8; Dakota ties Ash at
fielding 6, ahead of Frankie at 4. Emery has fielding 8 and was preferred
over equally rated Cal. Casey and Jules tied at 6 contact / 7 power;
Casey came first in the visible offer. Native starter and fielder slots
were still 0 and 1.

Fixture 0 produced a real **10–0 road win**, versus the baseline 6–5.
Pilot batting was 32 PA, 17 hits, one home run, zero walks and 10
strikeouts (baseline 33 PA, 15 hits, no home runs or walks and 13
strikeouts). Val threw 24 pitches, allowing one hit, no walks and four
strikeouts; Dakota threw 26, allowing two hits, no walks and four
strikeouts. The baseline four pitchers combined for 87 pitches, nine
hits, no walks and 14 strikeouts. Opponent policy stayed stock; the
opponent draft changed naturally after the different human selections.
This is one promising matchup, not proof of a better full-season roster
or of a title.

Both original NPC jobs finished, the round produced three settled results
and six exact club rewards, and the separate cold check did not write
either save. The exact generated pilot pair is:

- Primary `965ade35837ff04e0ebab63746a5a907d6536bb7f92006d98f5d73d4d8dd4761`.
- Backup `f04e11d5b42fe83720c1c086c89a9f99670187f51d0533c99584715dbc94f566`.

Do not advance this separate title candidate without first verifying its
settled checkpoint. Its opening win supplies no earned D1 access.
