# Season shell polish

Date: 2026-09-25. Base: local `bc36788`, branch `season-stable-field-camera`.
This pass audits the existing season shell, menus, settings, camera integration,
AI decisions and match interaction. It does not implement progression-blueprint
features or claim native visual acceptance.

## Findings and changes

| Area | Finding | Change |
| --- | --- | --- |
| Settings | Only accessible inside a match; mute was the only audio adjustment | Shared clubhouse/pause panel with persisted volume, mute, backdrop and scorebox placement |
| Save recovery | Failed season writes showed a notice but offered no explicit retry | Retry Saving Season keeps the current page and persists the current session; Quit asks before losing unsaved changes |
| Final results | In-memory result recording and disk saving have different success states | Expose pending writes while retaining the existing once-only score guard; retry cannot duplicate a game |
| Settings writes | Write failure was only a console warning | Visible error/retry, validated loaded values, temporary-file replacement |
| Navigation | No general page-back shortcut; footer assumed one horizontal row | Escape/controller B returns from pages; footer wraps; wide body content can scroll |
| Controls | Discoverability depended on scattered gameplay hints | Shared How to Play guide in clubhouse and a scrollable Controls page while paused |
| Playability | Switching away from the application left play running | Focus loss pauses; a held uncommitted delivery cancels; returning focus requires deliberate resume |
| Controller pause | No Start-button pause route | Start pauses/resumes; B backs out of nested pause pages |
| Camera | Inspection ran frozen ball samples through live coverage, and a dead-ball hold could retain the inspected view after resume | Separate preview from live filters/result timing; restore the saved resolved-play frame and lens over 0.6 s |
| AI fielding | Pull-side choice read the authored batting hand instead of a switch hitter's selected hand | Use effective handedness and update the actual fielder anchor before delivery |

Audio volume scales the existing mix and defaults to 100% for old settings.
Muting preserves the chosen level, and zero volume stops cues. Settings remain
local; this is not a new audio bus/mixing system or controller-remapping feature.
Existing swing/contact rates, pitch sequencing, field physics, normal live camera
policies and season rules are preserved.

## Verification

The full `tools/verify.py` run completed 32 checks. 31 passed; the presentation-polish
fixture called the old private mute method after it moved into the shared panel.
That fixture was updated to activate the actual shared mute button, and its targeted
rerun passed. This was a test-call migration, not a disabled assertion.

- Full run: `builds/verification/20260925T051921504929Z/summary.json`.
- Corrected presentation check: `builds/season-polish-presentation-final.log`.
- Final expanded polish check: `builds/season-polish-targeted-final.log`.

The new `season_polish_test` runs actual menu/match components with isolated save
paths. It checks home-to-match settings, write failure/retry, malformed settings,
zero volume, failed final-score persistence without duplication, page-back input,
1280×720 and 1024×768 footer bounds, focus loss during a held delivery (including
an already paused delivery), controller pause, pause-controls bounds, both-handed
AI fielding, and resolved-camera restoration for both roles. Viewport-dispatched
mouse press/drag/release also confirmed that releasing a pitch over the HUD commits
at the chosen time; no production change was needed for that case.

Existing season/playoff/save, menu, live-match, match-soak, physical-ball, pitch,
AI chase/zone, switch-hitter and camera checks passed in the full run. Dynamic
camera coverage still passes the 120-trajectory fixture for both roles across
18/32/55 m fields, multiple aspect ratios/frame rates and transformed terrain.

### AI balance audit

The controlled 1,944-delivery production zone fixture reproduced the prior baseline:

| Contact rating | Swings | Contact, including fouls | Timing misses | Contact / swing |
| --- | ---: | ---: | ---: | ---: |
| 3 | 480 | 170 | 38 | 35.4% |
| 5 | 486 | 232 | 38 | 47.7% |
| 8 | 484 | 343 | 34 | 70.9% |

These are seeded zone deliveries, not batting averages or measured season difficulty.
There is no new reason here to retune batting probabilities. Native games must still
judge whether pitch sequencing feels useful and opponents feel appropriately fallible.

## Native review still needed

Rendering was unavailable in this environment. Geometry, lifecycle and interaction
checks do not prove readable typography, comfortable motion, controller-hardware
behavior or a good audio mix. On the Mac build, review:

1. Home Settings/Controls, draft, lineup, hub, stats, postgame and season recap.
   Check scrolling, keyboard focus, button clarity and the new volume slider.
2. Pause during delivery, flight and fielding; switch applications while holding
   a pitch. Confirm the canceled delivery and deliberate resume feel clear.
3. Inspect cameras on a dead-ball result, then resume; compare short contact,
   liners and deep flight at normal speed with the developer replay's C toggle.
4. Switch a switch hitter's side before readiness and check the opponent's setup.
   Play several innings across pitcher repertoires before judging AI difficulty.
5. Listen to contact, catch, bobble, wall and home-run cues at several volume levels.

The Quit confirmation covers the in-game Quit button; it cannot protect against
forced OS termination or storage failure. Unfinished games still restart from the
beginning. No midgame resume, cloud settings, general responsive/mobile redesign,
new cinematic shot director or progression systems are introduced.

## Engine contracts checked

Godot's [application focus notifications](https://docs.godotengine.org/en/stable/classes/class_mainloop.html)
provide the application-level focus boundary, avoiding ordinary transitions between
windows within the game. [HFlowContainer](https://docs.godotengine.org/en/stable/classes/class_hflowcontainer.html)
wraps controls when horizontal space runs out. These documentation contracts support
the implementation; they are not evidence of native UX quality.
