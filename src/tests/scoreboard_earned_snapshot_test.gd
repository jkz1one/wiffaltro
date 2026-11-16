extends Node
## Historical synthetic pennants; only representation changes, never earned authority.
var _checks: int = 0
var _failures: int = 0

func _ready() -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		OS.get_environment("SCOREBOARD_SAVE_FIXTURE")))
	var cold: Dictionary = raw.home_property
	var expected: String = "c9240dbfe05d9026cc1f3c74387ea2a713024946fa14e43d8b1f1d9aac5b29d3"
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
	var stock_before: String = JSON.stringify(
		StadiumStock.from_data(warm.inventory).to_data(), "", true, true)
	StadiumLayoutSnapshot.normalized(warm)
	_check(JSON.stringify(StadiumStock.from_data(warm.inventory).to_data(), "", true, true)
		== stock_before, "raw legacy stock serialization remains untouched")
	var season: SeasonState = SeasonSave._decode(raw)
	_check(season != null, "historical cold save remains valid")
	var lossy: SeasonState = SeasonSave._decode(JSON.parse_string(JSON.stringify(raw)))
	var precise: SeasonState = SeasonSave._decode(
		JSON.parse_string(JSON.stringify(raw, "", true, true)))
	print("SCOREBOARD_PRECISION ", JSON.stringify({"lossy_restores": lossy != null,
		"precise_restores": precise != null}))
	_check(lossy == null, "truncated current venue authority fails closed")
	_check(precise != null, "production full-precision encoding retains current venue authority")
	_check(StadiumLayoutSnapshot.key(StadiumScoreboardSnapshot.fixture(warm, 96, 0))
		== StadiumLayoutSnapshot.key(StadiumScoreboardSnapshot.fixture(cold, 96, 0)),
		"warm/cold complete playable fixture identity remains identical")
	var cold3: Dictionary = cold.duplicate(true)
	cold3.inventory.version = 3
	cold3.inventory.copies[StadiumStock.SALVAGE_COPY] = {
		"item": "ST-005", "paid": 0, "source": StadiumStock.SALVAGE_SOURCE}
	var warm3: Dictionary = warm.duplicate(true)
	warm3.inventory.version = 3
	warm3.inventory.copies[StadiumStock.SALVAGE_COPY] = {
		"item": "ST-005", "paid": 0, "source": StadiumStock.SALVAGE_SOURCE}
	_check(StadiumLayoutSnapshot.valid(cold3)
		and StadiumLayoutSnapshot.valid(warm3), "stock3 mixed pennant/salvage shape validates")
	_check(StadiumLayoutSnapshot.key(cold3) == StadiumLayoutSnapshot.key(warm3)
		and StadiumLayoutSnapshot.key(cold3)
		== "5bc3daf1817bbee5b6696231a97faacc0cd3fdc47b57bd21eb72c4a3fc5c1d2b",
		"stock3 uses the same retained cold counter representation")
	print("SCOREBOARD_COLD_KEYS ", JSON.stringify({"stock2": StadiumLayoutSnapshot.key(cold),
		"stock3": StadiumLayoutSnapshot.key(cold3)}))
	var earned_key: String = "championship-v1:1"
	for field: String in ["version", "season_id", "season_number"]:
		for invalid: Variant in [true, false, "1", -1, 1.5, null, 999999999]:
			var bad: Dictionary = warm.duplicate(true)
			bad.inventory.copies[earned_key].earned[field] = invalid
			_check(not StadiumLayoutSnapshot.valid(bad)
				and StadiumLayoutSnapshot.normalized(bad).is_empty(),
				"malformed earned counter rejects before casting")
	var bad: Dictionary = warm.duplicate(true)
	bad.inventory.copies[earned_key].earned.era.version = true
	_check(not StadiumLayoutSnapshot.valid(bad), "malformed era version rejects")
	print("SCOREBOARD_EARNED_RESULT ", JSON.stringify({"checks": _checks, "failures": _failures}))
	get_tree().quit(0 if _failures == 0 else 1)

func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(message)
