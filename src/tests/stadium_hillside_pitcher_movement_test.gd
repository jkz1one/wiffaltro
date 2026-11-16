extends Node3D
## Actual marker movement only. Explicit targets do not qualify tracking or control.
# gdlint: disable=max-file-lines,max-line-length,max-returns

const FIELD: FieldDefinition = preload("res://src/content/fields/npc_venue_field.tres")
const LAB: Script = preload("res://src/labs/pitch_bat_lab/pitch_bat_lab.gd")
const REAL32_EPSILON: float = 0.00000011920928955078125
const RATES: Array[int] = [30, 60, 120]
var _checks: int = 0
var _failures: int = 0
var _route_count: int = 0
var _graph: StadiumRecipeBoundary


func _ready() -> void:
	_graph = StadiumRecipeBoundary.create("deeper_center")
	await _flat_cases()
	await _hill_cases()
	print("HILLSIDE_PITCHER_MOVEMENT checks=%d failures=%d" % [_checks, _failures])
	print("HILLSIDE_PITCHER_ROUTE_COUNT %d" % _route_count)
	get_tree().quit(0 if _failures == 0 else 1)


# Attach the exact production script after the empty host's ready notification.
# This suppresses only broad startup; every tested method and actor is real.
func _lab() -> PitchBatLab:
	var host: Node3D = Node3D.new()
	add_child(host)
	host.set_script(LAB)
	var lab: PitchBatLab = host as PitchBatLab
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.set_process_input(false)
	lab.set_process_unhandled_input(false)
	lab._match_mode = false
	lab._field_definition = FIELD.duplicate(true) as FieldDefinition
	lab._field_definition.shallow_center_available = true
	lab._field_definition.middle_center_available = true
	PitchBatLabPresentation.build_pitch_actor(lab)
	lab._pitch_actor.set_physics_process(false)
	PitchBatLabPresentation.build_defenders(lab)
	lab._primary_fielder.set_physics_process(false)
	lab._primary_fielder.stadium_boundary_clip = Callable(_graph, "clip")
	lab._ball_play_resolver = BallPlayResolver.new()
	lab._ball_play_resolver.start_play(lab._field_definition)
	lab._ball_play_resolver.state.dead = true
	lab._status_label = Label.new()
	lab.add_child(lab._status_label)
	lab._live_label = Label.new()
	lab.add_child(lab._live_label)
	return lab


func _ball(lab: PitchBatLab) -> void:
	if not is_instance_valid(lab._batted_ball):
		lab._batted_ball = BattedBallBody.new()
		lab._batted_ball.freeze = true
		lab.add_child(lab._batted_ball)
		lab._batted_ball.set_physics_process(false)
	lab._batted_ball.linear_velocity = Vector3(0, 0, 2)
	lab._batted_ball.global_position = Vector3(0, 0.1, 16)
	lab._ball_play_resolver.start_play(lab._field_definition)
	lab._ball_play_resolver.state.elapsed_seconds = 1.0
	lab._pitcher_attempted = false
	lab._primary_attempts = 0
	lab._fielding_cooldown_seconds = 0.0


func _bind(lab: PitchBatLab, terrain: Node3D, profile: String) -> bool:
	if not lab._primary_fielder.bind_hillside_motion(lab._field_definition, terrain, 4, profile):
		return false
	lab._primary_fielder.set_anchor(Vector3(-7, 0, 17))
	return lab.bind_hillside_pitcher_motion()


func _prepare(lab: PitchBatLab, row: Dictionary) -> void:
	lab._primary_fielder.stadium_obstacles.clear()
	lab._primary_fielder.reset_stadium_pool_routes()
	lab._primary_fielder.set_anchor(row.get("other", Vector3(-7, 0, 17)))
	if lab.hillside_pitcher_motion != null:
		lab.reset_hillside_pitcher()
	else:
		lab._pitcher_marker.position = lab.MOUND_ORIGIN
		lab._pitcher_marker.rotation = Vector3.ZERO
	var start: Vector3 = row.get("start", lab.MOUND_ORIGIN)
	if lab.hillside_pitcher_motion != null:
		start = StadiumHillsideTerrain.point(start.x, start.z, lab.hillside_pitcher_motion.profile)
	if start != lab.MOUND_ORIGIN:
		for preparation_step in range(3):
			if lab._pitcher_marker.global_position == start:
				break
			var flat: Vector3 = DefenderSpacing.step_around_mound(lab._pitcher_marker.global_position,
				start, lab._primary_fielder.global_position, 8.0)
			lab._pitcher_marker.global_position = StadiumPropertyRuntime.pitcher_step(lab, start, 8.0, flat)
	for obstacle: Dictionary in row.get("obstacles", []):
		lab._primary_fielder.stadium_obstacles.append(obstacle.duplicate(true))
	_ball(lab)
	lab.hillside_pitcher_target = row.get("target", Vector3(0, 0, 18))
	if lab.hillside_pitcher_motion != null and lab.hillside_pitcher_target.is_finite():
		lab.hillside_pitcher_target = StadiumHillsideTerrain.point(lab.hillside_pitcher_target.x,
			lab.hillside_pitcher_target.z, lab.hillside_pitcher_motion.profile)
	lab._pitcher_attempted = row.get("attempted", false)
	lab._ball_play_resolver.state.defender_touched = row.get("touched", false)
	lab._ball_play_resolver.state.elapsed_seconds = row.get("elapsed", 1.0)
	lab._batted_ball.linear_velocity = row.get("velocity", Vector3(0, 0, 2))
	lab._batted_ball.global_position = row.get("ball", Vector3(0, 0.1, 16))


