extends "res://src/tests/league_home_modern_tiers_test.gd"
## Every League/tier has a genuine journal clearance, with synthetic earned income.
const Assets = preload("res://src/gameplay/season/dynasty_stadium_assets.gd")

func _authority(wins: Array) -> Dictionary:
	var funded: Array = wins.duplicate(true)
	if funded.is_empty():
		# Standard income funds clearance without granting any higher Dugout tier.
		funded.append({"league": "standard", "tier": 0})
	var authority: Dictionary = super._authority(funded)
	if authority.is_empty():
		return {}
	var club: ClubCareer = Authority._history(authority)
	var ledger: ClubAssetLedger = ClubPlayers.assets(club)
	var before: int = ledger.balance()
	var command: Dictionary = {"id": "tier-paid-clear", "rev": ledger.revision(),
		"op": "stadium_salvage_clear", "copy": StadiumStock.SALVAGE_COPY,
		"price_version": 1, "through": ClubPlayers.income_through(club)}
	var result: Dictionary = Assets.command(authority, command)
	if not check(not result.authority.is_empty() and result.applied.ok, "real clearance journal before tier admission"):
		return {}
	var paid: ClubAssetLedger = ClubPlayers.assets(Authority._history(result.authority))
	check(paid.balance() == before - 190 and Live.paid_modern_clearance(paid),
		"exact paid190 and unchanged starter copy before tier admission")
	return result.authority

func _expected_home(home: Dictionary) -> bool:
	return Live.modern_cleared(home) and not Live.modern_origin(home)
