# Legacy Game109 exotic-history branch

Inactive additive pure helper. No Game109, Owner111/112/113, original source,
prices, thresholds or saves change. It neither installs history nor grants a
recipe, money, ownership, a new run, migration or persistent authority.

## API

- `valid_history(value)` validates a bounded array using frozen Game109 Eligibility.
- `evaluate(value)` returns `{ok: true, proofs, ids}` with detached copies, or
  `{ok: false, error}`. Valid empty history is distinct from invalid history.
- `collect(runs, before_run)` requires an explicit target from 1 through
  `runs.size() + 1`. It validates only the ordered prefix preceding that target.
  Every included row must be closed (`completed` or `abandoned`), pass original
  receipt/finish/tier/league-unlock policy, and carry strictly validated successor
  progress with its exact Game109 catalog and `season:<seed>` evidence binding.
  An active row before the target fails instead of being skipped or inherited.
  The target and later suffix are deliberately not validated by this prefix API.
- `price(id)` delegates frozen Game109 offerings/prices; unknown IDs return -1.

Abandoned rows retain only their validated known evidence, matching existing
career-history semantics. Null/unknown successor progress cannot be promoted into
proof. There is no reconstructed or invented physical provenance.

Repeated seeds and repeated proof season keys are allowed and retained, including
identical proofs. Eligibility is evaluated separately for each retained proof,
then recipe IDs are unioned, deduplicated and sorted. Partial per-season counters
are never combined to meet an otherwise unmet threshold. All returned proof arrays
are deep copies. No caller-owned row, proof, or saved file is changed.

Future game families may combine this legacy branch with their own current
validator. This helper intentionally does not accept future/mixed catalogs or
provide physical replay/owner admission. Tests of structural inputs do not prove
an actual completed season, inherited owned start, or Dynasty integration.
