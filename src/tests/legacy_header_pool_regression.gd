extends Node
## Synthetic empty-header compatibility, not income/progression or earned ownership evidence.

const INTRODUCED: Dictionary = {
	2: ["starter_grant", "starter_catalog"], 3: ["draft_catalog"], 4: ["property_catalog"],
	5: ["construction_catalog"], 6: ["seating_catalog", "seating_layout_catalog"],
	7: ["land_catalog"], 8: ["style_catalog", "appearance_catalog"],
	9: ["display_catalog", "display_layout_catalog"],
	10: ["ground_catalog", "ground_layout_catalog"],
	11: ["bleacher_catalog", "bleacher_layout_catalog"],
	12: ["target_catalog", "target_layout_catalog"],
	13: ["net_catalog", "net_layout_catalog"], 14: ["light_catalog", "light_layout_catalog"],
	15: ["infield_catalog", "infield_layout_catalog"],
	16: ["wall_catalog", "wall_layout_catalog"],
	17: ["surface_catalog", "surface_origin", "surface_layout_catalog"],
	18: ["wall_piece_catalog"], 19: ["advanced_layout_catalog"], 20: ["scoreboard_catalog"],
	21: ["scoreboard_layout_catalog"], 22: ["mounted_scoreboard_layout_catalog"],
	23: ["pool_catalog", "pool_layout_catalog"],
}
var _checks: int = 0
var _failures: int = 0

func _ready() -> void:
	var source: ClubAssetLedger = ClubAssetLedger.new(41, [220])
	var raw: Dictionary = source.to_data()
	for version in range(1, 24):
		var value: Dictionary = raw.duplicate(true)
		value.version = version
		var expected: Array = ["version", "seed", "catalog", "events"]
		for first: int in INTRODUCED:
			for key: String in INTRODUCED[first]:
				if first > version:
					value.erase(key)
				else:
					expected.append(key)
		_check(value.size() == expected.size() and value.has_all(expected),
			"explicit historical header shape " + str(version))
		var warm: ClubAssetLedger = ClubAssetLedger.from_data(value, 41, [220])
		var cold: ClubAssetLedger = ClubAssetLedger.from_data(
			JSON.parse_string(JSON.stringify(value, "", true, true)), 41, [220])
		_check(warm != null and cold != null and ClubCareer.same(warm.view(), source.view())
			and ClubCareer.same(cold.view(), source.view()),
			"warm/cold migration preserves wallet, stock and empty state " + str(version))
		for key: String in ["pool_catalog", "pool_layout_catalog"]:
			var bad: Dictionary = value.duplicate(true)
			if version < 23:
				bad[key] = raw[key]
			else:
				bad.erase(key)
			_check(ClubAssetLedger.from_data(bad, 41, [220]) == null,
				"pool declarations forbidden before23 and mandatory at23: " + str(version) + key)
	print("LEGACY_HEADER_POOL checks=", _checks, " failures=", _failures, " versions=23")
	get_tree().quit(0 if _failures == 0 else 1)

func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(label)
