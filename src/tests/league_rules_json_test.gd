extends Node
## Exact composed profile JSON transport and malformed-version regression.

var checks: int = 0
var failures: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _ready() -> void:
	_json_profiles()
	print("League rules JSON checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _json_profiles() -> void:
	for league: String in LeagueRules.IDS:
		if league == "standard":
			continue
		for tier in range(1, 5):
			var rules: Dictionary = LeagueRules.capture_tier(league, tier,
				443 if league == "scramble" else null)
			var transported: Dictionary = JSON.parse_string(JSON.stringify(rules))
			check(transported.version is float and transported.tier is float,
				"fixture exercises real JSON numeric types")
			check(LeagueRules.normalized(transported) == rules,
				"composed profile survives real JSON transport: %s d%d" % [league, tier])
			check(LeagueRules.tiered(transported) and LeagueRules.season_matches(transported, 443),
				"transported profile retains tier and seed identity")
			for invalid: Variant in [true, false, -1, 0, 1, 2, 5, 3.5, 4.5, INF, NAN, null, "3"]:
				var bad: Dictionary = transported.duplicate(true)
				bad.version = invalid
				check(LeagueRules.normalized(bad).is_empty(), "invalid numeric version refuses")
			var foreign: Dictionary = transported.duplicate(true)
			foreign.version = 3.0 if league == "dynasty" else 4.0
			check(LeagueRules.normalized(foreign).is_empty(), "foreign League version refuses")
			var missing: Dictionary = transported.duplicate(true)
			missing.erase("version")
			check(LeagueRules.normalized(missing).is_empty(), "missing version refuses")
