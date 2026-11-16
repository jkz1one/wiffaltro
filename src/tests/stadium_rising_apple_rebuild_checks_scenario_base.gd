extends "res://src/tests/stadium_rising_apple_rebuild_checks_fixture_base.gd"


func _time_phase(label: String, started_us: int) -> void:
	_phase_timings_ms[label] = (Time.get_ticks_usec() - started_us) / 1000.0


func _setup_error(message: String) -> Dictionary:
	_setup_error_text = message
	print(
		(
			"RISING_APPLE_SETUP_ERROR "
			+ JSON.stringify(
				{"error": message, "executed_checks": _checks, "scored_failures": _failures},
				"",
				true,
				true
			)
		)
	)
	return {"checks": _checks, "failures": maxi(_failures, 1), "setup_error": message}


func _write_bounded(path: String, value: Dictionary) -> bool:
	var bytes: String = JSON.stringify(value, "", true, true)
	if bytes.to_utf8_buffer().size() > 131072:
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(bytes)
	file.flush()
	var result: bool = file.get_error() == OK
	file.close()
	return result


func _read_bounded(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var length: int = file.get_length()
	if length <= 0 or length > 131072:
		file.close()
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func _run_retirement(
	directory: String, bootstrap_path: String, expected_sha256: String
) -> Dictionary:
	var setup_started: int = Time.get_ticks_usec()
	if (
		DisplayServer.get_name() == "headless"
		or directory.is_empty()
		or DirAccess.make_dir_recursive_absolute(directory) != OK
	):
		return _setup_error("phase 2 needs the same rendered scene and a writable output directory")
	if (
		bootstrap_path.is_empty()
		or expected_sha256.length() != 64
		or FileAccess.get_sha256(bootstrap_path) != expected_sha256
	):
		return _setup_error("phase 2 bootstrap path or explicit SHA256 does not match")
	var bootstrap: Dictionary = _read_bounded(bootstrap_path)
	if not SeasonOwnership._keys(
		bootstrap,
		[
			"version",
			"kind",
			"carried_checks",
			"union_expected_checks",
			"phase1_evidence_sha256",
			"source_context",
			"seed",
			"credits",
			"progress",
			"ledger",
			"paid_copy_ids",
			"inherited_paid_copies",
			"empty_layout",
			"layout",
			"snapshot"
		]
	):
		return _setup_error("phase 2 bootstrap has an unknown exact field set")
	# Version 1 preserves only the exact f00 source inventory; version 2 seals relocated helpers.
	# The explicit bootstrap SHA256 still binds the producer, separately from this executor.
	var carried_context: Dictionary = _source_context()
	if (
		not _apple_source_version_supported(bootstrap.version)
		or bootstrap.kind != "rising-apple-phase1-bootstrap"
		or bootstrap.carried_checks != PHASE1_CHECKS
		or bootstrap.union_expected_checks != UNION_CHECKS
		or bootstrap.seed != SEED
		or not bootstrap.source_context is Dictionary
		or not _apple_source_context_matches(
			bootstrap.version, bootstrap.source_context, carried_context
		)
	):
		return _setup_error("phase 2 bootstrap version counts seed or exact source context differs")
	var evidence_path: String = bootstrap_path.get_base_dir().path_join("rising-apple-rebuild.json")
	if (
		not bootstrap.phase1_evidence_sha256 is String
		or FileAccess.get_sha256(evidence_path) != bootstrap.phase1_evidence_sha256
	):
		return _setup_error("carried phase 1 evidence SHA256 does not match the bootstrap")
	var evidence: Dictionary = _read_bounded(evidence_path)
	return await _apple_retirement_evidence_checks(
		directory, expected_sha256, setup_started, bootstrap, evidence
	)


func _apple_retirement_evidence_checks(
	directory: String, expected_sha256: String, setup_started: int, bootstrap: Dictionary,
	evidence: Dictionary
) -> Dictionary:
	if (
		evidence.get("execution_phase") != 1
		or evidence.get("executed_checks") != PHASE1_CHECKS
		or evidence.get("checks") != PHASE1_CHECKS
		or evidence.get("failures") != 0
		or evidence.get("expected_checks") != PHASE1_CHECKS
		or evidence.get("carried_checks") != 0
		or evidence.get("cumulative_checks") != PHASE1_CHECKS
		or evidence.get("union_expected_checks") != UNION_CHECKS
		or not ClubCareer.same(evidence.get("phase_checks"), EXPECTED_PHASE_CHECKS)
		or evidence.get("model_checks") != StadiumRisingAppleGeometryRebuildChecks.expected_checks()
	):
		return _setup_error(
			"carried phase 1 evidence is not the exact successful 267-check partition"
		)
	if (
		not bootstrap.credits is Array
		or not bootstrap.progress is Array
		or not bootstrap.ledger is Dictionary
		or not bootstrap.paid_copy_ids is Array
		or not bootstrap.inherited_paid_copies is Dictionary
		or not bootstrap.empty_layout is Dictionary
		or not bootstrap.layout is Dictionary
		or not bootstrap.snapshot is Dictionary
	):
		return _setup_error("bootstrap paid context has malformed value types")
	var expected_credits: Array = []
	var expected_progress: Array = []
	for index in range(40):
		expected_credits.append(1000)
		expected_progress.append(
			{"seasons": 1, "wins": 5, "strikeouts": 10, "hits": 4, "homers": 2}
		)
	if (
		not ClubCareer.same(bootstrap.credits, expected_credits)
		or not ClubCareer.same(bootstrap.progress, expected_progress)
		or not StadiumCareerProgress.valid(bootstrap.progress, bootstrap.credits)
	):
		return _setup_error(
			"bootstrap funding or closed progression differs from the disclosed fixed synthetic context"
		)
	_credits = bootstrap.credits.duplicate(true)
	_progress = bootstrap.progress.duplicate(true)
	_paid = ClubAssetLedger.from_data(bootstrap.ledger, SEED, _credits, _progress)
	if (
		_paid == null
		or not ClubCareer.same(_paid.to_data(), bootstrap.ledger)
		or _paid.to_data().version != 43
	):
		return _setup_error("bootstrap exact ledger43 cold journal did not replay")
	if (
		bootstrap.paid_copy_ids.size() != 2
		or not SeasonOwnership._keys(
			bootstrap.inherited_paid_copies, ["ST-048", "ST-038", "ST-076"]
		)
	):
		return _setup_error("bootstrap exact two-apple or inherited paid identity set differs")
	return await _apple_retirement_cold_checks(
		directory, expected_sha256, setup_started, bootstrap, evidence
	)


func _apple_retirement_cold_checks(
	directory: String, expected_sha256: String, setup_started: int, bootstrap: Dictionary,
	evidence: Dictionary
) -> Dictionary:
	for value: Variant in bootstrap.paid_copy_ids:
		if not value is String:
			return _setup_error("bootstrap paid apple identity is not a string")
	_copies.assign(bootstrap.paid_copy_ids)
	_inherited = bootstrap.inherited_paid_copies.duplicate(true)
	_empty = bootstrap.empty_layout.duplicate(true)
	_layout = bootstrap.layout.duplicate(true)
	_snapshot = bootstrap.snapshot.duplicate(true)
	var checked: Dictionary = StadiumHomeLayout.validate(_layout, _paid.construction(), "mogul")
	var empty_checked: Dictionary = StadiumHomeLayout.validate(
		_empty, _paid.construction(), "mogul"
	)
	if (
		_copies[0] == _copies[1]
		or _paid.construction().copies.size() != 8
		or _paid.view().land != "mogul"
		or not checked.ok
		or not empty_checked.ok
		or not ClubCareer.same(_paid.view().stadium_active, _layout)
		or not ClubCareer.same(StadiumLayoutSnapshot.capture(_paid), _snapshot)
		or not StadiumLayoutSnapshot.matches(_snapshot, _paid)
		or not ClubCareer.same(_layout.get("rising_apple"), [{"copy": _copies[0], "site": SITE}])
		or not checked.stored.has(_copies[1])
		or not ClubCareer.same(StadiumRisingAppleItems.store_copy(_layout, _copies[0]), _empty)
	):
		return _setup_error(
			"bootstrap layout snapshot stored copy or complete fixed placement differs after cold replay"
		)
	for copy: String in _copies:
		if not ClubCareer.same(
			_paid.construction().copies.get(copy),
			{"item": ITEM, "paid": 240, "source": "purchase-v1"}
		):
			return _setup_error("bootstrap apple copy is not an exact independently paid receipt")
	for item: String in _inherited:
		if (
			not _inherited[item] is String
			or not ClubCareer.same(
				_paid.construction().copies.get(_inherited[item]),
				{
					"item": item,
					"paid": StadiumCatalog.item(item).copy_price,
					"source": "purchase-v1"
				}
			)
		):
			return _setup_error("bootstrap inherited copy is not the exact paid receipt")
	if (
		not ClubCareer.same(evidence.get("layout"), _layout)
		or not ClubCareer.same(evidence.get("snapshot"), _snapshot)
		or not ClubCareer.same(evidence.get("paid_copy_ids"), _copies)
		or not ClubCareer.same(evidence.get("inherited_paid_copies"), _inherited)
		or not ClubCareer.same(evidence.get("paid_inventory"), _paid.construction().to_data())
	):
		return _setup_error(
			"bootstrap authority differs from the hashed successful phase 1 evidence"
		)
	_time_phase("bootstrap_validation", setup_started)
	var started: int = Time.get_ticks_usec()
	await _tamper_cases()
	_time_phase("retirement", started)
	_time_phase("total_before_evidence", _run_started_us)
	return _apple_retirement_runtime_checks(directory, expected_sha256, bootstrap)


func _apple_retirement_runtime_checks(
	directory: String, expected_sha256: String, bootstrap: Dictionary
) -> Dictionary:
	if _checks != PHASE2_CHECKS or _runtime.get("tamper_cases", []).size() != 13:
		return _setup_error(
			(
				"phase 2 did not execute exactly thirteen three-check retirement cases including "
				+ "unauthorized moving visibility"
			)
		)
	var payload: Dictionary = {
		"kind": "rising-apple-retirement",
		"execution_phase": 2,
		"checks": _checks,
		"expected_checks": PHASE2_CHECKS,
		"executed_checks": _checks,
		"carried_checks": PHASE1_CHECKS,
		"cumulative_checks": PHASE1_CHECKS + _checks,
		"union_expected_checks": UNION_CHECKS,
		"failures": _failures,
		"bootstrap_sha256": expected_sha256,
		"carried_phase1_sha256": bootstrap.phase1_evidence_sha256,
		"source_context": bootstrap.source_context,
		"producer_source_context_version": bootstrap.version,
		"executor_source_context_version": 2,
		"executor_source_context": _source_context(),
		"images": [],
		"games": 0,
		"synthetic_funding": true,
		"synthetic_progression": true,
		"earned_career_claim": false,
		"cold_bootstrap_validated": true,
		"tamper_cases": _runtime.tamper_cases,
		"phase_timings_ms": _phase_timings_ms,
		"lab_setup_timings": _lab_setup_timings
	}
	if not _write_bounded(directory.path_join("rising-apple-retirement.json"), payload):
		return _setup_error("phase 2 retirement evidence could not fully write within 128 KiB")
	print(
		(
			(
				"RISING_APPLE_RETIREMENT phase=2 executed_checks=%d carried_checks=267 "
				+ "cumulative_checks=%d union_expected_checks=306 failures=%d images=0 games=0"
			)
			% [_checks, PHASE1_CHECKS + _checks, _failures]
		)
	)
	return {"checks": _checks, "failures": _failures}


func _project_rect(camera: Camera3D, box: AABB) -> Rect2:
	var rect: Rect2 = Rect2()
	var started: bool = false
	for index in range(8):
		var point: Vector3 = box.get_endpoint(index)
		if camera.is_position_behind(point):
			continue
		var pixel: Vector2 = camera.unproject_position(point)
		if not started:
			rect = Rect2(pixel, Vector2.ZERO)
			started = true
		else:
			rect = rect.expand(pixel)
	return rect


func _in_frame(camera: Camera3D, box: AABB) -> bool:
	var readable: Rect2 = Rect2(12, 110, 1256, 565)
	for index in range(8):
		var point: Vector3 = box.get_endpoint(index)
		if (
			camera.is_position_behind(point)
			or not readable.has_point(camera.unproject_position(point))
		):
			_operands = {
				"corner": _v3(point),
				"pixel": str(camera.unproject_position(point)),
				"readable": str(readable)
			}
			return false
	return true


func _rect(value: Rect2) -> Array:
	return [value.position.x, value.position.y, value.size.x, value.size.y]


func _v3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _progression() -> void:
	_phase = "validated-v1-v2-closed-homer-source"
	var season: SeasonState = SeasonState.create(SEED, false, true, true)
	season.career = ClubCareer.new()
	_check(
		season.career.start(season), "synthetic source season begins through ordinary career API"
	)
	for pick in range(4):
		season.choose_player(season.offers()[0])
	for homers: int in [2, 3]:
		var fixture: Dictionary = season.pending_fixture()
		var roster: Array = season.teams[fixture.away].roster + season.teams[fixture.home].roster
		var stats: Dictionary = {}
		for id: String in roster:
			stats[id] = MatchPerformance.empty_line()
		var ours: String = season.teams[0].roster[0]
		var enemy: String = (
			season.teams[fixture.away if fixture.home == 0 else fixture.home].roster[0]
		)
		stats[ours].h = homers
		stats[ours].hr = homers
		stats[ours].pa = homers
		stats[enemy].p_h = homers
		_check(
			(
				SeasonPerformance.valid(stats, roster)
				and season.record_player_result(
					fixture.id,
					0 if fixture.home == 0 else homers,
					homers if fixture.home == 0 else 0,
					stats
				)
			),
			(
				"balanced disclosed synthetic home runs enter one real scheduled-result source "
				+ str(homers)
			)
		)
	var proof: Dictionary = ClubSeasonRecord.capture(season)
	var legacy: Dictionary = ClubPlayerProgress.capture(season)
	var current: Dictionary = ClubPlayerProgress.capture_with_hits(season)
	_check(
		(
			not ClubSeasonRecord.analyze(proof).is_empty()
			and ClubPlayerProgress.valid(legacy, proof.scores)
			and ClubPlayerProgress.valid(current, proof.scores)
			and legacy.games.size() == 2
			and current.games.size() == 2
		),
		"actual captured v1 and v2 evidence validate against the same scheduled score proof"
	)
	var career: ClubCareer = ClubCareer.new()
	for details: Dictionary in [legacy, current]:
		career.runs = [{"status": "abandoned", "proof": proof, "player_progress": details}]
		var rows: Array = StadiumCareerProgress.capture(career)
		_check(
			(
				rows.size() == 1
				and rows[0].get("homers", -1) == 5
				and rows[0].seasons == 0
				and StadiumCareerProgress.metrics(rows, 1).get("homers", -1) == 5
				and StadiumCareerProgress.valid(rows, [0])
			),
			(
				"validated closed v"
				+ str(details.version)
				+ " aggregates genuine source home runs once without inventing a completed season"
			)
		)
		_progress_cases.append(
			{
				"case": "validated-v" + str(details.version),
				"source_game_homers": [2, 3],
				"aggregated_homers": rows[0].get("homers", -1) if rows.size() == 1 else -1,
				"proof_valid": ClubPlayerProgress.valid(details, proof.scores),
				"synthetic_source": true
			}
		)
	career.runs = [{"status": "active", "proof": proof, "player_progress": current}]
	_check(
		StadiumCareerProgress.capture(career).is_empty(),
		"unfinished current season cannot leak home runs into a closed purchase prefix"
	)
	career.runs[0].status = "abandoned"
	career.runs[0].player_progress = null
	var unknown: Array = StadiumCareerProgress.capture(career)
	_check(
		unknown.size() == 1 and not unknown[0].has("homers"),
		"missing historical detail invents no home-run field"
	)
	var partial: Dictionary = current.duplicate(true)
	partial.games[1].stats = null
	career.runs[0].player_progress = partial
	var retained: Array = StadiumCareerProgress.capture(career)
	_check(
		(
			ClubPlayerProgress.valid(partial, proof.scores)
			and retained.size() == 1
			and retained[0].get("homers", -1) == 2
		),
		"null game statistics preserve only independently evidenced earlier home runs"
	)
	for value: Variant in [true, -1, "2", 10000]:
		var bad: Dictionary = current.duplicate(true)
		bad.games[0].stats.homers = value
		career.runs[0].player_progress = bad
		_check(
			(
				not ClubPlayerProgress.valid(bad, proof.scores)
				and StadiumCareerProgress.capture(career).is_empty()
			),
			"invalid homer source fails closed " + str(value)
		)
	for value: Variant in [true, -1, "40", 120000]:
		_check(
			not StadiumCareerProgress.valid([{"seasons": 1, "wins": 1, "homers": value}], [1000]),
			"malformed or unbounded closed homer metric refuses " + str(value)
		)
	_check(
		(
			StadiumCareerProgress.valid([{"seasons": 1, "wins": 1}], [1000])
			and not StadiumCareerProgress.metrics([{"seasons": 1, "wins": 1}], 1).has("homers")
		),
		"exact historical no-homer rows retain their original grammar"
	)
	var old_credits: Array = []
	var old_progress: Array = []
	var enriched_progress: Array = []
	for index in range(20):
		old_credits.append(1000)
		old_progress.append({"seasons": 1, "wins": 5})
		enriched_progress.append({"seasons": 1, "wins": 5, "homers": 2})
	var old_paid: ClubAssetLedger = ClubAssetLedger.new_club(SEED, old_credits, old_progress)
	var old_buy: Dictionary = old_paid.commit(
		{
			"id": "apple-old-proof",
			"rev": old_paid.revision(),
			"op": "stadium_buy",
			"item": "ST-038",
			"quantity": 1,
			"price_version": StadiumFloodlightOwnedItems.PRICE_VERSION,
			"through": 20,
			"progress_through": 20
		}
	)
	_check(
		old_buy.ok,
		"actual earlier-price paid command accepts its historical no-homer source prefix"
	)
	var enriched_cold: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(old_paid.to_data())), SEED, old_credits, enriched_progress
	)
	_check(
		enriched_cold != null and ClubCareer.same(enriched_cold.to_data(), old_paid.to_data()),
		"newly enriched homer capture replays an exact earlier-price paid journal without migration"
	)


