# Common V4 Earnings Base: settlement and base game Cash

The authored Earnings rule replaces the ordinary win/loss payment with
15 plus your own final signed run margin, clamped to 10–24 Cash. The Common
clubhouse now displays that rule and attaches base game Cash to a result
only when an exact committed reward and both final scores agree. The
Common shop explains the same funding rule, separately from its current
Cash balance, purchases, refunds and later sponsor effects. No payout,
offer, save/economy, or other league behavior changed.

The test uses a fresh isolated seed-42 Common owner created through the
existing named engineering lane, not B3 standalone and not earned entry.
All three opening fixtures are actual physical results. For each of the
six clubs, the QA runner replays its own journal, checks exact opposed
final scores and signed margin, and measures the reward-event balance
delta rather than assuming the total current bank balance equals the
award. No ordinary win/loss award is stacked on top. The human away 6–5 and CPU games 9–10 and 15–12 paid opposing pairs
16/14, 14/16 and 18/12 Cash respectively. A fresh process displayed the
actual human 16 base Cash and +1 margin, verified the settled save unchanged
until the real shop opened at 16 Cash, and replayed all six rewards again.
Upper/lower clamp bounds and a tied-score refusal are separate formula
tests, not played scores invented to reach the endpoints.

## Reproduction

Assemble with `tools/assemble_successor.py --dynasty-owner
--preserve-authored-project` and import the disposable project. Map
`successor_standard_base_journey.gd.txt` to `res://qa.gd` and
`successor_earnings_base_journey.gd.txt` to `res://earnings.gd` in the
disposable project only. Attach the latter to a plain Node scene.

Use isolated HOME/XDG paths and `WIFFALTRO_ISOLATED_TEST=1
WIFFALTRO_DYNASTY_ENGINEERING=1`. With `--headless --fixed-fps 60` and
`WIFFALTRO_EARNED_LEAGUES_PREVIEW=0`, use `birth 42` and four successive
`step <current-primary-sha256>` invocations for native human, CPU, CPU
and settlement. Copy the final exact pair into a fresh profile and run
`cold <settled-sha256>` with earned preview enabled. It strictly reopens
the original paid state before opening the real shop, testing the label
and legitimate earned Cash without a purchase. The independent `other`
control uses only the exact generated CP221 active Equipment pair with
earned preview enabled and verifies neither Earnings label appears.

The earned path from an Equipment championship remains separate. This does
not qualify a whole Earnings season, balance approval, rendered UI or
package export.
