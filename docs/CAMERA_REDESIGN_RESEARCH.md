# Camera redesign: preserve batting, make defensive coverage purposeful

Research date: 2026-09-24. Original research and design proposal.

**Implementation follow-up:** [ADAPTIVE_CAMERA_IMPLEMENTATION.md](ADAPTIVE_CAMERA_IMPLEMENTATION.md)
records the subsequent runtime changes, dynamic-stadium contract, and verification.
The historical measurements below still describe the versions originally examined.

This document supersedes the camera direction in `SEASON_CAMERA_RESEARCH.md` and
`SEASON_STABLE_COVERAGE.md`. Their historical measurements and AI findings remain
valid within their stated limits. The local camera revision `c116818` is an
unpublished prototype, not a visually accepted solution. Published main at the
start of this research was `f1dc209`.

## Decision

Use the earlier batting experience as a comparison baseline across the entire
pitch and contact sequence. Jay clarified that research-led improvements to
batting are welcome too; the old transforms and timing are not frozen. Preserve
pitch readability, reliable aiming, and spatial clarity while improving framing
and transitions wherever playback demonstrates a benefit.
Build defensive coverage around the space a play needs and how soon it needs it.
Short contact should require little adjustment; deep flight should earn a clearly
wider composition. These need distinct shot policies, with shared framing tools.

There is no camera lock after release. There is also no blanket prohibition on
changing orientation, moving sideways, or changing the lens. Those tools must
solve a visible coverage problem. Power, contact, and crossing Single or Double
are insufficient reasons to turn the view around.

The research supports this architecture, but does not provide a ready-made
Wiffaltro camera or universal comfort constants. Native visual review remains
necessary before calling a replacement better.

## What actually changed

`MatchCameraDirector` retained the same pre-pitch batting position across the
three versions examined: `(hand * 0.18, 2.10, -3.38)`, looking toward
`(0, 1.10, 7.1)`. That narrow check missed the regression: the camera after contact
while the player was batting changed substantially.

| Version | Offensive contact behavior | Defensive design and limitation |
| --- | --- | --- |
| `665b46e`, immediately before season camera troubleshooting | Smoothed ball/field focus; camera follows behind that focus with depth-dependent pullback | Separate offset ahead of the focus; visibility recovery can make abrupt corrections |
| `f1dc209`, published main | Replaced by the shared coverage system, including a side offset and changing lens | Carry-driven ground/aerial destination, large lateral obstacle response, simultaneous travel/turn/lens changes |
| `c116818`, local prototype | Another replacement: central position, fixed lens, height tied to ball height | More restrained translation, but one rig, a four-metre lateral ceiling, and a fixed lens limit alternative coverage |

`665b46e` is the first comparison candidate for the batting behavior Jay liked.
It is not a confirmed exact preference or a reason to restore every historical
camera bug. Isolate the offensive policy before any defensive experiments.

The published implementation could add a 14 m lateral destination near an
upright. Bounding speed per frame does not make that whole journey desirable.
The local revision removes that path, but still starts a prescribed opening on
every contact and lets ball height drive camera height. Less travel alone does
not establish better composition.

### Matched motion audit

The attached [CSV](CAMERA_REDESIGN_MOTION_AUDIT.csv) compares five synthetic
trajectories for both roles through the actual camera directors of all three
versions. Selected defensive results:

| Trajectory / observation window | Published travel / accumulated rotation | Local prototype travel / accumulated rotation |
| --- | ---: | ---: |
| Soft grounder / first 0.50 s | 1.07 m / 7.37° | 1.37 m / 5.52° |
| Hard grounder / 1.55 s | 30.87 m / 98.47° | 14.00 m / 77.34° |
| Fast liner / 0.98 s | 21.48 m / 66.73° | 14.83 m / 57.33° |
| Deep fly / first 1.32 s | 29.09 m / 98.48° | 17.17 m / 59.67° |

Rotation is the sum of frame-to-frame quaternion angles, **not net yaw or proof
of a 180° reversal**. The soft-grounder example also shows why the user's report
cannot be reduced to one global motion threshold. Much of the problem is which
composition is chosen, and when.

