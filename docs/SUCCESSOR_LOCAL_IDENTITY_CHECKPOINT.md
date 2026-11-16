# Local identity-work reduction — 2026-11-16

The experimental live League progression helpers now compute one fresh catalog
signature per synchronous wrap/unwrap call, instead of recomputing it for the
explicit field, descriptor and composed journal signature. Pure private helpers
reuse that local string only within the call. There is no global cache, operation
lease, cached validation result, decoded-state reuse or caller-supplied authority.
All descriptor keys/types/version/purpose/nonempty/equality checks remain intact.
No gameplay rule or original source/standalone-v7 file changes.

## Native evidence

`python tools/test_successor_signature.py --identity` compares all four optimized
helpers against inline pre-optimization reference bodies under the same actual
catalog signature. Build/development wrap and unwrap outputs match exactly.
Both paths reject six corrupted-descriptor cases. Full JSON replay and exact
recapture also pass.

A scratch three-sample comparison measured fresh drafted capture **349→181 ms**
and restore **2571→2294 ms**. The independent repository runner measured about
**173 ms capture / 2112 ms restore** for the 17,615-byte fresh draft checkpoint.
These are scoped samples with ordinary system-load variation, not a claim that
all UI transactions or full-season restores have those latencies. The remaining
synchronous replay cost still needs attention before release.

The actual live Dugout `--dugout-round` suite is rerun against the new source
identity: seed `1794845591`, real human game, cold pending resume, two real AI
reports, once-only round settlement, earned pack purchase and separate cold
purchased reopen. No score, reward or catalog identity is substituted to reuse
older evidence. The retained actual one-AI pending checkpoint also passes the
full pending projection/nonmutation, report/ownership tamper rejection and
separate cold exact-recapture suite under this source identity.

## Compatibility boundary

This implementation file is part of the experimental source signature. Prior
live109 fixtures remain preserved with their verified checkpoint
`d400705da27e280d9316ce3e7f057a406fed74bc`; they are not migrated or re-signed.
Current tests create new isolated data. Original production and standalone-v7
readers/saves remain unchanged. This is not whole-season, career, Dynasty,
visual/input or export qualification. Private saves, logs and caches are excluded
from the source checkpoint.