func _flat_cases() -> void:
	var terrain: Node3D = StadiumHillsideTerrainModels.create("flat-control")
	add_child(terrain)
	await _barrier()
	var ordinary: PitchBatLab = _lab()
	var bound: PitchBatLab = _lab()
	_check(ordinary.get_script() == LAB and bound.get_script() == LAB
		and bound._pitcher_marker.get_class() == "Node3D"
		and bound._pitcher_marker == bound.get_node("PitcherDefender")
		and bound._primary_fielder.pitcher_defender == bound._pitcher_marker,
		"exact production lab, actual constructed Node3D marker and linked primary")
	_check(ordinary._pitcher_marker.position == ordinary.MOUND_ORIGIN
		and ordinary.hillside_pitcher_motion == null, "ordinary construction stays unbound at original mound")
	_check(_bind(bound, terrain, "flat-control"), "flat-control actual pitcher binding")
	_check(bound.hillside_pitcher_motion != bound._primary_fielder.hillside_motion
		and bound._pitcher_marker.global_position == bound.MOUND_ORIGIN,
		"pitcher owns independent adapter and supported mound")
	var rows: Array[Dictionary] = [
		{"name": "clear"}, {"name": "attempted", "attempted": true},
		{"name": "touched", "touched": true}, {"name": "reaction", "elapsed": 0.199},
		{"name": "settled", "velocity": Vector3.ZERO},
		{"name": "far-target", "ball": Vector3(0, 0.1, 24)},
		{"name": "negative-delta", "delta": -0.1},
	]
	for row: Dictionary in rows:
		_prepare(ordinary, row)
		var expected: Vector3 = _legacy_advance(ordinary, row.get("delta", 0.1))
		var before: Dictionary = _primary_state(ordinary)
		PitchBatLabDefenseSupport.advance_pitcher(ordinary, row.get("delta", 0.1))
		_check(ordinary._pitcher_marker.global_position == expected and _primary_state(ordinary) == before
			and (expected != ordinary.MOUND_ORIGIN if row.name == "clear" else true),
			"unbound exact retained planner/reaction/spacing arithmetic: " + row.name)
	for outcome: FieldingResolver.Outcome in [FieldingResolver.Outcome.CLEAN, FieldingResolver.Outcome.BOBBLE]:
		_prepare(ordinary, {})
		var ball: Vector3 = ordinary.MOUND_ORIGIN + Vector3(2, 3, 1)
		var expected: Dictionary = _legacy_lunge(ordinary, ball, outcome)
		PitchBatLabPresentation.show_pitcher_fielding_attempt(ordinary, ball, outcome)
		_check(ordinary._pitcher_marker.global_position == expected.position
			and ordinary._pitcher_marker.rotation.z == expected.rotation,
			"unbound exact retained lunge and outcome-supplied presentation rotation")
	var flat_rows: Array[Dictionary] = [
		{"name": "clear", "target": Vector3(2, 0, 17)},
		{"name": "separation", "target": Vector3(0, 0, 18), "other": Vector3(0, 0, 17)},
		{"name": "obstacle", "target": Vector3(2, 0, 17),
			"obstacles": [{"center": Vector3(0.6, 0, 15), "radius": 0.6}]},
		{"name": "clipped-budget", "target": Vector3(0, 0, 18.716), "delta": 2.0},
	]
	for row: Dictionary in flat_rows:
		_prepare(bound, row)
		var before: Vector3 = bound._pitcher_marker.global_position
		var primary: Dictionary = _primary_state(bound)
		var budget: float = _speed(bound) * row.get("delta", 0.1)
		var expected: Vector3 = _ordinary_candidate(bound, before, row.target, budget)
		PitchBatLabDefenseSupport.advance_pitcher(bound, row.get("delta", 0.1))
		var path: Dictionary = bound.hillside_pitcher_motion.last_path
		_check(bound._pitcher_marker.global_position == expected and not bound.hillside_pitcher_motion.blocked,
			"flat bound exact retained candidate: " + row.name)
		_check(_primary_state(bound) == primary and path.get("path", []) == [before, expected]
			and path.get("budget", -1.0) == budget, "flat path and primary isolation: " + row.name)
		_emit("flat-" + row.name, 0, path.get("path", []), budget)
	ordinary.queue_free()
	bound.queue_free()
	terrain.queue_free()
	await _barrier()


func _hill_cases() -> void:
	var terrain: Node3D = StadiumHillsideTerrainModels.create("hill")
	add_child(terrain)
	await _barrier()
	var lab: PitchBatLab = _lab()
	_check(_bind(lab, terrain, "hill"), "hill actual primary/context and pitcher bind")
	_check(lab._pitcher_marker.global_position == StadiumHillsideTerrain.point(0, lab.MOUND_ORIGIN.z),
		"original mound obtains retained physical support even where height is zero")
	_gates_and_capabilities(lab)
	var traces: Array[Dictionary] = [
		{"name": "ramp-entry", "start": Vector3(0, 0, 15.9), "target": Vector3(0, 0, 18.6)},
		{"name": "uphill", "start": Vector3(0, 0, 17), "target": Vector3(0, 0, 18.6)},
		{"name": "downhill", "start": Vector3(0, 0, 18.5), "target": Vector3(0, 0, 15.5)},
		{"name": "cross-slope", "start": Vector3(-2, 0, 17), "target": Vector3(2, 0, 17)},
		{"name": "obstacle", "start": Vector3(-2, 0, 17), "target": Vector3(2, 0, 17),
			"obstacles": [{"center": Vector3(0, 0, 17), "radius": 0.7}]},
		{"name": "other-defender", "start": Vector3(-2, 0, 17), "target": Vector3(2, 0, 17),
			"other": Vector3(0, 0, 17)},
	]
	for row: Dictionary in traces:
		for rate: int in RATES:
			_trace(lab, row, rate)
	_prefix_limits(lab)
	_lunges(lab)
	_lifecycle(lab)
	_preview_cases(lab)
	_private_refusals(lab, terrain)
	await _support_failures(lab, terrain)
	lab.queue_free()
	await _barrier()