Method: begin each case from a snapped batting or pitching shot at 70° FOV;
ball starts at `(0, 1, 0.28)`. Launch velocities in m/s are soft grounder
`(0,-2,8)`, hard grounder `(5,-1,22)`, fast liner `(0,2,33)`, deep fly
`(0,18,26)`, and short popup `(0,22,5)`. Step aerodynamics/gravity at 120 Hz,
camera at 60 Hz; use a synthetic bounce at y=0.08 with vertical restitution 0.52.
Stop at z>23, three seconds, or 0.50 seconds for the soft grounder. Thus the deep
fly row covers early flight, not its complete arc. Each case uses a fresh director
and the starter field's visibility configuration. The older API receives position
only; newer APIs also receive launch velocity.

This is a camera comparison, not a full-match replay: it omits production fielding
resolution and collision responses. It cannot certify comfort, occlusion quality,
or actual defender readability. An exploratory fixed-height projection probe was
excluded from the CSV because it did not verify that its subject was on screen.

## What the external evidence establishes

### Actual baseball games

**MLB The Show developer account.** Clayton Read's
[TruBroadcast article](https://blog.playstation.com/2012/03/15/mlb-12-the-show-how-trubroadcast-presentations-put-you-in-the-game/)
describes studying MLB broadcasts to improve shot framing, cut timing, subject
selection, and continuity of actor locations. This supports coordinated shot
design. It does not disclose the live defensive algorithm, and it describes
MLB 12, not the current release.

**Super Mega Baseball 3 visual inspection.** Sampled the official Steam
[Gameplay Trailer](https://store.steampowered.com/app/988910/Super_Mega_Baseball_3/)
at two-second intervals, then approximately quarter-second intervals around
three plays. Approximate timestamps refer to that 78-second trailer:

| Interval | Direct observation |
| --- | --- |
| 4.4–7.9 s | Pitcher-to-batter view changes abruptly to an elevated view along the right infield. The following composition includes defenders, infield, foul line, and outfield. |
| 12.1–14.9 s | A batting-side hit progresses into elevated outfield coverage; grass, defenders, and wall provide context as the ball travels deep. |
| 30.1–35.9 s | After a defensive angle change, the view follows right-infield action and expands toward a broad diamond view during the ensuing throws. |

These are edited promotional sequences. They support observations about
composition; they do not establish exact production transition delays or prove
every apparent cut belongs to the game. Borrow the useful field context, not an
automatic defensive reversal that conflicts with Jay's feedback.

**Super Mega Baseball 4 evidence boundary.** The official Steam
[launch trailer](https://store.steampowered.com/app/1487210/Super_Mega_Baseball_4/)
was sampled across its 80 seconds. Its closeups, theatrical viewpoints, and rapid
montage edits are unsuitable for deriving continuous defensive camera behavior.
Do not use those shots as proof of playable transitions.

The separate [EA staff gameplay notes](https://forums.ea.com/discussions/other-ea-games-en/ballpark-notes---gameplay-on-and-off-field/10925575)
describe a line-drive view intended to help judge jumping. The
[Update 3 notes](https://www.ea.com/news/update-3-patch-notes) narrow that special
view toward relevant infield plays. Official indexed text was available; the
patch page's direct fetch was unavailable in the earlier pass. The useful lesson
is to constrain a special shot to the decision it improves, not generalize it to
every hard hit.

### Reusable camera systems

| Primary reference | Documented mechanism | Proposed use here |
| --- | --- | --- |
| Unity Cinemachine [Target Group](https://docs.unity3d.com/Packages/com.unity.cinemachine@3.1/manual/CinemachineTargetGroup.html) | Multiple subjects have weights and spatial radii | Frame ball, relevant defender, and useful ground area as a group |
| Unity Cinemachine [Group Framing](https://docs.unity3d.com/Packages/com.unity.cinemachine@3.1/manual/CinemachineGroupFraming.html) | Screen occupancy drives framing; bounded dolly, zoom, or dolly-then-zoom; lateral adjustment can use position or rotation | Solve the composition before deciding how far to travel |
| Unity Cinemachine [Rotation Composer](https://docs.unity3d.com/Packages/com.unity.cinemachine@3.1/manual/CinemachineRotationComposer.html) | Dead zones, damping, hard screen limits; predictive lookahead can amplify noisy motion | Let small ball movements remain inside a stable composition; filter forecasts and bounces |
| Unity Cinemachine [Custom Blends](https://docs.unity3d.com/Packages/com.unity.cinemachine@3.1/manual/CinemachineBlending.html) | Transition shape and duration can vary by the pair of shots | Give ground-to-flight and live-to-result different transition policies |
| Unity Cinemachine [Deoccluder](https://docs.unity3d.com/Packages/com.unity.cinemachine@3.1/manual/CinemachineDeoccluder.html) | Can evaluate obstruction without automatically moving; separate entry/return damping and persistence controls | Assess a pole as a visibility problem before selecting a whole new camera path |

These are architectural references for a Godot implementation, not a proposal to
change engines or a claim that a baseball game uses Cinemachine.

John Giors's [Full Spectrum Warrior camera paper](https://media.gdcvault.com/gdc04/slides/full_spectrum_warrior.pdf),
sections 3–4, explains separate cameras and filtered target points. A proportional
follower trades graceful arrival against lag behind fast targets; abrupt target
changes can cause abrupt velocity. Its acceleration limits and target-velocity
compensation address different parts of that problem. This explains why changing
one smoothing constant cannot solve both late deep coverage and excessive short
play movement. We are not adopting that game's input lockouts or flyby rules.

Brian Hawkins's [event-driven camera design](https://www.gamedeveloper.com/programming/creating-an-event-driven-cinematic-camera-part-two)
separates shot suggestions, selection/transitions, and realization of the view.
It considers whether a camera move can finish at a reasonable speed while the
shot remains useful. Applied here, a destination that arrives after fielding is
already complete is a failed candidate even if its interpolation is smooth.

For broadcast context, [Seminole Productions](https://sempro.cci.fsu.edu/training/diamond-sports/)
assigns high-home and center-field cameras different coverage duties. Our earlier
Mets interview research remains in `SEASON_CAMERA_RESEARCH.md`. This pass did not
inspect a new full Mets broadcast. Cinematic between-play presentation and useful
live coverage should have separate selection policies.

## Proposed defensive shot design

The remainder is our design inference. The source material does not specify
these Wiffaltro rules or thresholds.

### Select by framing need and urgency

Estimate a short, revisable flight corridor from current ball state and physics.
Project that corridor, the active defender or plausible fielding region, and
ground reference into each candidate view. Also estimate time until a required
subject leaves the safe screen area. Speed matters through that deadline;
expected carry matters through the required area. Neither should directly map
to an orbit angle.

Use the same legitimate ball state available to presentation. Do not choose a
shot from the eventual scoring result, a scripted outcome, or private future AI
decisions. As the flight estimate changes, update its confidence and area rather
than switching the view's side on every recalculation.

| Situation | Required composition | Response and exit condition |
| --- | --- | --- |
| Soft contact before Single | Ball, nearby defender/fielding area, ground | Retain the current view while those subjects fit. Make only the adjustment needed. If fielded, abandon any unfinished widening. |
| Grounder, including beyond Double | Ball's ground corridor and approaching defender | Expand/pan along that corridor. Scoring-line crossings do not change shot family. |
| Fast low liner | Ball, immediate interception space, relevant defender | Widen early enough for the short reaction window. Lateral adjustment is available; speed does not mandate reversal. |
| High short popup | Ball's vertical arc, defender, nearby ground | Add vertical room while retaining ground context. Do not mistake height for deep carry. |
| Deep airborne hit | Flight corridor, defender or landing region, relevant wall | Establish wider elevated coverage early. A purposeful side position and orientation change are available when they improve readability and can arrive in time. |
| Uncertain or deflected flight | Ball and conservative nearby fielding region | Reduce reliance on the old prediction. Retain the current shot if usable; reevaluate promptly if it is failing. |
| Foul / resolved play | Result location and appropriate pitch/result information | Resolve live coverage before moving to presentation. Preserve foul pitch feedback. Avoid a second camera whip as the result appears. |

Keep a useful minimum subject size as well as an outer framing boundary.
Zooming far enough to fit everything can make the actual play unreadable.
On a short play the batter need not remain the focal subject after contact. On
a deep play the camera should turn toward the fielding action; facing the batter
is not an objective by itself.

### Choose the transition separately

Nearby compositions can use a short dolly, side move, or pan. Solve bounded dolly
first and use modest lens expansion when it still improves framing. Do not
animate every available property just because contact happened.

For a substantially different deep-flight angle, compare a composed cut with a
continuous move in replay. A slow sweep across the field can be worse than a
well-timed cut. A cut can also be disorienting: it must preserve recognisable
field context and make the ball easy to reacquire. Neither option is approved
without playback. Do not copy a broadcast 180° cut as the default.

Retain a useful shot until another offers a meaningful improvement. This
retention is a preference with visibility overrides, not a timer that forbids
movement after release. Stop irrelevant movement when a play resolves. Avoid
repeated close-wide-close changes when forecast confidence fluctuates.

Check intermediate views as well as endpoints. Two good compositions can have
an unusable interpolated path. Reject a path that loses the play, crosses a prop,
or consumes most of the remaining fielding time. In the synthetic fast-liner
fixture the ball reaches z>23 in 0.98 s: a universal 0.85 s opening leaves little
time to benefit from its destination.

Treat obstruction as a separate constraint. Try a small compositional correction
or an already viable alternative shot. The local prototype's temporary prop
transparency remains an option requiring native rendering review; it is not a
reason to preserve the rest of that camera design. Short transient obstruction
should not schedule a huge relocation, while sustained loss of the ball needs
immediate attention.

## Implementation sequence and acceptance

1. **Establish the batting comparison baseline.** Compare the full offensive sequence
   against `665b46e`: pitch, swing, contact follow, foul, result, next pitch, both
   handednesses. Isolate its policy from defense. Preserve aiming coordinates and
   input behavior. Do not blind-revert visibility fixes or unrelated season work.
   Then apply the framing research to offense as well: restrained short-contact
   coverage, timely expansion for deep flight, and readable result transitions.
   Evaluate intentional changes against the baseline rather than treating exact
   historical camera poses as permanent acceptance criteria.
2. **Create deterministic camera replays.** Reuse identical recorded/simulated
   ball trajectories and fielding events for baseline and candidate. Include
   early resolution, repeated bounces, lateral hits, popups, liners, deep flight,
   fouls, obstructions, and viewport sizes. Provide a debug overlay for shot,
   required subjects, screen bounds, and transition reason.
3. **Implement defensive selection and composition.** Keep shot selection,
   subject framing, transition choice, and motion filtering separate. Start with
   local ground coverage and deep-flight coverage; add special cases only when
   replay demonstrates a need. Do not begin with more global easing changes.
4. **Replace tests that encode the overcorrection.** Fixed FOV, maximum four-metre
   lateral movement, and never changing orientation are prototype choices, not
   universal requirements. Test subject visibility, useful size, framing deadlines,
   total excursion, repeated direction changes, and offensive preservation.
   Include the contact frame and the handoff into results, at multiple frame rates.
5. **Review native clips before publishing.** Compare the same plays at normal
   speed. A short grounder should resolve without unnecessary travel; a deep fly
   should reveal its fielding area in time and feel clearly different. Check the
   defender/ball/ground relationship, not only whether a point remains on screen.

Existing headless checks do not establish subjective comfort. Native Godot
rendering was unavailable in this environment, so this pass supplies measured
history, external visual references, and a concrete design, not a rendered
approval. The earlier user recording is also not a recording of the latest
published revision. A new implementation needs matching native captures.

No AI tuning changed in this research pass. Keep the existing AI timing audit
separate so camera revisions cannot obscure whether batting balance improved.
