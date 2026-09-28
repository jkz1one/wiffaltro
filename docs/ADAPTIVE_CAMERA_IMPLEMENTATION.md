# Adaptive camera implementation

Date: 2026-09-24. Follows [CAMERA_REDESIGN_RESEARCH.md](CAMERA_REDESIGN_RESEARCH.md).
Local implementation; native visual acceptance remains open.

## Behavior

Batting and defense use independent coverage policies and a shared projection fit.
The offensive audit compared against the restored `665b46e` follow and exposed
an immediate high crane target on every contact, plus abrupt visibility recovery.
`BattingContactCamera` now holds the entry composition when the subject group fits
and the play needs little room. Height and forecast depth relative to the active
field progressively open the view. It keeps a plate-side composition, frames the
ball/ground/forecast/relevant defender, and bounds acceleration, rotation and lens
expansion. It no longer replaces the transform to recover visibility. The existing
pre-pitch composition and aim mapping remain intact; the pose now uses the active
field coordinate frame.

Defense uses a subject group: ball, ground reference, short forecast, and nearby
relevant defender including head/feet. Remote defenders are excluded until relevant.
A screen-space dead zone allows soft contact to remain locally framed. As play
approaches the camera, ground coverage opens and follows the action without a
scoring-line trigger or turnaround. Deep airborne contact earns an elevated side
composition; short popups receive vertical coverage. The solver uses the viewport's
aspect ratio and projection convention to fit the group. It moves the camera to
provide room and uses at most 12 additional FOV degrees as a secondary correction.

Translation is acceleration-limited and orientation changes at a bounded rate.
The selected flight side stays consistent through the play. Live movement ends
when the play resolves. There is no fixed delay after release and no mandatory
0.85-second opening on every contact. This is a continuous coverage implementation;
a broadcast cut/editor system remains future work.

The home-run handoff from live coverage to the establishing shot now eases from
the actual current pose, with duration based on travel/angle and bounded to
0.9–2.8 seconds. This is a targeted result transition, not a change to all match
cadence or view switches. The existing 1.25-second carry and 4.4-second total
home-run presentation remain intact. No post-release view lock is introduced.

The forecast is a short, revisable estimate from observed movement. Initial
classification uses a conservative carry estimate. Neither affects AI decisions,
fielding, or scoring. These are game-tuning choices, not measured human camera
operator parameters or a reproduction of a proprietary baseball camera.

## Dynamic stadium interface

Configure `MatchCameraDirector.configure_field(field, geometry, mound)` when
building or replacing a venue. `mound` is a field-local position; the geometry
root establishes the coordinate frame. Existing fields use `FieldDefinition`
depth, fair angle, and wall height. No live coverage position is selected by
stadium ID, a named wall node, or a hard-coded 23.4 m boundary.

A generated stadium may supply these methods on its geometry root:

```gdscript
# Field-local bounds enclosing the playable area, not every decorative building.
func camera_play_bounds() -> AABB:
    return generated_play_bounds

# Ground elevation at the requested field-local point, in local metres.
# Extend meaningfully beyond the playable area, where the camera may travel.
func camera_ground_height(local_point: Vector3) -> float:
    return terrain_height_at(local_point.x, local_point.z)
```

The camera reads those queries live, so a changed bound or terrain sample is not
stuck in an old configuration. Providers can supply asymmetric bounds and uneven
ground. Bounds alone are an envelope, not a collision shape or a replacement for
actual field/scoring geometry. The camera frames the actual action rather than
zooming out to include the entire stadium on every play. Pitching uses the mound;
field setup and scenic shots use the venue bounds. Batting keeps its established
plate-relative behavior.

For scenery, set `camera_occluder = true` metadata on a mesh or a parent subtree.
Children inherit the setting; `false` excludes a subtree. Current wall/pole and
Commons scenery are registered this way; ground is excluded. Thin surface decals
are ignored. The collector refreshes on contact and every 0.25 s while tracking.
Registered meshes use their current transforms/AABBs, so moving or removing a
prop does not leave old bounds behind. Reconfiguration restores temporary materials.

Current fading supports `StandardMaterial3D` overrides. Custom shaders and complex
multi-material assets need an explicit compatible fading strategy when authored;
they are not automatically made transparent. Terrain providers do not generate
new playable hills, stadium rules, or future venue assets. This change establishes
the camera integration point for that work. Changing pitch/plate coordinates or
nonstandard gravity would need a broader gameplay-coordinate update too.

## Verification and replay

`src/tests/adaptive_camera_test.tscn` checks:

- Offensive contact framing across both handednesses and three launch types,
  comparing the initial step to the captured historical fixture. Soft contact
  must travel less than 0.7 m in its first half-second; historical poses are a
  comparison baseline, not frozen transform requirements.
- Home-run transition entry, completion, lens restoration and next batting view.
- Projection fits cross-checked against Godot in landscape and portrait viewports,
  with both horizontal and vertical FOV conventions.