func _gates_and_capabilities(lab: PitchBatLab) -> void:
	var rows: Array[Dictionary] = [
		{"name": "no-explicit-target", "target": Vector3.INF},
		{"name": "attempted", "attempted": true},
		{"name": "touched", "touched": true},
		{"name": "before-reaction", "elapsed": 0.199999},
		{"name": "settled", "velocity": Vector3(0, 0, 0.5)},
		{"name": "outside-original-disk", "target": Vector3(5.001, 0, lab.MOUND_ORIGIN.z)},
		{"name": "negative-delta", "delta": -1.0},
	]
	for row: Dictionary in rows:
		_prepare(lab, row)
		var before: Vector3 = lab._pitcher_marker.global_position
		PitchBatLabDefenseSupport.advance_pitcher(lab, row.get("delta", 0.1))
		_check(lab._pitcher_marker.global_position == before and not lab.hillside_pitcher_motion.blocked,
			"retained pursuit gate holds without corrupting valid binding: " + row.name)
	_prepare(lab, {"target": Vector3(0, 0, lab.MOUND_ORIGIN.z + 5.0), "elapsed": 0.20})
	lab.hillside_pitcher_target = StadiumHillsideTerrain.point(0, lab.MOUND_ORIGIN.z + 5.0)
	var before: Vector3 = lab._pitcher_marker.global_position
	PitchBatLabDefenseSupport.advance_pitcher(lab, 0.1)
	_check(lab.hillside_pitcher_target.distance_to(lab.MOUND_ORIGIN) > 5.0
		and lab._pitcher_marker.global_position.z > before.z,
		"exact five-metre XZ target remains eligible despite supported elevation and exact reaction threshold")
	_prepare(lab, {"start": Vector3(4, 0, lab.MOUND_ORIGIN.z),
		"target": Vector3(6, 0, lab.MOUND_ORIGIN.z)})
	before = lab._pitcher_marker.global_position
	PitchBatLabDefenseSupport.advance_pitcher(lab, 0.1)
	_check(lab._pitcher_marker.global_position == before,
		"charge disk stays centred at original mound rather than current pitcher")
	_prepare(lab, {})
	var state_before: Dictionary = _outcome_state(lab)
	PitchBatLabDefenseSupport.try_primary(lab)
	PitchBatLabDefenseSupport.try_pitcher(lab, lab.MOUND_ORIGIN + Vector3.DOWN, lab.MOUND_ORIGIN + Vector3.DOWN)
	_check(_outcome_state(lab) == state_before, "distant primary and below-terrain pitcher candidate refuse actual control without changing movement state")
	for rating: int in [0, 5, 10]:
		lab._match_state = _match(rating)
		lab._match_mode = true
		_prepare(lab, {"target": Vector3(3, 0, 15)})
		before = lab._pitcher_marker.global_position
		var speed: float = lerpf(3.6, 4.6, float(rating) / 10.0)
		var candidate: Vector3 = _ordinary_candidate(lab, before, lab.hillside_pitcher_target, speed * 0.1)
		var expected: Dictionary = _surface_prefix(before, candidate, speed * 0.1)
		PitchBatLabDefenseSupport.advance_pitcher(lab, 0.1)
		_check(lab._pitcher_marker.global_position == expected.position
			and lab.hillside_pitcher_motion.last_path.get("path", []) == expected.path
			and lab.hillside_pitcher_motion.last_path.get("budget", -1.0) == speed * 0.1,
			"actual player-derived speed retains exact 3.6-to-4.6 interpolation: " + str(rating))
	lab._match_state = _match(5)
	lab._match_state.pitcher().definition.season_gear = {"misc": "MISC-FLD-03"}
	_prepare(lab, {"target": Vector3(3, 0, 15), "elapsed": 0.17})
	before = lab._pitcher_marker.global_position
	PitchBatLabDefenseSupport.advance_pitcher(lab, 0.1)
	_check(PitchBatLabDefenseSupport.reaction_delay(lab) == 0.20 * 0.85
		and lab._pitcher_marker.global_position != before, "existing goggles reaction treatment retained")
	lab._match_state.pitcher().definition.season_gear = {"misc": "MISC-FLD-01"}
	_prepare(lab, {"target": Vector3(3, 0, 15)})
	var expected_budget: float = lerpf(3.6, 4.6, 0.5) * SeasonGearCatalog.factor(
		lab._match_state.pitcher().definition, "speed") * 0.1
	PitchBatLabDefenseSupport.advance_pitcher(lab, 0.1)
	_check(lab.hillside_pitcher_motion.last_path.get("budget", -1.0) == expected_budget,
		"existing gear factor is retained as source arithmetic, not a new gear qualification")
	lab._match_mode = false
	lab._match_state = null


