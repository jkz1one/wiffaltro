# Vanilla Match + Mechanics Lab — Phase 3 Milestone Test

This is a functional match simulator and shared debug lab, not a polished game screen.

## What this milestone now contains

- 9 selectable Pitches
- Overhand and Sidearm release profiles
- 240 Hz custom RK2 Pitch simulation
- gravity, drag, spin lift, perforation/asymmetry, and seeded instability
- iterative aim solving to an intended plate location
- execution error and fatigue degradation
- release/plate-speed and aerodynamic movement instrumentation
- Contact and Power swing profiles
- 240 Hz swept timing/spatial contact resolution against a moving Swing
- exit velocity, launch-angle, and spray output
- corrected fatigue degradation and release-speed telemetry
- Jolt physical ball-in-play with custom aerodynamic forces
- starter field Safe, Deep Air, back-wall, and Home Run rules
- automated Primary Fielder and Pitcher defense
- deterministic clean, bobble, deflection, miss, and recovery handling
- ghost-base hit advancement and sacrifice-fly/tag advancement
- four debug camera views
- full five-inning Match Mode with provisional four-player rosters
- batting order, current/on-deck batter, counts, walks, outs, runs, and innings
- Stamina, pitch counts, pitching changes, mercy, extra innings, and game over
- automatic batting, pitching, and ball-in-play cameras
- smooth camera transitions and dynamic ball-in-play follow
- bounded Pitch effort and outside-zone aiming
- larger visible Contact and Power batting coverage
- player-timed Pitch release influenced by Control and fatigue
- early/late and directional swing feedback
- count-aware deterministic opponent decisions
- deterministic per-play diagnostic records
- one confirmation per new Batter, automatic within-at-bat dead-ball cadence,
  and Pitcher windup telegraph
- pointer-projected mouse batting
- clickable four-player pitching-staff panel
- full-simulation debug pause
- handed Batter/Pitcher/Fielder avatars and independent visible bat swing
- visible non-authoritative receiver for taken and missed Pitches
- automatic one-to-three-shot game intro and win/loss outro
- seeded still / zoom / pan / tilt motion per presentation shot
- nearly centered batting camera with a very small handed offset
- Batter approach memory for Pitch/location repetition
- varied delivery rhythm and distinct Pitch speed bands
- hold/release mouse pitching through the shared execution meter
- overhead 3×3 Field Setup view
- preserved Mechanics Lab and debug telemetry
- suspended-match return from Mechanics Lab at safe pre-Pitch boundaries
- compact movable broadcast-style scorebug, small beneath-scorebug calls, and
  centered boxless transition/result text
- tiny display menu for scorebug anchor and procedural sky/gray backdrop
- persistent compact selected-Pitch identifier during player defense
- visible player-controlled Pitcher windup during the release meter
- late release sweet spot with bounded category-aware overdrive risk/reward

## Shared controls

- `F1`: toggle detailed telemetry and trajectory overlays
- `F2`: enter Mechanics Lab from a stopped pre-Pitch state, then resume the
  same match state
- `F3`: print completed records and show their automatically saved JSON file path
- `P`: pause/resume the simulation for debug inspection
- `V`: cycle camera manually

## Match Mode controls

- During the intro: left click, `Space`, or `Escape` skips to gameplay
- During automatic dead-ball holds: no acceptance input is required
- When a new player-controlled Batter steps in: left click, `Space`, or
  controller A confirms that plate appearance once
- `Space` while pitching: hold to start the delivery and release near the
  meter's late gold mark
- Mouse movement: position batting coverage on the contact plane
- Left click: aim at the pointer and commit a Contact Swing
- Right click: aim at the pointer and commit a Power Swing
- `W A S D` / left stick: continuously move batting aim
- `Z` / controller A: Contact Swing
- `X` / controller X: Power Swing
- `1–9`: select from the active Pitcher's repertoire while pitching
- Mouse movement while pitching: aim directly on the plate plane
- Hold left click while pitching: lock the pointer target, fill the release
  meter, and release near its late gold marker to throw
