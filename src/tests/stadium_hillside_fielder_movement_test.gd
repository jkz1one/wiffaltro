extends Node3D
## Actual primary-mover component qualification only; no ball or public Hillside admission.
# gdlint: disable=max-file-lines,max-line-length,max-returns

const FIELD: FieldDefinition = preload("res://src/content/fields/npc_venue_field.tres")
const REAL32_EPSILON: float = 0.00000011920928955078125
const TRACE_RATES: Array[int] = [30, 60, 120]
var _checks: int = 0
var _failures: int = 0
var _route_count: int = 0
var _graph: StadiumRecipeBoundary


func _ready() -> void:
	_graph = StadiumRecipeBoundary.create("deeper_center")
	await _flat_components()
	await _hill_components()
	print("HILLSIDE_FIELDER_MOVEMENT checks=%d failures=%d" % [_checks, _failures])
	print("HILLSIDE_FIELDER_MOVEMENT_ROUTE_COUNT %d" % _route_count)
	get_tree().quit(0 if _failures == 0 else 1)


func _controller() -> FielderController:
	var actor: FielderController = FielderController.new()
	add_child(actor)
	actor.set_physics_process(false)
	actor.stadium_boundary_clip = Callable(_graph, "clip")
	return actor


func _field_all_slots() -> FieldDefinition:
	var field: FieldDefinition = FIELD.duplicate(true) as FieldDefinition
	field.shallow_center_available = true
	field.middle_center_available = true
	return field


func _flat_components() -> void:
	var terrain: Node3D = StadiumHillsideTerrainModels.create("flat-control")
	add_child(terrain)
	await _barrier()
	var ordinary: FielderController = _controller()
	var bound: FielderController = _controller()
	_check(ordinary.get_script().resource_path == "res://src/presentation/fielding/fielder_controller.gd"
		and bound.get_script() == ordinary.get_script(), "exact actual primary controller instantiated")
	_check(bound.bind_hillside_motion(_field_all_slots(), terrain, 4, "flat-control"),
		"flat-control binds retained actual support and existing boundary" + _describe(bound))
	if bound.hillside_motion_blocked():
		ordinary.queue_free()
		bound.queue_free()
		terrain.queue_free()
		await _barrier()
		return
	var cases: Array[Dictionary] = [
		{"name": "clear", "start": Vector3(0, 0, 17), "target": Vector3(4, 0, 19), "delta": 0.1},
		{"name": "target-threshold", "start": Vector3(0, 0, 17), "target": Vector3(0.025, 0, 17), "delta": 0.1},
		{"name": "mound", "start": Vector3(-2, 0, 18), "target": Vector3(2, 0, 18), "delta": 0.5, "mound": 18.0},
		{"name": "static-obstacle", "start": Vector3(-2, 0, 20), "target": Vector3(2, 0, 20), "delta": 0.5,
			"obstacles": [{"center": Vector3(0, 0, 20), "radius": 0.9}]},
		{"name": "graph-boundary", "start": Vector3(0, 0, 25.4), "target": Vector3(0, 0, 30), "delta": 0.75},
		{"name": "large-delta", "start": Vector3(-4, 0, 17), "target": Vector3(4, 0, 17), "delta": 1.25},
	]
	for row: Dictionary in cases:
		_prepare(ordinary, row)
		_prepare(bound, row)
		var expected: Dictionary = _legacy_tick(ordinary, row.delta)
		ordinary._physics_process(row.delta)
		bound._physics_process(row.delta)
		_check(_matches(ordinary, expected), "unbound exact retained source arithmetic: " + row.name)
		_check(_matches(bound, expected) and _same_state(ordinary, bound),
			"bound flat exact pose/velocity/time/routes: " + row.name)
		_emit(row.name, 0, [row.start, bound.global_position], row.delta * bound.move_speed_mps,
			bound.global_position.distance_to(row.start), 0.0, "exact-flat-component")
	await _flat_timing(ordinary, bound)
	await _flat_first_step(ordinary, bound)
	_pool_component(ordinary, bound, terrain)
	ordinary.queue_free()
	bound.queue_free()
	terrain.queue_free()
	await _barrier()


func _prepare(actor: FielderController, row: Dictionary) -> void:
	actor.end_play()
	actor.pitcher_defender = null
	actor.pitcher_lane_z = row.get("mound", INF)
	var obstacles: Array[Dictionary] = []
	for obstacle: Dictionary in row.get("obstacles", []):
		obstacles.append(obstacle.duplicate(true))
	actor.stadium_obstacles = obstacles
	actor.set_anchor(row.start)
	actor.reaction_delay_seconds = row.get("reaction", 0.0)
	actor.begin_play(row.get("stationary", false), row.get("first_step", Vector3.ZERO))
	actor.target_position = row.target


