extends "res://src/tests/season_same_save_night_test.gd"
## Synthetic funding only. No native gameplay evidence or activation claim.
const Live = preload("res://src/gameplay/season/dynasty_standard_live.gd")
const Bound = preload("res://src/gameplay/season/dynasty_standard_save.gd")
const Grant = preload("res://src/gameplay/season/dynasty_standard_grant.gd")
const Authority = preload("res://src/gameplay/season/dynasty_career_authority.gd")
const Save = preload("res://src/gameplay/season/dynasty_career_save.gd")
func _ready() -> void:
	SeasonSave.path = "user://isolated-night-funding.json"
	_unlit_controls()
	var source: SeasonState = _retained_funding()
	_check(source != null, "synthetic original funding")
	if source != null:
		var ledger: ClubAssetLedger = ClubPlayers.assets(source.career) if OS.get_cmdline_user_args().has("--prepared-fixture") else _public_purchases(source)
		_check(ledger != null, "public paid layout fixture")
		if ledger != null:
			var authority: Dictionary = Authority.create(SeasonSave.snapshot(source), "night-owner")
			_check(not authority.is_empty(), "source-qualified paid authority")
			if not authority.is_empty():
				_run_profiles(authority)
	print("SHARED_NIGHT checks=%d failures=%d physical_games=0 synthetic_funding=true" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)
func _run_profiles(authority: Dictionary) -> void:
	var grant: Dictionary = Grant.capture(authority)
	var legacy: Dictionary = Bound.binding({"owner_id": "night-owner", "lineage_id": "night-lineage",
		"generation": 0, "ordinal": 1, "session_id": "night-session", "seed": 301,
		"tier": 0, "league": "standard", "format": 89, "grant_sha256": Save.snapshot_reference(grant).sha256})
	_check(not legacy.is_empty() and not legacy.has("starting_profile"), "omitted profile remains omitted")
	var old: SeasonState = Live.create(grant, legacy)
	_check(old != null and old.owned_surface_night.is_empty(), "old89 remains ordinary unchanged")
	for mode: String in ["day", "sunset", "night"]:
		var binding: Dictionary = legacy.duplicate(true)
		binding.starting_profile = mode
		binding = Bound.binding(binding)
		var season: SeasonState = Live.create(grant, binding)
		_check(season != null and not season.owned_surface_night.is_empty(), "paid profile " + mode)
		if season == null:
			continue
		_check(season.owned_surface_night.mode == mode and season.career == null, "immutable mode and no second wallet " + mode)
		var raw: Dictionary = Live.capture_raw(season)
		_check(not raw.is_empty(), "raw captures " + mode)
		var cold: SeasonState = Live.decode(JSON.parse_string(JSON.stringify(raw, "", true, true)), grant, binding)
		_check(cold != null, "cold profile " + mode)
		for i in range(4):
			_check(season.choose_player(season.offers()[0]), "draft " + mode)
		var envelope: Dictionary = Bound.capture(season, binding, grant, authority)
		_check(not envelope.is_empty(), "bound capture " + mode)
		_check(not Bound.qualify(JSON.parse_string(JSON.stringify(envelope, "", true, true)), authority).is_empty(), "bound cold qualification " + mode)
		var admitted: Dictionary = Authority.open_session(authority, envelope)
		_check(not admitted.is_empty() and admitted.sessions[binding.session_id].session.starting_profile == mode, "authority retains profile " + mode)
		_check(not Authority.normalize(JSON.parse_string(JSON.stringify(admitted, "", true, true))).is_empty(), "authority cold profile " + mode)
		var fork: SeasonState = SeasonRoundSettlement._fork_replayed_standard(season)
		_check(fork != null and ClubCareer.same(fork.owned_surface_night, season.owned_surface_night), "validated fork policy " + mode)
		var bad: Dictionary = raw.duplicate(true)
		bad.owned_surface_night.mode = "night" if mode != "night" else "day"
		_check(Live.decode(bad, grant, binding) == null, "changed policy refused " + mode)
		_check(Live.decode(raw, grant, legacy) == null, "policy cannot use old binding " + mode)
		season.owned_surface_night = {}
		_check(not Live.matches(season), "live policy removal refused " + mode)
	_night_identity_unit()
	for invalid: Variant in ["", "dusk", 0, null]:
		var bad: Dictionary = legacy.duplicate(true)
		bad.starting_profile = invalid
		_check(Bound.binding(bad).is_empty(), "invalid profile rejected " + str(invalid))
	var old_format: Dictionary = legacy.duplicate(true)
	old_format.erase("format")
	old_format.starting_profile = "night"
	_check(Bound.binding(old_format).is_empty(), "legacy88 cannot opt into profile")

func _night_identity_unit() -> void:
	# Comparison-only fixture, never admitted as actual physical evidence.
	var replay: GDScript = load("res://src/gameplay/season/dynasty_standard_replay.gd")
	var path: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--transition-operands="):
			path = argument.trim_prefix("--transition-operands=")
	if not path.is_absolute_path() or not FileAccess.file_exists(path):
		_check(false, "retained comparison operands required")
		return
	var input: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var human: Array = input.human.slice(0, 15)
	human.append(null)
	human.append(null)
	human.append({"comparison_only": true})
	var result: Dictionary = input.result.duplicate(true)
	result.erase("yard_evidence")
	result.night_evidence = human[17].duplicate(true)
	_check(replay._human_matches(human, result), "night18 identity comparison only")
	for field: String in ["pool_evidence", "yard_evidence", "doubleheader_evidence", "inventory_final"]:
		var bad: Dictionary = result.duplicate(true)
		bad[field] = {}
		_check(not replay._human_matches(human, bad), "night rejects mixed " + field)
	for index in [13, 14, 15, 16, 17]:
		var bad: Array = human.duplicate(true)
		if index == 13:
			bad[index].append("changed")
		elif index == 14:
			bad[index] += "changed"
		elif index == 17:
			bad[index].comparison_only = false
		else:
			bad[index] = {}
		_check(not replay._human_matches(bad, result), "night changed tail refused " + str(index))

func _unlit_controls() -> void:
	var source: SeasonState = SeasonState.create(41, false, true, true)
	source.career = ClubCareer.new()
	_check(source.career.start(source), "unlit ordinary source")
	for i in range(4):
		source.choose_player(source.offers()[0])
	var authority: Dictionary = Authority.create(SeasonSave.snapshot(source), "unlit-owner")
	var grant: Dictionary = Grant.capture(authority)
	var binding: Dictionary = Bound.binding({"owner_id": "unlit-owner", "lineage_id": "unlit-lineage",
		"generation": 0, "ordinal": 1, "session_id": "unlit-session", "seed": 301,
		"tier": 0, "league": "standard", "format": 89, "grant_sha256": Save.snapshot_reference(grant).sha256})
	var old: SeasonState = Live.create(grant, binding)
	var old_raw: Dictionary = Live.capture_raw(old)
	_check(Live.decode(JSON.parse_string(JSON.stringify(old_raw, "", true, true)), grant, binding) != null,
		"existing omitted89 cold remains valid")
	for mode: String in ["day", "sunset", "night"]:
		var context: Dictionary = binding.duplicate(true)
		context.starting_profile = mode
		var season: SeasonState = Live.create(grant, context)
		if mode == "day":
			_check(season != null and season.owned_surface_night.is_empty(), "unlit Day ordinary fallback")
			_check(ClubCareer.same(Live.capture_raw(season), old_raw), "unlit Day preserves ordinary checkpoint bytes")
		else:
			_check(season == null, "unlit " + mode + " refuses, never daylight fallback")
