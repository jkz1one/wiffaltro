extends Node
const Fixture = preload("res://src/tests/league_flat_home_fixture.gd")
const Normal = preload("res://src/gameplay/season/normal_league_home.gd")
const Carried = preload("res://src/gameplay/season/dynasty_carried_home_live.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _ready() -> void:
	check(Normal.FLAT_LAYOUTS == Fixture.ADAPTERS.keys() and Carried.FLAT_LAYOUTS == Fixture.ADAPTERS.keys(), "both routes explicitly pin exactly29 qualified adapters")
	for version: int in Fixture.ADAPTERS:
		var paid: ClubAssetLedger = Fixture.ledger(version)
		var home: Dictionary = StadiumLayoutSnapshot.capture(paid, true)
		for tier: int in [0, 4]:
			check(Normal._supported(home, LeagueRules.capture_tier("dugout", tier)), "ordinary named flat scope " + str(version) + "/" + str(tier))
			check(Carried.supported_home(home, {"league": "dynasty", "tier": tier}), "carried named flat scope " + str(version) + "/" + str(tier))
		var json: Dictionary = JSON.parse_string(JSON.stringify(home, "", true, true))
		check(Normal._supported(json, LeagueRules.capture("dugout")) and Carried.supported_home(json, {"league": "dynasty", "tier": 0}), "transported complete named contract " + str(version))
		check(not Normal._supported(home, LeagueRules.capture("dynasty")) and not Carried.supported_home(home, {"league": "dugout", "tier": 0}), "independent league route pins " + str(version))
		var bad: Dictionary = home.duplicate(true)
		bad.layout.family += "-unknown"
		check(not Normal._supported(bad, LeagueRules.capture("dugout")) and not Carried.supported_home(bad, {"league": "dynasty", "tier": 0}), "numeric version alone cannot admit either route")
		bad = home.duplicate(true)
		bad.erase("inventory")
		check(not Normal._supported(bad, LeagueRules.capture("dugout")) and not Carried.supported_home(bad, {"league": "dynasty", "tier": 0}), "complete stock required in each route")
	for version: int in [13, 14, 15, 16, 17, 46, 47]:
		check(version not in Normal.FLAT_LAYOUTS and version not in Carried.FLAT_LAYOUTS, "separate contract stays unapproved " + str(version))
	print("FLAT_ROUTE_SCOPE checks=", checks, " failures=", failures, " physical_games=0")
	get_tree().quit(0 if failures == 0 else 1)
