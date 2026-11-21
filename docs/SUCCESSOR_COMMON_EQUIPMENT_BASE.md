# Common V4 Equipment Base: active Ball and inactive spare

The Common App already inherits the full Equipment shop, authored Gear and
spare inspection, and native between-game purchase and exchange gates. This
checkpoint does not alter those product rules or the Common earned gate.
Public Equipment still requires a Dugout championship. An isolated existing
private named engineering route birthed this QA owner; earned-on Continue
could then reopen it, without granting a fresh unlock.

The preselected B5 comparison seed 1001 naturally generated the Scraped Ball
(`BALL-MOV-01`) on the first Common shop visit. One actual Common opening
round produced a human 10–8 away victory, both native CPU reports, and six
exactly-once 18/12 game Cash awards. All six builds kept one shared held
slot and five sponsor slots. The safe shop showed no free spare and no
active purchased Ball. One native confirmation paid 10 of the 18 earned
Cash for the inactive spare; cancel and duplicate submission kept the save
unchanged. There was no synthetic funding, offer injection or reroll.

A fresh process reopened the exact inactive copy (`spare-purchase:3`).
The inherited loadout showed that receipt as the inactive spare, not
equipped. The next native pregame and one actual physical release had the
standard active Ball (movement multiplier 1.0 and no paid Ball receipt in
the release evidence). The exact normal activation command was refused both
in pregame and during physical play. The test exited without settling.
Back in the safe shop **Activate Spare** moved the same exact paid copy to
the previously empty active Ball slot at zero Cash, preserving 8 Cash and
all six original rewards. This is activation into the default slot, not a
two-owned-Ball exchange. A separate cold process reopened the exact active
copy, and the next native release used the active movement multiplier 1.08
and recorded the same receipt in its first-release snapshot. It exited
without completing the match or earning completed-game usage credit.

## Reproduction

Assemble with `tools/assemble_successor.py --dynasty-owner
--preserve-authored-project` and import the disposable project normally.
In the disposable project only map the QA scripts:
`successor_standard_base_journey.gd.txt` → `res://qa.gd`,
`successor_equipment_base_journey.gd.txt` → `res://equipment.gd`,
and `successor_equipment_base_shop.gd.txt` → `res://gear.gd`. Attach the
last two to separate plain Node scenes.

Use isolated HOME/XDG paths and `WIFFALTRO_ISOLATED_TEST=1
WIFFALTRO_DYNASTY_ENGINEERING=1`. On the journey scene use
`--headless --fixed-fps 60`, `WIFFALTRO_EARNED_LEAGUES_PREVIEW=0`,
`birth 1001` and four `step <current-primary-sha256>` invocations for
human, two CPU reports and settlement. Copy the exact settled primary and
backup into a fresh profile and run `cold <current-primary-sha256>` with
earned preview enabled. Use the gear scene with earned preview enabled,
`--headless`, and `<mode> <exact-primary-sha256> <exact-backup-sha256>`.
The modes are `buy` from the settled pair, `activate` from the exact
purchased pair, and `cold` from the activated pair, each isolated.

This is bounded Common gameplay, shop, panel, and first-release evidence.
It is not a complete Equipment season, earned public admission, broader
stock coverage, or a replay of B5's stand-alone two-copy swap/sale sequence.
