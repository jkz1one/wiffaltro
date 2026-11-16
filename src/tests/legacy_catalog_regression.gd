extends Node
const INPUTS = preload("res://src/tests/legacy_decode_probe.gd").INPUTS
var checks: int = 0
var failures: Array[String] = []


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
	print("CATALOG_CHECK ", label, " ", ok)


func restore(data: Dictionary) -> SeasonBuild:
	var roster: Array[String] = []
	roster.assign(data.roster)
	var pool: Array[String] = []
	pool.assign(data.pool)
	var blocked: Array[String] = []
	blocked.assign(data.blocked)
	return SeasonBuild.from_data(data, int(data.seed), roster, pool, blocked)


func _ready() -> void:
	var old: Dictionary = SeasonAlleyGear.ITEMS.duplicate(true)
	old[SeasonAlleyGear.GAP]["name"] = "Gap Driver"
	check(
		(
			JSON.stringify(old).sha256_text()
			== "0662475719bcea2a198f2fb7a87c585440c84cb487eabc405a6fb77abdff7a7a"
		),
		"historical_name_hash"
	)
	check(
		(
			JSON.stringify(SeasonAlleyGear.ITEMS).sha256_text()
			== "3294846d71f111102f795fabdf71b234fc29d44fbb920fcea467782f1550fcaf"
		),
		"current_catalog_unchanged"
	)
	for version: int in [3, 5, 20, 39]:
		check(
			SeasonBuild._signature(version) == SeasonBuild._signature(version, null, true),
			"pre40_identity_unchanged:" + str(version)
		)
	for path: String in INPUTS:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)).build
		var result: SeasonBuild = restore(data)
		check(result != null, path + ":restore")
		if result != null:
			check(ClubCareer.same(data, result.to_data()), path + ":exact_roundtrip")
			check(ClubCareer.same(data, result._fork().to_data()), path + ":fork_exact_roundtrip")
		var damaged: Dictionary = data.duplicate(true)
		damaged.catalog = "x" + damaged.catalog.substr(1)
		check(restore(damaged) == null, path + ":catalog_tamper")
		damaged = data.duplicate(true)
		damaged.catalog = (
			damaged
			. catalog
			. replace(
				"0662475719bcea2a198f2fb7a87c585440c84cb487eabc405a6fb77abdff7a7a",
				"f662475719bcea2a198f2fb7a87c585440c84cb487eabc405a6fb77abdff7a7a"
			)
			. replace(
				"3294846d71f111102f795fabdf71b234fc29d44fbb920fcea467782f1550fcaf",
				"f294846d71f111102f795fabdf71b234fc29d44fbb920fcea467782f1550fcaf"
			)
		)
		check(restore(damaged) == null, path + ":alley_hash_tamper")
		damaged = data.duplicate(true)
		damaged.events.append({"op": "credit", "amount": 999999, "rev": data.events.size()})
		check(restore(damaged) == null, path + ":fabricated_credit_tamper")
		damaged = data.duplicate(true)
		damaged["legacy_gap_name"] = true
		check(restore(damaged) == null, path + ":persisted_flag_injection")
		damaged = data.duplicate(true)
		damaged.events[0].rev = 999
		check(restore(damaged) == null, path + ":event_revision_tamper")
	print("CATALOG_RESULTS ", JSON.stringify({"checks": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
