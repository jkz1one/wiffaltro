extends Node
var checks: int = 0
var failures: int = 0


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)


func _ready() -> void:
	for league: String in ["dugout", "equipment", "doubleheader"]:
		var season: SeasonState = SeasonState.create_closed_league(
			443, LeagueRules.capture(league), true
		)
		check(not SeasonInventoryRules.enable(season), "partial draft cannot migrate")
		for i in range(4):
			check(season.choose_player(season.offers()[0]), "draft")
		var legacy: Dictionary = SeasonSave.snapshot(season)
		check(SeasonSave._decode(legacy) != null, "old contract still loads")
		check(SeasonInventoryRules.enable(season), "atomic six-club admission")
		check(season.league_context_consistent(), "consistent capability")
		check(not SeasonInventoryRules.enable(season), "repeat migration rejects")
		var data: Dictionary = SeasonSave.snapshot(season)
		check(data.get("version") == 78, "explicit save78")
		var restored: SeasonState = SeasonSave._decode(
			JSON.parse_string(JSON.stringify(data, "", true, true))
		)
		check(restored != null, "cold capability restore")
		if restored != null:
			check(ClubCareer.same(SeasonSave.snapshot(restored), data), "cold exact")
		check(SeasonSave._decode(data.checkpoint) == null, "stripped outer capability rejects")
		var bad: Dictionary = data.duplicate(true)
		bad.inventory_rules.completed_rounds = 1
		check(SeasonSave._decode(bad) == null, "unsupported later migration rejects")
		season.inventory_rules = {}
		check(not season.league_context_consistent(), "stripped runtime header rejects")
		check(SeasonSave.snapshot(season).is_empty(), "stripped runtime cannot save")
		season.inventory_rules = SeasonInventoryRules.header()
		var first: Dictionary = season.opponents.clubs.values()[0]
		first.build._bank._state.erase("inventory_rules")
		check(not season.league_context_consistent(), "one AI marker stripped rejects")
	print("Inventory admission checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
