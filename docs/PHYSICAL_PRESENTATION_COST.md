# Offscreen presentation cost

Saved physical fixtures default to a lean presentation path. The actual pitching,
batting, contact, Jolt ball/defender integration, fixed physics step, gameplay
cadence, home-run carry/freeze/hold, event capture and elapsed simulation clock
remain the same. Invisible per-frame camera, ball trail/shadow, pitcher telegraph,
feedback/event panel and flight diagnostic updates are omitted. Pitch/contact
trace meshes and ordinary HUD refreshes are also omitted.

The existing lab nodes still allocate at startup to preserve shared dependencies.
This is a bounded hot-path reduction, not a scene-free resolver or an accepted
release latency. No global time scale, physics tick rate, sport tuning, save schema,
resolver identity or request hash changes. Build41/save46/Career21/policy2 remain
unchanged; historic Build41/save45 score-only seasons still use their old resolver.

`PhysicalMatchRunner.presentation_enabled = true`, set before `start`, retains the
previous presentation updates for diagnostic native captures. The job copies that
flag at start; changing the runner's next-job setting cannot change an active job.
It never enters persisted match identity. Human matches always retain presentation.
The round progress lightbox reads actual MatchState scores/innings directly and
continues to render, pause, recover and retry normally.

`python tools/verify.py --only physical-match-equivalence --timeout 360` runs two
pairs of complete real games, checking every full-precision JSON-normalized report
field. One pair uses the home field; the other uses the away field, paid Gear and
exhausted starters requiring legal replacements. It checks omitted dynamic meshes,
retained diagnostic traces, unchanged global time/ticks and untouched source state.
`--rendered-ui` also runs this paired scene on the native renderer. Wall times are
measurements, not pass/fail speed thresholds or hardware guarantees.

Primary references consulted: Godot4.7 [SubViewport](https://docs.godotengine.org/en/4.7/classes/class_subviewport.html)
defines UPDATE_DISABLED as stopping render-target updates; it does not promise
that scripts cease generating geometry. [ImmediateMesh](https://docs.godotengine.org/en/4.7/classes/class_immediatemesh.html)
documents explicit surface clearing/vertex submission/commit and their efficiency
limits. [Node](https://docs.godotengine.org/en/4.7/classes/class_node.html) documents
independent process callbacks. The implementation explicitly skips visual work,
and real paired execution verifies that the gameplay evidence stays identical.

Headless baseline/checkpoint measurements on this environment:

| Scope | Prior presentation | Lean path | Reduction |
| --- | ---: | ---: | ---: |
| Seed29 home-field paired job | 13,202ms | 11,477ms | 13.1% |
| Seed47 away-field/Gear/fatigued paired job | 12,556ms | 11,762ms | 6.3% |
| Complete23-game saved season | 386,601ms | 365,647ms | 5.4% |
| Final five-fixture resolution wave | 85,306ms | 77,003ms | 9.7% |

The paired jobs ran sequentially in one test. The whole-season comparison uses the
previous checkpoint's recorded benchmark and the fresh run; it is not a controlled
hardware benchmark. Both season runs produce3376 releases,4462.7666666677 simulated
seconds and1,517,377 saved bytes. The new run reloads every round with exact evidence,
wallets and builds. Regular two-game visits range19.3–31.95 seconds, and total cost
remains substantial. Speed is not an acceptance criterion.

Final measured results and reviewed native captures are recorded in VERIFICATION.
Broader AI purchasing/use/settlement, Doubleheader workload carry, final UI polish,
human visual/feel acceptance and historical full-suite reliability remain open.

Reviewed actual native captures: [round progress](reviews/20261003-physical-cost/round-running.png)
and [diagnostic field](reviews/20261003-physical-cost/diagnostic-field.png). These
verify retained presentation; they do not grant human visual/feel approval. Native
pairs also compare exactly, with3.4–3.7% measured reductions on llvmpipe.