func _flat_timing(ordinary: FielderController, bound: FielderController) -> void:
	var row: Dictionary = {"start": Vector3(0, 0, 17), "target": Vector3(4, 0, 17),
		"reaction": 0.35, "first_step": Vector3.BACK}
	_prepare(ordinary, row)
	_prepare(bound, row)
	var transitions: Array[Dictionary] = []
	var identical: bool = true
	for delta: float in [0.1, 0.1, 0.1, 0.05, 0.05]:
		var expected: Dictionary = _legacy_tick(ordinary, delta)
		ordinary._physics_process(delta)
		bound._physics_process(delta)
		identical = identical and _matches(ordinary, expected) and _matches(bound, expected)
		transitions.append({"position": bound.global_position, "velocity": bound.velocity,
			"elapsed": bound._play_elapsed_seconds, "reaction": bound.reaction_ready(),
			"pursuit": bound.pursuit_ready()})
	_check(identical, "forced first step then reaction wait then pursuit matches exact retained source")
	_check(transitions[0].position.z > 17.0 and transitions[1].position.z > transitions[0].position.z
		and transitions[2].position == transitions[1].position
		and transitions[3].position == transitions[2].position
		and transitions[4].position.x > transitions[3].position.x,
		"explicit expected first-step/wait/pursuit transition outputs")
	row = {"start": Vector3(0, 0, 17), "target": Vector3(4, 0, 17), "stationary": true,
		"reaction": 0.11, "first_step": Vector3.BACK}
	_prepare(ordinary, row)
	_prepare(bound, row)
	for actor: FielderController in [ordinary, bound]:
		var expected: Dictionary = _legacy_tick(actor, 0.5)
		actor._physics_process(0.5)
		_check(_matches(actor, expected) and actor.global_position == row.start
			and actor.first_step == Vector3.ZERO and actor.velocity == Vector3.ZERO,
			"stationary ignores forced heading and stays exactly at anchor")
	row["stationary"] = false
	row["first_step"] = Vector3.ZERO
	_prepare(ordinary, row)
	_prepare(bound, row)
	for delta: float in [-0.1, 0.05, 0.05, 0.02]:
		var expected: Dictionary = _legacy_tick(ordinary, delta)
		ordinary._physics_process(delta)
		bound._physics_process(delta)
		identical = identical and _matches(ordinary, expected) and _matches(bound, expected)
	_check(identical and bound._play_elapsed_seconds == ordinary._play_elapsed_seconds
		and bound.global_position.x > 0, "negative delta and ordinary reaction delay preserve exact timing")


func _flat_first_step(ordinary: FielderController, bound: FielderController) -> void:
	var blocker: StaticBody3D = _box(Vector3(0, 0.5, 19), Vector3(1, 1, 0.2))
	await _barrier()
	var rows: Array[Dictionary] = [
		{"name": "flat-sphere", "start": Vector3(0, 0, 18), "target": Vector3(0, 0, 23)},
		{"name": "flat-forced-mound", "start": Vector3(0, 0, 15), "target": Vector3(0, 0, 21), "mound": 17.0},
		{"name": "flat-forced-obstacle", "start": Vector3(-3, 0, 20), "target": Vector3(-3, 0, 24),
			"obstacles": [{"center": Vector3(-3, 0, 21), "radius": 0.6}]},
		{"name": "flat-forced-boundary", "start": Vector3(0, 0, 25), "target": Vector3(0, 0, 30)},
	]
	for row: Dictionary in rows:
		_prepare(ordinary, row)
		_prepare(bound, row)
		var expected: Vector3 = _legacy_first_step(ordinary, Vector3.BACK, 0.6)
		FielderFirstStep.advance(ordinary, Vector3.BACK, 0.6)
		FielderFirstStep.advance(bound, Vector3.BACK, 0.6)
		_check(ordinary.global_position == expected and bound.global_position == expected
			and bound.velocity == ordinary.velocity
			and bound.velocity == (expected - row.start) / 0.6,
			"flat exact source forced-heading/sweep/clip: " + row.name)
		_check(bound.global_position.x == row.start.x and bound.global_position.z < row.start.z + 4.6 * 0.6,
			"existing restriction clips forced direction without steering: " + row.name)
	blocker.queue_free()
	await _barrier()


func _pool_component(ordinary: FielderController, bound: FielderController, terrain: Node3D) -> void:
	var row: Dictionary = {"start": Vector3(-3, 0, 20), "target": Vector3(3, 0, 20),
		"obstacles": [{"center": Vector3(0, 0, 20), "radius": 2.0, "owned_pool": true}]}
	_prepare(ordinary, row)
	var exact: bool = true
	var clear: bool = true
	var path: Array[Vector3] = [ordinary.global_position]
	for frame in range(16):
		var previous: Vector3 = ordinary.global_position
		var expected: Dictionary = _legacy_tick(ordinary, 0.1)
		ordinary._physics_process(0.1)
		exact = exact and _matches(ordinary, expected)
		clear = clear and StadiumDefenderRoutes.clear(previous, ordinary.global_position,
			ordinary.stadium_obstacles)
		path.append(ordinary.global_position)
	_check(exact and clear and ordinary.global_position != row.start,
		"unbound owned-Pool component uses unchanged route with exact state each frame")
	ordinary.stadium_pool_pitcher_route["sentinel"] = 1
	ordinary.end_play()
	_check(ordinary.stadium_pool_fielder_route.is_empty() and ordinary.stadium_pool_pitcher_route.is_empty(),
		"existing Pool begin/end reset clears both actual transient route dictionaries")
	bound.end_play()
	bound.stadium_obstacles = ordinary.stadium_obstacles.duplicate(true)
	var before: Vector3 = bound.global_position
	_check(not bound.bind_hillside_motion(_field_all_slots(), terrain, 4, "flat-control")
		and bound.global_position == before, "bound slice refuses incompatible paid-Pool route binding")
	_emit("owned-pool-unbound", 10, path, 16.0 * 0.1 * 4.6, _length(path), 0.0, "exact-unbound-component")


