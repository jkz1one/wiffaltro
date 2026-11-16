# Successor operation-local Resource retention — 2026-11-16

The inactive successor codec now holds strong references to the authored pitch
manifests, retired recipes and four new pitch Resources for each synchronous
capture or restore call. References are cleared on return. It does not retain
signatures, validation answers, decoded seasons, gameplay outcomes or save data.
Original scope checks, source hashing, replay and exact recapture remain intact.
Historical live source and project configuration are unchanged.

## Focused native verification

`python tools/test_successor_signature.py` on Godot 4.6.3 verifies:

- Held and unheld capture return exactly equivalent payloads.
- A changed catalog or unexpected envelope key is still rejected after a valid
  operation; earlier successful capture does not grant later admission.
- Fresh creation/capture/JSON restore/durable save and separate cold reopen pass.
- Fresh legacy save/reopen and exact slot byte preservation still pass.
- Authored Resources remain unaffected by mutations to detached gameplay copies.

One same-process fresh-capture measurement was **167 ms held / 1312 ms unheld**.
This is a scoped sample, not a claim of universal latency or full-game speedup.
`--flow` additionally selects the separate real App draft/native physical-game/
cold-reopen suite described in `SUCCESSOR_FLOW_CHECKPOINT.md`; that suite also
passed against this candidate (seed `1794841049`).

## Compatibility and evidence boundary

The successor catalog intentionally hashes codec source. This edit changes its
signature. Earlier isolated draft fixtures are retained outside source, not
silently migrated or reinterpreted. No historical slot is opened or rewritten.
This is not cross-checkpoint v7 save compatibility or public career admission;
that requires the explicit versioned design in `SUCCESSOR_INTEGRATION_STATUS.md`.
No Dynasty, complete-round, shop-purchase, visual or export pass is implied.
