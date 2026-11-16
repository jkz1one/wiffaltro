extends "res://src/tests/stadium_lighting_kit_candidate_test.gd"
## Positive admission is exercised only in a disposable source-generated synthetic registry copy.
## No runtime test bypass, save-supplied trust, earned history or optical qualification.
var _registry: Dictionary = {}
var _durations: Array[Dictionary] = []


func _ready() -> void:
	_historical()
	var emit: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--emit-registry="):
			emit = arg.trim_prefix("--emit-registry=")
	for pattern: String in StadiumLightingKitItems.PATTERNS:
		print("KIT_ROUTE_CASE ", pattern)
		var selected: String = ""
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--route-pattern="):
				selected = arg.trim_prefix("--route-pattern=")
		if not selected.is_empty() and pattern != selected:
			continue
		var paid: ClubAssetLedger = _ledger(pattern)
		if paid == null:
			continue
		var candidate: Dictionary = CANDIDATE.capture(paid)
		var manifest: Dictionary = _synthetic_manifest(candidate.entry)
		manifest.palette_profile = "KIT_FILL2048"
		manifest.palette = PALETTE.signature(manifest.palette_profile)
		manifest.engine = Engine.get_version_info().string
		manifest.renderer = str(RenderingServer.get_current_rendering_method())
		manifest["driver"] = RenderingServer.get_current_rendering_driver_name()
		manifest["adapter"] = RenderingServer.get_video_adapter_name()
		manifest["vendor"] = RenderingServer.get_video_adapter_vendor()
		_check(
			CANDIDATE.evidence_shape(manifest, candidate.entry),
			pattern + " strict synthetic manifest shape"
		)
		_registry[manifest.composition] = {
			"digest": CANDIDATE.evidence_digest(manifest), "manifest": manifest
		}
		var season: SeasonState = _season_for(paid)
		_check(
			(
				StadiumSurfaceNightLayout.valid(candidate, paid)
				and StadiumSurfaceNightLayout.candidate_shape(candidate)
			),
			pattern + " new structural dispatch preserves candidate"
		)
		_check(
			StadiumFixtureEnvironment.capture(candidate.entry, 163, 0).mode == "day",
			pattern + " ordinary fixture remains Day"
		)
		var policy: Dictionary = StadiumSurfaceNightSnapshot.capture_policy(season, paid)
		if not CANDIDATE.PUBLIC_READY:
			_check(
				(
					policy.is_empty()
					and StadiumSurfaceNightSnapshot.signature_for(candidate.entry).is_empty()
				),
				pattern + " empty compiled registry keeps public policy closed"
			)
			continue
		if not _check(
			not policy.is_empty(),
			pattern + " compiled synthetic evidence admits explicit fixed Night"
		):
			continue
		season.owned_surface_night = policy
		_check(
			StadiumSurfaceNightSnapshot.valid_policy(policy, season, paid),
			pattern + " exact paid policy valid"
		)
		for time: String in ["day", "sunset", "night"]:
			_check(
				StadiumSurfaceNightSnapshot.capture_time_policy(season, paid, time).is_empty(),
				pattern + " cannot inherit legacy clock " + time
			)
		var scheduled: Dictionary = season.pending_fixture()
		var snapshot: Dictionary = StadiumSurfaceNightSnapshot.fixture(season, scheduled)
		if not _check(
			not snapshot.is_empty() and snapshot.version == 26, pattern + " immutable fixture26"
		):
			continue
		_check(
			StadiumSurfaceNightSnapshot.matches_fixture(snapshot, season, scheduled, paid),
			pattern + " fixture binding and paid prefix"
		)
		var proof: Dictionary = StadiumSurfaceNightSnapshot.proof(snapshot, policy, paid)
		_check(
			StadiumSurfaceNightSnapshot.proof_valid(proof, snapshot),
			pattern + " dedicated kit proof"
		)
		var altered: Dictionary = snapshot.duplicate(true)
		altered.environment.profile = StadiumSurfaceNightSnapshot.signature()
		_check(
			not StadiumSurfaceNightSnapshot.valid(altered),
			pattern + " old four-pole profile rejected"
		)
		altered = snapshot.duplicate(true)
		altered.binding.fixture += 1
		_check(
			not StadiumSurfaceNightSnapshot.matches_fixture(altered, season, scheduled, paid),
			pattern + " foreign fixture rejected"
		)
		var prior: ClubAssetLedger = paid.prefix(0)
		_check(
			prior != null and not StadiumSurfaceNightSnapshot.matches(snapshot, prior),
			pattern + " unpaid prefix rejected"
		)
		await _managed_runtime(season, paid, pattern)
	if not emit.is_empty():
		var file: FileAccess = FileAccess.open(emit, FileAccess.WRITE)
		file.store_string(JSON.stringify(_registry, "\t", true, true))
		file.close()
	_historical()
	print(
		"KIT_ROUTE_RESULT ",
		JSON.stringify(
			{
				"checks": checks,
				"failures": failures,
				"synthetic_registry": CANDIDATE.PUBLIC_READY,
				"optical_qualification": false,
				"candidate3": CANDIDATE.signature(),
				"durations": _durations
			}
		)
	)
	get_tree().quit(0 if failures.is_empty() else 1)


func _season_for(paid: ClubAssetLedger) -> SeasonState:
	var season: SeasonState = SeasonState.create(101, false, true, true)
	for pick in range(4):
		season.choose_player(season.offers()[0])
	while not season.pending_fixture().is_empty() and season.pending_fixture().get("home") != 0:
		var prior: Dictionary = season.pending_fixture()
		if not season.record_player_result(int(prior.id), 1, 0):
			break
	season._pool_replay_ledger = paid
	season._npc_replay_run = 0
	season.home_property = StadiumLayoutSnapshot.capture(paid)
	_check(season.pending_fixture().get("home") == 0, "synthetic fixture starts at home")
	return season


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