- Arrow keys / right stick: continuously move the Pitch target
- `- / =`: lower / raise Pitch effort from 82–112%
- Click the pitching-staff panel: select any of the four Pitchers between batters
- `Q / E`: previous / next Pitcher between batters
- `F`: cycle Primary Fielder between batters
- `C`: cycle Primary Fielder position through the 3×3 grid
- Click `FIELD VIEW / POSITION`: enter the overhead view, select an anchor, and
  click `RETURN TO PITCH`
- `[ / ]`: set a minimum fatigue level for focused testing
- `R`: restart the match
- After the outro: `R` starts a new match

## Mechanics Lab controls

- `1–9`: select Pitch
- `Space`: throw selected Pitch
- Arrow keys: move intended Pitch target
- `W A S D`: move batting aim
- Left click / `Z`: Contact Swing
- Right click / `X`: Power Swing
- `- / =`: lower / raise Pitch effort
- `, / .`: lower / raise execution quality
- `[ / ]`: lower / raise fatigue
- `C`: cycle Primary Fielder position through the 3×3 grid
- `G`: cycle empty / runner-on-third / bases-loaded test states
- `B`: launch the next direct Ball-in-Play diagnostic
- `R`: reset lab conditions

Mechanics Lab must preserve its manually selected camera through contact and
ball-in-play so a chosen angle can be inspected. Match Mode retains automatic
role and contact camera direction.

## Pitch keys

1. Overhand Four-Seam
2. Overhand Sinker
3. Sidearm Sinker
4. Overhand Slider
5. Sidearm Slider
6. Eephus
7. Knuckleball
8. Sidearm Riser
9. Drop

## What to look for

At 100% execution / 0% fatigue, different Pitches aimed at the same marker should generally finish around that intended location while taking visibly different paths.

At minimum effort, throw the Eephus to low, middle, and high targets. Every
attempt should launch and cross the plate plane; no attempt may display an aim
solver failure or leave the game unable to continue.

Fatigue should be virtually invisible from 0–50%. Debug telemetry reports both
raw fatigue and effective pressure: 50% raw fatigue is only 2.5% effect. From
50–92%, velocity, movement, and command should worsen progressively. At 92%+
the Pitcher is in the danger band. At 100%, faster Pitches should be clearly
slower, breaking Pitches should lose most of their finish, and edge targets
should frequently leak toward hittable center territory. Location still varies,
but exhausted Pitches must generally reach the plate rather than disappearing
into the dirt.

The Knuckleball is intentionally less repeatable because its seeded orientation instability is part of the Pitch identity.

For batting, move the pointer over the approaching ball and click early enough
for the bat to reach it near the plate. Left click uses Contact; right click
uses Power. The click starts a real authored-duration Swing; it does not freeze
the ball or decide contact immediately. Mouse position is projected onto the
same mathematical contact plane used by the WASD and controller reticle, so
both paths exercise the same ContactResolver. The outer cyan rectangle is
Contact coverage and the inner orange rectangle is Power coverage. Batter
Contact rating scales both regions. The camera should sit at a subtle handed
over-shoulder angle. Right-handed Batters must stand on the third-base side
with hands and bat on the back/right shoulder; left-handed Batters must mirror
the full setup. The widened depth should improve timing without making poor
X/Y aim succeed.

The batting camera should sit far enough toward the handed shoulder that the
loaded barrel does not cover the incoming Pitch lane. Move the aim marker from
low to high and left to right before the Pitch: the hands/bat may load slightly
higher/lower and change tilt, but the motion must stay subtle, bounded, and
must not move the authoritative contact target.

At swing commitment, the hands and bat should begin together at the back
shoulder, slot forward, accelerate to a square-across-plate pose at the authored
contact encounter, extend through the ball, and then finish once toward the
front shoulder. It should hold briefly and never wrap around the Batter in a
full circle. Repeat with both handednesses and verify that the complete motion,
not just the Batter's box position, mirrors. The torso and weight should drive
modestly in sequence, while the independently owned hands and bat remain
visually connected. Aim high/low before swinging and verify that a bounded
amount of that posture remains visible through contact rather than snapping to
one universal path.

Try a descending Pitch with early, centered, and late versions of the same
aimed Swing. The virtual barrel should move upward through the aimed contact
point: aligned timing should be most forgiving, while early/late encounters
should alter vertical offset and resulting launch/spin without moving the
reticle or granting contact outside the authored window.

