extends "res://src/tests/stadium_surface_night_gameplay_a_test.gd"


## Save-only extraction of original _checkpoint_controls assertions. No timing,
## callback, installed-scene, optical or actual-game qualification is claimed.
func _ready() -> void:
	SeasonSave.path = "user://same-save-night-funding.json"
	var completed: SeasonState = _retained_funding()
	_check(completed != null, "existing synthetic20 funding fixture")
	if completed != null:
		var paid: ClubAssetLedger = (
			ClubPlayers.assets(completed.career)
			if OS.get_cmdline_user_args().has("--prepared-fixture")
			else (
				_public_purchases(completed)
				if OS.get_cmdline_user_args().has("--public-purchases")
				else _purchases(completed)
			)
		)
		_check(paid != null, "existing original Night paid fixture")
		if paid != null:
			for version in [72, 73]:
				await _persistence(completed, version)
	print(
		(
			"SAME_SAVE_NIGHT_RESULT "
			+ JSON.stringify(
				{
					"checks": _checks,
					"failures": _failures,
					"save_only": true,
					"synthetic_funding": true
				}
			)
		)
	)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)


func _persistence(completed: SeasonState, version: int) -> void:
	SeasonSave.path = "user://same-save-night-%d.json" % version
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	app.set_process(false)
	app.season = completed
	var closed: ClubCareer = completed.career.fork()
	var close_ok: bool = closed.close(completed)
	var checked: ClubCareer = ClubCareer.from_data(closed.to_data()) if close_ok else null
	var paid: ClubAssetLedger = ClubPlayers.assets(closed)
	print(
		(
			"NIGHT_SETUP_DIAGNOSTIC "
			+ JSON.stringify(
				{
					"version": version,
					"close_ok": close_ok,
					"cold_career_ok": checked != null,
					"current": closed.current,
					"runs": closed.runs.size(),
					"paid_ok": paid != null,
					"balance": paid.balance() if paid != null else -1,
					"pennants_delivered": StadiumPennantRewards.delivered(closed, paid),
					"plaques_delivered": StadiumPlaqueRewards.delivered(closed, paid)
				}
			)
		)
	)
	if version == 72:
		app.begin_surface_night_season(101, 0)
	else:
		app.begin_surface_time_season("night", 101, 0)
	var valid: SeasonState = app.season
	if valid == completed or valid == null or valid.owned_surface_night.is_empty():
		_check(false, "real named Night start%d: %s" % [version, app.notice])
		app.free()
		return
	var pre_draft: ClubCareer = valid.career
	var draft_values: String = _career_values(pre_draft)
	for pick in range(4):
		if valid.offers().is_empty() or not valid.choose_player(valid.offers()[0]):
			_check(false, "ordinary Night draft%d" % version)
			app.free()
			return
	_check(SeasonSave.save(valid), "real round0 Night checkpoint%d" % version)
	var expected: Dictionary = SeasonSave.snapshot(valid)
	_check(expected.get("version") == version, "exact Night envelope%d" % version)
	var original: ClubCareer = valid.career
	var values: String = _career_values(original)
	var equal_saved: bool = app._checkpoint()
	var cold: SeasonState = SeasonSave.restore() if equal_saved else null
	_check(
		(
			equal_saved
			and valid.career == original
			and _career_values(original) == values
			and cold != null
			and ClubCareer.same(SeasonSave.snapshot(cold), expected)
		),
		"equal Night%d save retains owner and exact cold closure" % version
	)
	var path: String = SeasonSave.path
	var bytes: String = FileAccess.get_file_as_string(path)
	SeasonSave.path = path + "/missing/save.json"
	_check(
		(
			not app._checkpoint()
			and valid.career == original
			and _career_values(original) == values
			and FileAccess.get_file_as_string(path) == bytes
			and (
				SeasonSave.last_error
				== "Could not save season. Your current session is still available."
			)
		),
		"failed temporary open preserves Night%d owner values bytes" % version
	)
	SeasonSave.path = path
	_check(
		(
			app._checkpoint()
			and valid.career == original
			and FileAccess.get_file_as_string(path) == bytes
			and FileAccess.get_file_as_string(path + ".bak") == bytes
		),
		"Night%d retry retains identity and exact primary backup" % version
	)
	valid.career = pre_draft
	var unequal_saved: bool = app._checkpoint()
	cold = SeasonSave.restore() if unequal_saved else null
	_check(
		(
			unequal_saved
			and valid.career != pre_draft
			and _career_values(pre_draft) == draft_values
			and _career_values(valid.career) == values
			and cold != null
			and ClubCareer.same(SeasonSave.snapshot(cold), expected)
		),
		"unequal Night%d draft sync replaces owner without mutating prior career" % version
	)
	app.free()
	await get_tree().process_frame


