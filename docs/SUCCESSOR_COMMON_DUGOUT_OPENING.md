# Common V4 Dugout Base: real opening-round QA

Dugout is available at Base in the opt-in earned-leagues Common preview, like
Standard, without an inherited title. The v4 League blueprint's Dugout
difference is one more shared carried-consumable slot: three instead of
Standard's two. Development cards and tactical supplies share it; base
sponsor capacity remains five. There is no free item, extra activation
window, sponsor penalty, or separate Dugout loyalty rule in that blueprint
or the inspected implementation. Small Batch and Double Major modifiers,
overflow resolution and actually filling the third slot are separate
qualification targets.

This test starts the actual current Common App, chooses Dugout, and takes
four visible roster picks in a new isolated profile. It tests native capacity
for all six club journals and independently reconstructed ownership for both
teams in the actual opening match. The match uses the normal field contract
(no named venue overlay) and the full successor pitch catalog. It uses the
existing actual-physics test driver, normal human capture and the two original
NPC workers, not historical standalone Dugout report30 or score fixtures.
Each boundary archives the validated primary and exact prior backup. A separate
process checks the three settled game rows, both actual General114 NPC reports,
six matching native reward events and unchanged storage on cold Continue.

Assemble with `python tools/assemble_successor.py --dynasty-owner
--preserve-authored-project <new-stage>`. Attach the new
`tests/successor_dugout_base_journey.gd.txt` to a scratch scene and copy
`tests/successor_standard_base_journey.gd.txt` as `res://qa.gd` for its
unmodified original physical driver. Import using Godot 4.6.3 in a fresh
home/config/data/cache profile; then use headless fixed 60 physics with
`WIFFALTRO_ISOLATED_TEST=1`, `WIFFALTRO_DYNASTY_ENGINEERING=1` and
`WIFFALTRO_EARNED_LEAGUES_PREVIEW=1`. Start with `-- birth 42`, then run
`-- step <exact primary SHA>` separately for the human game, each NPC and
settlement, and finally `-- cold <settled SHA>`. Neither a full Dugout season
nor public/distributable release or target hardware performance is claimed.

On the reviewed Linux authored-source assembly, seed 42 went through real
human 6–5, NPC 9–10 and NPC 15–12 results. The human opening win earned
18 game Cash. Final primary
`030b791edf6dd3e20687044accb83f9983555ffd488a8558f12f9e41c0cb196f`
and exact predecessor
`954e9bf5c9f75eb1cb6b987b79f8416bcbd433f4d7fac124bdefa8da5ac28706`
stayed unchanged after independent cold Continue. This is a QA-only
checkpoint; no gameplay, allocation or pricing rules were changed.