func _hill_components() -> void:
	var terrain: Node3D = StadiumHillsideTerrainModels.create("hill")
	add_child(terrain)
	await _barrier()
	await _slots_and_lifecycle(terrain)
	var actor: FielderController = _controller()
	_check(actor.bind_hillside_motion(_field_all_slots(), terrain, 4), "hill actual controller binds" + _describe(actor))
	if actor.hillside_motion_blocked():
		actor.queue_free()
		terrain.queue_free()
		await _barrier()
		return
	var traces: Array[Dictionary] = [
		{"name": "uphill", "start": Vector3(0, 0, 18), "target": Vector3(0, 0, 24)},
		{"name": "downhill", "start": Vector3(0, 0, 24), "target": Vector3(0, 0, 18)},
		{"name": "cross-slope", "start": Vector3(-3, 0, 21), "target": Vector3(3, 0, 21)},
		{"name": "diagonal", "start": Vector3(-2, 0, 18), "target": Vector3(3, 0, 24)},
		{"name": "ramp-start", "start": Vector3(0, 0, 15.9), "target": Vector3(0, 0, 21)},
		{"name": "z23.4-knot", "start": Vector3(0, 0, 23.45), "target": Vector3(0, 0, 18)},
	]
	for row: Dictionary in traces:
		for rate: int in TRACE_RATES:
			_trace(actor, row, rate)
	_hill_restrictions(actor)
	_hill_timing(actor)
	await _scheduled_delivery(actor)
	await _hill_forced_step(actor)
	_bare_seams()
	await _support_failures(actor, terrain)
	actor.queue_free()
	await _barrier()


func _slots_and_lifecycle(terrain: Node3D) -> void:
	var human: FielderController = _controller()
	var ai: FielderController = _controller()
	var actors: Array[FielderController] = [human, ai]
	for role_index in range(actors.size()):
		var actor: FielderController = actors[role_index]
		actor.set_meta("test_role", "human" if role_index == 0 else "ai")
		actor.move_speed_mps = 4.6
		actor.fielding_rating = 6
		actor.reach_m = 0.66
		for index in range(9):
			var row: Dictionary = StadiumHillsideAnchorContract.anchor(FIELD, index)
			var before: Vector3 = actor.global_position
			var accepted: bool = actor.bind_hillside_motion(FIELD, terrain, index)
			_check(accepted == FIELD.is_fielder_anchor_available(index)
				and row.source_anchor == FIELD.fielder_anchor(index)
				and (actor.global_position == row.position if accepted else actor.global_position == before),
				"all nine canonical identities/availability on actual role " + str(role_index) + ":" + str(index))
		for index in range(9):
			var row: Dictionary = StadiumHillsideAnchorContract.anchor(_field_all_slots(), index)
			_check(actor.bind_hillside_motion(_field_all_slots(), terrain, index)
				and actor.anchor_position == row.position and actor.target_position == row.position
				and actor.global_position == row.position, "all enabled original slots bind exact support")
	_check(human.global_position == ai.global_position and human.anchor_position == ai.anchor_position,
		"identical role capabilities give exact same actual supported placement")
	for actor: FielderController in actors:
		actor.reaction_delay_seconds = 0.0
		actor.begin_play()
		actor.target_position = Vector3(3, 0, 22)
		actor._physics_process(0.1)
	_check(_same_state(human, ai), "human/AI actual movement and time are exactly symmetric")
	var before: Vector3 = human.global_position
	var old_anchor: Vector3 = human.anchor_position
	human.set_anchor(Vector3(-3, 123, 19))
	_check(human.global_position == before
		and human.anchor_position == StadiumHillsideTerrain.point(-3, 19)
		and human.target_position == human.anchor_position,
		"active anchor ingress projects support but preserves original no-teleport semantics")
	for invalid: Vector3 in [Vector3(NAN, 0, 19), Vector3(33, 0, 19), Vector3(0, 0, 26)]:
		var anchor: Vector3 = human.anchor_position
		var target: Vector3 = human.target_position
		human.set_anchor(invalid)
		_check(human.anchor_position == anchor and human.target_position == target
			and human.global_position == before, "invalid/outside/graph-wall anchor cannot partially commit")
	_check(not human.bind_hillside_motion(_field_all_slots(), terrain, 4)
		and human.global_position == before, "healthy active controller refuses an idle-only rebind")
	human.stadium_pool_fielder_route["sentinel"] = 1
	human.stadium_pool_pitcher_route["sentinel"] = 2
	human.end_play()
	_check(not human.active and human.global_position == human.anchor_position
		and human.target_position == human.anchor_position and human.velocity == Vector3.ZERO
		and human._play_elapsed_seconds == 0.0 and human.stadium_pool_fielder_route.is_empty()
		and human.stadium_pool_pitcher_route.is_empty() and human.anchor_position != old_anchor,
		"real end resets to newly projected anchor and clears all ordinary transient state")
	human.begin_play(true, Vector3.BACK)
	var stationary: Vector3 = human.global_position
	human._physics_process(0.5)
	_check(human.global_position == stationary and human.velocity == Vector3.ZERO
		and human.stationary and human.first_step == Vector3.ZERO,
		"bound hillside stationary branch retains actual pose and ignores first step")
	human.end_play()
	human.begin_play(false, Vector3.BACK)
	_check(human.global_position == human.anchor_position and human.target_position == human.anchor_position
		and human._play_elapsed_seconds == 0.0 and human.first_step == Vector3.BACK,
		"real begin freshly supported reset preserves requested forced direction")
	human.queue_free()
	ai.queue_free()
	await _barrier()