Swing deliberately too early and too late. On a miss, the Pitch must keep
moving, cross the plate, continue visually to the receiver catch point, and
only then
enter the dead-ball flow. A miss may be identified when the authored Swing
window closes, but that identification must not stop authoritative Pitch
flight. Fair contact and fouls should still end custom Pitch flight at the
resolved encounter. A foul should immediately become a visible physical ball,
remain live for an airborne defensive catch, and otherwise resolve when it
grounds or leaves play. Contact should feel quicker than the prior slow placeholder Swing,
with Power remaining slightly longer and less forgiving. Fair contact must not
produce a `PitchFlightActor` null-state error. The bat should begin behind the
handed back shoulder, drive forward through contact, and continue through a
short front-shoulder finish instead of snapping or circling back to stance. The
large receiver outline must remain hidden unless the explicit debug layer is
enabled.

Starting a new match should automatically play one, two, or three readable
camera views with `GAME START`, then settle into the correct batting camera and
wait for the Batter-ready confirmation. A one-view package should be one longer
take; across restarts, one-, two-, and three-view packages should occur.
Individual shots should visibly vary among
still, slow zoom, pan, and tilt treatments without jerky movement. The lighter
intro tint should preserve the field view. The sequence must be skippable. Taken
Pitches, fouls, misses, walks, strikeouts, hits, outs, new batters, and inning
changes should all flow after a readable automatic hold. A new
player-controlled Batter waits for one confirmation; additional Pitches in
the same plate appearance do not. The camera should
switch to the field on contact and return for the next role. Counts must
persist within a plate appearance, and the batter must advance only when that
plate appearance ends.

During the player's defensive half, the automatic hold should return to a
ready pitching state without throwing by itself. Use that state to change
Pitch, aim, effort, or legal defensive assignments, then set the tempo by
starting the next hold/release delivery. No extra advance click should be
required before that delivery input.

During the player's defensive half, open the Pitching Staff submenu. Its wide
angled camera and four full-width rows should show every player, Stamina, and
fatigue state without clipping. Selection is enabled only between batters;
returning closes the submenu and restores the pitching camera. Choosing the
active Primary Fielder as Pitcher must automatically move the Primary Fielder
role to another player. Exactly one Player-team prototype should expose six
selectable Pitches. Shallow Center and Middle Center must appear as disabled
`PITCHER LANE` cells; neither cycling nor AI setup may place the Primary Fielder
there. Deep Center remains selectable.

Shallow side anchors may stand in front of the mound at X +/-5.5 m, Z 8.5 m.
They must not obscure the Batter, Pitcher, or curved Pitch flight in either
gameplay camera. Fielders stay at their anchors until contact. After contact,
they may charge forward past the mound depth but must route around the Pitcher
without overlapping. This is body clearance, not collision-induced errors.

While pitching, hold left click, `Space`, or controller A and release near the
late gold cue at roughly 85% of the short meter. Mouse and keyboard must show
and use the same faster timing bar. The visible Pitcher should load and deliver
during that hold. Releasing just beyond the cue may add a bounded amount of
Fastball velocity or breaking-Pitch finish, but must visibly sacrifice command;
it is not a free replacement for the separate effort setting.
High-Control, fresh Pitchers should have a more forgiving useful window than
tired, low-Control Pitchers. Early and late releases should reduce command
without allowing any mid-flight steering. Holding beyond the window must
auto-release rather than stall the match.

At a stopped pre-Pitch state, note the inning, score, count, bases, current
Batter/Pitcher, selected Pitch, aim, effort, and defensive anchor. Press `F2`,
use the Mechanics Lab, then press `F2` again. The same match and selections must
resume without replaying the intro or resetting the inning. `F2` during a live
Pitch, ball-in-play, cadence, or presentation should refuse safely rather than
discarding the play.

