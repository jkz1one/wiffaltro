# Successor plaque/legend private adapter

Inactive additive drafts. `Legend.project` strictly validates every present successor
progress record before making a deep-copy historical aggregation view. Null progress
stays unknown. Projection validates ordered run IDs and proof/status consistency but
is not owner provenance: the caller must replay owner-bound history first.

`Plaques.awards(career)` returns validated copied original-format records or null.
`valid_history` delegates exact award-time prefix checks to the original policy.
`capture` stages the original prospective capture privately and copies back only
plaque history on success. It neither adopts legacy history, delivers assets, saves,
nor admits owner checkpoints. There is intentionally no legacy `ClubPlayers.assets`
call. Original thresholds, five credited games per completed season, three completed
seasons, 40 hits OR 60 strikeouts OR 40 clean outs, and era/unknown semantics stay
owned by the original evaluator. No original files are changed.

The isolated test uses the actual owner-bound played-round fixture for no-award and
immutability checks. All multi-season eligibility operands are explicitly synthetic
structural histories, never physical games or proof of successor career completion.
Native verification is recorded in `docs/SUCCESSOR_ASSET_BASIS_CHECKPOINT.md`. This
adapter alone provides no full-season, Dynasty, owner-close, or distributable proof.