func _trace(actor: FielderController, row: Dictionary, rate: int) -> void:
	_prepare(actor, row)
	var path: Array[Vector3] = [actor.global_position]
	var exact: bool = true
	var supported: bool = true
	var bounded: bool = true
	var measured: float = 0.0
	var budget: float = 0.0
	var allowance: float = 0.0
	var delta: float = 1.0 / float(rate)
	for frame in range(int(rate * 0.5)):
		var previous: Vector3 = actor.global_position
		var displacement: Vector3 = actor.target_position - previous
		displacement.y = 0.0
		var candidate: Vector3 = previous.move_toward(previous + displacement, actor.move_speed_mps * delta)
		candidate = _graph.clip(previous, candidate)
		var expected: Dictionary = _source_surface_path(previous, candidate, actor.move_speed_mps * delta)
		actor._physics_process(delta)
		var actual: Dictionary = actor.hillside_motion.last_path
		if actual.is_empty() or actor.hillside_motion_blocked():
			push_error("Hill trace refused: " + row.name + _describe(actor))
			exact = false
			bounded = false
			break
		exact = exact and not actor.hillside_motion_blocked() and actor.global_position == expected.position \
			and actor.velocity == (actor.global_position - previous) / maxf(delta, 0.000001) \
			and actual.path == expected.path and actual.position == actor.global_position \
			and actor.stadium_pool_fielder_route.is_empty()
		var sample: Dictionary = _path_measure(actual.path)
		measured += sample.travel
		budget += actor.move_speed_mps * delta
		allowance += sample.allowance
		bounded = bounded and sample.valid and sample.travel <= actor.move_speed_mps * delta + sample.allowance \
			and sample.travel == float(actual.travel)
		for point_value: Vector3 in actual.path:
			supported = supported and absf(point_value.y - StadiumHillsideTerrain.support_height(
				Vector2(point_value.x, point_value.z))) <= StadiumHillsideTerrain.EPS
		for index in range(1, actual.path.size()):
			path.append(actual.path[index])
	_check(exact, "exact retained source arc endpoint/path and actual velocity: " + row.name + ":" + str(rate) + _describe(actor))
	_check(supported and bounded and absf(measured - budget) <= allowance,
		"unrestricted equal surface speed and piecewise support: " + row.name + ":" + str(rate))
	_emit(row.name, rate, path, budget, measured, allowance, "actual-controller-hill")


func _hill_restrictions(actor: FielderController) -> void:
	var rows: Array[Dictionary] = [
		{"name": "hill-target-stop", "start": Vector3(0, 0, 20), "target": Vector3(0, 0, 20.03), "delta": 0.5},
		{"name": "hill-graph-clip", "start": Vector3(0, 0, 25.4), "target": Vector3(0, 0, 30), "delta": 0.75},
		{"name": "hill-static-obstacle", "start": Vector3(-2, 0, 20), "target": Vector3(2, 0, 20), "delta": 0.5,
			"obstacles": [{"center": Vector3(0, 0, 20), "radius": 0.9}]},
		{"name": "hill-moving-defender", "start": Vector3(-2, 0, 19), "target": Vector3(2, 0, 19), "delta": 0.5,
			"mound": 19.0},
	]
	var other: Node3D = Node3D.new()
	add_child(other)
	for row: Dictionary in rows:
		_prepare(actor, row)
		if row.has("mound"):
			other.global_position = Vector3(0, 0, 19.2)
			actor.pitcher_defender = other
		var previous: Vector3 = actor.global_position
		var legal: Dictionary = _legacy_tick(actor, row.delta)
		actor._physics_process(row.delta)
		var actual: Dictionary = actor.hillside_motion.last_path
		var xz: float = Vector2(actor.global_position.x - previous.x, actor.global_position.z - previous.z).length()
		var allowed: float = Vector2(legal.position.x - previous.x, legal.position.z - previous.z).length()
		_check(not actor.hillside_motion_blocked() and xz <= allowed
			and actor.velocity == (actor.global_position - previous) / row.delta
			and StadiumDefenderRoutes.clear(previous, actor.global_position, actor.stadium_obstacles),
			"actual hill motion stays within original legal segment budget: " + row.name + _describe(actor))
		if row.name == "hill-target-stop":
			_check(actor.global_position == previous and actor.velocity == Vector3.ZERO,
				"existing 0.05 target threshold stops without spending surface distance")
		elif row.name == "hill-graph-clip":
			_check(actor.global_position.z == legal.position.z
				and actor.global_position.z <= 26.0 - StadiumRecipeBoundary.DEFENDER_RADIUS
				and actor.global_position.y == StadiumHillsideTerrain.point(actor.global_position.x,
					actor.global_position.z).y, "deeper-center exact clipped XZ with sampled Y and0.54 setback")
		elif row.has("mound"):
			_check(DefenderSpacing.segment_distance_xz(other.global_position, previous, actor.global_position)
				>= DefenderSpacing.MOUND_CLEARANCE_M, "moving other defender keeps unchanged XZ separation")
		else:
			_check(actor.global_position != previous and actor.stadium_pool_fielder_route.is_empty(),
				"ordinary Hillside obstacle route advances statelessly without a fabricated Pool row")
		var path: Array = [previous] if row.name == "hill-target-stop" else actual.get("path", [previous])
		var sample: Dictionary = _path_measure(path)
		_emit(row.name, 0, path, row.delta * actor.move_speed_mps, sample.travel,
			sample.allowance, "actual-controller-restriction")
	other.queue_free()


