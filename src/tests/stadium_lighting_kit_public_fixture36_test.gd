extends "res://src/tests/stadium_lighting_kit_route_test.gd"


## Fully decoded retained synthetic career, supported purchase/apply/SeasonApp/save APIs.
## The callback-only home cursor is a disposable decoded copy, never saved or settled.
func _ready() -> void:
	var old_path: String = SeasonSave.path
	SeasonSave.path = "user://kit-public-route-test.json"
	_historical()
	for pattern: String in StadiumLightingKitItems.PATTERNS:
		var selected: String = ""
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--route-pattern="):
				selected = arg.trim_prefix("--route-pattern=")
		if not selected.is_empty() and selected != pattern:
			continue
		print("KIT_PUBLIC_CASE ", pattern)
		await _public_case(pattern)
	_historical()
	SeasonSave.path = old_path
	print(
		"KIT_PUBLIC_FIXTURE36_RESULT ",
		JSON.stringify(
			{
				"checks": checks,
				"failures": failures,
				"synthetic_verified_career": true,
				"synthetic_compiled_registry": CANDIDATE.PUBLIC_READY,
				"authentic_earned_history": false,
				"physical_games": 0,
				"optical_qualification": false
			}
		)
	)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures.is_empty() else 1)


func _public_case(pattern: String) -> void:
	var wrapper: String = "47-46"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--wrapper="):
			wrapper = argument.trim_prefix("--wrapper=")
	if not _check(wrapper in ["43", "46", "47-45", "47-46"], "explicit successor test composition"):
		return
	var fixture: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://src/tests/lighting_audit_verified_season_fixture.json")
	)
	var completed: SeasonState = SeasonSave._decode(fixture)
	if not _check(completed != null, "verified 41-season synthetic fixture cold-loads"):
		return
	var legacy: ClubAssetLedger = ClubPlayers.assets(completed.career)
	var prefix: ClubAssetLedger = legacy.prefix(41)
	if not _check(
		(
			prefix != null
			and legacy.to_data().events[41].op == "stadium_land"
			and prefix.view().land == "backyard"
		),
		"exact pre-land historical paid prefix, no invented income"
	):
		return
	fixture.career.assets = prefix.to_data()
	completed = SeasonSave._decode(fixture)
	if not _check(completed != null, "whole career validates retained Backyard prefix"):
		return
	_check(SeasonSave.save(completed), "initial supported full file save")
	await _public_fixture_draft(pattern, wrapper, completed)


func _public_fixture_draft(pattern: String, wrapper: String, completed: SeasonState) -> void:
	var paid: ClubAssetLedger = ClubPlayers.assets(completed.career)
	var revision: int = paid.revision()
	var bought: Dictionary = ClubConstruction.buy_copy(completed, "ST-111", revision, 1)
	if not _check(bought.ok, "supported paid kit purchase: " + bought.error):
		return
	paid = ClubPlayers.assets(completed.career)
	var layout: Dictionary = StadiumLightingKitItems.place(
		paid.view().stadium_draft,
		paid.construction(),
		"purchase:stadium-buy:%d:0" % revision,
		pattern,
		0,
		paid.surface_owned()
	)
	# Explicit supported rough-dirt choice; legacy fixture starts prepared.
	layout.surface = CANDIDATE.DEFAULT_SURFACE.duplicate(true)
	if pattern == "MIXED_EDGE":
		revision = paid.revision()
		bought = ClubConstruction.buy_copy(completed, "ST-037", revision, 2)
		if not _check(bought.ok, "separate supported rear-pole purchase"):
			return
		paid = ClubPlayers.assets(completed.career)
		layout.lights = [
			{"copy": "purchase:stadium-buy:%d:0" % revision, "site": "YLIGHT-RL"},
			{"copy": "purchase:stadium-buy:%d:1" % revision, "site": "YLIGHT-RR"}
		]
	# Explicit supported complete successor draft, with the same purchased copies.
	# These wrappers are not a user-visible Night option or a new purchase.
	if wrapper != "43":
		layout = (
			StadiumLowWallLayout.upgrade(layout, paid.surface_owned())
			if wrapper != "47-45"
			else StadiumWaterfallLiveItems.upgrade(layout, paid.surface_owned())
		)
	if wrapper.begins_with("47"):
		layout = StadiumWaterfallAnimationLayout.upgrade(layout, paid.surface_owned())
	var result: Dictionary = ClubConstruction.save_draft(completed, layout, paid.revision())
	if not _check(result.ok, "supported complete kit draft: " + result.error):
		return
	paid = ClubPlayers.assets(completed.career)
	result = ClubConstruction.apply_draft(completed, layout, paid.revision())
	if not _check(result.ok, "supported Apply of exact rough dirt: " + result.error):
		return
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	add_child(viewport)
	var app: SeasonApp = SeasonApp.new()
	viewport.add_child(app)
	app.set_process(false)
	app.season = completed
	app.begin_season(101, true, true, true, true, true, 0)
	var day: SeasonState = app.season
	if not _check(
		day != completed and day != null and day.owned_surface_night.is_empty(),
		"default new season remains ordinary Day"
	):
		print("KIT_PUBLIC_NOTICE ", app.notice)
		viewport.free()
		return
	_check(
		(
			day.home_property.version == (8 if wrapper == "43" else 32 if wrapper == "46" else 34)
			and (
				day.home_property.layout.version
				== (43 if wrapper == "43" else 46 if wrapper == "46" else 47)
			)
		),
		"new ordinary club retains latest complete-owned entry"
	)
	var day_save: Dictionary = SeasonSave.snapshot(day)
	_check(
		SeasonSave._decode(day_save) != null and day_save.version != 72,
		"default Day full save keeps historical route"
	)
	await _day_startup_control(day, wrapper)
	app.begin_surface_time_season("night", 101, 0)
	var night: SeasonState = app.season
	if not CANDIDATE.PUBLIC_READY:
		_check(
			night == day and ClubCareer.same(SeasonSave.snapshot(day), day_save),
			"unqualified public Night fails without season/receipt mutation"
		)
		viewport.free()
		return
	await _public_fixture_night_state(wrapper, viewport, app, day, night)


