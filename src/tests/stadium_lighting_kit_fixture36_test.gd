extends "res://src/tests/stadium_lighting_kit_route_test.gd"
## Isolated original-complete-receipt adapter tests. Synthetic trust exists only in a disposable
## source copy.
const ADAPTER = preload("res://src/gameplay/stadium/stadium_lighting_kit_night_receipt_adapter.gd")
var _selected_wrapper: String = ""
var _exercise_runtime: bool = false


func _ready() -> void:
	_historical()
	_check(
		CANDIDATE.signature() == "306c6ce845123953945aae6f0e286210f8e3b94cfc765a7afeee7d82aa5b8102",
		"explicit new issued physical43 contract, not relabeled guard206"
	)
	var selected_pattern: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--route-pattern="):
			selected_pattern = argument.trim_prefix("--route-pattern=")
		elif argument.begins_with("--wrapper="):
			_selected_wrapper = argument.trim_prefix("--wrapper=")
		elif argument == "--exercise-runtime":
			_exercise_runtime = true
	for pattern: String in StadiumLightingKitItems.PATTERNS:
		if not selected_pattern.is_empty() and selected_pattern != pattern:
			continue
		for wrapper: String in ["46", "47-45", "47-46"]:
			if not _selected_wrapper.is_empty() and _selected_wrapper != wrapper:
				continue
			print("FIXTURE36_CASE ", pattern, " ", wrapper)
			await _wrapped_case(pattern, wrapper)
	_historical()
	print(
		"FIXTURE36_RESULT ",
		JSON.stringify(
			{
				"checks": checks,
				"failures": failures,
				"synthetic_registry": CANDIDATE.PUBLIC_READY,
				"optical_qualification": false,
				"runtime_exercised": _exercise_runtime,
				"adapter": ADAPTER.signature(CANDIDATE.signature()),
				"physical43_candidate": CANDIDATE.signature(),
				"durations": _durations
			}
		)
	)
	get_tree().quit(0 if failures.is_empty() else 1)


func _wrapped_case(pattern: String, wrapper: String) -> void:
	var tag: String = pattern.to_lower() + wrapper.replace("-", "")
	var paid: ClubAssetLedger = _ledger(pattern, tag)
	if paid == null:
		return
	var original43: Dictionary = CANDIDATE.capture(paid)
	if not _check(not original43.is_empty(), "original physical43 receipt valid"):
		return
	var old_events: int = paid.revision()
	var old_money: Variant = paid.view().get("balance")
	var old_inventory: Dictionary = paid.construction().to_data()
	var layout: Dictionary = (
		StadiumLowWallLayout.upgrade(paid.view().stadium_active, paid.surface_owned())
		if wrapper != "47-45"
		else StadiumWaterfallLiveItems.upgrade(paid.view().stadium_active, paid.surface_owned())
	)
	if wrapper.begins_with("47"):
		layout = StadiumWaterfallAnimationLayout.upgrade(layout, paid.surface_owned())
	if not _apply_complete(paid, layout, tag + "wrapped"):
		return
	_check(
		(
			paid.revision() == old_events + 2
			and ClubCareer.same(paid.construction().to_data(), old_inventory)
			and paid.view().get("balance") == old_money
		),
		"wrapper draft/apply requires no item purchase or inventory migration"
	)
	var before: Dictionary = paid.to_data()
	var candidate: Dictionary = CANDIDATE.capture(paid)
	if not _check(not candidate.is_empty(), "complete successor candidate capture"):
		return
	var entry: Dictionary = candidate.entry
	_check(
		(
			entry.version == (32 if wrapper == "46" else 34)
			and entry.layout.version == (46 if wrapper == "46" else 47)
		),
		"original entry and layout versions retained"
	)
	_check(
		(
			entry.has("wall_piece_inventory")
			and entry.has("scoreboard_inventory")
			and ADAPTER.valid_entry(entry)
		),
		"complete original inventories validate"
	)
	_check(
		(
			CANDIDATE.valid(candidate, paid)
			and CANDIDATE.candidate_shape(JSON.parse_string(JSON.stringify(candidate)))
		),
		"complete paid candidate and JSON roundtrip"
	)
	_check(
		(
			candidate.contract == ADAPTER.signature(CANDIDATE.signature())
			and candidate.contract != original43.contract
		),
		"new receipt adapter cannot borrow old receipt contract"
	)
	_check(
		(
			CANDIDATE.structural_profile(entry).composition_key
			== CANDIDATE.structural_profile(original43.entry).composition_key
		),
		"empty wrappers share only identical physical43 composition"
	)
	_check(
		ClubCareer.same(CANDIDATE.physical_layout(entry.layout), original43.entry.layout),
		"lossless empty projection equals the actual original physical43 layout"
	)
	_check(
		entry.geometry != original43.entry.geometry and entry.boundary == original43.entry.boundary,
		"original wrapper geometry retained separately from equal physical boundary"
	)
	_check(
		CANDIDATE.valid(original43, paid),
		"earlier exact paid prefix remains valid after additive wrapper"
	)
	_check(
		ClubCareer.same(before, paid.to_data()),
		"capture and projection never mutate ownership or paid receipt"
	)
	await _fixture36_scheduled_snapshot(pattern, paid, original43, candidate, entry)