func _hill_forced_step(actor: FielderController) -> void:
	var row: Dictionary = {"start": Vector3(0, 0, 18), "target": Vector3(0, 0, 24)}
	_prepare(actor, row)
	var previous: Vector3 = actor.global_position
	var expected: Dictionary = StadiumHillsideLocomotion.step(previous, Vector2(0, 1), 4.6 * 0.2)
	FielderFirstStep.advance(actor, Vector3.BACK, 0.2)
	_check(actor.global_position == expected.position and actor.hillside_motion.last_path.get("path", []) == expected.path
		and actor.velocity == (actor.global_position - previous) / 0.2,
		"ordinary terrain does not spuriously block retained sphere at feet plus0.5" + _describe(actor))
	var blocker: StaticBody3D = _box(StadiumHillsideTerrain.point(0, 20) + Vector3.UP * 0.5,
		Vector3(1, 1, 0.2))
	await _barrier()
	row["start"] = Vector3(0, 0, 19)
	_prepare(actor, row)
	previous = actor.global_position
	var clear_arc: Dictionary = StadiumHillsideLocomotion.step(previous, Vector2(0, 1), 4.6 * 0.6)
	var clipped_expected: Dictionary = _hill_first_expected(actor, Vector3.BACK, 0.6)
	FielderFirstStep.advance(actor, Vector3.BACK, 0.6)
	var path: Array = actor.hillside_motion.last_path.get("path", [])
	var sample: Dictionary = _path_measure(path)
	_check(not actor.hillside_motion_blocked() and actor.global_position.x == previous.x
		and actor.global_position.z > previous.z and actor.global_position.z < clear_arc.position.z
		and actor.global_position.z < 20.0 and sample.travel < 4.6 * 0.6,
		"actual uphill sphere restriction clips at first obstruction without steering")
	_check(actor.global_position == clipped_expected.position and path == clipped_expected.path
		and absf(actor.global_position.y - StadiumHillsideTerrain.support_height(
		Vector2(actor.global_position.x, actor.global_position.z))) <= StadiumHillsideTerrain.EPS
		and actor.velocity == (actor.global_position - previous) / 0.6,
		"partial forced sweep re-evaluates support and actual endpoint velocity")
	_emit("hill-forced-sphere", 0, path, 4.6 * 0.6, sample.travel, sample.allowance, "actual-controller-first-step")
	blocker.queue_free()
	await _barrier()


	var restrictions: Array[Dictionary] = [
		{"name": "mound", "start": Vector3(0, 0, 18), "target": Vector3(0, 0, 24), "mound": 20.0},
		{"name": "obstacle", "start": Vector3(-3, 0, 20), "target": Vector3(-3, 0, 24),
			"obstacles": [{"center": Vector3(-3, 0, 21), "radius": 0.6}]},
		{"name": "boundary", "start": Vector3(0, 0, 25), "target": Vector3(0, 0, 30)},
	]
	for restriction: Dictionary in restrictions:
		_prepare(actor, restriction)
		previous = actor.global_position
		clipped_expected = _hill_first_expected(actor, Vector3.BACK, 0.6)
		FielderFirstStep.advance(actor, Vector3.BACK, 0.6)
		_check(actor.global_position == clipped_expected.position
			and actor.hillside_motion.last_path.get("path", []) == clipped_expected.path
			and actor.global_position.x == previous.x and actor.global_position.z > previous.z,
			"exact source per-strip forced clipping without steering: " + restriction.name)
	_prepare(actor, {"start": Vector3(0, 0, 18), "target": Vector3(0, 0, 24)})
	previous = actor.global_position
	clipped_expected = _hill_first_expected(actor, Vector3.BACK * 0.5, 0.2)
	FielderFirstStep.advance(actor, Vector3.BACK * 0.5, 0.2)
	_check(actor.global_position == clipped_expected.position
		and actor.hillside_motion.last_path.get("budget", -1.0) == 0.5 * actor.move_speed_mps * 0.2,
		"forced nonunit heading retains its requested magnitude")