func _trace(lab: PitchBatLab, row: Dictionary, rate: int) -> void:
	_prepare(lab, row)
	var primary: Dictionary = _primary_state(lab)
	var path: Array = [lab._pitcher_marker.global_position]
	var exact: bool = true
	var legal: bool = true
	var budget: float = 0.0
	var allowance: float = 0.0
	var delta: float = 1.0 / float(rate)
	for frame in range(int(rate * 0.5)):
		var previous: Vector3 = lab._pitcher_marker.global_position
		var step_budget: float = _speed(lab) * delta
		var candidate: Vector3 = _ordinary_candidate(lab, previous, row.target, step_budget)
		var expected: Dictionary = _surface_prefix(previous, candidate, step_budget)
		PitchBatLabDefenseSupport.advance_pitcher(lab, delta)
		var actual: Dictionary = lab.hillside_pitcher_motion.last_path
		exact = exact and lab._pitcher_marker.global_position == expected.position \
			and actual.get("path", []) == expected.path and not lab.hillside_pitcher_motion.blocked
		var points: Array = actual.get("path", [])
		legal = legal and not points.is_empty() and _path_legal(lab, points) \
			and _length(points) == actual.get("travel", -1.0) \
			and _length(points) <= step_budget + _allowance(points)
		budget += step_budget
		allowance += _allowance(points)
		for index in range(1, points.size()):
			path.append(points[index])
	_check(exact, "exact retained route and sampled surface prefix: " + row.name + ":" + str(rate))
	_check(legal and _primary_state(lab) == primary and _length(path) <= budget + allowance,
		"actual supported budgets, restrictions and isolated primary: " + row.name + ":" + str(rate))
	_emit(row.name, rate, path, budget)


func _lunges(lab: PitchBatLab) -> void:
	var rows: Array[Dictionary] = [
		{"name": "full-uphill", "start": Vector3(0, 0, 18), "offset": Vector3(0, 2, 4)},
		{"name": "short-diagonal", "start": Vector3(0, 0, 17), "offset": Vector3(-0.2, 2, 0.2)},
		{"name": "outside-charge-disk", "start": Vector3(4.9, 0, lab.MOUND_ORIGIN.z),
			"offset": Vector3(4, 0, 0)},
	]
	for row: Dictionary in rows:
		_prepare(lab, row)
		var previous: Vector3 = lab._pitcher_marker.global_position
		var primary: Dictionary = _primary_state(lab)
		var ball_position: Vector3 = previous + row.offset
		var offset: Vector3 = ball_position - previous
		offset.y = 0.0
		offset = offset.normalized() * minf(0.72, offset.length())
		var budget: float = offset.length()
		var candidate: Vector3 = _ordinary_candidate(lab, previous, previous + offset, budget)
		var expected: Dictionary = _surface_prefix(previous, candidate, budget)
		PitchBatLabPresentation.show_pitcher_fielding_attempt(lab, ball_position,
			FieldingResolver.Outcome.CLEAN)
		var path: Array = lab.hillside_pitcher_motion.last_path.get("path", [])
		_check(lab._pitcher_marker.global_position == expected.position and path == expected.path,
			"actual lunge uses same supported route prefix: " + row.name)
		_check(_path_legal(lab, path) and _length(path) <= budget + _allowance(path)
			and lab.hillside_pitcher_motion.last_path.get("budget", -1.0) == budget
			and _primary_state(lab) == primary,
			"lunge spends at most original 0.72 surface budget with separate actor state: " + row.name)
		_check(lab._pitcher_marker.rotation.z == _canonical_z(0.18 * signf(offset.x if absf(offset.x) > 0.01 else 1.0))
			and lab.hillside_pitcher_motion.guard_pitcher(lab)
			and (lab._pitcher_marker.position.x > 5.0 if row.name == "outside-charge-disk" else true),
			"retained Z rotation is valid; lunge has no invented five-metre endpoint leash: " + row.name)
		_emit("lunge-" + row.name, 0, path, budget)


func _prefix_limits(lab: PitchBatLab) -> void:
	_prepare(lab, {"start": Vector3(0, 0, 17), "target": Vector3(0, 0, 17.025)})
	var before: Vector3 = lab._pitcher_marker.global_position
	var expected: Dictionary = _surface_prefix(before,
		_ordinary_candidate(lab, before, lab.hillside_pitcher_target, 4.1), 4.1)
	PitchBatLabDefenseSupport.advance_pitcher(lab, 1.0)
	var path: Array = lab.hillside_pitcher_motion.last_path.get("path", [])
	_check(lab._pitcher_marker.global_position == lab.hillside_pitcher_target
		and lab._pitcher_marker.global_position == expected.position and path == expected.path,
		"shorter-than-0.05 target is reached exactly without importing primary stop threshold")
	_check(_length(path) < 0.03 and lab._pitcher_marker.global_position != before,
		"short-target prefix cannot extend to spend unused movement budget")
	_emit("short-target-prefix", 0, path, 4.1)
	_prepare(lab, {"start": Vector3(0, 0, 25.4)})
	before = lab._pitcher_marker.global_position
	var target: Vector3 = StadiumHillsideTerrain.point(0, 30)
	var candidate: Vector3 = _ordinary_candidate(lab, before, target, 4.1)
	expected = _surface_prefix(before, candidate, 4.1)
	var primary: Dictionary = _primary_state(lab)
	lab._pitcher_marker.global_position = StadiumPropertyRuntime.pitcher_step(lab, target, 4.1, before)
	path = lab.hillside_pitcher_motion.last_path.get("path", [])
	_check(before == StadiumHillsideTerrain.point(0, 25.4) and candidate.z < target.z,
		"boundary diagnostic starts legally and source boundary actually clips requested path")
	_check(lab._pitcher_marker.global_position == expected.position and path == expected.path
		and not lab.hillside_pitcher_motion.blocked, "actual property path uses exact supported boundary prefix")
	_check(_length(path) < 4.1 and _path_legal(lab, path) and _primary_state(lab) == primary,
		"boundary prefix spends no leftover budget and retains actual legal support")
	_emit("boundary-prefix", 0, path, 4.1)


