# Common V4 Scramble Base: stable transformed ratings

The Common draft already uses the native Scramble-aware Build for each
displayed offer. The full Common shop also formats recipients from the
live developed profile, not the raw player resource. No production,
roster, economy, unlock, or save format changed in this checkpoint.

The bounded test starts one fresh seed-42 Common owner using the existing
private named engineering route. An independent SHA permutation reference
checks each offered player's stat and base vectors and the corresponding
actual Common draft label across all four real writes. It does not call the
game's Scramble mapping or consume gameplay randomness. The starting
definitions of both physical teams use those exact transformed ratings.
The strict saved Build/Development root and immutable per-player base
vectors are checked across the human and all five CPU clubs; CPU shop
seeds are not treated as the root. The original successor pitch catalog is
still used. The opening native human away loss was 8–9; two original NPC
workers and one settlement gave each club exactly one 18/12 award and
left the human 12 Cash. An independent cold read preserved that pair.

The actual fixed pack cost 8 from those 12 earned Cash and revealed an
eligible Pitching card. The native recipient quote showed Mika Reed's
permuted Pitching 1 → 2 rather than the authored same-field value of 3.
Cancel preserved both exact files. Confirmation changed only that one
live stat, without altering base ratings, mastery or other profile
fields; it charged nothing again. Duplicate submit was inert. A fresh
process strictly reopened the same result and one paid upgrade at 4
Cash, with the original players' Resource values unchanged by the shop
and the D2 entitlement gate still locked.

## Reproduction

Assemble with `tools/assemble_successor.py --dynasty-owner
--preserve-authored-project` and import the disposable project. In that
project only map `successor_standard_base_journey.gd.txt` to `res://qa.gd`,
`successor_scramble_base_journey.gd.txt` to `res://scramble.gd`, and
`successor_scramble_base_shop.gd.txt` to `res://mp.gd`. Attach the latter
two to separate plain Node scenes.

Use isolated HOME/XDG paths and `WIFFALTRO_ISOLATED_TEST=1
WIFFALTRO_DYNASTY_ENGINEERING=1`. For the Scramble journey use
`--headless --fixed-fps 60`, `WIFFALTRO_EARNED_LEAGUES_PREVIEW=0`,
`birth 42`, and four successive `step <current-primary-sha256>` invocations
for the native human, two CPU matches and settlement. Copy the exact final
pair into a new isolated profile and run `cold <settled-hash>` with earned
preview enabled. The paid QA scene takes
`<mode> <exact-primary-sha256> <exact-backup-sha256>` with the preview
enabled: `buy` from the settled pair and `cold` from the final purchase
pair, in independent profiles.

No D2 earned unlock, full season, native visual build, or recruitment
transaction is claimed by this coverage.
