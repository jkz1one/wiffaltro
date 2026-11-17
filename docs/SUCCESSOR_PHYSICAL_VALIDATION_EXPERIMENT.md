# Unbound physical-report validation candidate

This separate module does not change the production engine, App, Codec, catalog
identity or existing saves. Ordinary reports omit only the redundant outer
identity computation: unchanged Core validation still freshly checks the exact
supplied identity before accepting anything. All envelope, rules, ownership,
tactics, workload and physical checks remain. No cache, trusted token or caller
validation flag exists. Well-formed Doubleheader follows the full original route.

## Malformed ownership defect discovered

The initial Doubleheader negative test revealed that the original validator can
send boolean ownership entries into a Dictionary-typed helper before its later
element-type check. Both reference and initial delegate logged a script error.
The strict harness correctly failed despite their eventual false results; that
failure evidence is retained and is not a pass.

The candidate now rejects non-Dictionary ownership entries before Core or
Doubleheader delegation. Tests cover both bad positions and both bad together.
Those cases run against the candidate only, explicitly because the baseline
error is already known. Well-typed invalid ownership still has reference parity.
The production reference defect remains unfixed: this candidate must be integrated
and requalified before claiming production hardening.

## Verified scope

Godot 4.6.3 passes authentic current-source Standard history (two NPC reports)
and Doubleheader history (four NPC reports), followed by separate fresh-process
repeats. Every real report is accepted by both routes. Catalog, empty catalog,
envelope, core, rules, well-typed invalid ownership, workload, resolver, extra-key
and null tampering reject with parity. Caller data, replayed owner, immutable
source fixture, save files and held authored Resources remain unchanged.

A disposable catalog-bound source copy is changed between calls, both routes
reject the old report identity, then exact source bytes are restored before
asserting results. Both accept again on independent calls. The runner also checks
restored bytes. Original repository/stage/source fixtures are never modified.
This checks freshness between calls, not concurrent file-mutation atomicity.

## Limited performance evidence

Warm report-local ABBA samples, under concurrent background work:

| Actual reports | Reference mean seconds | Candidate mean seconds | Samples per route |
| --- | ---: | ---: | ---: |
| Standard, two processes | 0.098271 | 0.063552 | 8 |
| Doubleheader, two processes | 0.372982 | 0.401495 | 16 |

The ordinary route removes one direct signature computation per successful call.
The unchanged Doubleheader delegate's slower samples illustrate environmental
variation. These are small, overlapping-work diagnostics, not whole-restore
measurements or a production speedup. The earlier profiler's 236 total signature
calls are not all attributed to this boundary. Actual positive coverage does not
include every ordinary League, live integration or owned/Dynasty qualification.