func _lifecycle(lab: PitchBatLab) -> void:
	for ingress: String in ["shared-reset", "telegraph-reset", "cleanup", "reset-lab", "throw-pitch"]:
		_prepare(lab, {"start": Vector3(0, 0, 18)})
		PitchBatLabPresentation.show_pitcher_fielding_attempt(lab, Vector3(1, 0, 19), FieldingResolver.Outcome.BOBBLE)
		lab._primary_fielder.stadium_pool_pitcher_route["sentinel"] = 1
		lab._primary_fielder.stadium_pool_fielder_route["sentinel"] = 2
		match ingress:
			"shared-reset": lab.reset_hillside_pitcher()
			"telegraph-reset": PitchBatLabFeelSupport._reset_pitcher_telegraph(lab)
			"cleanup": lab._cleanup_batted_ball()
			"reset-lab": lab._reset_lab()
			"throw-pitch":
				lab._match_mode = true
				lab._match_state = null
				lab._throw_pitch()
				lab._match_mode = false
		_check(lab._pitcher_marker.position == lab.MOUND_ORIGIN
			and lab._pitcher_marker.rotation == Vector3.ZERO and not lab.hillside_pitcher_motion.blocked,
			"real ordinary pose ingress returns to supported mound: " + ingress)
		_check(lab.hillside_pitcher_target == Vector3.INF
			and not lab.hillside_pitcher_motion.presentation_active
			and (lab._primary_fielder.stadium_pool_pitcher_route.is_empty()
				if ingress in ["cleanup", "reset-lab"] else lab._primary_fielder.stadium_pool_pitcher_route == {"sentinel": 1}),
			"ordinary target/presentation reset preserves existing route-clear boundaries: " + ingress)
	_prepare(lab, {})
	lab._match_state = _match(5)
	lab._at_bat_cadence = AtBatCadenceController.new()
	lab._at_bat_cadence.state = AtBatCadenceController.State.DELIVERY
	lab._at_bat_cadence.active_set_seconds = 0.0
	lab._at_bat_cadence.active_windup_seconds = 1.0
	lab._at_bat_cadence.elapsed_seconds = 0.5
	var primary: Dictionary = _primary_state(lab)
	PitchBatLabFeelSupport._update_pitcher_telegraph(lab)
	var presentation_pose: Vector3 = lab._pitcher_marker.position
	_check(presentation_pose == lab.MOUND_ORIGIN + Vector3(0.08, 0.16, 0)
		and lab._pitcher_marker.rotation.z == _canonical_z(0.08) and lab.hillside_pitcher_motion.presentation_active,
		"actual delivery retains known 0.16 lift and existing marker rotation")
	PitchBatLabDefenseSupport.advance_pitcher(lab, 0.1)
	_check(lab._pitcher_marker.position == presentation_pose
		and not lab.hillside_pitcher_motion.blocked and _primary_state(lab) == primary,
		"known delivery presentation cannot become a fielding origin or poison primary")
	PitchBatLabFeelSupport._reset_pitcher_telegraph(lab)
	lab.hillside_pitcher_target = StadiumHillsideTerrain.point(0, 18)
	PitchBatLabDefenseSupport.advance_pitcher(lab, 0.1)
	_check(lab._pitcher_marker.position.z > lab.MOUND_ORIGIN.z
		and not lab.hillside_pitcher_motion.presentation_active and not lab.hillside_pitcher_motion.blocked,
		"delivery-to-supported-reset-to-fielding recovers without treating lift as support")
	lab._at_bat_cadence = null
	lab._match_state = null