func _hill_timing(actor: FielderController) -> void:
	_prepare(actor, {"start": Vector3(0, 0, 18), "target": Vector3(4, 0, 21),
		"reaction": 0.35, "first_step": Vector3.BACK})
	var exact: bool = true
	var positions: Array[Vector3] = [actor.global_position]
	for index in range(5):
		var delta: float = 0.1 if index < 3 else 0.05
		var previous: Vector3 = actor.global_position
		var expected: Vector3 = previous
		if index < 2:
			expected = _hill_first_expected(actor, Vector3.BACK, delta).position
		elif index == 4:
			var legal: Dictionary = _legacy_tick(actor, delta)
			expected = _source_surface_path(previous, legal.position, actor.move_speed_mps * delta).position
		actor._physics_process(delta)
		exact = exact and actor.global_position == expected \
			and actor.velocity == (expected - previous) / delta
		positions.append(actor.global_position)
	_check(exact and actor.pursuit_ready(), "hill real forced step/wait/pursuit preserves exact ordinary transition times")
	_check(positions[1].z > positions[0].z and positions[2].z > positions[1].z
		and positions[3] == positions[2] and positions[4] == positions[3]
		and positions[5].x > positions[4].x, "hill explicit expected transition positions")


func _scheduled_delivery(actor: FielderController) -> void:
	_prepare(actor, {"start": Vector3(0, 0, 19), "target": Vector3(0, 0, 23)})
	var previous: Vector3 = actor.global_position
	actor.set_physics_process(true)
	await _barrier()
	actor.set_physics_process(false)
	var path: Array[Vector3] = [previous]
	for z: float in StadiumHillsideTerrain.knots():
		if z > previous.z and z < actor.global_position.z:
			path.append(StadiumHillsideTerrain.point(0, z))
	path.append(actor.global_position)
	var sample: Dictionary = _path_measure(path)
	var budget: float = actor.move_speed_mps * actor._play_elapsed_seconds
	_check(actor._play_elapsed_seconds > 0.0 and actor.global_position.z > previous.z
		and not actor.hillside_motion_blocked() and not actor.is_physics_processing(),
		"actual enabled engine physics delivery invokes the ordinary movement hook")
	_check(sample.valid and absf(sample.travel - budget) <= sample.allowance
		and absf(actor.global_position.y - StadiumHillsideTerrain.point(0, actor.global_position.z).y) <= StadiumHillsideTerrain.EPS,
		"scheduled actual motion preserves supported surface budget without global tick-rate changes")
	_emit("scheduled-physics", 0, path, budget, sample.travel, sample.allowance, "engine-scheduled-controller")


# Source-expected prefix, built without calling the adapter under test.
func _source_surface_path(previous: Vector3, candidate: Vector3, budget: float) -> Dictionary:
	var heading: Vector2 = Vector2(candidate.x - previous.x, candidate.z - previous.z)
	var generated: Dictionary = StadiumHillsideLocomotion.step(previous, heading, budget)
	var path: Array[Vector3] = [previous]
	for index in range(1, generated.path.size()):
		var point_value: Vector3 = generated.path[index]
		if Vector2(point_value.x - previous.x, point_value.z - previous.z).length() >= heading.length():
			path.append(StadiumHillsideTerrain.point(candidate.x, candidate.z))
			break
		path.append(point_value)
	return {"position": path[-1], "path": path}


# Independent expected per-strip first-step query using the retained shape/mask/clip policy.
func _hill_first_expected(actor: FielderController, direction: Vector3, seconds: float) -> Dictionary:
	var heading: Vector2 = Vector2(direction.x, direction.z)
	var arc: Dictionary = StadiumHillsideLocomotion.step(actor.global_position, heading,
		heading.length() * actor.move_speed_mps * maxf(seconds, 0.0))
	var path: Array[Vector3] = [actor.global_position]
	for index in range(1, arc.path.size()):
		var start: Vector3 = path[-1]
		var endpoint: Vector3 = arc.path[index]
		var segment: Vector3 = endpoint - start
		var fraction: float = 1.0
		if actor.pitcher_lane_z != INF and DefenderSpacing.segment_distance_xz(_other(actor), start, endpoint) < DefenderSpacing.MOUND_CLEARANCE_M:
			var low: float = 0.0
			var high: float = 1.0
			for iteration in range(24):
				var middle: float = (low + high) * 0.5
				if DefenderSpacing.segment_distance_xz(_other(actor), start, start + segment * middle) < DefenderSpacing.MOUND_CLEARANCE_M:
					high = middle
				else:
					low = middle
			fraction = low
		var shape: SphereShape3D = SphereShape3D.new()
		shape.radius = 0.25
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY, start + Vector3.UP * 0.5)
		query.motion = segment * fraction
		query.collision_mask = 1
		query.exclude = [actor.get_rid()]
		var safe: PackedFloat32Array = actor.get_world_3d().direct_space_state.cast_motion(query)
		if safe.size() == 2:
			fraction *= safe[0]
		var proposed: Vector3 = endpoint if fraction == 1.0 else start + segment * fraction
		proposed = StadiumDefenderRoutes.clip(start, proposed, actor.stadium_obstacles)
		proposed = actor.stadium_boundary_clip.call(start, proposed)
		if proposed != endpoint:
			path.append(StadiumHillsideTerrain.point(proposed.x, proposed.z))
			break
		path.append(endpoint)
	return {"position": path[-1], "path": path}


