extends Node
const Fixture = preload("res://src/tests/league_unlock_fixture.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _ready() -> void:
	for tier in range(1, 5):
		for value: Variant in [tier, float(tier)]:
			var club: ClubCareer = ClubCareer.new()
			club.runs.append({"league": "standard", "tier": value})
			check(club.standard_version() == 22 + tier, "integral tier version")
	for value: Variant in [null, true, "1", 0, -1, 1.5, 5, INF, NAN]:
		var club: ClubCareer = ClubCareer.new()
		club.runs.append({"league": "standard", "tier": value})
		check(club.standard_version() == 22, "malformed tier cannot select format")
	var source: ClubCareer = Fixture.prefix([
		{"league": "standard", "tier": 0}, {"league": "standard", "tier": 1},
		{"league": "standard", "tier": 2}, {"league": "standard", "tier": 3}])
	var cold: ClubCareer = ClubCareer.from_data(JSON.parse_string(JSON.stringify(source.to_data(), "", true, true)))
	check(cold != null and cold.standard_version() == source.standard_version(), "cold valid history retains native version")
	print("STANDARD_TIER_VERSION_JSON: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
