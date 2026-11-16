extends Node
const INPUTS = preload("res://src/tests/legacy_decode_probe.gd").INPUTS
var checks: int = 0
var failures: Array[String] = []


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
	print("FULL_CHECK ", label, " ", ok)


func _ready() -> void:
	# The integrated source now has a reviewed qualification profile. Frozen
	# original pins must still reject it; the reviewed alternative must accept it.
	check(
		not StadiumNpcSourceQualification.matches_original(StadiumNpcPublicRuntime.SOURCE_PINS),
		"changed_source_rejects_original_pins"
	)
	check(StadiumNpcPublicRuntime.source_qualified(), "reviewed_source_qualified")
	var bad_pins: Dictionary = StadiumNpcPublicRuntime.SOURCE_PINS.duplicate()
	bad_pins[bad_pins.keys()[0]] = "0".repeat(64)
	check(
		not StadiumNpcSourceQualification.matches_current(bad_pins),
		"reviewed_source_rejects_changed_baseline"
	)
	for path: String in INPUTS.slice(0, 2):
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var restored: SeasonState = SeasonSave._decode(data)
		check(restored != null, path + ":full_decode")
		if restored != null:
			check(
				ClubCareer.same(data, SeasonSave.snapshot(restored)), path + ":full_exact_roundtrip"
			)
		for kind: String in ["catalog", "event", "cursor", "role", "extra"]:
			var bad: Dictionary = data.duplicate(true)
			var club: Dictionary = bad.opponents.clubs["1"]
			if kind == "catalog":
				club.build.catalog = "x" + club.build.catalog.substr(1)
			if kind == "event":
				club.build.events[0].rev = 999
			if kind == "cursor":
				club.cursor += 1
			if kind == "role":
				club.roles["unknown"] = "fabricated"
			if kind == "extra":
				club["extra"] = true
			check(SeasonSave._decode(bad) == null, path + ":opponent_" + kind + "_tamper")
	print("FULL_RESULTS ", JSON.stringify({"checks": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
