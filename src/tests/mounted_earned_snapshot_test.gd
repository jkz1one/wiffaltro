extends Node
## Historical synthetic pennants; only representation changes, never earned authority.
var _checks: int = 0
var _failures: int = 0

func _ready() -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		OS.get_environment("MOUNTED_SAVE_FIXTURE")))
	var cold: Dictionary = raw.home_property
	var expected: String = "9f9027d1f75b9e813dbf734a9efd9c6d97a9a10425206444e15648efb9a0e6c9"
	_check(StadiumLayoutSnapshot.key(cold) == expected, "existing cold property hash is unchanged")
	var warm: Dictionary = cold.duplicate(true)
	for copy: Dictionary in warm.inventory.copies.values():
		if copy.has("earned"):
			for field: String in ["version", "season_id", "season_number"]:
				copy.earned[field] = int(copy.earned[field])
			copy.earned.era.version = int(copy.earned.era.version)
	var before: String = JSON.stringify(warm, "", true, true)
	_check(StadiumLayoutSnapshot.key(warm) == expected,
		"warm pennant counters use retained cold identity")
	_check(JSON.stringify(warm, "", true, true) == before,
		"snapshot canonicalization does not mutate input")
	_check(ClubCareer.same(StadiumLayoutSnapshot.normalized(warm), cold),
		"numeric canonicalization preserves full ownership and geometry")
	var season: SeasonState = SeasonSave._decode(raw)
	_check(season != null, "historical cold save remains valid")
	for fixture: Dictionary in season.schedule:
		if fixture.home != 0:
			continue
		var old_request: String = SeasonPhysicalFixtures.request_key(season, fixture)
		season.home_property = warm
		_check(SeasonPhysicalFixtures.request_key(season, fixture) == old_request,
			"warm/cold complete fixture request remains identical")
		season.home_property = cold
		break
	var cold3: Dictionary = cold.duplicate(true)
	cold3.inventory.version = 3
	cold3.inventory.copies[StadiumStock.SALVAGE_COPY] = {
		"item": "ST-005", "paid": 0, "source": StadiumStock.SALVAGE_SOURCE}
	var warm3: Dictionary = warm.duplicate(true)
	warm3.inventory.version = 3
	warm3.inventory.copies[StadiumStock.SALVAGE_COPY] = {
		"item": "ST-005", "paid": 0, "source": StadiumStock.SALVAGE_SOURCE}
	_check(StadiumMountedScoreboardSnapshot.valid(cold3)
		and StadiumMountedScoreboardSnapshot.valid(warm3), "stock3 mixed pennant/salvage shape validates")
	_check(StadiumLayoutSnapshot.key(cold3) == StadiumLayoutSnapshot.key(warm3),
		"stock3 uses the same retained cold counter representation")
	print("MOUNTED_COLD_KEYS ", JSON.stringify({"stock2": StadiumLayoutSnapshot.key(cold),
		"stock3": StadiumLayoutSnapshot.key(cold3)}))
	var earned_key: String = "championship-v1:1"
	for field: String in ["version", "season_id", "season_number"]:
		for invalid: Variant in [true, "1", -1, 1.5, null]:
			var bad: Dictionary = warm.duplicate(true)
			bad.inventory.copies[earned_key].earned[field] = invalid
			_check(not StadiumMountedScoreboardSnapshot.valid(bad)
				and StadiumMountedScoreboardSnapshot.normalized(bad).is_empty(),
				"malformed earned counter rejects before casting")
	var bad: Dictionary = warm.duplicate(true)
	bad.inventory.copies[earned_key].earned.era.version = true
	_check(not StadiumMountedScoreboardSnapshot.valid(bad), "malformed era version rejects")
	print("MOUNTED_EARNED_RESULT ", JSON.stringify({"checks": _checks, "failures": _failures}))
	get_tree().quit(0 if _failures == 0 else 1)

func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(message)