func _fixture36_scheduled_snapshot(
	pattern: String, paid: ClubAssetLedger, original43: Dictionary, candidate: Dictionary,
	entry: Dictionary
) -> void:
	var changed: Dictionary = candidate.duplicate(true)
	changed.contract = CANDIDATE.signature()
	_check(
		not CANDIDATE.candidate_shape(changed),
		"old core contract cannot stand in for complete receipt adapter"
	)
	changed = candidate.duplicate(true)
	changed.entry.geometry = original43.entry.geometry
	_check(
		not CANDIDATE.candidate_shape(changed),
		"physical geometry cannot replace original receipt geometry"
	)
	changed = candidate.duplicate(true)
	changed.entry.wall_piece_inventory = {}
	_check(not CANDIDATE.candidate_shape(changed), "omitted complete wall inventory refused")
	changed = candidate.duplicate(true)
	changed.entry.scoreboard_inventory = {}
	_check(not CANDIDATE.candidate_shape(changed), "omitted complete scoreboard inventory refused")
	changed = candidate.duplicate(true)
	changed.entry.layout.lighting_kits[0].copy = "foreign:copy"
	_check(not CANDIDATE.valid(changed, paid), "foreign kit copy cannot reuse wrapper authority")
	for field: String in ["outfield_plaza", "live_waterfalls", "waterfall_motion"]:
		if not entry.layout.has(field):
			continue
		var nonempty: Dictionary = entry.layout.duplicate(true)
		nonempty[field] = (
			["foreign"] if field == "waterfall_motion" else [{"copy": "foreign", "site": "foreign"}]
		)
		_check(
			CANDIDATE.physical_layout(nonempty).is_empty(),
			"nonempty " + field + " never projects into qualified physical43"
		)
	if entry.layout.has("low_wall"):
		var nonempty: Dictionary = entry.layout.duplicate(true)
		nonempty.low_wall["profile"] = "foreign"
		_check(
			CANDIDATE.physical_layout(nonempty).is_empty(),
			"nonempty low-wall profile cannot inherit Night"
		)
	var season: SeasonState = _season_for(paid)
	var policy: Dictionary = StadiumSurfaceNightSnapshot.capture_policy(season, paid)
	if not CANDIDATE.PUBLIC_READY:
		_check(
			policy.is_empty() and CANDIDATE.admission_profile(entry).is_empty(),
			"closed release does not grant fixture36"
		)
		return
	if not _check(not policy.is_empty(), "synthetic source-only evidence exercises fixed Night36"):
		return
	season.owned_surface_night = policy
	var scheduled: Dictionary = season.pending_fixture()
	var fixture: Dictionary = StadiumSurfaceNightSnapshot.fixture(season, scheduled)
	if not _check(not fixture.is_empty() and fixture.version == 36, "explicit fixture36 issued"):
		return
	_check(
		fixture.entry_version == entry.version and fixture.receipt_adapter == candidate.contract,
		"fixture36 binds original entry discriminator and adapter"
	)
	_check(
		ClubCareer.same(StadiumSurfaceNightSnapshot.entry(fixture), entry),
		"fixture36 reconstructs exact original complete entry, not fabricated entry8"
	)
	_check(
		(
			StadiumLayoutSnapshot.valid(fixture, paid.construction())
			and StadiumSurfaceNightSnapshot.matches_fixture(fixture, season, scheduled, paid)
		),
		"public layout dispatcher and complete paid fixture match"
	)
	_check(
		ClubCareer.same(
			StadiumSurfaceNightSnapshot.normalized(JSON.parse_string(JSON.stringify(fixture))),
			fixture
		),
		"fixture36 exact JSON replay"
	)
	var proof: Dictionary = StadiumSurfaceNightSnapshot.proof(fixture, policy, paid)
	_check(
		StadiumSurfaceNightSnapshot.proof_valid(proof, fixture),
		"proof binds original complete receipt"
	)
	_check(
		PhysicalStadiumContacts.valid([], [], fixture),
		"complete original receipt contact dispatcher accepts empty actual-contact sequence"
	)
	_check(
		(
			StadiumSurfaceNightSnapshot.is_fixed(fixture)
			and not StadiumSurfaceNightSnapshot.is_time(fixture)
		),
		"new fixed fixture is distinct from legacy clock"
	)
	_check(
		(
			not StadiumSurfaceNightReport.valid(
				{"version": 24, "property": fixture, "night": proof}
			)
			and not StadiumSurfaceNightHumanEvidence.valid(
				{"version": 1, "property": fixture, "night": proof}
			)
		),
		"fixture36 cannot manufacture complete-game evidence from receipt alone"
	)

	changed = fixture.duplicate(true)
	changed.entry_version = 8
	_check(not StadiumSurfaceNightSnapshot.valid(changed), "entry8 substitution rejected")
	changed = fixture.duplicate(true)
	changed.receipt_adapter = "0".repeat(64)
	_check(not StadiumSurfaceNightSnapshot.valid(changed), "stale adapter rejected")
	changed = fixture.duplicate(true)
	changed.geometry = original43.entry.geometry
	_check(
		not StadiumSurfaceNightSnapshot.valid(changed),
		"fixture physical geometry substitution rejected"
	)
	changed = fixture.duplicate(true)
	changed.environment.profile = StadiumSurfaceNightSnapshot.signature_for(original43.entry)
	_check(
		not StadiumSurfaceNightSnapshot.valid(changed),
		"fixture26 profile cannot substitute for fixture36"
	)
	changed = fixture.duplicate(true)
	changed.binding.fixture += 1
	_check(
		not StadiumSurfaceNightSnapshot.matches_fixture(changed, season, scheduled, paid),
		"foreign fixture binding rejected"
	)
	if _exercise_runtime:
		await _managed_runtime(season, paid, pattern)


