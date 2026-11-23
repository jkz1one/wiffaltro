# CP310 recovery checkpoint: authored pack and second native round

The production patch recreates the pre-reset tracked patch exactly:
`4db0fd58acd99f63ff5e8ed01eb6711614dd86ee396372250017c473ccf1248f`.
This is a new bounded proof harness, not the lost whole-season harness. The
only inputs are exact generated terminal-unpaid, paid, and unresolved-pack
primary saves kept after the actual packaged Linux game and in-game purchase.

- Build with `build.py <official Godot editor> <pinned official Linux ELF>`.
- Run `run.py <proof-root> pack <exact generated unresolved primary>`,
  similarly `paid <exact settled primary>` and `settle <exact terminal-unpaid primary>`.
  Each is a fresh primary-only environment using the official Linux template.
- Checks exact input and output bytes, native predecessor history, current
  native Shop/physical replay, stale CPU rejection, no duplicate debit or
  settlement, and exact round payment from stored reports without replaying
  the games. No current user save is used or altered.

Implementation generalizes normal game and ordered journal replay. This
checkpoint only proves the tested Shop/first two regular rounds and the
following fixture's admission. Later rounds and postseason are not verified;
no new closure/Next, public rollout, performance improvement, Mac, visual
playtest, or Dynasty verification claim is made.