With F1 off, the compact scorebug should be the only persistent baseball-state
readout: score, half/inning, count, outs, bases, Batter, Pitcher, Pitch count,
and Stamina. Use the tiny bottom-left `...` menu to cycle bottom right, top left,
and top right; bottom right should sit low while leaving a narrow call area
beneath it. Ball, Strike, and Foul calls should use that small beneath-scorebug
treatment in both player roles, and Ball/Strike reports should identify the
Pitch and speed. Begin-at-bat prompts and major play results should instead use
centered boxless white text with dark-blue outline/shadow. Hit results should
include exit velocity. The selected Pitch should remain compactly visible while
the player is pitching. There should be no persistent numeric effort prose or
WINDUP/DELIVERY/TRACK THE BALL helper text outside the F1 layer. With F1 on,
diagnostic text may appear at left but must not overlap or redundantly replace
the scorebug/result stack.

Use the same `...` menu to toggle the procedural sky back to the neutral gray
background. Neither choice may change gameplay. Field Setup's overhead framing
should include the plate and Batter rather than cropping the near field.

With `F1` telemetry visible, try pressing a Pitch number, `-` / `=`, `Q` / `E`,
`F`, and `C` after starting the release meter and again while the ball is in
flight. Pitch choice, effort, Pitcher/Primary Fielder roles, and Fielder anchor
must remain locked until the play returns to a legal ready state. Before
delivery begins, the controls legal for that point in the at-bat must work.

At game completion, a short automatic camera sequence must show `WIN` or
`LOSS`, the final score, and the new-match control. It must not alter the final
MatchState. Skipping the sequence should preserve the result overlay.

Missed swings should report whether timing or aim was the dominant error. The
opponent should protect more often with two strikes, take more selectively in
three-ball counts, and avoid feeling like a purely uniform random chooser.
Repeatedly using the same Pitch and visible location should raise debug
awareness and make good contact more likely. Mixing Pitch, speed, and location
should suppress that advantage. Far chase Pitches should remain difficult to
hit; the outer half should be more approachable than the inner edge. Even when
fresh in the awareness model, a high-speed Four-Seam should create visibly more
timing/aim pressure than a slower Pitch rather than being automatically squared.

Effort changes the speed of every Pitch, including off-speed Pitches. Higher effort should be faster and costlier without making an Eephus, Slider, or Drop feel identical to a Four-Seam.

The Four-Seam should occupy a clearly faster but still readable band, while the
Eephus should arrive slower without becoming a novelty-speed Pitch. A first
well-located Eephus may
deceive; a repeated or center-hanging Eephus should be dangerous to throw.
AI Pitcher set/windup duration should vary readably rather than repeat one exact
interval.

The yellow line marks the ordinary Safe boundary at 10.5 m, visibly in front of
the mound. The cyan Deep Air line sits at 17.0 m, leaving a 6.5 m ordinary-safe
band and a separate 6.4 m final band before the 23.4 m wall. A clean Primary
Fielder play on a still-moving grounded ball before the yellow line is an Out;
a stopped ball or a ball that crossed the line is at least a Single. A clean
moving-ground-ball control inside the Pitcher's fixed 0.60 m mound envelope is
the narrow exception and remains an Out. The cyan line marks Deep Air. A
bouncing ball reaching the back wall is a Double, a wall
strike on the fly is a Triple, and a fair airborne ball clearing the modestly
lower/closer wall top is a Home Run. Thin chalk foul lines remain as readable
fair-territory guides because airborne fouls are now live catch opportunities;
they are presentation, not the rules authority. The brown pole is a live object:
it should physically redirect the ball without deciding the baseball result.

The cyan line is not a general Double line: only an untouched airborne ball
crossing it establishes a Double. Use `F3` after a meaningful sample of normal
plate appearances and compare Out/Single/Double/Triple/Home Run frequency
before changing Contact/Power transfer or aerodynamic coefficients.

Hit moving grounders and low liners through the 0.60 m mound envelope. The
visible Pitcher must react, and a clean moving-ground-ball control there must
resolve as an Out even though the yellow line is in front of the mound. A
bobble or stopped ball must remain safe. Balls outside the radius or above the
authored reaction height must pass the Pitcher.

After a meaningful normal-play sample, press `F3` and inspect the emitted play
records. Calibration fields now include exit speed, launch angle, spray, first
ground position, resolution position/reason, result floor, and final defender
touch. Compare those distributions before moving a boundary or changing aero.