func _preview_cases(lab: PitchBatLab) -> void:
	_prepare(lab, {"start": Vector3(0, 0, 17)})
	var virtual_from: Vector3 = StadiumHillsideTerrain.point(-2, 17)
	var virtual_target: Vector3 = StadiumHillsideTerrain.point(2, 17)
	var snapshot: Dictionary = _live_state(lab)
	var obstacles: Array[Dictionary] = []
	var pure: Dictionary = lab.hillside_pitcher_motion.pitcher_step_from(lab, virtual_from,
		virtual_target, 0.41, lab._primary_fielder.global_position, obstacles)
	var expected: Dictionary = _surface_prefix(virtual_from,
		_ordinary_candidate(lab, virtual_from, virtual_target, 0.41), 0.41)
	_check(pure.get("path", []) == expected.path and pure.get("position") == expected.position,
		"one-step query uses supplied virtual origin rather than actual live marker")
	_check(_live_state(lab) == snapshot and obstacles.is_empty(),
		"one-step query leaves actor, route, time, latch and caller obstacle snapshot unchanged")
	var rows: Array[Dictionary] = [
		{"name": "supported-arrival", "start": Vector3(0, 0, 17), "target": Vector3(0, 0, 17.6)},
		{"name": "obstacle-detour", "start": Vector3(-0.4, 0, 17), "target": Vector3(0.4, 0, 17),
			"obstacles": [{"center": Vector3(0, 0, 17), "radius": 0.15}]},
	]
	for row: Dictionary in rows:
		for rate: int in RATES:
			_prepare(lab, row)
			var before: Dictionary = _live_state(lab)
			var target: Vector3 = StadiumHillsideTerrain.point(row.target.x, row.target.z)
			lab.hillside_pitcher_target = target
			before = _live_state(lab)
			var preview: Dictionary = lab.hillside_pitcher_motion.preview_pitcher(lab, target,
				_speed(lab), 1.0 / rate, 30)
			_check(_live_state(lab) == before, "preview has no actor, time, route or latch side effect: " + row.name + ":" + str(rate))
			var actual_path: Array = [lab._pitcher_marker.global_position]
			var elapsed: float = 0.0
			var reported_travel: float = 0.0
			for step in range(int(preview.get("steps", 0))):
				PitchBatLabDefenseSupport.advance_pitcher(lab, 1.0 / rate)
				elapsed = float(step + 1) * (1.0 / rate)
				reported_travel += float(lab.hillside_pitcher_motion.last_path.get("travel", -1.0))
				var points: Array = lab.hillside_pitcher_motion.last_path.get("path", [])
				for index in range(1, points.size()):
					actual_path.append(points[index])
			_check(preview.get("reached", false) and lab._pitcher_marker.global_position == target
				and actual_path == preview.get("path", []) and elapsed == preview.get("elapsed", -1.0),
				"same frozen snapshot actual schedule equals exact tick-quantized preview: " + row.name + ":" + str(rate))
			_check(reported_travel == preview.get("travel", -1.0)
				and absf(_length(actual_path) - reported_travel) <= _allowance(actual_path)
				and _path_legal(lab, actual_path) and int(preview.get("steps", 0)) <= 30,
				"preview returns complete measured route and bounded arrival: " + row.name + ":" + str(rate))
			_emit("preview-" + row.name, rate, actual_path, _speed(lab) * elapsed)
	_prepare(lab, {"target": Vector3(0, 0, 18)})
	var before: Dictionary = _live_state(lab)
	for target: Vector3 in [Vector3(NAN, 0, 18), Vector3(0, 2, 18), Vector3(33, 0, 18)]:
		var refused: Dictionary = lab.hillside_pitcher_motion.preview_pitcher(lab, target, 4.1, 0.1, 30)
		_check(not refused.get("reached", false) and _live_state(lab) == before,
			"invalid or unsupported preview target is unknown with no live-state poisoning")
	var horizon: Dictionary = lab.hillside_pitcher_motion.preview_pitcher(lab,
		StadiumHillsideTerrain.point(0, 18), 0.1, 0.1, 30)
	_check(not horizon.get("reached", false) and int(horizon.get("steps", -1)) <= 30
		and float(horizon.get("elapsed", INF)) <= 3.0 and _live_state(lab) == before,
		"finite horizon exhaustion cannot become straight-line arrival")
	_prepare(lab, {"target": Vector3(0, 0, 17), "other": Vector3(0, 0, 17)})
	before = _live_state(lab)
	var redirected: Dictionary = lab.hillside_pitcher_motion.preview_pitcher(lab,
		StadiumHillsideTerrain.point(0, 17), 4.1, 0.1, 30)
	_check(not redirected.get("reached", false) and _live_state(lab) == before,
		"other-defender redirected goal never counts as arrival at original target")


func _private_refusals(lab: PitchBatLab, terrain: Node3D) -> void:
	lab._cleanup_batted_ball()
	for flag: String in ["managed", "public", "property", "pool", "yard", "active-primary", "live-ball", "delivery"]:
		lab._primary_fielder.end_play()
		lab._primary_fielder.stadium_obstacles.clear()
		lab._ball_play_resolver.state.dead = true
		var before: Dictionary = _primary_state(lab)
		var position: Vector3 = lab._pitcher_marker.position
		match flag:
			"managed": lab._managed_match = true
			"public": lab.set_meta(StadiumNpcPublicRuntime.PUBLIC_BOUND, true)
			"property": lab.set_meta("stadium_property", Node3D.new())
			"pool": lab._primary_fielder.stadium_obstacles = [{"center": Vector3(6, 0, 17), "radius": 1.0, "owned_pool": true}]
			"yard": lab.yard_bound_startup_failed = true
			"active-primary": lab._primary_fielder.active = true
			"live-ball": _ball(lab)
			"delivery":
				lab._at_bat_cadence = AtBatCadenceController.new()
				lab._at_bat_cadence.state = AtBatCadenceController.State.DELIVERY
		before = _primary_state(lab)
		_check(not lab.bind_hillside_pitcher_motion() and lab._pitcher_marker.position == position
			and _primary_state(lab) == before, "private idle binding refuses incompatible context without primary mutation: " + flag)
		match flag:
			"managed": lab._managed_match = false
			"public": lab.remove_meta(StadiumNpcPublicRuntime.PUBLIC_BOUND)
			"property":
				(lab.get_meta("stadium_property") as Node).free()
				lab.remove_meta("stadium_property")
			"pool": lab._primary_fielder.stadium_obstacles.clear()
			"yard": lab.yard_bound_startup_failed = false
			"active-primary": lab._primary_fielder.active = false
			"live-ball":
				lab._batted_ball.queue_free()
				lab._batted_ball = null
				lab._ball_play_resolver.state.dead = true
			"delivery": lab._at_bat_cadence = null
	_check(_bind(lab, terrain, "hill"), "explicit valid context rebind restores refused private binding")


