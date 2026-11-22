# Starter Standard NPC fixed-step feasibility (CP253)
QA only. No new player-facing path, subprocess runner or engine-time change
shipped. Both timed callbacks used the unmodified CP252 source Common App and
General V2 native in-process runner with pinned Godot 4.6.3, normal
`Engine.time_scale=1` and 60 physics ticks/s. This measures explicit
headless/fixed-FPS scheduling against older CP250 rendered observation
bounds on Linux software rendering. It does not predict Mac or a player
hardware speedup; it is a deterministic two-fixture feasibility gate only.

| Opening-round fixture | Rendered completion observed by | Source headless Resume → slot CAS/readback | Common App native launch included | Strict initial Continue (separate) |
|---|---:|---:|---:|---:|
| 1: Comets at Rivets | 196.4 s | 14.742 s | 1.019 s | 0.468 s |
| 2: Kites at Lanterns | 282.1 s | 27.781 s | 1.824 s | 0.738 s |

Native actual fixture1 was 3–4 (153 plays), fixture2 11–7 (202 plays).
Each took its own exact independently rendered predecessor; fixture2 did
not use fixture1's headless result. Report request, complete play records
including timing fields within plays, scores/stats, workloads and receipts
and the entire decoded owner candidate matched the rendered reference
except the named timer `report.physical.elapsed`. That scalar shifted
170.26792066666698→172.41666666669602 and
272.392791666667→275.2000000000784, respectively; the scalar is not silently
normalized anywhere in runtime. Original decoded prior data, no award or
settlement, and raw exact predecessor backups also matched. Independent
primary-only native Continue reopened both new pending snapshots. Nothing
restored or reran any real player's save or replayed the human game.

## Reproduce without shipping the test

Use the approved clean CP252 tree (`37d2c8a08d8ea5d6f2eaad69ed900b4f0973af6c`).
Build the CP252 Starter audited source stage as documented for the pinned
builder; copy its imported `out/project` to a fresh temp `project`, then
restore the exact detached `out/authored-project.godot` as
`project/project.godot` (raw SHA256 below, not the exported boot overlay).
In the observed run those were 2,719 hash-matched declared source files,
with only the excluded 3,511 test files absent. Alternatively assemble
the exact full source via `--dynasty-owner --preserve-authored-project`
and import; don't benchmark alongside unrelated games. Never include
these files in a distributed PCK. Copy these two .txt scenes into project
root with .txt stripped and both scripts alongside the project directory.
Set `W_GODOT` to the pinned absolute editor binary. Source App admission
requires its existing engineering launch flag; the wrapper sets that flag
only, not any packaged worker or test gameplay flag. Provide the audited
generated inputs from custody, never a regular profile.

| n | Start SHA256 | Expected native report request | Previous reports |
|---|---|---|---:|
| 1 | `7a361b19f3ce56d8ef280e86765be5377c4daab88622a2598ddabece4ce2b6e8` | `814e38b6f9e84c16cc644799a2c5b6fb9e7a0a169bc0edc0a035e5ff1150e16c` | 0 |
| 2 | `7641b956266cde7321e160a80deaa38786f57e0fd86471bb3f4e27305e856200` | `366867af4c58304ea5b7b259211b3f54b4c255b9bda3b4c66c0f67f98c4c6f6d` | 1 |

Run `bash run.sh run N ABSOLUTE_PRIOR START_SHA REQUEST PRIOR_REPORTS` once
each; it creates fresh directories and true isolated XDG data. Then use
`python compare.py ABSOLUTE_PRIOR GENERATED_PRIMARY RENDERED_SETTLED N`
with the CP250 real rendered settled oracle SHA256
`9e344b6552f4bf8b3e847a451acc3eefb6a3e730937b23027b00c1ce660b9ed3`.
Use `bash run.sh cold N GENERATED_PRIMARY GENERATED_SHA REQUEST N`
for each independent no-backup native read with no mutation.
Authored project SHA256:
`9650ccc2ce6957eda9f088663597bd754098dc05d42d0a00c9fa25c7085e35fd`.

A future player implementation would need a fixed same-executable child,
explicit immutable request and revision guards, bounded report transport,
cancellation and stale behavior, and the native validated parent-only slot
writer, followed by further coverage before calling it a speed fix.
