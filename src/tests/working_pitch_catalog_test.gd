extends Node
## Finite native acceptance for authored recipes, not a season/release qualification.

const FrozenSolver = preload("res://src/tests/fixtures/pitches/pitch_flight_solver_20261110.gd")
const TARGET: Vector3 = Vector3(0, 1.05, 0)
var _failures: Array[String] = []
var _metrics: Dictionary = {}
var _context: String = "inventory"


func _ready() -> void:
	_test_inventory()
	_test_delivery_poses()
	var ball: BallSetupDefinition = ContentDB.get_ball_setup(&"ball_setup.fresh")
	for recipe: PitchDefinition in WorkingPitchCatalog.conventional_recipes():
		_test_recipe(recipe, ball)
	_test_identity_relations()
	_test_command_and_ai(ball)
	var report: Dictionary = {
		"catalog_version": WorkingPitchCatalog.VERSION,
		"catalog_signature": WorkingPitchCatalog.signature(),
		"status": "passed" if _failures.is_empty() else "failed",
		"failures": _failures,
		"recipes": _metrics,
		"scope": "Finite native recipe acceptance; no visual, paid-season or release claim."
	}
	var file: FileAccess = FileAccess.open(
		"user://working_pitch_catalog_v1_native.json", FileAccess.WRITE)
	_check(file != null, "native evidence must be writable in the isolated user directory")
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	if _failures.is_empty():
		print("Working pitch catalog checks passed: 38 recipes, exact legacy oracle, bounded identities.")
	get_tree().quit(0 if _failures.is_empty() else 1)


func _test_delivery_poses() -> void:
	for id: String in ["pitch.three_quarter_four_seam", "pitch.submarine_riser"]:
		var recipe: PitchDefinition = WorkingPitchCatalog.get_recipe(id)
		for left: bool in [false, true]:
			_context = "%s left=%s delivery pose" % [id, left]
			var avatar: PlayerAvatar = PlayerAvatar.new()
			add_child(avatar)
			avatar.configure(PlayerAvatar.Role.PITCHER, false, left, Color.WHITE)
			avatar.position = PitchBatLab.MOUND_ORIGIN
			var release: Vector3 = recipe.delivery_profile.release_offset_pitcher_frame_m
			var world: Vector3 = PitchBatLab.MOUND_ORIGIN + CoordinateFrame.pitcher_frame_vector(
				release.x, release.y, release.z, left)
			avatar.set_pitch_profile_progress(1.0, recipe.delivery_profile, world)
			_check(avatar._throw_hand.global_position.distance_to(world) < 0.00001,
				"new slot's visible release matches authored geometry")
			avatar.free()


func _test_inventory() -> void:
	_check(WorkingPitchCatalog.conventional_recipes().size() == 38, "exact candidate count")
	_check(WorkingPitchCatalog.new_ids().size() == 32, "exact additive count")
	_check(WorkingPitchCatalog.ids().size() == 41, "41 active recipes")
	_check(WorkingPitchCatalog.known_ids().size() == 44, "44 retained historical IDs")
	for old_id: String in WorkingPitchCatalog.RETIRED_ALIASES:
		var exact: PitchDefinition = WorkingPitchCatalog.historical_recipe(old_id)
		_check(exact != null and String(exact.id) == old_id, "history retains exact retired ID")
		_check(not WorkingPitchCatalog.is_active(old_id), "retired ID never active")
		_check(WorkingExoticAccess.price(old_id) < 0, "retired ID has no new lesson")
		var selected: PitchDefinition = WorkingPitchCatalog.selection_recipe(old_id)
		_check(selected != null and String(selected.id) == WorkingPitchCatalog.canonical_id(old_id),
			"explicit selection alias resolves without rewriting history")
	for id: String in WorkingPitchCatalog.HISTORICAL_CANONICAL_PATHS:
		_check(WorkingPitchCatalog.historical_recipe(id).display_name.begins_with("Overhand "),
			"exact original canonical definition is retained")
		_check(not WorkingPitchCatalog.get_recipe(id).display_name.begins_with("Overhand "),
			"active Exotic uses its unique name")
	var families: Dictionary = {}
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://docs/pitches/authored_recipe_index.json"))
	for row: Dictionary in index.recipes:
		_context = String(row.id)
		if row.get("source_kind") == "project_fiction":
			continue
		var recipe: PitchDefinition = WorkingPitchCatalog.get_recipe(row.id)
		_check(recipe != null, "indexed recipe exists: " + row.id)
		if recipe == null:
			continue
		if not families.has(row.offering):
			families[row.offering] = {}
		families[row.offering][recipe.delivery_profile.id] = true
		if row.new:
			_check(recipe.design_status == "Working design", "visible Working provenance")
			_check(not recipe.source_urls.is_empty(), "sourced identity")
			_check(ContentDB.get_pitch(recipe.id) == null, "candidate cannot silently widen old ContentDB")
	for offering: String in families:
		_context = offering
		_check(families[offering].size() == 2,
			"retained ordinary slots have distinct actual release profiles")
	var hashes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://docs/pitches/legacy_content_sha256.json"))
	for path: String in hashes:
		_check(FileAccess.get_sha256("res://" + path) == hashes[path], "historical bytes: " + path)
	_check(WorkingPitchCatalog.resolve_alias("Banana Ball") == "pitch.sidearm_slurve", "Banana alias")
	_check(ContentDB.get_pitch(&"pitch.switchback") == null,
		"candidate Exotic cannot leak to old ContentDB")


