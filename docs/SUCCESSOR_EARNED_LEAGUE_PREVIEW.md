# Earned league entry preview (Common V4)

Keep `WIFFALTRO_DYNASTY_ENGINEERING=1`. The separate, exact
`WIFFALTRO_EARNED_LEAGUES_PREVIEW=1` flag exposes draft public-entry rules on
the private Common V4 launcher only. Unset or other values retain the existing
engineering launcher behavior. Original Game has no change.

A fresh slot offers only Standard and Dugout Base. All nine leagues and D1–D4
status remain visible. The existing native `league_unlocks.gd` consumes title
keys from the admitted common career, not booleans coming from the selector.
The same league's prior championship earns the next difficulty. Earning
Doubleheader or a higher tier is not advertised as playable: the paired private
harness and original launcher remain independent, and higher tier is not added
to the Common V4 play/settle pipeline here. None of these policy test vectors
constitute earned game evidence.

New starts recheck admission even when called directly, not only through a
button. Missing-session creation and the ordinary / Dynasty Next producer
check the exact promoted owner and disk bytes before consulting titles. An
existing career can be continued, copied through an existing strict reader, or
resumed from its parked side even if its league is currently locked for new
play. Its next season can be locked, without replacing either existing side.
No title is inserted, no saved flag is added, and no higher-tier close is enabled.

## Isolated smoke tests

With a new scratch directory, run
`python3 -B tools/assemble_successor.py /new/scratch/project --dynasty-owner`
and import that project with Godot 4.6.3
(`--headless --audio-driver Dummy --editor --import --path /new/scratch/project`).
Copy `tests/successor_earned_league_preview.gd.txt` outside the project to
`preview.gd`. Then, in a fresh separate HOME and XDG data/config/cache per mode,
run:

```sh
WIFFALTRO_ISOLATED_TEST=1 WIFFALTRO_DYNASTY_ENGINEERING=1 \
WIFFALTRO_EARNED_LEAGUES_PREVIEW=1 godot --headless --audio-driver Dummy \
  --path /new/scratch/project --script /new/scratch/preview.gd -- standard
```

Repeat with `dugout` in a new empty profile. For `policy_off`, set the preview
flag to `true` (not the literal `1`). For `legacy_resume`, stage only the
audited generated CP88 paid primary and its exact backup in a fresh isolated
profile (see `tools/test_successor_dynasty_post_purchase.py::evidence`).
That test leaves the input ZIP unchanged and checks Continue, mutation refusal,
and normal resume in the scratch copy. Expect `EARNED_LEAGUE_PREVIEW_PASS`.
