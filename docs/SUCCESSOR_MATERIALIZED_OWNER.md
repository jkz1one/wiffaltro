# Materialized live-owner integration

This additive route addresses the remaining persistence bottleneck after69.
Removing117 history replay from pack handlers did not make them responsive:
observed successful purchase/selection still took about40/47seconds. The new
route stores explicit current runtime state instead of embedding prior-season
owners or re-simulating historical pitches during ordinary cold reopening.

## Isolation and contract

- New `wiffaltro-materialized-draft-v1.json` slot and explicit118 draft-only
  format. Earned-gameplay admission requires a deliberate subsequent contract.
- Original114/117 source, save readers, gameplay art and slots remain unchanged.
- `tools/assemble_successor.py --live-owner` selects the additive launcher in a
  newly assembled project. Default assembly still selects117; the repository's
  original project main scene is untouched.
- Explicit field allowlists include human and five AI builds, bank state,
  player development, current-season transaction journals and hidden shop state.
  Journal-dependent gameplay queries are retained, not replaced by an invented
  balance-only save. Authored objects are recreated by fixed known factories;
  arbitrary script or Resource deserialization is not accepted.
- This is offline consistency, not cryptographic proof of historical purchases.
- Atomic writes pin expected primary bytes, preserve backup, refuse uncertain
  temporary files, and keep an exact failed candidate for retry. This is not a
  power-loss or multiwriter guarantee; automatic interrupted-temp recovery is
  not yet integrated.

## Current scope

Increment70 passes genuine fresh Standard/Dugout entry, four actual draft
choices and separate-process Continue. Its admission is deliberately
limited to pristine first-season draft/roster state. A bounded deterministic
birth/draft reference checks exact unearned state; it does not replay physical
games or past-season history. Full operation timings are measured before claiming improvement. Original character stats and repertoire remain authored.

Gameplay, earned shops, settlement, permanent career advancement and Dynasty
must be bound to this route and retested before their controls are enabled.
They are not removed from the project or inferred from draft hydration. Deferred
Dynasty adapters are preserved as unqualified work and excluded from70's manifest.
No distributable or completed-game claim is made by this document.

## Verification

Both leagues passed birth, four picks, injected prewrite refusal and exact
retained retry, changed-primary refusal, malformed-save rejection, detached
clone isolation, and separate-process Continue. Genuine earlier66 v3 primary
and backup copies stayed byte-identical. The common imported source assembly
and all11 core new-family files were independently hash checked afterward.
The two Python assembly-safety tests also pass.

Observed full-operation milliseconds in this environment:

| League | Birth | Draft1 | Draft2 fault | Draft3 | Draft4 | ColdContinue |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Standard | 2434 | 2717 | 2269 | 1693 | 5003 | 7095 |
| Dugout | 2794 | 1772 | 1666 | 1631 | 9728 | 6422 |

These are not a responsiveness pass. Cold performs materialized hydration plus
a bounded pristine fresh/draft reference, not historical physical simulation
or journal replay. Earned-state admission must not reintroduce the old replay
chain. Original failed diagnostics are retained: an inherited legacy HUD update
was inapplicable to this new scene, and native nested container comparison
rejected JSON numeric representations. Final source overrides that HUD update
and uses explicit primitive semantic comparison, keeping booleans distinct from
numbers. Native Sky smoke created a genuine Dugout career and selected Jules Moss,
Val Morgan, Finley Brooks and Jo Lane with mouse input. Empty-slot Continue
showed its explanatory notice; roster scrolling worked. It found a display-only
mismatch: draft summaries used old raw asset pitch lists while the roster used
the actual build profiles. The summary also omitted Fielding and Pitching.
Both views now use actual build definitions and the four authored stats. Focused
menu tests checked all12 offers and four roster summaries for the native seed.
A native cold Continue after correction restored all four saved players and
visually confirmed corrected Val/Jo pitches and Contact/Power/Fielding/Pitching.
Only the menu changed after core qualification; two focused menu tests bring
the final manifest to13 files. Gameplay/character values were not retuned. The editor additionally reported parse errors in historical
`src/tests` scripts present in the broad source assembly. This is not a clean
release export or whole-repository test pass.