func _public_fixture_night_state(
	wrapper: String, viewport: SubViewport, app: SeasonApp, day: SeasonState, night: SeasonState
) -> void:
	if not _check(
		(
			night != day
			and not night.owned_surface_night.is_empty()
			and night.owned_surface_night.version == 1
		),
		"public Night selection chooses explicit fixed policy, not time27"
	):
		print("KIT_PUBLIC_NOTICE ", app.notice)
		print("KIT_PUBLIC_PROFILE ", CANDIDATE.structural_profile(day.home_property))
		print("KIT_PUBLIC_LAYOUT ", JSON.stringify(day.home_property))
		print("KIT_PUBLIC_ADMISSION ", CANDIDATE.admission_profile(day.home_property))
		viewport.free()
		return
	for index in range(4):
		_check(night.choose_player(night.offers()[0]), "ordinary draft choice")
	if not _check(SeasonSave.save(night), "actual Night save file commits"):
		viewport.free()
		return
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	var cold: SeasonState = SeasonSave._decode(saved)
	if not _check(
		saved.version == 72 and cold != null and ClubCareer.same(SeasonSave.snapshot(cold), saved),
		"save72 cold replay retains exact paid kit profile"
	):
		viewport.free()
		return
	_check(
		(
			ClubCareer.same(cold.home_property, night.home_property)
			and ClubCareer.same(cold.owned_surface_night.candidate.entry, cold.home_property)
			and (
				wrapper == "43"
				or (
					cold.home_property.has("wall_piece_inventory")
					and cold.home_property.has("scoreboard_inventory")
				)
			)
		),
		"save72 cold replay preserves complete original entry32/34, not projected entry8"
	)
	var bad: Dictionary = saved.duplicate(true)
	bad.owned_surface_night.candidate.entry.layout.lighting_kits[0].copy = "foreign:copy"
	_check(SeasonSave._decode(bad) == null, "save rejects foreign paid kit identity")
	bad = saved.duplicate(true)
	bad.owned_surface_night.candidate.contract = "0".repeat(64)
	_check(SeasonSave._decode(bad) == null, "save rejects stale candidate contract")
	var disk: String = FileAccess.get_file_as_string(SeasonSave.path)
	var first_home: Dictionary = {}
	for row: Dictionary in cold.schedule:
		if row.home == 0 and (first_home.is_empty() or row.round < first_home.round):
			first_home = row
	# Isolated callback cursor only. No save/results/settlement.
	cold.round_index = int(first_home.round)
	app.season = cold
	app._fixture_id = int(cold.pending_fixture().id)
	var exact_match: MatchState = cold.make_match()
	_check(
		(
			exact_match != null
			and exact_match.stadium.version == (26 if wrapper == "43" else 36)
			and ClubCareer.same(
				StadiumSurfaceNightSnapshot.entry(exact_match.stadium), cold.home_property
			)
		),
		"actual current-baseline public caller receives fixture36 with original complete receipt"
	)
	app._open_match(exact_match, true, true, PitchBatLab.FIELD_ID)
	var lab: PitchBatLab = app.lab
	if _check(
		(
			is_instance_valid(lab)
			and StadiumSurfaceNightRuntime.installed_bound(lab, lab._match_state.stadium)
		),
		"genuine SeasonApp public caller installs selected kit"
	):
		var owner: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.current(lab)
		_check(
			(
				owner._kit_physical_layout.version == 43
				and (
					owner._kit_physical_geometry == owner._snapshot.geometry
					if wrapper == "43"
					else owner._kit_physical_geometry != owner._snapshot.geometry
				)
				and owner._property.get_meta("property_signature") == owner._kit_physical_geometry
			),
			"actual public fixture installs separate physical43 without rewriting receipt"
		)
		lab.set_process(false)
		lab.set_physics_process(false)
		lab._pitch_actor.set_physics_process(false)
		lab._at_bat_cadence.stop()
		_check(
			StadiumSurfaceNightRuntime.action_allowed(lab),
			"public caller action guard accepts intact fixture"
		)
		_check(
			app._played_field_matches(),
			"ordinary settlement field gate accepts exact original receipt plus physical43"
		)
		var mutation: String = ""
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--settlement-mutation="):
				mutation = argument.trim_prefix("--settlement-mutation=")
		if not mutation.is_empty():
			_check(
				mutation in ["foreign-copy", "original-geometry"],
				"one explicit terminal settlement mutation"
			)
			var substituted: Dictionary = lab._match_state.stadium.duplicate(true)
			if mutation == "foreign-copy":
				substituted.layout.lighting_kits[0].copy = "foreign:copy"
			elif mutation == "original-geometry":
				substituted.geometry = owner._kit_physical_geometry
			lab._match_state.stadium = substituted  # Do not mutate the deeply read-only issued receipt.
			_check(
				not app._played_field_matches(),
				(
					"ordinary settlement rejects "
					+ mutation
					+ " instead of treating projection as paid receipt"
				)
			)
		if StadiumSurfaceNightRuntime.current(lab) != null:
			StadiumSurfaceNightRuntime.current(lab)._restore(lab)
	_check(
		FileAccess.get_file_as_string(SeasonSave.path) == disk,
		"callback cursor and runtime never rewrite saved results or receipt"
	)
	viewport.free()
	await get_tree().process_frame