func _installed_lab(root: Node3D, label: String) -> PitchBatLab:
	var setup_started: int = Time.get_ticks_usec()
	var lab: PitchBatLab = PitchBatLab.new()
	root.add_child(lab)
	var ready_finished: int = Time.get_ticks_usec()
	lab.process_mode = Node.PROCESS_MODE_PAUSABLE
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	PitchBatLabPresentation.hide_match_presentation(lab)
	lab._status_label.visible = false
	lab._match_state.stadium = _snapshot.duplicate(true)
	lab._stadium_ledger = _paid
	var install_started: int = Time.get_ticks_usec()
	var installed: bool = StadiumPropertyRuntime.install_bound(lab)
	var install_finished: int = Time.get_ticks_usec()
	_lab_setup_timings.append(
		{
			"case": label,
			"ready_ms": (ready_finished - setup_started) / 1000.0,
			"install_ms": (install_finished - install_started) / 1000.0,
			"total_ms": (install_finished - setup_started) / 1000.0
		}
	)
	_check(
		installed and StadiumRisingAppleRuntime.current(lab) != null,
		"ordinary frozen exact paid snapshot installs the one registered apple runtime"
	)
	return lab


func _tamper_cases() -> void:
	_phase = "independent-foreign-mutation-fail-closed"
	var cases: Array[Dictionary] = []
	for kind: String in [
		"root-transform",
		"moving-transform",
		"moving-visible",
		"mesh-resource",
		"material-resource",
		"collision-resource",
		"owned-copy",
		"moving-reparent",
		"resolver-listener",
		"match-state",
		"controller-detach",
		"scorer-deferred",
		"scorer-reordered"
	]:
		var root: Node3D = _world()
		var lab: PitchBatLab = _installed_lab(root, kind)
		lab.set_process(false)
		lab.set_physics_process(false)
		var controller: StadiumRisingAppleRuntime = StadiumRisingAppleRuntime.current(lab)
		if controller == null:
			await _close_view()
			continue
		var property: StadiumPropertyGeometry = lab.get_meta("stadium_property")
		var model: Node3D = property.objects[_copies[0]]
		var moving: Node3D = model.get_node("RisingAssembly")
		var mesh: MeshInstance3D = moving.get_node("Visual").get_child(0) as MeshInstance3D
		var shape: CollisionShape3D = (
			moving.get_node("Collision").get_child(0).get_child(0) as CollisionShape3D
		)
		_check(
			(
				controller.intact()
				and controller.accepted_events == 0
				and is_zero_approx(controller.height())
			),
			"fresh independent ordinary authority precedes foreign mutation " + kind
		)
		match kind:
			"root-transform":
				model.position.x += 0.25
			"moving-transform":
				moving.position.y = 0.5
			"moving-visible":
				moving.visible = true
			"mesh-resource":
				mesh.mesh = mesh.mesh.duplicate(true)
			"material-resource":
				mesh.material_override = StandardMaterial3D.new()
			"collision-resource":
				shape.shape = shape.shape.duplicate(true)
			"owned-copy":
				model.set_meta("owned_copy", "purchase:foreign:0")
			"moving-reparent":
				moving.reparent(root)
			"resolver-listener":
				lab._ball_play_resolver.play_resolved.disconnect(controller._on_resolved)
			"match-state":
				lab._match_state = null
			"controller-detach":
				property.remove_child(controller)
			"scorer-deferred":
				lab._ball_play_resolver.play_resolved.disconnect(lab._on_ball_play_resolved)
				lab._ball_play_resolver.play_resolved.connect(
					lab._on_ball_play_resolved, Object.CONNECT_DEFERRED
				)
			"scorer-reordered":
				lab._ball_play_resolver.play_resolved.disconnect(lab._on_ball_play_resolved)
				lab._ball_play_resolver.play_resolved.connect(lab._on_ball_play_resolved)
		var root_pose: Transform3D = model.transform
		var moving_pose: Transform3D = moving.transform
		var moving_visible: bool = moving.visible
		var mesh_id: int = mesh.mesh.get_instance_id()
		var material: Material = mesh.material_override
		var shape_id: int = shape.shape.get_instance_id()
		var copy: String = model.get_meta("owned_copy", "")
		controller._sync(lab._home_run)
		var unchanged: bool = (
			model.transform == root_pose
			and moving.transform == moving_pose
			and moving.visible == moving_visible
			and mesh.mesh.get_instance_id() == mesh_id
			and mesh.material_override == material
			and shape.shape.get_instance_id() == shape_id
			and model.get_meta("owned_copy", "") == copy
		)
		_check(
			(
				controller.phase == StadiumRisingAppleRuntime.Phase.RETIRED
				and not controller.intact()
				and controller.accepted_events == 0
				and unchanged
			),
			(
				"foreign pose resource copy or lifecycle mutation retires without overwriting foreign state "
				+ kind
			)
		)
		cases.append(
			{
				"case": kind,
				"fresh_authority": true,
				"retired": controller.phase == StadiumRisingAppleRuntime.Phase.RETIRED,
				"foreign_state_unchanged": unchanged,
				"accepted_events": controller.accepted_events,
				"actual_height": moving.position.y,
				"moving_visible": moving.visible
			}
		)
		if controller.get_parent() == null:
			controller.free()
		# Finish native sky uploads while this same-frame retirement lab still exists.
		await RenderingServer.frame_post_draw
		await _close_view()
	_runtime.tamper_cases = cases


