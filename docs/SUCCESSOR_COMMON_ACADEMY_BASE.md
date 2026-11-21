# Common V4 Academy Base: earned development pack

The Common owner had the original Academy pack and a native match guard, but
the home screen kept offering Play and the direct App showed only a generic
fixture error. For an active ordinary Academy owner with a paid choice still
pending, the Common menu now offers **Resume Paid Academy Pack** in place of
Play and Shop. It restores the existing full shop rather than reopening or
rebuying a pack. Direct Play also refuses with the specific resolution
message. No recipe, offer odds, economy, recipient eligibility or entitlement
was changed.

In the separate existing named engineering lane, seed 42 completed the
actual Common opening round: the human won away 6–5, two native CPU workers
completed, and all six team bank journals replayed exactly one 18 Cash win or
12 Cash loss award. A cold process with earned preview enabled still showed
Academy locked for fresh entry, while continuing the existing save and its
18 season Cash.

The normal Common shop spent 12 Cash once to reveal the real fixed pack.
After a separate Continue, the normal card and recipient confirmation
immediately applied Pitching to Mika Reed. Continue preserved that change
and the exact reveal and visibly disabled the card already used. A distinct
second selection immediately applied Round Out to Dakota Wells without
recharging or changing Mika's first effect. A separate branch from the same
first-pick bytes explicitly skipped, preserving only the first improvement
without refund. The two outcomes retain the original six rewards and 6 Cash.
Cancel and exact duplicate/fresh-ID repeated card probes made no changes. No
game from the next round was played or saved.

## Reproduction

Assemble with `tools/assemble_successor.py --dynasty-owner
--preserve-authored-project` and import the disposable project normally.
In that disposable project only, map the tracked QA text to project-local
scripts: `successor_standard_base_journey.gd.txt` → `res://qa.gd`,
`successor_academy_base_journey.gd.txt` → `res://academy.gd`, and
`successor_academy_base_pack.gd.txt` → `res://pack.gd`. Attach the latter
two to separate plain Node scenes.

Use fresh HOME/XDG paths and `WIFFALTRO_ISOLATED_TEST=1
WIFFALTRO_DYNASTY_ENGINEERING=1` for every invocation. First launch the
Academy QA scene with the pre-existing named engineering lane
(`WIFFALTRO_EARNED_LEAGUES_PREVIEW=0`), `--headless --fixed-fps 60`, and
`birth 42`. Run four successive `step <current-primary-sha256>` invocations
to write the human result, two CPU reports and settlement. Copy the exact
resulting primary/backup pair to a fresh profile and run `cold <primary-hash>`
with earned preview enabled.

Use the pack QA scene with earned preview enabled for the remaining stages.
Each invocation takes `<mode> <exact-primary-sha256> <exact-backup-sha256>`
and receives an isolated copy of the preceding exact pair. The sequence
is `reveal` from settled, `first` from reveal, `second` and `skip` each
from the same first pair, then independent `cold-second` and `cold-skip`.
Do not mix the skip and second-pick branches.

This qualifies the bounded Common Academy opening and both paid pack outcomes,
not the older standalone contract or every eligible/capped pack combination.
A Sponsorship championship and actual Academy earned admission remain
separate; the tested engineering creation did not confer them.
