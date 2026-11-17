# Read-only partial authored identity foundation

This module is not connected to save admission. It creates no owner, grants no
access, migrates no save and changes no existing catalog descriptor. Game109,
Owner112 and General114 retain their exact source-bound readers. A partial
content ID cannot replace any of those signatures.

## What is projected

Every invocation reads live authored values and returns detached primitive data:

- All 50 known pitch definitions and ordered 41-active recipes, authored nested
  deliveries and neutral calibration fields; retired/historical mappings and
  historical canonical definitions remain explicit rather than discarded.
- Original reserved offerings, aliases, lesson prices and candidate acquisition
  metadata. Including a proposed price does not make it final balance.
- All 49 authored player definitions (48 progression players plus the debug
  definition), handedness, delivery, initial repertoire and
  gameplay fields, plus the actual progression ROWS/RECIPES/stat order/cap and
  initial profiles. These script-backed tables are not inferred from Resources.
- The currently selected commons and starter field definitions and dimensions.

Exact scripts and declared stored field allowlists prevent newly added fields
from being silently omitted. Resource path inputs require their expected domain
class. Top-level duplicate IDs fail closed. These structural/finite checks are not
a substitute for every gameplay range, eligibility or balance validator. Nested
historical definitions are embedded with all values: old and new recipe variants
may share an ID while differing in authored values, so this is not a claim of
one globally unique nested ID registry. Resource paths, instance IDs, editor
metadata and script bytes are excluded from the returned projection.

The record has explicit schema, partial=true and coverage fields, three named
domain projections/digests and a combined authored_content_id. The combined ID
binds both the declared partial scope and the domain digests. Gear, sponsors,
tactics, recruit/development policy, earned-access thresholds, League/career
reward policy, physics/replay algorithms and other content are NOT fully covered.
Do not label this identifier all game content or a complete replay identity.

## Canonical wire contract and native checks

The bounded primitive encoder uses distinct tags for null/bool/int/float/string/
array/dictionary, signed 64-bit two's-complement and IEEE754 finite binary64 in explicit
big-endian order, unsigned 32-bit lengths/counts, UTF-8 strings, ordered arrays and
sorted string keys. It distinguishes integers from floats and preserves signed
zero. Nonfinite values, non-string map keys, unsupported Objects/Resources/
Vectors/StringName values, cycles and exceeded depth/element/byte limits reject.
The projector explicitly converts supported authored vectors and StringNames
before encoding. Shared aliases encode by value; no cache survives a call.

Godot 4.6.3 passes fixed wire vectors, independent dictionary ordering, type and
length disambiguation, cycle/alias/budget rejection and caller immutability. The
actual catalog projects successfully; live pitch velocity, nested delivery
position, player rating and field boundary mutations change the relevant digest
and restoring each value restores the exact identity. Missing delivery,
nonfinite data, duplicate manifest player IDs and unsupported Resources reject.
Detached active ordering/profile changes affect their digests without editing
actual policy tables. Editor metadata changes are inert. A separate fresh process
produces the exact same identity. Existing save bytes, held authored Resource
graph and 109/112/114 descriptors remain unchanged.

The isolated JSON record is diagnostic evidence, not a new save schema or a
canonical-wire decoder. JSON numeric type coercion must not be used to reconstruct
typed wire data. Future owners may compare a stored identifier to a newly computed
authored identifier only under a separately qualified replay/schema contract.

## Required next ownership boundary

A persistent owner needs three distinct concepts: complete approved authored
content identity, an explicit replay protocol/schema selecting a fully validating
reader, and informational implementation attestation. Source/menu edits must not
silently relabel an old save, and an attestation is not authentication or a
permissive reader selector.

The first real continuation must fully validate an actual completed Owner112
run, retain its envelope unchanged, rederive its closed row/receipt/assets, and
create owned run 2 atomically in a separate format and slot with inherited access
and the existing ledger. Terminal112 already settles completion in sync(); its
frozen close()/start() methods intentionally reject. Do not rewrite its current
run field or invoke a rejected close as a migration shortcut. Actual next-owned
round/shop/cold qualification and eventual Dynasty remain required.
