# Pure successor stadium-progress adapter

This additive adapter accepts career run operands and returns only closed-prefix
stadium aggregates. It cannot admit a career, close a run, award cash or items,
or persist anything. Callers must first replay the entire owner-bound history.
An empty result can mean either no closed runs or rejected input; it must never
be used as proof that arbitrary history is valid.

Each closed row is checked for consistent completed/abandoned proof state.
Non-null successor progress passes the existing strict CareerProgress validator
before an in-memory historical-compatible projection reaches unchanged
StadiumCareerProgress.capture. The projection preserves every game's stats and
unknown evidence. Recipe IDs outside the old validator are filtered only from
that private view; lessons do not affect stadium aggregates. Nothing is serialized
as historical evidence. Structurally valid invented stats still require rejection
by the caller's full physical/owner replay.

Shared rules remain authoritative: regular-season wins, completed-season counts,
positive-only hits/homers/strikeout fields, null-progress behavior, credit pairing,
and totals through a specified closed prefix. Capture stops at the first active
row exactly as the original helper does. It is not a history-order validator.

The focused test first restores an actual isolated one-round owner111 checkpoint
from user://source-owned.json and verifies no closed credit. Separately labeled
synthetic abandoned/completed operands test shared aggregate equivalence, null
progress, ten regular wins versus playoff wins, credit pairing, active-prefix
stopping, totals, inconsistent input rejection and source preservation. These
are not played completion or abandonment evidence.

Native verification and limits are recorded in `docs/SUCCESSOR_ASSET_BASIS_CHECKPOINT.md`.
