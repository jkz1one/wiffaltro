# Successor integration status and gates

Source inspection after signature checkpoint `59ea701444e38a78f2189855ea53c44c4b8bce29`.
This is an implementation map, not a release or historical test certification.

## Preserve the full game

The live baseline retains substantial career, League, Dynasty, stadium, shop and
inventory code. The inactive successor's small menu and pitch-only shop are not
the intended finished interface. Preserve the original clubhouse/development
visuals and full game depth. Existing test files are references, not evidence
that this checkpoint passed their tests. Lost later work must be rebuilt and
retested; it is not recovered merely because similar baseline files exist.

## Explicit integration boundaries

- `successor_v7/codec.gd` rejects career, League, Dynasty, inventory, home/venue
  and inherited-access context. `progression.gd` admits base Build version 41.
- `build.gd` disables League/difficulty enable paths. `development.gd` disables
  Scramble/Dynasty and inherited Exotic history. Do not delete these guards to
  obtain superficial admission; add versioned, validated adapter contracts.
- `presentation/season/successor_v7/app.gd` disables inherited loadout, exposes
  only learn-type offers and rejects inherited checkpoint writes. Full shop,
  inventory and original presentation require successor transaction adapters.
- Baseline Dynasty profile capture and bridge construction use historical save,
  Build and authored-profile authorities. Successor uses `fresh_profiles.gd` and
  a different catalog. Carryover/decay must preserve exact recipe mastery,
  remembered inactive recipes, authored floors and paid-growth provenance.
- Baseline `league_unlocks.gd` starts Standard and Dugout and records later
  championship/tier access. Preserve this existing source policy when bridging;
  do not replace it with invented unlock thresholds from older proposals.
- `dynasty_lineage.gd` currently requires empty pending replacement. Release
  before reveal, mandatory refill and interrupted choice persistence need an
  actual implementation. Replacement cadence, candidate entitlement and price
  remain separate blueprint decisions; do not mistake commitment rules for an
  approved free replacement grant.
- `catalog_context.gd` hashes successor implementation files. Source changes
  invalidate its current save signature. Before admitting persistent public
  careers, add an explicit versioned compatibility/migration design rather than
  dropping validation or silently reinterpreting saves.

## Small, separately checkpointed sequence

1. Qualify four-pick draft, actual gameplay, complete round, once-only settlement,
   generated paid purchases and cold reopen. A single physical game is not a
   settled round and a standalone season is not Dynasty evidence.
2. Restore full shop/inventory UI through successor save transactions. Cover
   repeated clicks, pending pack selections, failed saves and exact retry.
3. Introduce catalog-aware career/League envelopes. Qualify one complete League
   route, then all nine and their difficulty rules without altering old readers.
4. Introduce Dynasty profile/decay/owner persistence, pause/resume, rollover,
   capacity resolution and committed release/refill workflows.
5. Reconnect owned-field/away-park/shared-career assets and original presentation.
   Qualify actual Dynasty seasons, then native visual playtesting and exports.

Keep saves and raw local evidence out of source publication. Every meaningful
increment must satisfy `SOURCE_CHECKPOINT_PROTOCOL.md` before the next batch.
