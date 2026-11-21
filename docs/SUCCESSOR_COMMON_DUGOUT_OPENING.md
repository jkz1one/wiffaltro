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

## Actual opening shop and detached shared-bag boundary

The exact settled pair above funds this test; no game was rerun. In the
actual Common App, seed 42's first visit offered one holdable tactical item,
Extra Heat (5 Cash). Cancelling its native confirmation preserved both
files; confirming bought it once. A native reroll cost 4 and exposed one
holdable development card, Batting Cage (6 Cash). The final wallet held
both items in the same pool and had 3 of its initial 18 Cash left. There was
no further hold offer and the next reroll cost 6, so this actual opening
visit did not acquire a third held item or reach a fourth purchase. The
six first-round rewards remained once each after independent cold Continue.

A separately labeled in-memory test reused those two exact receipts to
probe the normal field-delivery allocation boundary. Standard's two-place
bag rejects the supplied third Tape; Dugout lets it occupy the third place.
A separate already-full Dugout delivery refuses a fourth and preserves the
existing copies. This controls the delivery trigger (no sponsor earned or
game/score simulated); it neither acquires a third item in the career nor
changes its Cash or slots. Native shop source shows a full held purchase
as disabled with explicit “use or discard” guidance, not a one-step
replacement dialog; no real full-bag interaction is established here.

Reuse the source-preserving assembly and disposable profile clone. Attach
`tests/successor_dugout_base_shop.gd.txt` to its scratch scene. Use
`-- buy` on the exact opening pair, then
`-- cold 5791b095c5c84997bcc916124d5f332c96a6faea36f91622a829046634d82550 2 3`.
The test accepts neither normal player saves nor any synthetic reward or
stock injection.

## Capacity rules in the Common Dugout shop

The Common Dugout shop's held inventory now exposes the authored Small Batch
and Double Major rules. It reads the current native sponsor pool, exact
offers and owned copies to distinguish locked, eligible for future offers,
offered now and active. It displays the current wallet separately from the
rules: base 3 held/5 sponsors, Small Batch +1 held with its native three-sponsor
cap, Double Major −1 held, and both together 3 held. Their existing earned
conditions are shown beside the current Small Batch count. No shop price,
offer generation, unlock, confirmation or overflow rule changed.

`tests/successor_dugout_capacity_access.gd.txt` checks the actual Common App
on the exact CP194 shop pair from cold Continue. It requires both sponsors to
be shown locked on this real owner and the primary/backup to be unchanged.
A separate exact Standard opening-round control still displays the original
two-place bag and receives no Dugout instructions. The isolated Standard
control opens its first shop once; no normal player save is used. No earned
modifier purchase is asserted for this fixture.

## Round progress while an NPC game runs

The Common clubhouse footer stays visible while a pending round finishes.
It shows the actual NPC matchup, half-inning, completed plate appearances,
and the number of NPC results already saved. The Resume button is disabled
while the real match runs. After the report is retained, the saved count
updates and Resume becomes available for the next step. Nothing here
predicts an ETA or changes the existing write and quit rules.

The isolated source test `tests/successor_common_npc_progress.gd.txt` used the
exact generated CP193 human-only pair. It observed Comets at Rivets from Top
1 through Bottom 1, with no slot writes while the game ran. The first NPC
fixture finished 9–10 and produced the exact prior CP193 report114 primary
`279aba29ebc52d7329edc991df0657afc580a45af62ea94ba7a747e8a759edd2`.
The unchanged human-only checkpoint became its backup. A separate process
showed one saved NPC result and an enabled Resume, with no second fixture,
round settlement, or new rewards. This exercised the source App controls
and real match, not a new rendered Linux package or target-device timings.

To repeat, attach the test to a Node scene in a source-preserving Common
assembly and copy the CP193 human-only primary and backup into a fresh
isolated HOME/XDG profile. Use the engineering, earned-preview and
isolated-test flags and run `-- run <absolute CP193 npc-1 primary>` with Godot
4.6.3 `--headless --audio-driver Dummy --fixed-fps 60`, then run
`-- cold <same absolute CP193 npc-1 primary>` in a separate process.