func _support_failures(lab: PitchBatLab, terrain: Node3D) -> void:
	var body: StaticBody3D = terrain.get_node("TerrainCollision") as StaticBody3D
	var shape: CollisionShape3D = body.get_node("ClosedTerrainShape") as CollisionShape3D
	var original: Shape3D = shape.shape
	for fault: String in ["disabled", "layer", "transformed", "shape-replaced"]:
		_prepare(lab, {"start": Vector3(0, 0, 17), "target": Vector3(0, 0, 18)})
		PitchBatLabDefenseSupport.advance_pitcher(lab, 0.1)
		var before: Vector3 = lab._pitcher_marker.global_position
		var primary: Dictionary = _primary_state(lab)
		match fault:
			"disabled": shape.disabled = true
			"layer": body.collision_layer = 0
			"transformed": terrain.position.x = 0.25
			"shape-replaced": shape.shape = original.duplicate()
		await _barrier()
		var live: Dictionary = _live_state(lab)
		var preview: Dictionary = lab.hillside_pitcher_motion.preview_pitcher(lab,
			StadiumHillsideTerrain.point(0, 18), 4.1, 0.1, 30)
		_check(not preview.get("reached", false) and _live_state(lab) == live,
			"read-only invalid-support preview leaves both actor latches untouched: " + fault)
		PitchBatLabDefenseSupport.advance_pitcher(lab, 0.1)
		_check(lab.hillside_pitcher_motion.blocked and lab._pitcher_marker.global_position == before
			and _primary_state(lab) == primary, "support fault freezes only pitcher at last accepted pose: " + fault)
		_check(not lab.reset_hillside_pitcher() and lab._pitcher_marker.global_position == before,
			"failed explicit reset has no flat or mound fallback: " + fault)
		match fault:
			"disabled": shape.disabled = false
			"layer": body.collision_layer = 1 | StadiumHillsideTerrainModels.QUERY_LAYER
			"transformed": terrain.position = Vector3.ZERO
			"shape-replaced": shape.shape = original
		await _barrier()
		lab.hillside_pitcher_target = StadiumHillsideTerrain.point(0, 18)
		PitchBatLabDefenseSupport.advance_pitcher(lab, 0.1)
		_check(lab.hillside_pitcher_motion.blocked and lab._pitcher_marker.global_position == before,
			"restoration alone never resumes a failed movement binding: " + fault)
		_check(lab.reset_hillside_pitcher() and not lab.hillside_pitcher_motion.blocked
			and lab._pitcher_marker.global_position == lab.MOUND_ORIGIN,
			"successful explicit supported reset is the recovery point: " + fault)
	_prepare(lab, {"start": Vector3(0, 0, 17)})
	var before: Vector3 = lab._pitcher_marker.global_position
	var primary: Dictionary = _primary_state(lab)
	terrain.queue_free()
	await _barrier()
	PitchBatLabDefenseSupport.advance_pitcher(lab, 0.1)
	_check(lab.hillside_pitcher_motion.blocked and lab._pitcher_marker.global_position == before
		and _primary_state(lab) == primary, "freed terrain freezes only actual pitcher")
	var replacement: Node3D = StadiumHillsideTerrainModels.create("hill")
	add_child(replacement)
	await _barrier()
	PitchBatLabDefenseSupport.advance_pitcher(lab, 0.1)
	_check(lab.hillside_pitcher_motion.blocked and lab._pitcher_marker.global_position == before,
		"matching replacement terrain cannot silently replace retained support identity")
	lab._cleanup_batted_ball()
	_check(_bind(lab, replacement, "hill") and lab._pitcher_marker.global_position == lab.MOUND_ORIGIN,
		"explicit primary and pitcher rebind adopts replacement support")
	replacement.queue_free()


# Independent retained source arithmetic; no changed adapter/property calls.
func _legacy_advance(lab: PitchBatLab, delta: float) -> Vector3:
	var state: BallPlayState = lab._ball_play_resolver.state
	var previous: Vector3 = lab._pitcher_marker.global_position
	if lab._pitcher_attempted or state.defender_touched or state.elapsed_seconds < PitchBatLabDefenseSupport.reaction_delay(lab):
		return previous
	if lab._batted_ball.linear_velocity.length() <= lab.SETTLED_SPEED_MPS:
		return previous
	var plan: FielderPlan = FielderPlanner.plan(lab._batted_ball.global_position,
		lab._batted_ball.linear_velocity, state.has_grounded, previous, _speed(lab), PitcherDefense.REACTION_RADIUS_M)
	var target: Vector3 = Vector3(plan.intercept_position.x, 0, plan.intercept_position.z)
	if not plan.reachable or target.distance_to(lab.MOUND_ORIGIN) > 5.0:
		return previous
	return DefenderSpacing.step_around_mound(previous, target,
		lab._primary_fielder.global_position, _speed(lab) * maxf(0, delta))


func _legacy_lunge(lab: PitchBatLab, ball: Vector3, outcome: FieldingResolver.Outcome) -> Dictionary:
	var offset: Vector3 = ball - lab._pitcher_marker.global_position
	offset.y = 0.0
	if offset.length_squared() > 0.0001:
		offset = offset.normalized() * minf(0.72, offset.length())
	return {"position": DefenderSpacing.step_around_mound(lab._pitcher_marker.global_position,
		lab._pitcher_marker.global_position + offset, lab._primary_fielder.global_position, offset.length()),
		"rotation": _canonical_z((0.18 if outcome == FieldingResolver.Outcome.CLEAN else 0.10)
			* signf(offset.x if absf(offset.x) > 0.01 else 1.0))}


func _ordinary_candidate(lab: PitchBatLab, from: Vector3, target: Vector3, budget: float) -> Vector3:
	var next: Vector3 = DefenderSpacing.step_around_mound(from, target,
		lab._primary_fielder.global_position, budget)
	if not lab._primary_fielder.stadium_obstacles.is_empty():
		var obstacles: Array[Dictionary] = lab._primary_fielder.stadium_obstacles.duplicate(true)
		obstacles.append({"center": lab._primary_fielder.global_position, "radius": DefenderSpacing.MOUND_CLEARANCE_M})
		next = StadiumDefenderRoutes.step(from, target, budget, obstacles)
	return _graph.clip(from, next)