func _test_recipe(recipe: PitchDefinition, ball: BallSetupDefinition) -> void:
	_context = String(recipe.id)
	var right: PitchLaunchParameters = PitchAimSolver.solve(
		recipe, ball, PitchBatLab.MOUND_ORIGIN, TARGET, false, 41)
	var left: PitchLaunchParameters = PitchAimSolver.solve(
		recipe, ball, PitchBatLab.MOUND_ORIGIN, TARGET, true, 41)
	_check(right != null and left != null, "center aim reaches: " + String(recipe.id))
	if right == null or left == null:
		return
	var r: Dictionary = _measure(right)
	var l: Dictionary = _measure(left)
	_check(r.crossed and l.crossed, "both hands cross plate")
	if not r.crossed or not l.crossed:
		return
	_check(Vector3(r.point[0], r.point[1], r.point[2]).distance_to(TARGET) <= 0.0125,
		"center target tolerance")
	_check(absf(r.point[0] + l.point[0]) < 0.002 and absf(r.point[1] - l.point[1]) < 0.002,
		"mirrored plate crossing")
	_check(absf(r.arrival - l.arrival) < 0.00001, "same hand-mirrored timing")
	_metrics[String(recipe.id)] = r
	var mastered: PitchDefinition = WorkingPitchCatalog.mastered(String(recipe.id), 5)
	_check(mastered != null and mastered.mastery_level == 5, "mastery exact recipe support")
	if mastered != null:
		_check(mastered.id == recipe.id and recipe.mastery_level == 1,
			"mastery cannot mutate authored IDs")
		_metrics[String(recipe.id)]["mastery_level5"] = {}
		for is_left: bool in [false, true]:
			_context = "%s level=5 left=%s" % [recipe.id, is_left]
			var launch: PitchLaunchParameters = PitchAimSolver.solve(
				mastered, ball, PitchBatLab.MOUND_ORIGIN, TARGET, is_left, 41)
			_check(launch != null, "level5 recipe remains reachable")
			_metrics[String(recipe.id)]["mastery_level5"][str(is_left)] = (
				_measure(launch) if launch != null else {"crossed": false})
	_context = String(recipe.id)
	if WorkingPitchCatalog.LEGACY_PRICES.has(String(recipe.id)):
		_exact_legacy_trace(right)
		_exact_legacy_trace(left)


func _measure(parameters: PitchLaunchParameters) -> Dictionary:
	var actual: PitchCrossingResult = PitchTrajectorySimulator.simulate_to_plane(parameters, 0)
	if not actual.crossed:
		return {"crossed": false}
	var neutral: PitchLaunchParameters = parameters.copy()
	neutral.magnus_scale = 0
	neutral.perforation_force_scale = 0
	neutral.instability_strength = 0
	var baseline: PitchCrossingResult = PitchTrajectorySimulator.simulate_to_plane(neutral, 0)
	_check(baseline.crossed, "paired neutral flight crosses")
	var delta: Vector3 = actual.point - baseline.point
	var state: PitchState = _state(parameters)
	var apex: float = state.position.y
	var trace: Array = []
	for step: int in range(720):
		PitchFlightSolver.step(state, parameters)
		apex = maxf(apex, state.position.y)
		if step % 8 == 0 or state.position.z <= 0:
			trace.append([state.elapsed_time, state.position.x, state.position.y, state.position.z,
				state.velocity.x, state.velocity.y, state.velocity.z])
		if state.position.z <= 0:
			break
	return {
		"crossed": true, "arrival": actual.elapsed_seconds, "apex": apex,
		"point": [actual.point.x, actual.point.y, actual.point.z],
		"movement": [delta.x, delta.y, delta.z], "trace": trace
	}


func _exact_legacy_trace(parameters: PitchLaunchParameters) -> void:
	var current: PitchState = _state(parameters)
	var frozen: PitchState = _state(parameters)
	for _step: int in range(720):
		PitchFlightSolver.step(current, parameters)
		FrozenSolver.step(frozen, parameters)
		_check(current.position == frozen.position and current.velocity == frozen.velocity
			and current.orientation == frozen.orientation,
			"EXACT old solver equality: " + String(parameters.pitch_id))
		if current.position.z <= 0:
			break


