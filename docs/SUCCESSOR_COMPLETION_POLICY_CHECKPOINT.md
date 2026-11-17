# Successor completion-policy foundations

This increment adds pure player-metric and receipt/title adapters. It does not
admit a terminal owner, finish a season, grant permanent currency, enable another
League, start a subsequent run, or establish Dynasty. Existing owner111, old
slots, original source and all earlier manifests remain unchanged.

`player_metrics.gd` strictly validates successor progress, then uses a private
historical-compatible projection to preserve every existing shared metric and
player-unlock threshold. Full successor lesson counts are retained. Unknown
progress remains unknown. The projection is never serialized or treated as a
legacy owner.

`completion_policy.gd` reuses the existing receipt calculation, ordered title
prefix rules, tier gates, first-title bonuses and all nine League unlock rules.
It rejects forged receipts, locked League starts, higher-tier self-unlocks,
misordered IDs, unfinished completion claims and Dynasty session rows. It returns
only a deep-copied structural proposal. A future owner adapter must first fully
replay all seasons and validate progression/assets/provenance before using it.
Structural score fixtures cannot authorize persistent rewards.

## Qualification

Run `tools/test_successor_signature.py --completion-fixture <isolated-owner111-save>`.
The fixture must be an actual previously played owned round. The runner restores
all hash-checked dependencies into an isolated project and leaves its source
fixture byte-identical.

The metrics test first replays the actual three-game owned checkpoint using the
unchanged strict codec, compares shared aggregates/unlock thresholds, checks
unknown progress, rejects inconsistent successor fields, and checks non-mutation.
The receipt/title test uses clearly labeled synthetic structural proofs, not
played wins, to cover the full unlock chain and original difficulty reward scales.

The first test attempt revealed missing explicit preload constants in the new
policy unit scene. It was stopped, corrected, and is not counted as passing.
Godot 4.6.3 final isolated run `dlq3cu79` passed both corrected suites.
The full successor-only lesson count branch was additionally exercised using an
explicitly synthetic structurally valid operand, not represented as a purchased
lesson. Inconsistent null aggregate stats were rejected without inventing data.

## Remaining integration

Successor-aware stadium progress, plaque/legend derivation and permanent-asset
adapters are still needed. Then a separately versioned terminal-capable owner must
be exercised through an actual full season, terminal save/retry, close/reopen and
next-run inheritance. No replacement cadence/count/fee is invented here.