- 120 trajectories covering both roles across 18/32/55 m field depths, 16:9 and square viewports,
  and 30/120 Hz camera updates. Providers include asymmetric bounds, a translated
  and rotated root, and an 8% ground grade.
- Ball/ground framing, nearby defender visibility and useful projected height,
  limited whole-play rotation on grounders, little movement on soft contact,
  dead-play holds, live bounds changes, and added/moved/freed obstacles.

Measured dynamic-field rows are saved in [ADAPTIVE_CAMERA_AUDIT.csv](ADAPTIVE_CAMERA_AUDIT.csv).
`path` is accumulated travel in metres; `rotation` is accumulated quaternion
angular travel in degrees, not net yaw. Counts cover the sampled synthetic flight
and stop at the field boundary, three seconds, or half a second for soft contact.

The existing camera audit additionally checks both current venues, eight flight
patterns, both player roles, and 30/60/120 Hz, plus 7,680 tracking samples. Obsolete
fixed-lens/four-metre-lane assertions have been replaced. Both roles now receive
per-step translation and rotation checks, alongside framing and obstruction checks.

The dynamic-field fixture deliberately disables camera physics interpolation,
matching the production camera. This is necessary when testing many manual
updates without rendering frames, or projection calls can observe stale poses.
These checks establish geometry and continuity properties, not subjective comfort.

For normal-speed native review, open this scene in Godot and run it with F6:

`res://src/labs/camera_replay/camera_replay.tscn`

Left/Right selects a play; R restarts the exact trajectory; B switches offensive
and defensive views; V switches Yard/Commons; Space pauses. C switches to batting
and restarts the same play with the old/new offensive follow. The old controller
is a developer-only reference captured from `6edb9a4`, never used by normal matches.
The yellow ball is
enlarged for visibility. The scene is a synthetic camera fixture, not a complete
match: it does not run AI, advance a season, or reproduce wall/fielding outcomes.
Use an actual match afterward to review real contact, fouls, catches, home runs,
result transitions, and the following pitch. Native rendering was unavailable in
this environment; no visual-quality pass is claimed.

Verification result: all 31 steps in `tools/verify.py` passed, including live-match,
AI, season flow, camera and core regression checks. Run record:
`builds/verification/20260924T042349010209Z/summary.json`. The replay's old/new toggle
also passed a headless smoke check in both venues. No rendered acceptance is
implied by these results.

## Matched offensive audit

The same deterministic trajectories, aerodynamic integration and 60 Hz camera
updates compare the previous local baseline (`6edb9a4`) with this implementation.
These are synthetic paths, not measured human camera operation or full matches.
First-half-second travel and accumulated angular travel:

| Contact | Before travel | Now travel | Before turn | Now turn |
| --- | ---: | ---: | ---: | ---: |
| Soft grounder | 14.39 m | 0.00 m | 35.79° | 0.00° |
| Hard grounder | 15.00 m | 5.03 m | 34.42° | 13.17° |
| Fast liner | 16.18 m | 6.78 m | 34.00° | 27.99° |
| Deep fly | 20.54 m | 6.55 m | 38.50° | 20.44° |
| Short popup | 22.44 m | 9.00 m | 41.64° | 22.37° |

[CAMERA_BATTING_COMPARISON.csv](CAMERA_BATTING_COMPARISON.csv) includes these samples
and each observation's endpoint. Angular travel is cumulative quaternion rotation,
not net yaw. Reduced movement is evidence of restraint, not proof of comfort.
Native A/B playback must still judge whether deep coverage opens in time and
whether the ball, ground and defender remain easy to read together.

## Research addendum

The implementation adapts the group-framing/dead-zone principles and separation
of shot selection from movement documented in the research report. Godot's
[Camera3D documentation](https://docs.godotengine.org/en/stable/classes/class_camera3d.html)
confirms that FOV interpretation depends on `keep_aspect`; the fit accounts for
both conventions. [AABB operations](https://docs.godotengine.org/en/stable/classes/class_aabb.html)
provide the envelope/segment primitives used for scenery. These are engine
contracts, not evidence of comfortable camera timing.

Unity's [Position Composer documentation](https://docs.unity3d.com/Packages/com.unity.cinemachine@3.1/manual/CinemachinePositionComposer.html)
describes screen-space dead zones, damping, and the noise/lag tradeoff of lookahead.
This pass adapts those principles with a short forecast and separate bounded
rotation. The exact thresholds and transition times are game-specific tuning.


## Pause integration polish — 2026-09-25

Inspection now uses authored previews without sending the frozen ball through live
coverage filters or advancing a home-run transition. Pause without inspection holds
the current view. Resuming after inspection of a resolved play eases back to its
saved pose/FOV over 0.6 seconds, then holds until the next shot. The normal small-hit
and deep-flight policies remain unchanged. `season_polish_test` covers both roles.