func _reset_concealed(model: Node3D) -> bool:
	var moving: Node3D = model.get_node("RisingAssembly")
	if moving.visible or moving.position.y != 0.0:
		return false
	var meshes: Array[Node] = moving.find_children("*", "MeshInstance3D", true, false)
	if meshes.size() != 10:
		return false
	for mesh: MeshInstance3D in meshes:
		# Inspect the actual tree flags; explicit ordinary and overhead captures are recorded separately.
		if not mesh.visible or mesh.is_visible_in_tree():
			return false
	return true


func _retained_apple_hulls(model: Node3D) -> bool:
	var collision: Node3D = model.get_node("RisingAssembly/Collision")
	if collision.get_child_count() != 10:
		return false
	for body: StaticBody3D in collision.get_children():
		if (
			body.collision_layer != 1
			or body.collision_mask != 2
			or body.get_child_count() != 1
			or body.get_meta("surface_role", "") != "DECORATIVE_AFTER_TERMINAL"
		):
			return false
		var shape: CollisionShape3D = body.get_child(0) as CollisionShape3D
		if (
			shape == null
			or shape.disabled
			or not shape.shape is ConvexPolygonShape3D
			or shape.shape.margin != 0.0
		):
			return false
	return true


func _apple_capture_lighting(root: Node3D) -> Dictionary:
	var lights: Array[Node] = root.find_children("*", "DirectionalLight3D", true, false)
	var environments: Array[Node] = root.find_children("*", "WorldEnvironment", true, false)
	var sun: DirectionalLight3D = lights[0] as DirectionalLight3D if lights.size() == 1 else null
	var world: WorldEnvironment = (
		environments[0] as WorldEnvironment if environments.size() == 1 else null
	)
	return {
		"directional_lights": lights.size(),
		"world_environments": environments.size(),
		"sun_name": str(sun.name) if sun != null else "",
		"sun_energy": sun.light_energy if sun != null else -1.0,
		"environment_name": str(world.name) if world != null else "",
		"ambient_energy": world.environment.ambient_light_energy if world != null else -1.0,
		"tonemap_mode": world.environment.tonemap_mode if world != null else -1,
		"tonemap_exposure": world.environment.tonemap_exposure if world != null else -1.0,
		"studio_light_added": false,
		"heading_backing_rect": [10, 10, 1260, 94]
	}


