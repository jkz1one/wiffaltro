# Earned Dynasty fixed-step feasibility (CP419)

This is a diagnostic under `tools/qa`, not a player-facing runner or a release.
It compares the same two owned Round 2 CPU fixtures that were previously played
by the normal installed Linux build. It neither opens a player's regular
profile nor writes a season save. No original player data or report payload is
tracked here.

The real Dynasty runner and its authored 60 Hz physics are unchanged, with
`Engine.time_scale=1`. The editor is headless with fixed frame scheduling, so
it does not wait out every second of the simulated game. Before each run, the
probe independently derives the exact previously rendered request from that
fixture's own audited predecessor. The second timing does not assume that
the first diagnostic report is accepted in place of its rendered oracle.

| CPU fixture | Away–home | Physical plays | Canonical projection | Fixed-step simulation |
|---|---:|---:|---:|---:|
| 4 | 14–3 | 128 | 21.275 s | 11.428 s |
| 5 | 3–5 | 135 | 22.009 s | 11.217 s |

Reading/materializing the prequalified D3 image took 21.190 s once in this
process. That is not a full cold career verification. The rendered report
game-clock values were 200.136785 / 184.678289 s; fixed-step values were
199.416667 / 184.200000 s. The JSON comparison separately reports the named
outer elapsed timer and only single-last-bit differences in 25 / 28 floating
values. Scores and report structure match. The diagnostic neither modifies
nor normalizes the reports used in validation. These are engineering measures
on the Linux cloud computer, not shipping-performance or Mac claims.

The exact two returned reports were also admitted sequentially, without
writing, by the existing Dynasty round projector. The first report left
fixture 5's request key unchanged. Both reports reproduced the rendered
round’s scores, all six clubs’ cash, exact reward and purchase journals,
rosters, and the next managed fixture. This does not certify other schedules,
the playoffs, a shipped worker, or a target Mac.

## Reproducing

Prepare a fresh, imported disposable forward-catalogue QA source project
from the verified CP418 recovery commit `3f61b4ac6621e2c9940c895d5920f255c18ed52d`.
The official forward candidate's preimported source project is suitable if
copied to a new disposable directory; keep all three forward-catalogue overlay
files. Do not inject test scenes into an export package. Run with the pinned
Godot 4.6.3 vendor editor and these three audited synthetic, unzipped wrappers:

| Exact predecessor | SHA-256 |
|---|---|
| CP417 human home game, zero CPU reports | `1f66bea4b194fc58a917177867624291d77dec7853c36b6d9b4178174473f9bc` |
| CP418 with native fixture 4 appended | `9a2fb35d903a2857b74e066393f29542460be69a543914aa590dcc34f3113196` |
| CP418 with both native reports, before payment | `614fe931fdcb03c0327b5473d3f59dddd0efcad7a5bbbf52f3d22a3e754519e4` |

```sh
bash tools/qa/cp419_dynasty_fixed_step/run.sh GODOT FORWARD_QA_PROJECT \
  HOME_PRIMARY CPU1_PRIMARY CPU2_PRIMARY NEW_OUTPUT_DIR
```

The temporary scene and XDG profile are isolated. The script refuses existing
output or scene files, verifies the wrapper hashes before running a fixture,
and writes no new save. Its second scene validates reports through the
unmodified admission and projection routines without writing to disk.

A straightforward generic materialized hydration was rejected as a fast
request path: it produced a different fixture 4 request and could not project
fixture 5. Keep the validated canonical request source. A production worker
would separately require the exact graphical owner's authorization, an
unchanged revision and request, a bounded return protocol, fail-closed
cancel/timeout/stale handling, and the normal parent-only save path. The
single-process measurements here do not include that worker overhead.