func _apply_complete(paid: ClubAssetLedger, layout: Dictionary, tag: String) -> bool:
	var drafted: Dictionary = paid.commit(
		{"id": tag + "-draft", "rev": paid.revision(), "op": "stadium_draft", "layout": layout}
	)
	var applied: Dictionary = (
		paid.commit(
			{
				"id": tag + "-apply",
				"rev": paid.revision(),
				"op": "stadium_apply",
				"layout": layout,
				"geometry": StadiumOwnedLayout.geometry("backyard", layout)
			}
		)
		if drafted.ok
		else drafted
	)
	return _check(
		drafted.ok and applied.ok,
		"complete-owned wrapper draft/apply: " + str(applied.get("error", ""))
	)


func _managed_runtime(season: SeasonState, paid: ClubAssetLedger, pattern: String) -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	add_child(viewport)
	var app: SeasonApp = SeasonApp.new()
	viewport.add_child(app)
	app.set_process(false)
	app.season = season
	app._fixture_id = int(season.pending_fixture().id)
	var lab: PitchBatLab = PitchBatLab.new()
	lab._configured_match = season.make_match()
	lab._npc_season = season
	lab._stadium_ledger = paid
	lab._managed_match = true
	lab._player_home = true
	app.lab = lab
	app._season_game = true
	_check(
		StadiumSurfaceNightRuntime.configure(lab, season, paid),
		pattern + " genuine configure with synthetic replay ledger"
	)
	app.add_child(lab)
	if not _check(is_instance_valid(lab), pattern + " managed caller creates actual bound lab"):
		print("KIT_ROUTE_NOTICE ", app.notice)
		viewport.free()
		return
	lab._sounds.set_muted(true)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._pitch_actor.set_physics_process(false)
	lab._primary_fielder.set_physics_process(false)
	lab._at_bat_cadence.stop()
	var owner: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.current(lab)
	if not _check(
		owner != null and StadiumSurfaceNightRuntime.installed_bound(lab, lab._match_state.stadium),
		pattern + " actual fixture/runtime installation"
	):
		print(
			"KIT_ROUTE_INSTALL_FAIL ",
			owner._install_step if owner else "no-owner",
			" phase=",
			owner._phase if owner else -1,
			" notice=",
			app.notice
		)
		viewport.free()
		return
	_check(
		(
			lab._match_state.stadium.version == 36
			and owner._snapshot.geometry != owner._kit_physical_geometry
			and owner._property.get_meta("property_signature") == owner._kit_physical_geometry
			and owner._kit_physical_layout.version == 43
			and ClubCareer.same(
				StadiumSurfaceNightSnapshot.entry(owner._snapshot), season.home_property
			)
		),
		"installed physical43 is separately bound while original complete36 receipt stays exact"
	)
	var prior_layout: Dictionary = owner._kit_physical_layout
	var foreign_layout: Dictionary = prior_layout.duplicate(true)
	foreign_layout.lighting_kits[0].copy = "foreign:copy"
	owner._kit_physical_layout = foreign_layout
	_check(
		not owner._kit_action_intact(lab) and not (owner._context(lab) and owner._operands()),
		"hot and deep predicates reject physical projection mutation"
	)
	owner._kit_physical_layout = prior_layout
	var prior_geometry: String = owner._kit_physical_geometry
	owner._kit_physical_geometry = owner._snapshot.geometry
	_check(
		not owner._kit_action_intact(lab) and not (owner._context(lab) and owner._operands()),
		"hot and deep predicates reject original receipt geometry as physical geometry"
	)
	owner._kit_physical_geometry = prior_geometry
	_check(
		owner._kit_action_intact(lab) and owner._context(lab) and owner._operands(),
		"exact separate physical bindings restore hot and deep predicates"
	)
	_check(
		(
			owner._kit_mode
			and not owner._floodlight_mode
			and not owner._time_mode
			and owner._kit_lease.active
		),
		pattern + " dedicated fixed-night participant, not legacy floodlight/palette"
	)
	_check(
		(
			owner._property.props_intact()
			and not owner._property.has_node("OwnedSurfaceFinish/GroundTreatment/SurfaceVisual")
		),
		pattern + " rough-dirt property needs no plate-sand surface"
	)
	var started: int = Time.get_ticks_usec()
	_check(StadiumSurfaceNightRuntime.action_allowed(lab), pattern + " actual hot action guard")
	_durations.append(
		{"pattern": pattern, "single_action_guard_ms": (Time.get_ticks_usec() - started) / 1000.0}
	)
	var beam: SpotLight3D = owner._kit_lease.sources[0]
	var energy: float = beam.light_energy
	beam.light_energy += 0.1
	_check(
		not (owner._context(lab) and owner._operands()),
		pattern + " complete action predicate refuses source mutation within same frame"
	)
	beam.light_energy = energy
	_check(
		owner._context(lab) and owner._operands(),
		pattern + " exact source restoration restores checks"
	)
	viewport.size = Vector2i(1228, 690)
	_check(
		owner._operands(),
		pattern + " ordinary resize is not a hardware allowlist or evidence claim"
	)
	viewport.size = Vector2i(1280, 720)
	var prior_profile: Dictionary = owner._kit_profile
	var foreign_profile: Dictionary = prior_profile.duplicate(true)
	foreign_profile.renderer = (
		"mobile" if prior_profile.renderer != "mobile" else "gl_compatibility"
	)
	owner._kit_profile = foreign_profile
	_check(not owner._operands(), pattern + " unreviewed renderer cannot reuse profile")
	owner._kit_profile = prior_profile
	var before_env: Environment = owner._kit_lease._source_environment
	var before_sun: float = owner._kit_lease._changes[2].original
	owner._restore(lab)
	_check(
		(
			owner._phase == StadiumSurfaceNightRuntime.Phase.RETIRED
			and lab._world_environment.environment == before_env
			and not viewport.has_meta(StadiumSurfaceNightRuntime.ATLAS)
			and not viewport.has_meta(StadiumLightingKitPreviewRuntime.LEASE)
		),
		pattern + " transactional teardown restores exact original ownership"
	)
	viewport.free()
	await get_tree().process_frame