func _apple_lighting_exact(lighting: Dictionary) -> bool:
	return (
		lighting.directional_lights == 1
		and lighting.world_environments == 1
		and lighting.sun_name == "Sun"
		and lighting.environment_name == "LabWorldEnvironment"
	)


func _apple_capture_heading(root: Node3D, title: String, subtitle: String) -> Control:
	var heading: ColorRect = ColorRect.new()
	heading.position = Vector2(10, 10)
	heading.size = Vector2(1260, 94)
	heading.color = Color(0.06, 0.10, 0.13, 0.94)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(heading)
	_label(heading, title, Vector2(12, 8), 22)
	_label(heading, subtitle, Vector2(12, 40), 16)
	_label(
		heading,
		(
			"Working scenery | synthetic funding and progression | no CO4 grant, completed game or "
			+ "final-art claim"
		),
		Vector2(12, 67),
		16
	)
	return heading


func _apple_capture_view(
	filename: String,
	camera: Camera3D,
	model: Node3D,
	controller: StadiumRisingAppleRuntime,
	property: StadiumPropertyGeometry
) -> Dictionary:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	# Image and evidence are sampled together from this actual completed render.
	var image: Image = _view.get_texture().get_image()
	var moving: Node3D = model.get_node("RisingAssembly")
	var mesh_visibility: Array[Dictionary] = []
	var hidden: int = 0
	for raw_mesh: Node in moving.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = raw_mesh as MeshInstance3D
		var visible_in_tree: bool = mesh.is_visible_in_tree()
		if not visible_in_tree:
			hidden += 1
		mesh_visibility.append(
			{
				"path": str(model.get_path_to(mesh)),
				"own_visible": mesh.visible,
				"visible_in_tree": visible_in_tree
			}
		)
	var reserve: AABB = StadiumRisingAppleItems.bounds(
		StadiumRisingAppleItems.row(_copies[0], ITEM, SITE)
	)
	var model_bounds: AABB = model.global_transform * StadiumRisingAppleModels.swept_bounds()
	var forward: Vector3 = -camera.global_basis.z
	var directly_overhead: bool = (
		camera.global_position.x == model.global_position.x
		and camera.global_position.z == model.global_position.z
		and camera.global_position.y > reserve.end.y
		and forward.is_equal_approx(Vector3.DOWN)
	)
	var record: Dictionary = {
		"image": filename,
		"process_frame": Engine.get_process_frames(),
		"physics_frame": Engine.get_physics_frames(),
		"rendered_frame": Engine.get_frames_drawn(),
		"viewport_size": [image.get_width(), image.get_height()],
		"camera_eye": _v3(camera.global_position),
		"camera_forward": _v3(forward),
		"camera_up": _v3(camera.global_basis.y),
		"camera_projection": int(camera.projection),
		"camera_size": camera.size,
		"camera_current": camera.is_current(),
		"directly_overhead": directly_overhead,
		"reservation_position": _v3(reserve.position),
		"reservation_size": _v3(reserve.size),
		"reservation_projected_rect": _rect(_project_rect(camera, reserve)),
		"whole_reservation_in_frame": _in_frame(camera, reserve),
		"model_bounds_position": _v3(model_bounds.position),
		"model_bounds_size": _v3(model_bounds.size),
		"model_projected_rect": _rect(_project_rect(camera, model_bounds)),
		"whole_model_in_frame": _in_frame(camera, model_bounds),
		"height": controller.height(),
		"accepted_events": controller.accepted_events,
		"moving_visible": moving.visible,
		"moving_visible_in_tree": moving.is_visible_in_tree(),
		"moving_mesh_count": mesh_visibility.size(),
		"hidden_moving_mesh_count": hidden,
		"mesh_visibility": mesh_visibility,
		"reset_concealed": _reset_concealed(model),
		"owned_guard_intact": controller.intact() and property.props_intact(),
		"retained_collision_exact": _retained_apple_hulls(model),
		"scene_tree_paused": get_tree().paused
	}
	_check(
		not image.is_empty() and image.get_size() == SIZE, "exact native image 1280x720 " + filename
	)
	if not image.is_empty():
		_check(
			image.save_png(_capture_dir.path_join(filename)) == OK,
			"original native PNG saved " + filename
		)
		_images.append(filename)
	return record
