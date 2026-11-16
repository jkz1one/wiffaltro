extends "res://src/tests/league_legacy_home_contracts_test.gd"
## Reuse an exact retained ordinary prerequisite history, then real paid commands.
## Does not replay funding loops, manufacture wins, or strip owner history metadata.
var retained: String = ""
var requested_layout: int = 1
var requested_land: String = "backyard"
var requested_lights: int = 1
var requested_league: String = "dugout"
var requested_tier: int = 0

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--home-operand-input="): retained = arg.trim_prefix("--home-operand-input=")
		if arg.begins_with("--home-operand-output="): output = arg.trim_prefix("--home-operand-output=")
		if arg.begins_with("--home-operand-layout="): requested_layout = int(arg.trim_prefix("--home-operand-layout="))
		if arg.begins_with("--home-operand-land="): requested_land = arg.trim_prefix("--home-operand-land=")
		if arg.begins_with("--home-operand-lights="): requested_lights = int(arg.trim_prefix("--home-operand-lights="))
		if arg.begins_with("--home-operand-league="): requested_league = arg.trim_prefix("--home-operand-league=")
		if arg.begins_with("--home-operand-tier="): requested_tier = int(arg.trim_prefix("--home-operand-tier="))
	if not retained.is_absolute_path() or not FileAccess.file_exists(retained) \
		or not output.is_absolute_path() or DirAccess.dir_exists_absolute(output) \
		or requested_layout not in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 16] \
		or requested_land not in ["backyard", "expanded"] or requested_lights not in [1, 4] \
		or requested_league not in ["dugout", "doubleheader", "scramble"] or requested_tier not in [0, 4] \
		or (requested_layout == 16 and requested_land != "backyard"):
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var original_bytes: String = FileAccess.get_file_as_string(retained)
	var authority: Dictionary = _retained_source(original_bytes)
	if not authority.is_empty():
		if requested_layout == 16:
			authority = _pool_operand(authority)
		else:
			for item: String in ["ST-001", "ST-026", "ST-025", "ST-037"]:
				authority = _command(authority, {"op": "stadium_buy", "item": item,
					"quantity": 4 if item == "ST-037" else 1,
					"price_version": ClubConstruction.copy_catalog(item).price_version})
				if authority.is_empty(): break
			if not authority.is_empty() and requested_land == "expanded":
				authority = _command(authority, {"op": "stadium_land", "tier": "expanded", "price_version": StadiumLand.VERSION})
			if not authority.is_empty(): authority = _apply_legacy(authority, requested_layout, requested_lights)
	if not authority.is_empty():
		var snapshot: Dictionary = Live.prepare(authority, _session(authority, requested_league, requested_tier))
		if check(not snapshot.is_empty() and not Live.qualify(snapshot, authority).is_empty(), "fresh exact complete91 operand replays"):
			_write("operand.json", {"authority": authority, "snapshot": snapshot})
	check(FileAccess.file_exists(output.path_join("operand.json")), "complete paid operand was written")
	check(FileAccess.get_file_as_string(retained) == original_bytes, "retained source untouched")
	_write("summary.json", {"checks": checks, "failures": failures, "physical_games": 0,
		"authored_prerequisites": true, "retained_input": retained, "input_sha256": original_bytes.sha256_text(),
		"layout": requested_layout, "land": requested_land, "lights": requested_lights,
		"league": requested_league, "tier": requested_tier, "paid_commands": commands})
	print("REMAINING_HOME_OPERAND checks=", checks, " failures=", failures, " physical_games=0 authored_prerequisites=true")
	get_tree().quit(0 if failures == 0 else 1)

func _retained_source(bytes: String) -> Dictionary:
	return _retained_ordinary_authority(bytes, "remaining-home-operand")

func _pool_operand(authority: Dictionary) -> Dictionary:
	for item: String in ["ST-079", "ST-006"]:
		authority = _command(authority, {"op": "stadium_buy", "item": item, "quantity": 1,
			"price_version": ClubConstruction.copy_catalog(item).price_version})
		if authority.is_empty(): return {}
	var paid: ClubAssetLedger = _paid(authority)
	var base: Dictionary = StadiumSurfaceLayout.upgrade(paid.view().stadium_active, paid.surface_owned())
	base.receiver = _copy(paid, "ST-079")
	var layout: Dictionary = StadiumPoolOwnedLayout.upgrade(base, paid.construction(), paid.surface_owned(),
		"backyard", _copy(paid, "ST-006"))
	if not check(not layout.is_empty(), "exact paid owned Pool grammar"): return {}
	authority = _command(authority, {"op": "stadium_draft", "layout": layout})
	return {} if authority.is_empty() else _command(authority, {"op": "stadium_apply", "layout": layout,
		"geometry": StadiumOwnedLayout.geometry("backyard", layout)})
