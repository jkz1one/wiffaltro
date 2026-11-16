extends Node
## Data-only synthetic combinations; never a paid journal or an installed field.
const COLD_KEYS: Dictionary = {
	"advanced": {
		"stock2": "deea2648551566baaa7919e94f987054a25130f034c0760e2eab4b972caceb37",
		"stock3": "c469274a2436710e00ee21b8c7852535dc2c54218d1466f8437ea608c257aa65"
	},
	"pool": {
		"stock2": "d34192b22d9813aa9f1ad05bce4e3307a35c480859075408083d5de74f0bde73",
		"stock3": "249d37b883235781c32a0f33dc1954de75025e781cff7171499cd6a07c9d92e0"
	}
}
var _checks: int = 0
var _failures: int = 0

func _ready() -> void:
	var root: String = OS.get_environment("SNAPSHOT_IDENTITY_FIXTURES")
	var pool: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		root.path_join("historical-pool-entry.json")))
	_check(StadiumPoolOwnedSnapshot.valid(pool), "retained historical pool entry is valid")
	var retained: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		root.path_join("terrain-rough-save.json")))
	# Deliberately combine unused valid earned records with a retained valid declaration.
	# This tests numeric representation, not authority to acquire or install either field.
	for key: String in retained.home_property.inventory.copies:
		var copy: Dictionary = retained.home_property.inventory.copies[key]
		if copy.has("earned"):
			pool.inventory.copies[key] = copy.duplicate(true)
	pool.inventory.version = 2
	var layout: Dictionary = StadiumAdvancedWallLayout.upgrade(
		StadiumSurfaceLayout.upgrade(StadiumStarterLayout.empty(), ["grass", "ground_prep"], true))
	var advanced: Dictionary = {
		"version": 10, "tier": "backyard", "revision": pool.revision,
		"geometry": StadiumOwnedLayout.geometry("backyard", layout), "layout": layout,
		"inventory": pool.inventory.duplicate(true),
		"wall_piece_inventory": StadiumWallPieceOwnership.new().to_data(),
		"surface_access": ["grass", "ground_prep"],
		"boundary": StadiumOwnedLayout.boundary_signature(layout)}
	_exercise("advanced", StadiumAdvancedSnapshot, advanced)
	_exercise("pool", StadiumPoolOwnedSnapshot, pool)
	_check(not StadiumLayoutSnapshot.valid(advanced),
		"data repair cannot open advanced production admission")
	print("REMAINING_SNAPSHOT_RESULT checks=", _checks, " failures=", _failures)
	get_tree().quit(0 if _failures == 0 else 1)

func _exercise(label: String, family: Variant, original: Dictionary) -> void:
	var cold: Dictionary = JSON.parse_string(JSON.stringify(original, "", true, true))
	_check(family.valid(cold), label + " data-only declaration validates")
	if not family.valid(cold):
		return
	var warm: Dictionary = cold.duplicate(true)
	for copy: Dictionary in warm.inventory.copies.values():
		if copy.has("earned"):
			for field: String in ["version", "season_id", "season_number"]:
				copy.earned[field] = int(copy.earned[field])
			copy.earned.era.version = int(copy.earned.era.version)
	var raw_before: String = JSON.stringify(warm, "", true, true)
	var cold_key: String = family.key(cold)
	_check(cold_key == COLD_KEYS[label].stock2, label + " retained cold stock2 hash unchanged")
	_check(family.valid(warm), label + " warm declaration validates")
	_check(family.key(warm) == cold_key, label + " warm/cold entry key is stable")
	var cold_fixture: Dictionary = family.fixture(cold, 96, 0)
	var warm_fixture: Dictionary = family.fixture(warm, 96, 0)
	_check(not cold_fixture.is_empty() and not warm_fixture.is_empty(),
		label + " explicit data fixtures are nonempty")
	_check(family.key(cold_fixture) == family.key(warm_fixture),
		label + " complete fixture identity is stable")
	_check(JSON.stringify(warm, "", true, true) == raw_before,
		label + " normalization never mutates raw input")
	_check(ClubCareer.same(family.normalized(warm), cold),
		label + " full semantic declaration remains exact")
	var normalized: Dictionary = family.normalized(warm)
	_check(JSON.stringify(normalized, "", true, true)
		== JSON.stringify(family.normalized(normalized), "", true, true),
		label + " normalization is byte-idempotent")
	normalized.inventory.copies["championship-v1:1"].earned.era.version = 99
	_check(JSON.stringify(warm, "", true, true) == raw_before,
		label + " returned nested earned data is detached")
	_check(not family.matches(warm, ClubAssetLedger.new()),
		label + " synthetic declaration is not a paid active journal")
	var cold3: Dictionary = cold.duplicate(true)
	cold3.inventory.version = 3
	cold3.inventory.copies[StadiumStock.SALVAGE_COPY] = {
		"item": "ST-005", "paid": 0, "source": StadiumStock.SALVAGE_SOURCE}
	var warm3: Dictionary = warm.duplicate(true)
	warm3.inventory.version = 3
	warm3.inventory.copies[StadiumStock.SALVAGE_COPY] = {
		"item": "ST-005", "paid": 0, "source": StadiumStock.SALVAGE_SOURCE}
	_check(family.valid(cold3) and family.valid(warm3), label + " stock3 is valid")
	_check(family.key(cold3) == family.key(warm3), label + " stock3 identity is stable")
	_check(family.key(cold3) == COLD_KEYS[label].stock3,
		label + " retained cold stock3 hash unchanged")
	print("REMAINING_COLD_KEYS ", label, " ", JSON.stringify(
		{"stock2": cold_key, "stock3": family.key(cold3)}))
	for field: String in ["version", "season_id", "season_number"]:
		for invalid: Variant in [true, false, "1", null, -1, 1.5, 999999999]:
			var bad: Dictionary = warm.duplicate(true)
			bad.inventory.copies["championship-v1:1"].earned[field] = invalid
			_check(not family.valid(bad) and family.normalized(bad).is_empty(),
				label + " malformed earned counter fails before normalization")
	var bad: Dictionary = warm.duplicate(true)
	bad.inventory.copies["championship-v1:1"].earned.era.version = true
	_check(not family.valid(bad), label + " malformed era version rejects")

func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(message)
