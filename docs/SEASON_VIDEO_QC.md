# Season video QC: September 23, 2026

Implementation branch: `season-qc-camera-batting`, based on `665b46e`.
This records the first published pass. Its automatic contact cut and batting
balance were rejected in follow-up playtesting. See `SEASON_CAMERA_AI_REVISION.md`
for the replacement behavior and new evidence. The progression blueprint is untouched.

## Recording findings

Reviewed the 171.85-second September 22 11:13 PM recording using overview frames
and a three-frames-per-second breakdown of the defensive sequence at 14–24 seconds.
Around 17–21 seconds the defensive camera rises, retreats toward the wall, then
looks sharply down, sacrificing field context. The recording shows the plain
backyard environment; the Commons Park changes are a separate requested venue edit.
The recording alone cannot establish an inside-pitch exploit statistically.

## Implemented

- Foul and other contact results retain pitch name and actual incoming speed,
  captured before the pitch actor resets. Exit velocity remains separately labeled.
- Commons Park loses the live pole, gains a small decorative tree outside play,
  and uses an isosceles trapezoid wall silhouette in front elevation. Mesh and
  physical wall shape agree. Existing scoring planes, HR height and anchors remain.
  This is not a trapezoidal field footprint.
- Post-release camera position and side are unrestricted, per the user's amendment.
  Pitching coverage pans gently with visible flight. Contact coverage is selected
  from launch direction, with elevated home and baseline options independent of role.
  Established rigs pan instead of chasing behind the ball into scenery. High flies
  raise coverage; descent does not pump camera height. Dead-ball framing holds.
- Turf markings are excluded from obstruction padding. Previously, their inflated
  bounds could trigger large camera recoveries despite no actual visual obstruction.
- Removed the universal outside sweet-spot bonus and inside swing/aim penalty.
  Contact skill, speed, recognition difficulty, count and imperfect flight reads remain.
  Lineup memory carries a modest location read across batters, capped at 0.24
  awareness and limited to eight visible deliveries. Individual familiarity resets.

## Evidence and limits

The new physical batting test runs 2,880 deliveries through trajectory, decision,
swing timing and contact resolution: Four-Seam, Overhand Slider and Eephus;
both pitcher and batter hands; matched inside/outside targets; contact ratings 3/8.
At rating 3, each side made contact on 235/720 deliveries; at rating 8, 382/720.
This includes foul contact, not just fair hits. Equal pooled results remove evidence
of the former blanket side bias in these fixtures; they do not prove all pitches,
sequences, release qualities, fatigue levels or full-season outcomes are balanced.
Existing pitch-quality and live-match regressions provide additional coverage.

Camera coverage checks sample 7,680 frames across both venues, both player roles,
wide contact, near-wall balls and high flies. The tested paths had no blocked or
offscreen balls. After the deliberate contact cut, maximum measured movement was
0.227 m/frame and rotation 1.072 degrees/frame at 60 fps. Tests also check that
post-release motion leaves stored world-space batting aim unchanged.

Rendered preview could not launch because the environment could not establish an
X display. Human camera-feel, shot composition and Commons Park appearance review
remain open. Automated geometry checks do not certify “world class” presentation.

## Verification status

The full regression run covers parsing/lint, engine import, season QC, bobble rules,
AI chase, switch hitters, pitch handedness/routing/quality, venues, season flow,
season enrichment/shell, camera, presentation, player flow, live matches, match soak,
physical ball, core rules, exports and startup. A result-hold pause-inspection failure
was fixed after the run's source snapshot; the affected player-flow test and expanded
camera audit passed against the final source. See ignored `builds/verification/`
for the full-run logs. The full run completed with only that earlier player-flow
failure; all other checks passed. The final affected reruns passed. Human rendered
QC is still open as described above.

## Cinematic direction still to implement

The reference is John DeMarsico's film-inspired Mets coverage, including motivated
framing and sequences built around the moment. A primary event description lists
his broadcast/film comparisons: https://burnsfilmcenter.org/booking/baseball-is-cinema-an-evening-with-n-y-mets-game-director-john-demarsico/

A later broadcast director should select shots from game context and tension,
coordinate reveal/reaction/result coverage, and support replay/highlight capture.
Live movement and cuts remain permitted whenever action is readable and input
stays reliable. This patch does not implement that full director, weather or lighting.