func _bare_seams() -> void:
	for rate: int in TRACE_RATES:
		var start: Vector3 = StadiumHillsideTerrain.point(0, 25.99)
		var result: Dictionary = StadiumHillsideLocomotion.step(start, Vector2(0, 1), 4.6 / rate)
		var sample: Dictionary = _path_measure(result.path)
		_check(result.position.z > 26.0 and result.position.y == 2.0
			and result.path.has(StadiumHillsideTerrain.point(0, 26.0))
			and absf(sample.travel - 4.6 / rate) <= sample.allowance,
			"bare terrain ramp-end seam coverage without illegal graph origin: " + str(rate))
		_emit("bare-terrain-z26", rate, result.path, 4.6 / rate,
			sample.travel, sample.allowance, "retained-locomotion-only")


func _support_failures(actor: FielderController, terrain: Node3D) -> void:
	actor.end_play()
	var before: Vector3 = actor.global_position
	_check(not actor.bind_hillside_motion(_field_all_slots(), terrain, 4, "flat-control")
		and actor.global_position == before, "wrong physical profile cannot silently rebind")
	_check(actor.bind_hillside_motion(_field_all_slots(), terrain, 4), "valid explicit rebind after refusal")
	var body: StaticBody3D = terrain.get_node("TerrainCollision") as StaticBody3D
	var shape: CollisionShape3D = body.get_node("ClosedTerrainShape") as CollisionShape3D
	var original_shape: Shape3D = shape.shape
	for fault: String in ["disabled", "layer", "transformed", "replaced-shape"]:
		_prepare(actor, {"start": Vector3(0, 0, 19), "target": Vector3(0, 0, 23)})
		actor._physics_process(0.1)
		before = actor.global_position
		match fault:
			"disabled": shape.disabled = true
			"layer": body.collision_layer = 0
			"transformed": terrain.position.x = 0.25
			"replaced-shape": shape.shape = original_shape.duplicate()
		await _barrier()
		actor._physics_process(0.1)
		_check(actor.hillside_motion_blocked() and actor.global_position == before
			and actor.velocity == Vector3.ZERO, "changed physical support freezes exact last pose: " + fault)
		actor.end_play()
		_check(actor.global_position == before and actor.velocity == Vector3.ZERO
			and actor.hillside_motion_blocked(), "failed reset never teleports/falls toflat: " + fault)
		match fault:
			"disabled": shape.disabled = false
			"layer": body.collision_layer = 1 | StadiumHillsideTerrainModels.QUERY_LAYER
			"transformed": terrain.position = Vector3.ZERO
			"replaced-shape": shape.shape = original_shape
		await _barrier()
		actor._physics_process(0.1)
		_check(actor.hillside_motion_blocked() and actor.global_position == before,
			"support restoration alone cannot resume failed binding: " + fault)
		_check(actor.bind_hillside_motion(_field_all_slots(), terrain, 4)
			and not actor.hillside_motion_blocked(), "explicit supported rebind permits recovery: " + fault)
	_prepare(actor, {"start": Vector3(0, 0, 19), "target": Vector3(0, 0, 23)})
	actor._physics_process(0.1)
	before = actor.global_position
	terrain.queue_free()
	await _barrier()
	actor._physics_process(0.1)
	_check(actor.hillside_motion_blocked() and actor.global_position == before and actor.velocity == Vector3.ZERO,
		"freed retained terrain freezes actual mover")
	var replacement: Node3D = StadiumHillsideTerrainModels.create("hill")
	add_child(replacement)
	await _barrier()
	actor._physics_process(0.1)
	_check(actor.hillside_motion_blocked() and actor.global_position == before,
		"same-signature replacement root cannot be silently adopted")
	actor.end_play()
	_check(actor.bind_hillside_motion(_field_all_slots(), replacement, 4)
		and actor.global_position == StadiumHillsideAnchorContract.anchor(_field_all_slots(), 4).position,
		"explicit replacement-root rebind is required and uses exact current anchor support")
	replacement.queue_free()
	await _barrier()


# Independent retained controller arithmetic. Never calls the new adapter or changed first-step script.
func _legacy_tick(actor: FielderController, delta: float) -> Dictionary:
	var result: Dictionary = {"position": actor.global_position, "velocity": actor.velocity,
		"elapsed": actor._play_elapsed_seconds,
		"route": actor.stadium_pool_fielder_route.duplicate(true),
		"pitcher_route": actor.stadium_pool_pitcher_route.duplicate(true)}
	if not actor.active:
		return result
	var before: float = result.elapsed
	result.elapsed += maxf(0.0, delta)
	if not actor.first_step.is_zero_approx() and before + 0.000001 < SeasonJumpstart.STEP_SECONDS:
		var seconds: float = minf(maxf(0.0, delta), SeasonJumpstart.STEP_SECONDS - before)
		result.position = _legacy_first_step(actor, actor.first_step, seconds)
		if not (actor.first_step * actor.move_speed_mps * maxf(seconds, 0.0)).is_zero_approx():
			result.velocity = (result.position - actor.global_position) / maxf(seconds, 0.000001)
		return result
	if (not actor.first_step.is_zero_approx() and before < actor.reaction_delay_seconds) \
		or actor.stationary or result.elapsed < actor.reaction_delay_seconds:
		result.velocity = Vector3.ZERO
		return result
	var displacement: Vector3 = actor.target_position - actor.global_position
	displacement.y = 0.0
	if displacement.length() <= 0.05:
		result.velocity = Vector3.ZERO
		return result
	var previous: Vector3 = actor.global_position
	var next: Vector3 = previous.move_toward(previous + displacement, actor.move_speed_mps * maxf(0.0, delta))
	if actor.pitcher_lane_z != INF:
		next = DefenderSpacing.step_around_mound(previous, actor.target_position, _other(actor), actor.move_speed_mps * delta)
	if not actor.stadium_obstacles.is_empty():
		var obstacles: Array[Dictionary] = actor.stadium_obstacles.duplicate(true)
		if actor.pitcher_lane_z != INF:
			obstacles.append({"center": _other(actor), "radius": DefenderSpacing.MOUND_CLEARANCE_M})
		next = StadiumDefenderRoutes.owned_pool_step(previous, actor.target_position,
			actor.move_speed_mps * maxf(delta, 0), obstacles, result.route)
	if actor.stadium_boundary_clip.is_valid():
		next = actor.stadium_boundary_clip.call(previous, next)
	result.position = next
	result.velocity = (next - previous) / maxf(delta, 0.000001)
	return result