func _test_identity_relations() -> void:
	if _metrics.size() != 38:
		return
	for slot: String in ["overhand", "sidearm"]:
		_context = slot + " two_seam/sinker"
		var two: Dictionary = _metric(slot + "_two_seam")
		var sink: Dictionary = _metric(slot + "_sinker")
		_check(two.movement[0] > 0 and sink.movement[1] < two.movement[1], "run versus sink: " + slot)
	for slot: String in ["overhand", "three_quarter"]:
		_context = slot + " curveball/slow_curve/forkball/splitter vs pitch.eephus"
		var curve: Dictionary = _metric(slot + "_curveball")
		var slow: Dictionary = _metric(slot + "_slow_curve")
		var eephus: Dictionary = _metric("eephus")
		var split: Dictionary = _metric(slot + "_splitter")
		var fork: Dictionary = _metric(slot + "_forkball")
		_check(curve.arrival < slow.arrival and slow.arrival < eephus.arrival, "curve tempo order")
		_check(curve.apex < eephus.apex and slow.apex < eephus.apex, "Eephus highest arc")
		_check(curve.movement[1] < 0 and slow.movement[1] < 0, "spin-driven downward curve identity")
		_check(fork.arrival > split.arrival and fork.movement[1] < split.movement[1], "fork versus split")
	_check(_metric("sidearm_sweeper").movement[0] < _metric("sidearm_slider").movement[0] - 0.25,
		"Sweeper broader than existing Sidearm Slider")
	_check(_metric("sidearm_sweeper").arrival > _metric("sidearm_slider").arrival, "Sweeper slower")
	_check(_metric("submarine_riser").movement[1] > 0.5, "Submarine Riser actual aerodynamic rise")
	for id: String in ["pitch.sidearm_slide_drop", "pitch.submarine_slide_drop"]:
		_context = id
		var recipe: PitchDefinition = WorkingPitchCatalog.get_recipe(id)
		var p: PitchLaunchParameters = PitchLaunchBuilder.build_nominal(recipe,
			ContentDB.get_ball_setup(&"ball_setup.fresh"), PitchBatLab.MOUND_ORIGIN, TARGET, false, 41)
		var early: Vector2 = PitchFlightSolver.axis_movement_weight(p.release_z * 0.75, p)
		var late: Vector2 = PitchFlightSolver.axis_movement_weight(p.release_z * 0.15, p)
		_check(early.x > early.y * 5 and late.y > early.y * 5, "Slide-Drop stages lateral then dip")


func _test_command_and_ai(ball: BallSetupDefinition) -> void:
	var ids: Array[String] = ["pitch.three_quarter_four_seam", "pitch.overhand_splitter",
		"pitch.sidearm_knuckleball", "pitch.submarine_slide_drop"]
	var options: Array[PitchDefinition] = []
	for id: String in ids:
		_context = id
		var recipe: PitchDefinition = WorkingPitchCatalog.mastered(id, 1)
		options.append(recipe)
		var launch: PitchLaunchParameters = PitchAimSolver.solve(
			recipe, ball, PitchBatLab.MOUND_ORIGIN, TARGET, false, 41)
		if launch == null:
			continue
		var points: Array = []
		for seed_value: int in [17, 31, 53, 79, 101, 137, 173, 211]:
			_context = "%s command seed=%d" % [id, seed_value]
			var executed: PitchLaunchParameters = PitchExecutionModel.apply(launch, 0.85, 0.3,
				recipe.control_difficulty, recipe.execution_difficulty, recipe.category, seed_value)
			var crossing: PitchCrossingResult = PitchTrajectorySimulator.simulate_to_plane(executed, 0)
			_check(crossing.crossed, "bounded command fixture reaches plate")
			points.append([crossing.point.x, crossing.point.y])
		_check(points[0] != points[1], "command spread remains nonzero")
		_metrics[id]["command_samples"] = points
	var pitcher: PlayerDefinition = ContentDB.get_player(&"player.casey_rivers")
	for seed_value: int in [7, 19, 41, 73]:
		var choice: Dictionary = PitchingStrategy.choose(
			options, pitcher, 1, 2, 0, seed_value, 0.7, false)
		_check(choice.pitch_index >= 0 and choice.pitch_index < options.size(),
			"AI selects candidate options")


func _metric(id: String) -> Dictionary:
	return _metrics["pitch." + id]


static func _state(parameters: PitchLaunchParameters) -> PitchState:
	var state: PitchState = PitchState.new()
	state.position = parameters.position
	state.velocity = parameters.velocity
	state.orientation = parameters.orientation
	state.angular_velocity = parameters.angular_velocity
	state.pitch_id = parameters.pitch_id
	state.seed = parameters.seed
	return state


func _check(condition: bool, message: String) -> void:
	message = _context + ": " + message
	if not condition:
		_failures.append(message)
		if _failures.size() <= 20:
			push_error(message)