func _retained_funding() -> SeasonState:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--funding-input="):
			var path: String = argument.trim_prefix("--funding-input=")
			if not FileAccess.file_exists(path):
				return null
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			var restored: SeasonState = SeasonSave._decode(data)
			return (
				restored
				if restored != null and restored.phase == SeasonState.Phase.COMPLETE
				else null
			)
	return _funding()


func _public_purchases(completed: SeasonState) -> ClubAssetLedger:
	# Bounded replacement for obsolete fixture-origin reset: retain all existing
	# earned history and use only public purchase/apply transactions.
	var paid: ClubAssetLedger = ClubPlayers.assets(completed.career)
	if paid == null:
		return null
	var bought: Dictionary = ClubConstruction.buy_copy(completed, "ST-037", paid.revision(), 4)
	_check(bought.ok, "public paid four original yard lights: " + str(bought.get("error")))
	if not bought.ok:
		return null
	paid = ClubPlayers.assets(completed.career)
	var expanded: Dictionary = ClubConstruction.buy_land(completed, "expanded", paid.revision())
	_check(expanded.ok, "public Expanded land: " + str(expanded.get("error")))
	if not expanded.ok:
		return null
	paid = ClubPlayers.assets(completed.career)
	for item: String in ["grass", "ground_prep"]:
		if paid.surface_owned().has(item):
			continue
		var surface: Dictionary = ClubConstruction.buy_surface(completed, item, paid.revision())
		_check(surface.ok, "public surface " + item + ": " + str(surface.get("error")))
		if not surface.ok:
			return null
		paid = ClubPlayers.assets(completed.career)
	for item: String in ["ST-063b", "ST-063i"]:
		var styled: Dictionary = ClubConstruction.buy_style(completed, item, paid.revision())
		_check(styled.ok, "public original Night style " + item + ": " + str(styled.get("error")))
		if not styled.ok:
			return null
		paid = ClubPlayers.assets(completed.career)
	return _night_purchase_layout(completed, paid)


func _night_purchase_layout(completed: SeasonState, paid: ClubAssetLedger) -> ClubAssetLedger:
	var layout: Dictionary = StadiumSurfaceLayout.upgrade(
		paid.view().stadium_active, paid.surface_owned(), true
	)
	layout.styles.grass = "ST-063b"
	layout.ground = "ST-063i"
	var copies: Array[String] = []
	for id: String in paid.construction().copies:
		if paid.construction().copies[id].item == "ST-037":
			copies.append(id)
	copies.sort()
	var sites: Array = StadiumYardLightModels.SITES.keys()
	sites.sort()
	if copies.size() != 4:
		return null
	layout.lights.clear()
	for index in range(4):
		layout.lights.append({"copy": copies[index], "site": sites[index]})
	var drafted: Dictionary = ClubConstruction.save_draft(completed, layout, paid.revision())
	_check(drafted.ok, "public original Night-compatible saved draft: " + str(drafted.get("error")))
	if not drafted.ok:
		return null
	paid = ClubPlayers.assets(completed.career)
	var applied: Dictionary = ClubConstruction.apply_draft(completed, layout, paid.revision())
	_check(
		applied.ok, "public original Night-compatible layout Apply: " + str(applied.get("error"))
	)
	if not applied.ok:
		return null
	paid = ClubPlayers.assets(completed.career)
	_check(
		ClubCareer.from_data(completed.career.to_data()) != null,
		"public purchases retain fully cold-valid original career"
	)
	return paid


func _check(condition: bool, message: String) -> void:
	_checks += 1
	print("NIGHT_SAVE_CHECK " + JSON.stringify({"ok": condition, "label": message}))
	if not condition:
		_failures += 1