func _legacy_first_step(actor: FielderController, direction: Vector3, seconds: float) -> Vector3:
	var previous: Vector3 = actor.global_position
	var motion: Vector3 = direction * actor.move_speed_mps * maxf(seconds, 0.0)
	if motion.is_zero_approx():
		return previous
	var fraction: float = 1.0
	if actor.pitcher_lane_z != INF:
		var obstacle: Vector3 = _other(actor)
		if DefenderSpacing.segment_distance_xz(obstacle, previous, previous + motion) < DefenderSpacing.MOUND_CLEARANCE_M:
			var low: float = 0.0
			var high: float = 1.0
			for iteration in range(24):
				var middle: float = (low + high) * 0.5
				if DefenderSpacing.segment_distance_xz(obstacle, previous, previous + motion * middle) < DefenderSpacing.MOUND_CLEARANCE_M:
					high = middle
				else:
					low = middle
			fraction = low
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = 0.25
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, previous + Vector3.UP * 0.5)
	query.motion = motion * fraction
	query.collision_mask = 1
	query.exclude = [actor.get_rid()]
	var safe: PackedFloat32Array = actor.get_world_3d().direct_space_state.cast_motion(query)
	if safe.size() == 2:
		fraction *= safe[0]
	var next: Vector3 = StadiumDefenderRoutes.clip(previous, previous + motion * fraction, actor.stadium_obstacles)
	if actor.stadium_boundary_clip.is_valid():
		next = actor.stadium_boundary_clip.call(previous, next)
	return next


func _other(actor: FielderController) -> Vector3:
	return actor.pitcher_defender.global_position if is_instance_valid(actor.pitcher_defender) \
		else Vector3(0, 0, actor.pitcher_lane_z)


func _matches(actor: FielderController, expected: Dictionary) -> bool:
	return actor.global_position == expected.position and actor.velocity == expected.velocity \
		and actor._play_elapsed_seconds == expected.elapsed \
		and actor.stadium_pool_fielder_route == expected.route \
		and actor.stadium_pool_pitcher_route == expected.pitcher_route


func _same_state(first: FielderController, second: FielderController) -> bool:
	return first.global_position == second.global_position and first.velocity == second.velocity \
		and first._play_elapsed_seconds == second._play_elapsed_seconds \
		and first.active == second.active and first.stationary == second.stationary \
		and first.first_step == second.first_step and first.reaction_ready() == second.reaction_ready() \
		and first.pursuit_ready() == second.pursuit_ready() \
		and first.stadium_pool_fielder_route == second.stadium_pool_fielder_route \
		and first.stadium_pool_pitcher_route == second.stadium_pool_pitcher_route


func _box(at: Vector3, size: Vector3) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	add_child(body)
	body.global_position = at
	return body


func _path_measure(path: Array) -> Dictionary:
	var travel: float = _length(path)
	var valid: bool = not path.is_empty()
	for point_value: Vector3 in path:
		valid = valid and point_value.is_finite() and absf(point_value.x) <= 38.0 \
			and absf(point_value.y) <= 38.0 and absf(point_value.z) <= 38.0
	for index in range(1, path.size()):
		valid = valid and path[index - 1].distance_to(path[index]) <= 8.0
	return {"travel": travel, "valid": valid,
		"allowance": 8.0 * REAL32_EPSILON * 38.0 * float(path.size())}


func _length(path: Array) -> float:
	var result: float = 0.0
	for index in range(1, path.size()):
		result += path[index - 1].distance_to(path[index])
	return result


func _emit(case_name: String, rate: int, path: Array, budget: float, travel: float,
	allowance: float, scope: String) -> void:
	var points: Array = []
	for point_value: Vector3 in path:
		points.append([point_value.x, point_value.y, point_value.z])
	_route_count += 1
	print("HILLSIDE_MOVEMENT_ROUTE " + JSON.stringify({"case": case_name, "rate": rate,
		"path": points, "travel": travel, "budget": budget, "measured_minus_budget": travel - budget,
		"working_arithmetic_allowance": allowance, "scope": scope}))


func _barrier() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame


func _describe(actor: FielderController) -> String:
	return " [pose=%s anchor=%s profile=%s error=%s]" % [actor.global_position,
		actor.anchor_position, actor.hillside_motion.profile if actor.hillside_motion != null else "unbound",
		actor.hillside_motion.last_error if actor.hillside_motion != null else ""]


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(message)