While the player is pitching, put a fair ball in play and verify that the camera
stays on the defensive/pitching side, pulls wider, and follows the ball. It must
not rotate through to the behind-the-Batter view at contact. Player-offense
contact should retain the ordinary behind-the-Batter follow orientation.

The Primary Fielder should show a brief rating-scaled reaction delay, run at a
believable speed, and only control balls the visible actor actually reaches.
High or horizontally distant balls must pass as misses. Bobbles should remain
near the defender. The Pitcher should react only to true
comebackers inside the small mound envelope, including a fast ball whose swept
frame segment crosses that envelope. A behind-mound Primary Fielder should not
run through the Pitcher to steal that play, but may route around the Pitcher
and charge into the near field after contact. Across player offensive plate
appearances, the AI should visibly choose different sensible grid anchors based
on Batter handedness/Power with deterministic variation. A below-wall ball must resolve at
the wall even if the physical contact callback misses a fast frame.

Compare mishits, centered line drives, high-contact flies, and rolled-over
grounders. The physical ball should now show a wider but deterministic range of
carry, fade/drop, and true slow rollers instead of converging on one tame path.
The AI offense should offer at a few more strikes but also swing through more
often; this is intended as behavioral variety, not a blanket contact buff.

Open Field View and verify the visible grid reads Deep Left/Center/Right on the
top row, Middle on the second, and Shallow on the third. Left and Right should
match the view from home plate. Foul flies toward a positioned defender should
be catchable; grounded fouls should not become fair hits. The same Primary
Fielder speed/reach thresholds apply in both halves.

`B` cycles Grounder, Deep Air, Wall On Fly, and Home Run Arc diagnostics. These bypass Pitch/contact only so field physics and rulings can be inspected deliberately; normal swings still exercise the full contact-to-ball pipeline.

Use `G` to put a runner on third, then produce or diagnose a fly catch at different fielder depths. Shallow catches should normally hold the runner; sufficiently deep catches can score a sacrifice fly.

## Not yet final

### Focused field QC collection

1. Run `python3 tools/verify.py` before playtesting (one-time setup and current
   results are documented in `VERIFICATION.md`). It imports a temporary project
   copy, checks core regressions/QC export, runs match and Jolt tests, and
   launches a headless smoke. Scripted test records are not human QC samples.
2. Check all seven anchors, then both role cameras with sidearm breaking
   Pitches and extreme aim/effort/fatigue. Neither defender may obscure the
   pitch lane. Check left- and right-handed delivery where available.
3. Verify Field Setup shows Single 10.5 m, Deep Air 17.0 m, wall 23.4 m and
   returns to perspective normally. Capture a current-build screenshot if the
   lines still look crowded; do not infer loaded geometry from an older image.
4. Collect an initial target of 100 fair balls in normal Match Mode across
   multiple matches, both offensive sides, and both swing types. This is a
   diagnostic sample, not a statistically conclusive balance target. Keep
   Mechanics Lab/direct-launch results separate. Completed records automatically
   save to `user://qc/`; F3 shows the absolute path. `R` starts a new session
   without deleting earlier saved files. Repeated F3 dumps are cumulative,
   not additional samples.
5. Keep `WIFFALTRO_FIELD_QC` metadata with each `WIFFALTRO_PLAY_RECORDS` dump.
   Compare fair-ball results and first-ground depth by swing type and player/AI
   offense; exclude balls, strikes, and fouls from the fair-ball denominator.
   First-ground proportions use only records with `has_first_ground = true`.
6. Separately test grounders crossing both internal lines (still Single),
   grounders reaching wall (Double), untouched airborne Deep Air crossings
   (Double unless caught), wall on fly (Triple), HR clears, and Pitcher
   clean/bobble/miss plays. Record seed/play number and video for mismatches.
7. Try an Eephus at minimum effort with a high target. If it cannot solve,
   verify the retry message, unchanged Stamina/count, and normal delivery after
   explicitly raising effort. The game must not launch a knowingly mis-aimed
   nominal pitch or silently raise the selected effort.

No Contact/Power, aerodynamic, or scoring-boundary tuning should precede review
of that sample. Physical bump-induced errors are not part of this pass.

All coefficients, field dimensions, fielding thresholds, Pitch identities, swing windows, camera framing, UI, and visual geometry remain tuning/debug content.