func _surface_prefix(from: Vector3, candidate: Vector3, budget: float) -> Dictionary:
	var heading: Vector2 = Vector2(candidate.x - from.x, candidate.z - from.z)
	var generated: Dictionary = StadiumHillsideLocomotion.step(from, heading, budget)
	var path: Array = [from]
	for index in range(1, generated.path.size()):
		var point: Vector3 = generated.path[index]
		if Vector2(point.x - from.x, point.z - from.z).length() >= heading.length():
			path.append(StadiumHillsideTerrain.point(candidate.x, candidate.z))
			break
		path.append(point)
	return {"position": path[-1], "path": path}


func _canonical_z(angle: float) -> float:
	var marker: Node3D = Node3D.new()
	marker.rotation.z = angle
	var result: float = marker.rotation.z
	marker.free()
	return result


func _speed(lab: PitchBatLab) -> float:
	return lerpf(3.6, 4.6, float(MatchLabSupport.pitcher_fielding_rating(lab)) / 10.0) \
		* PitchBatLabDefenseSupport.gear_factor(lab, "speed")


func _match(rating: int) -> MatchState:
	var roster: Array[PlayerDefinition] = []
	for index in range(4):
		var player: PlayerDefinition = PlayerDefinition.new()
		player.fielding = rating
		player.throws = PlayerDefinition.Handedness.RIGHT
		roster.append(player)
	return MatchState.create(TeamMatchState.create("A", roster), TeamMatchState.create("B", roster))


func _primary_state(lab: PitchBatLab) -> Dictionary:
	var fielder: FielderController = lab._primary_fielder
	return {"position": fielder.global_position, "anchor": fielder.anchor_position,
		"target": fielder.target_position, "velocity": fielder.velocity,
		"elapsed": fielder._play_elapsed_seconds, "active": fielder.active,
		"fielder_route": fielder.stadium_pool_fielder_route.duplicate(true),
		"pitcher_route": fielder.stadium_pool_pitcher_route.duplicate(true),
		"blocked": fielder.hillside_motion.blocked if fielder.hillside_motion != null else false,
		"error": fielder.hillside_motion.last_error if fielder.hillside_motion != null else "",
		"path": fielder.hillside_motion.last_path.duplicate(true) if fielder.hillside_motion != null else {}}


func _outcome_state(lab: PitchBatLab) -> Dictionary:
	var state: BallPlayState = lab._ball_play_resolver.state
	return {"primary_attempts": lab._primary_attempts, "pitcher_attempted": lab._pitcher_attempted,
		"dead": state.dead, "touched": state.defender_touched, "floor": state.result_floor,
		"grounded": state.has_grounded, "elapsed": state.elapsed_seconds,
		"ball": lab._batted_ball.global_position, "velocity": lab._batted_ball.linear_velocity}


func _live_state(lab: PitchBatLab) -> Dictionary:
	return {"primary": _primary_state(lab), "position": lab._pitcher_marker.global_position,
		"rotation": lab._pitcher_marker.rotation, "target": lab.hillside_pitcher_target,
		"path": lab.hillside_pitcher_motion.last_path.duplicate(true),
		"blocked": lab.hillside_pitcher_motion.blocked, "error": lab.hillside_pitcher_motion.last_error,
		"presentation": lab.hillside_pitcher_motion.presentation_active,
		"outcome": _outcome_state(lab)}


func _path_legal(lab: PitchBatLab, path: Array) -> bool:
	if path.is_empty():
		return false
	for index in range(path.size()):
		var point: Vector3 = path[index]
		if not point.is_finite() or absf(point.x) > 38 or absf(point.y) > 38 or absf(point.z) > 38 \
			or absf(point.y - StadiumHillsideTerrain.support_height(Vector2(point.x, point.z),
			lab.hillside_pitcher_motion.profile)) > StadiumHillsideTerrain.EPS \
			or not _graph.contains(Vector2(point.x, point.z)):
			return false
		if index > 0:
			if path[index - 1].distance_to(point) > 8.0 \
				or not StadiumDefenderRoutes.clear(path[index - 1], point, lab._primary_fielder.stadium_obstacles) \
				or DefenderSpacing.segment_distance_xz(lab._primary_fielder.global_position,
				path[index - 1], point) < DefenderSpacing.MOUND_CLEARANCE_M:
				return false
	return true


func _length(path: Array) -> float:
	var total: float = 0.0
	for index in range(1, path.size()):
		total += path[index - 1].distance_to(path[index])
	return total


func _allowance(path: Array) -> float:
	return 8.0 * REAL32_EPSILON * 38.0 * float(path.size())


func _emit(case_name: String, rate: int, path: Array, budget: float) -> void:
	var points: Array = []
	var maximum_mound_xz: float = 0.0
	for point: Vector3 in path:
		points.append([point.x, point.y, point.z])
		maximum_mound_xz = maxf(maximum_mound_xz, Vector2(point.x, point.z - PitchBatLab.MOUND_ORIGIN.z).length())
	_route_count += 1
	print("HILLSIDE_PITCHER_ROUTE " + JSON.stringify({"case": case_name, "rate": rate,
		"path": points, "travel": _length(path), "budget": budget,
		"working_arithmetic_allowance": _allowance(path), "maximum_mound_xz": maximum_mound_xz}))


func _barrier() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(message)
