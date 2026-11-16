extends "res://src/tests/dynasty_league_home_live_owner_test.gd"
## Synthetic Base/D4, legacy/modern91 lifecycle. No physical games.
const Reuse = preload("res://src/tests/dynasty_league_qualified_reuse_controls.gd")
func _source() -> SeasonState:
	var source: SeasonState = super._source()
	if "--modern-origin" in OS.get_cmdline_user_args():
		var paid: ClubAssetLedger = ClubPlayers.assets(source.career)
		source.career._assets = ClubAssetLedger.new_club(paid._seed, paid._credits,
			paid._progress, paid._championships).to_data()
	return source
func _tier() -> int:
	return 4 if "--tier-four" in OS.get_cmdline_user_args() else 0
func _step(op: String, operands: Dictionary) -> Dictionary:
	if op == "checkpoint" or op == "close":
		var owner: Dictionary = Store.inspect(path).owner
		var snapshot: Dictionary = Store.read_snapshot(path, owner.other.reference)
		if op == "close": Reuse.run(owner, snapshot, check, "91-drafted")
		else: Reuse.positive(owner, snapshot, check, "91-fresh")
	return super._step(op, operands)