func _day_startup_control(source: SeasonState, wrapper: String) -> void:
	# Disposable cold-decoded callback cursor only. No result, settlement or saved
	# progression is manufactured; the later genuine bundle test covers that route.
	var day: SeasonState = SeasonSave._decode(SeasonSave.snapshot(source))
	if not _check(
		day != null and day.owned_surface_night.is_empty(),
		"Day startup control cold-decodes exact paid season"
	):
		return
	for pick in range(4):
		if not _check(
			not day.offers().is_empty() and day.choose_player(day.offers()[0]),
			"Day control ordinary draft choice"
		):
			return
	var first_home: Dictionary = {}
	for row: Dictionary in day.schedule:
		if row.home == 0 and (first_home.is_empty() or row.round < first_home.round):
			first_home = row
	if not _check(not first_home.is_empty(), "Day control has a real scheduled home fixture"):
		return
	day.round_index = int(first_home.round)  # Unsaved callback-only test cursor.
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	add_child(viewport)
	var app: SeasonApp = SeasonApp.new()
	viewport.add_child(app)
	app.set_process(false)
	app.season = day
	app._fixture_id = int(day.pending_fixture().id)
	var state: MatchState = day.make_match()
	if not _check(
		state != null and not StadiumSurfaceNightSnapshot.is_family(state.stadium),
		"Day control remains non-Night"
	):
		viewport.free()
		return
	var paid: ClubAssetLedger = ClubPlayers.assets(day.career)
	_check(
		app._mounted_match_ledger(state, true, true) != null,
		"exact mounted ledger validates Day " + wrapper
	)
	_check(
		(
			app._mounted_match_ledger(state, false, true) == null
			and app._mounted_match_ledger(state, true, false) == null
		),
		"away/exhibition cannot borrow mounted home ledger"
	)
	var saved_assets: Dictionary = day.career._assets
	var prior: ClubAssetLedger = paid.prefix(41)
	if not _check(
		prior != null and not StadiumLayoutSnapshot.matches(state.stadium, prior),
		"valid pre-purchase ledger cannot pay this Day fixture"
	):
		viewport.free()
		return
	day.career._assets = prior.to_data()
	_check(
		app._mounted_match_ledger(state, true, true) == null,
		"forged-current unpaid ledger refused by exact mounted route"
	)
	app._open_match(state, true, true, PitchBatLab.FIELD_ID)
	_check(
		not is_instance_valid(app.lab),
		"actual public Day startup refuses unpaid ledger before allocation"
	)
	day.career._assets = saved_assets
	app._open_match(state, true, true, PitchBatLab.FIELD_ID)
	var lab: PitchBatLab = app.lab
	if _check(
		is_instance_valid(lab), "actual public Day " + wrapper + " startup keeps installed property"
	):
		lab.set_process(false)
		lab.set_physics_process(false)
		lab._pitch_actor.set_physics_process(false)
		lab._primary_fielder.set_physics_process(false)
		lab._at_bat_cadence.stop()
		var property: Variant = (
			lab.get_meta("stadium_property") if lab.has_meta("stadium_property") else null
		)
		_check(
			(
				is_instance_valid(property)
				and property is StadiumPropertyGeometry
				and property.props_intact()
			),
			"Day property retains full ordinary integrity"
		)
		_check(
			(
				lab._stadium_ledger != null
				and StadiumLayoutSnapshot.matches(state.stadium, lab._stadium_ledger)
			),
			"Day caller binds exact paid receipt, not a generic trust bypass"
		)
		_check(
			(
				StadiumBoundaryRuntime.installed(lab, state.stadium)
				and StadiumSurfaceNightRuntime.current(lab) == null
			),
			"Day boundary installed with no Night owner"
		)
		_check(
			app._played_field_matches(), "Day settlement field comparison retains original receipt"
		)
	viewport.free()
	await get_tree().process_frame
