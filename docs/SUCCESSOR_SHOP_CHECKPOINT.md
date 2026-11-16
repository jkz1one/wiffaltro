# Additive successor full shop — 2026-11-16

The inactive successor App now opens a subclass of the original Season Shop,
not a reduced pitch-only list. Original widgets, theme, layout, scrolling,
confirmation, equipment/sponsor reviews and generated offer behavior are
inherited or copied verbatim with current-catalog display substitutions.
Three new adapter files are tracked separately in the manifest's `additions`;
the recovered 47-file inventory remains in `files`. No historical source or
original development visuals are overwritten.

Shop commits now adopt the candidate build through the runtime's roster-aware
method, preserving the outgoing recruit's lineup position. Success means the
exact candidate became durable and was promoted. Failed saves retain the exact
candidate and leave the original season intact. The exclusive shop modal exposes
an exact-save retry and close-without-discarding path; it cannot trap that retry
behind the modal or issue an intervening purchase while a candidate is retained.

## Native qualification

`python tools/test_successor_signature.py --shop-fixture <isolated-round-save>`
accepts only an explicitly supplied prior isolated test slot, reads it without
modification, and copies it into a fresh isolated user-data directory. The
verified winning-round seed `1794841606` was used: its real earned cash funds the
purchase; no reward, score, price or profile was injected. The tested behaviors:

- Existing three-game round restored through full Codec validation.
- Full inherited shop controls render, with one window on repeated opening.
- Generated development target labels, target inspection, cancellation and
  confirmation preview do not spend or mutate the saved build.
- A legal generated offer is purchased through the shop confirmation callback.
- An intentionally preexisting isolated `.tmp` file blocks saving. The original
  slot bytes and live build remain unchanged, no success is reported, and the
  identical candidate can be retried using the modal's actual retry button.
- Exact duplicate purchase does not grant another change (idempotent success is
  permitted by the underlying transaction ledger).
- Separate cold process exactly restores the expected checkpoint and constructs
  the next fixture.

The initial harness incorrectly routed non-development offers through the
recipient chooser; category-specific UI routes were already correct. A second
attempt used a legitimate losing-round fixture whose remaining cash could not
fund an offer. Those attempts were retained as failed evidence, then the harness
was corrected and a separately verified winning-round fixture used.

`--recruit` is a **controlled build-ledger fixture**, not actual gameplay:
a deterministic generated recruit offer is funded by one explicitly synthetic
reward command. It exercises quoted signing, unchanged preview, invalid-command
rejection, exact roster/lineup replacement, duplicate behavior and separate
cold build replay. It does not qualify full-season recruitment persistence.
The default signature suite separately rechecks fresh successor creation,
capture/restore/cold reopen and legacy slot preservation.

## Remaining boundaries

This is bounded headless UI/transaction qualification, not human-input visual
playtesting, every shop branch, whole-season/career/Dynasty integration or an
exported build. Sponsor-specific concession, capacity, pack-interruption and
full-season recruitment paths still need targeted qualification. Existing
synchronous clone/replay/save work can stall the UI; this increment does not
claim responsive background transactions. Saves and raw evidence remain private
outside GitHub. Current gameplay source hashes are unchanged, so prior valid
isolated successor saves are validated normally, not migrated or re-signed.
