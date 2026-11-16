# Inactive successor career evidence module

This additive module consumes the independently admitted League109 Dugout0
checkpoint. It does not change the League catalog, reader, source manifest or
save slot. Its own source signature includes the League catalog signature and
its adapters/shared aggregate validators. Restore these `.gd.txt` sources to
the manifest paths only inside an isolated project with the admitted League109
and frozen successor-v7 dependencies.

## API and authority

`career_run_evidence.gd.capture(checkpoint: Variant, run_id: int) -> Dictionary`
accepts a complete League109 envelope, **not a live SeasonState**. It first calls
`Codec.restore`, including full physical/history/ownership/Build replay and exact
recapture. Incomplete drafts, pending rounds and invalid inputs return `{}`.
The settled season's score proof is analyzed and its player progress is derived.
No save is written; the input checkpoint and original saves remain untouched.

The returned envelope has exactly:

- `version: 1`, `format: successor-career-evidence-v1`;
- `identity`: proposed `run_id`, decoded `seed`, exact `league_rules`, `tier`,
  League `pitch_catalog`, separate `module_signature`;
- `identity_digest`: JSON-normalized, sorted-key SHA-256 of that identity;
- `checkpoint_digest`: same digest of the complete canonical recapture of the validated checkpoint;
- detached complete `checkpoint`, compact score `proof`, and `player_progress`.

`restore(value: Variant) -> Dictionary` validates the envelope, recaptures from
its full checkpoint through the same replay gate, and requires exact equality.
It never accepts a compact proof, digest, or structurally valid progress record
as a substitute for replay.

The future owner journal must bind the identity to its own next contiguous run
ID and admitted seed/rules/tier, check the expected prior active run, and consume
`proof` and `player_progress` for synchronization. The identity digest is stable
across progress checkpoints for that run; the checkpoint digest changes with
progress. A caller-provided run ID or recomputed hash **does not prove ownership
or authorize a second run**. This module does not enforce an owner journal, award
receipts, permanent assets, unlocks, completion, abandonment or Dynasty access.
Those remain a subsequent explicitly admitted owner boundary, not implied by a
successful evidence capture.

## Retained semantics

- `player_progress` adapts the existing aggregate capture and ordered Build
  restore observer, replaying each Development event with its current Exotic
  prefix, checking prices/rewards/admission ordering and final ledger identity.
  It never extracts progression solely from the final development book.
- `player_legend` preserves prospective per-player roster/performance/fielding
  evidence and unknown historical provenance. It invents no historic numbers.
- `career_progress` uses a separate format/version and successor catalog. Exact
  four-player roster, strikeout/Exotic reconciliation and lesson provenance
  checks remain. Legacy aggregate validators are reused only after separately
  validating every successor lesson and projecting the historical lesson subset.
- Internal adapter `capture`/`valid` functions are derivation/shape checks only.
  Owner consumers must enter via `career_run_evidence.restore` (or capture on a
  complete checkpoint), never call those helpers as admission authority.
- No Career33 wrapping, historical save migration, inherited Exotic permission,
  owner/grant/unlock claims or unresolved Dynasty refill/pricing choices.

## Verification boundary

Native tests and evidence live in the repository's external test harness and
checkpoint report, not this manifest. A passing settled-round evidence test is
not proof of career completion, asset delivery, unlocks or Dynasty integration.
