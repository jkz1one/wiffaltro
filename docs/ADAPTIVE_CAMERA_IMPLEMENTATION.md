# Adaptive camera implementation

Date: 2026-09-24. Follows [CAMERA_REDESIGN_RESEARCH.md](CAMERA_REDESIGN_RESEARCH.md).
Local implementation; native visual acceptance remains open.

## Behavior

Batting contact now uses an isolated `BattingContactCamera` with the follow
behavior from `665b46e`, including its focus smoothing, pullback, and field-aligned
orientation. The pitching/batting aim and pre-pitch batting composition are
preserved. Defensive tuning no longer changes offensive contact follow.

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

The forecast is a short, revisable estimate from observed movement. Initial
classification uses a conservative carry estimate. Neither affects AI decisions,
fielding, or scoring. These are game-tuning choices, not measured human camera
operator parameters or a reproduction of a proprietary baseball camera.

## Dynamic stadium interface

Configure `MatchCameraDirector.configure_field(field, geometry, mound)` when
building or replacing a venue. `mound` is a field-local position; the geometry
root establishes the coordinate frame. Existing fields use `FieldDefinition`
depth, fair angle, and wall height. No live defensive position is selected by
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

- 24 historical offensive position/orientation snapshots, across both handednesses
  and three launch types. Expected values were captured from the actual old director,
  not calculated by the new implementation.
- 60 defensive trajectories across 18/32/55 m field depths, 16:9 and square viewports,
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
fixed-lens/four-metre-lane assertions have been replaced; offensive motion is
checked against its historical fixture rather than a new defensive speed limit.

The dynamic-field fixture deliberately disables camera physics interpolation,
matching the production camera. This is necessary when testing many manual
updates without rendering frames, or projection calls can observe stale poses.
These checks establish geometry and continuity properties, not subjective comfort.

For normal-speed native review, open this scene in Godot and run it with F6:

`res://src/labs/camera_replay/camera_replay.tscn`

Left/Right selects a play; R restarts the exact trajectory; B switches offensive
and defensive views; V switches Yard/Commons; Space pauses. The yellow ball is
enlarged for visibility. The scene is a synthetic camera fixture, not a complete
match: it does not run AI, advance a season, or reproduce wall/fielding outcomes.
Use an actual match afterward to review real contact, fouls, catches, home runs,
result transitions, and the following pitch. Native rendering was unavailable in
this environment; no visual-quality pass is claimed.

Verification result: all 31 steps in `tools/verify.py` passed, including live-match,
AI, season flow, camera, and core regression checks. Run record:
`builds/verification/20260924T034832905924Z/summary.json`. After that suite's source
snapshot, the final terrain-relative pitching-height adjustment separately passed
`adaptive_camera_test`, `camera_audit_test`, and `core_regression_test`. The replay
scene also completed a headless startup/run smoke check. No rendered acceptance
is implied by these results.

## Research addendum

The implementation adapts the group-framing/dead-zone principles and separation
of shot selection from movement documented in the research report. Godot's
[Camera3D documentation](https://docs.godotengine.org/en/stable/classes/class_camera3d.html)
confirms that FOV interpretation depends on `keep_aspect`; the fit accounts for
both conventions. [AABB operations](https://docs.godotengine.org/en/stable/classes/class_aabb.html)
provide the envelope/segment primitives used for scenery. These are engine
contracts, not evidence of comfortable camera timing.
