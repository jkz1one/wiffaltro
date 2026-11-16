extends Node3D
## Full-scale isolated geometry proof. Native physics is tested, not approximated.
## No ownership, scoring, rendered visual acceptance or Night qualification is claimed.

const M = preload("res://src/presentation/stadium/stadium_waterfall_live_models.gd")
const Witness = preload("res://src/presentation/stadium/stadium_waterfall_trap_witness.gd")
const Frozen = preload("res://src/presentation/stadium/stadium_waterfall_models.gd")
const Contract = preload("res://src/tests/stadium_waterfall_contract.gd")
const RADIUS: float = 0.0365
const EPS: float = 0.0002
const EXPECTED_SOLIDS: Array[String] = [
	"BasinFloor",
	"BasinFront",
	"BasinLeft",
	"BasinRight",
	"BasinBack",
	"RockLower",
	"RockMiddle",
	"RockCrownLeft",
	"RockCrownRight",
	"RockShoulderLeft",
	"RockShoulderRight",
	"SpillLip",
	"CatchLedge"
]
const WATER: Array[String] = [
	"Pool",
	"UpperWater",
	"LowerWater",
	"Foam",
	"UpperRillA",
	"UpperRillB",
	"LowerRillA",
	"LowerRillB"
]
var _checks: int = 0
var _failures: Array[String] = []
var _drop_result: Dictionary = {}


func _ready() -> void:
	_contract()
	var model: Node3D = M.create()
	if model == null:
		_check(false, "factory fails closed instead of supplying an unproved basin")
		_finish()
		return
	add_child(model)
	_geometry(model)
	_traps()
	_reach()
	_tampering()
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _physics(model)
	await _native_drop(model)
	model.free()
	_finish()


func _finish() -> void:
	print(
		(
			"ST046_LIVE_MODEL_RESULT "
			+ JSON.stringify(
				{
					"checks": _checks,
					"failures": _failures,
					"scope": "isolated_full_scale_geometry_and_native_physics",
					"meshes": 21,
					"solids": 13,
					"renderer_acceptance": "not_run_headless",
					"ownership_wired": false,
					"night_qualified": false,
					"native_drop": _drop_result
				}
			)
		)
	)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _contract() -> void:
	_check(
		M.VERSION == 1 and M.ITEM == "ST-046" and M.ITEMS == ["ST-046"] and M.LIVE_UNITS == 4,
		"separate versioned four-unit Working candidate identity"
	)
	_check(
		(
			M.create("") == null
			and M.create("ST-005") == null
			and M.envelope("ST-045") == AABB()
			and M.reservation("") == AABB()
			and M.surfaces("ST-045").is_empty()
		),
		"no sibling substitution"
	)
	_check(
		M.envelope() == AABB(Vector3(-4.2, 0, -1.9), Vector3(8.4, 3.8, 3.8)),
		"full original 8.4 by 3.8 by 3.8 metre appearance, never a resized obstacle"
	)
	_check(
		(
			M.reservation() == AABB(Vector3(-4.5, 0, -3.5), Vector3(9, 4, 7))
			and M.reservation().grow(EPS).encloses(M.envelope())
		),
		"adequate 9-wide 7-deep 4-high reserve, separate from physics"
	)
	_check(
		(
			M.surfaces() == ["WATERFALL_STONE"]
			and M.SOLID_IDS == EXPECTED_SOLIDS
			and M.solid_specs().size() == 13
		),
		"only the thirteen actual solid stone and basin pieces collide"
	)
	for id: String in WATER:
		_check(M.solid_bounds(id) == AABB(), "visual water/rill/foam is never a solid: " + id)
	_check(
		M.geometry_contract_valid(),
		"geometry-derived closed rim, free channel and unreachable subset are consistent"
	)
	var volume: AABB = M.basin_volume()
	_check(
		(
			volume.position.is_equal_approx(Vector3(-3.8, 0.2, -1.6))
			and volume.size.is_equal_approx(Vector3(7.6, 0.5, 1.0))
		),
		"channel bounds come from real floor, front rim and lower rock"
	)
	_check(
		(
			M.trap_apertures().size() == 1
			and M.trap_apertures()[0].id == "BASIN_TOP"
			and M.trap_apertures()[0].inward == Vector3.DOWN
			and is_equal_approx(M.trap_apertures()[0].origin.y, 0.7)
		),
		"one actual open top, not four imaginary side apertures"
	)


func _geometry(model: Node3D) -> void:
	_check(M.valid(model), "fresh full-scale live model validates")
	_check(
		(
			model.get_child_count() == 3
			and model.transform == Transform3D.IDENTITY
			and model.get_node("Visual").transform == Transform3D.IDENTITY
			and model.get_node("Collision").transform == Transform3D.IDENTITY
		),
		"exact original visual and isolated collision branches have no hidden scaling or displacement"
	)
	var visual: Node3D = model.get_node("Visual")
	_check(
		Frozen.valid(visual) and Contract.valid(visual),
		"independent frozen twenty-one-part art contract validates inside live wrapper"
	)
	var bounds: AABB = AABB()
	var first: bool = true
	for id: String in Contract.EXPECTED:
		var mesh: MeshInstance3D = visual.get_node(id)
		var local_bounds: AABB = mesh.transform * mesh.mesh.get_aabb()
		bounds = local_bounds if first else bounds.merge(local_bounds)
		first = false
	_check(
		(
			bounds.position.is_equal_approx(M.envelope().position)
			and bounds.size.is_equal_approx(M.envelope().size)
		),
		"actual visible meshes span original full-size envelope"
	)
	var body: StaticBody3D = model.get_node("Collision/WATERFALL_STONE")
	_check(
		(
			body.collision_layer == 1
			and body.collision_mask == 0
			and body.get_child_count() == 13
			and body.get_meta("surface_role") == "LIVE_RICOCHET"
		),
		"one immobile body exposes thirteen independent solid shapes"
	)
	for id: String in EXPECTED_SOLIDS:
		var shape: CollisionShape3D = body.get_node(id)
		var mesh: MeshInstance3D = visual.get_node(id)
		_check(
			(
				shape.shape is BoxShape3D
				and shape.shape.size == Contract.EXPECTED[id][1]
				and shape.position == Contract.EXPECTED[id][0]
				and shape.position == mesh.position
				and shape.shape.size == mesh.mesh.size
				and shape.shape.margin == 0.0
				and not shape.disabled
				and shape.transform.basis == Basis.IDENTITY
			),
			"native box exactly matches frozen visible stone: " + id
		)
	_check(
		(
			model.find_children("*", "CollisionShape3D", true, false).size() == 13
			and model.find_children("*", "CollisionObject3D", true, false).size() == 1
		),
		"no enclosing reservation, water-surface collider or hidden trigger body"
	)
	var carrier: Node3D = model.get_node("BasinTrap")
	_check(
		(
			carrier.get_class() == "Node3D"
			and carrier.get_child_count() == 0
			and carrier.get_meta("volume_id") == M.TRAP_ID
			and carrier.get_meta("volume") == M.basin_volume()
			and carrier.get_meta("pocket") == M.POCKET
			and carrier.get_meta("apertures") == M.trap_apertures()
		),
		"basin observation carrier is metadata only and does not manufacture contact"
	)
	var archive: Node3D = Frozen.create()
	var second: Node3D = M.create()
	var scenery: Node3D = M.create(M.ITEM, false)
	add_child(second)
	add_child(scenery)
	var original: PackedByteArray = _visual_signature(archive)
	_check(
		(
			original == _visual_signature(visual)
			and original == _visual_signature(second.get_node("Visual"))
			and original == _visual_signature(scenery.get_node("Visual"))
		),
		"archived, live and scenery geometry/material signatures are identical"
	)
	_check(
		(
			Frozen.valid(archive)
			and Contract.valid(archive)
			and archive.find_children("*", "CollisionObject3D", true, false).is_empty()
			and archive.find_children("*", "CollisionShape3D", true, false).is_empty()
			and archive.get_meta("obstacle_units") == 0
		),
		"original archived factory remains unchanged and collider-free"
	)
	_check(
		(
			M.valid(scenery, false)
			and not M.valid(scenery)
			and scenery.get_node("Collision").get_child_count() == 0
			and not scenery.has_node("BasinTrap")
		),
		"non-live wrapper has neither collision nor trapping authority"
	)
	var independent: bool = true
	for id: String in Contract.EXPECTED:
		independent = (
			independent
			and visual.get_node(id).mesh != second.get_node("Visual/" + id).mesh
			and (
				visual.get_node(id).material_override
				!= second.get_node("Visual/" + id).material_override
			)
		)
	for id: String in EXPECTED_SOLIDS:
		independent = (
			independent
			and body.get_node(id).shape != second.get_node("Collision/WATERFALL_STONE/" + id).shape
		)
	_check(independent, "owned candidates share no mesh, material or native shape resources")
	second.get_node("Visual/Pool").material_override.albedo_color = Color.MAGENTA
	second.get_node("Collision/WATERFALL_STONE/BasinFloor").shape.size = Vector3.ONE
	_check(
		_visual_signature(visual) == original and M.valid(model) and not M.valid(second),
		"mutating one candidate cannot alter another or the frozen source"
	)
	var fresh: Node3D = Frozen.create()
	_check(
		_visual_signature(fresh) == original and Frozen.valid(fresh),
		"live construction never modifies original factory output"
	)
	fresh.free()
	archive.free()
	second.free()
	scenery.free()


func _traps() -> void:
	var start: Vector3 = Vector3(0, 1.1, -1.05)
	var finish: Vector3 = Vector3(0, 0.2 + RADIUS, -1.05)
	var entry: Dictionary = M.trap_entry_local(start, finish, RADIUS)
	_check(
		(
			not entry.is_empty()
			and entry.volume_id == M.TRAP_ID
			and entry.aperture == "BASIN_TOP"
			and entry.fraction > 0
			and entry.fraction < 1
			and entry.position.distance_to(start.lerp(finish, entry.fraction)) < EPS
			and absf(entry.position.y + RADIUS - 0.7) < EPS
		),
		"witnessed downward entry waits until the entire sphere crosses actual rim-top plane"
	)
	_check(
		(
			not entry.has("role")
			and not entry.has("terminal")
			and not entry.has("dead")
			and not M.trap_contains_local(entry.position, RADIUS)
		),
		"admission alone never declares a trap or terminates play"
	)
	_check(
		M.basin_contains_local(finish, RADIUS) and M.trap_contains_local(finish, RADIUS),
		"floor-supported sphere can occupy the narrow genuinely unreachable pocket"
	)
	_check(
		(
			M.basin_contains_local(Vector3(0, 0.45, -1.05), RADIUS)
			and not M.trap_contains_local(Vector3(0, 0.45, -1.05), RADIUS)
		),
		"quiet airborne or water-height sphere cannot be a settled trap"
	)
	for radius: float in [0.02, RADIUS, 0.08]:
		_check(
			M.trap_contains_local(Vector3(0, 0.2 + radius, -1.075), radius),
			"pocket is full-sphere/radius aware, not a baseball-centre-only box %.4f" % radius
		)
	_check(
		not M.trap_contains_local(Vector3(0, 0.4, -1.075), 0.2),
		"oversized sphere cannot fit the narrow core"
	)
	for point: Vector3 in [
		Vector3(-3.3 + RADIUS, 0.2 + RADIUS, -1.075),
		Vector3(3.3 - RADIUS, 0.2 + RADIUS, -1.075),
		Vector3(0, 0.2 + RADIUS, -1.25 + RADIUS),
		Vector3(0, 0.2 + RADIUS, -0.9 - RADIUS),
		Vector3(0, 0.2 + RADIUS - 0.002, -1.075),
		Vector3(0, 0.2 + RADIUS + 0.006, -1.075),
		Vector3(0, 0.2 + RADIUS, -1.5),
		Vector3(0, 0.2 + RADIUS, -0.7),
		Vector3(3.7, 0.2 + RADIUS, -1.05),
		Vector3(0, 0.75, 0.5),
		Vector3(0, 0.4, -1.75)
	]:
		_check(
			not M.trap_contains_local(point, RADIUS),
			"solid, floating, near-rim or pocket-edge point never trapped: " + str(point)
		)
	for point: Vector3 in [
		Vector3(-3.8 + RADIUS, 0.4, -1),
		Vector3(3.8 - RADIUS, 0.4, -1),
		Vector3(0, 0.4, -1.6 + RADIUS),
		Vector3(0, 0.4, -0.6 - RADIUS),
		Vector3(0, 0.7 - RADIUS, -1),
		Vector3(0, 0.2 + RADIUS - 0.002, -1)
	]:
		_check(
			not M.basin_contains_local(point, RADIUS),
			"full sphere requires actual channel clearance: " + str(point)
		)
	var rejects: Array[Array] = [
		[finish, start, RADIUS],
		[Vector3(0, 0.5, -1.05), finish, RADIUS],
		[finish, finish, RADIUS],
		[Vector3(0, 0.4, -3), finish, RADIUS],
		[Vector3(-5, 0.4, -1.05), finish, RADIUS],
		[Vector3(0, 2, 0.5), finish, RADIUS],
		[Vector3(0, 3, -0.7), Vector3(0, 0.3, -0.7), RADIUS],
		[Vector3(0, 0.9, -3), Vector3(0, 0.3, -1), RADIUS],
		[Vector3(0, 1, -1.6 + RADIUS), Vector3(0, 0.4, -1.6 + RADIUS), RADIUS],
		[Vector3(0, 1, -0.6 - RADIUS), Vector3(0, 0.4, -0.6 - RADIUS), RADIUS],
		[Vector3(3.8 - RADIUS, 1, -1), Vector3(3.8 - RADIUS, 0.4, -1), RADIUS],
		[Vector3(0, 1, -1), Vector3(0, 0.7 - RADIUS, -1), RADIUS],
		[start, finish, 0.0],
		[start, finish, -RADIUS],
		[start, finish, NAN],
		[start, finish, INF],
		[start, finish, 0.25],
		[Vector3(NAN, 1, -1), finish, RADIUS],
		[start, Vector3(0, -INF, -1), RADIUS],
		[Vector3(0, 3.0e38, -1), Vector3(0, -3.0e38, -1), RADIUS]
	]
	for index in range(rejects.size()):
		var row: Array = rejects[index]
		_check(
			M.trap_entry_local(row[0], row[1], row[2]).is_empty(),
			"non-top, solid-crossing, partial, already-inside or malformed entry rejects %d" % index
		)
	var through: Dictionary = M.trap_entry_local(start, Vector3(0, -2, -1.05), RADIUS)
	_check(
		(
			not through.is_empty()
			and not M.basin_contains_local(Vector3(0, -2, -1.05), RADIUS)
			and not through.has("terminal")
		),
		"swept admission does not turn floor tunnelling or a pass-through into an automatic result"
	)
	_check(
		not M.trap_entry_local(Vector3(0, 0.68, -1.05), Vector3(0, 0.62, -1.05), RADIUS).is_empty(),
		(
			"trailing-sphere crossing can be witnessed over multiple physics frames without "
			+ "requiring a teleport"
		)
	)
	for point: Vector3 in [Vector3(NAN, 0, 0), Vector3(INF, 0, 0), Vector3.ZERO]:
		_check(
			not M.trap_contains_local(point, RADIUS),
			"invalid or nonsupported sphere never satisfies pocket"
		)
	for radius: float in [0.0, -RADIUS, NAN, INF]:
		_check(
			(
				not M.basin_contains_local(finish, radius)
				and not M.trap_contains_local(finish, radius)
				and not M.segment_clear_of_solids(start, finish, radius)
			),
			"degenerate sphere fails closed"
		)


func _reach() -> void:
	_check(
		StadiumDefenderRoutes.BODY_RADIUS == M.BODY_RADIUS and M.MAX_DEFENDER_REACH == 0.76,
		"proof uses retained 0.32m defender body clearance and maximum 0.76m reach"
	)
	var minimum: float = INF
	for x: float in [-3.3 + RADIUS + 0.001, 0.0, 3.3 - RADIUS - 0.001]:
		for z: float in [-1.25 + RADIUS + 0.001, -1.075, -0.9 - RADIUS - 0.001]:
			var point: Vector3 = Vector3(x, 0.2 + RADIUS, z)
			var clearance: float = M.minimum_exterior_reach_distance_local(point, RADIUS)
			minimum = minf(minimum, clearance)
			_check(
				(
					M.trap_contains_local(point, RADIUS)
					and clearance >= 0.97 - EPS
					and clearance > M.MAX_DEFENDER_REACH + 0.20
				),
				"analytical all-exterior-foot reach bound is conservative at each core witness"
			)
			# Dense exterior feet are an independent check of the closed-form lower bound.
			for index in range(121):
				var t: float = index / 120.0
				for foot: Vector3 in [
					Vector3(lerpf(-4.2, 4.2, t), 0, -2.22),
					Vector3(lerpf(-4.2, 4.2, t), 0, 2.22),
					Vector3(-4.52, 0, lerpf(-1.9, 1.9, t)),
					Vector3(4.52, 0, lerpf(-1.9, 1.9, t))
				]:
					if (
						not M.defender_foot_legal_local(foot)
						or (
							Vector2(point.x - foot.x, point.z - foot.z).length() - RADIUS
							< clearance - EPS
						)
					):
						_check(false, "exterior legal feet contradict analytical reach proof")
	_check(
		minimum > 0.96, "all core points retain more than 20cm margin beyond maximum glove reach"
	)
	_check(
		(
			M.defender_foot_legal_local(Vector3(0, 0, -2.22))
			and not M.defender_foot_legal_local(Vector3(0, 0, -2.20))
			and not M.defender_foot_legal_local(Vector3(0, 0, -1.0))
		),
		"front rim excludes grounded body centres, not just ball centres"
	)
	_check(
		(
			M.defender_foot_legal_local(Vector3(4.2 + 0.32 / sqrt(2.0), 0, 1.9 + 0.32 / sqrt(2.0)))
			and not M.defender_foot_legal_local(Vector3(4.3, 0, 2.0))
		),
		"rounded legal exterior corner follows true body radius, not enlarged square"
	)
	_check(
		(
			(
				M.minimum_exterior_reach_distance_local(Vector3(0, 0.24, -1.55), RADIUS)
				< M.MAX_DEFENDER_REACH
			)
			and not M.trap_contains_local(Vector3(0, 0.2 + RADIUS, -1.55), RADIUS)
		),
		"reachable near-front water explicitly cannot claim unreachable trap"
	)
	_check(
		(
			not M.defender_foot_legal_local(Vector3(NAN, 0, 0))
			and not M.defender_foot_legal_local(Vector3(0, 1, -3))
			and M.minimum_exterior_reach_distance_local(Vector3(INF, 0, 0), RADIUS) == -INF
		),
		"unproved raised/climbing feet and malformed reach queries fail closed"
	)
	print(
		(
			"ST046_LIVE_REACH_PROOF "
			+ JSON.stringify(
				{
					"minimum_ball_surface_distance": minimum,
					"maximum_defender_reach": M.MAX_DEFENDER_REACH,
					"body_radius": M.BODY_RADIUS,
					"basis": "actual_closed_basin_perimeter_not_reservation",
					"scope": "grounded_exterior_defenders"
				}
			)
		)
	)


func _tampering() -> void:
	var mutations: Array[Callable] = [
		func(n: Node3D) -> void: n.scale = Vector3(0.5, 0.5, 0.5),
		func(n: Node3D) -> void: n.scale = Vector3(-1, 1, 1),
		func(n: Node3D) -> void: n.visible = false,
		func(n: Node3D) -> void: n.set_meta("obstacle_units", 4.0),
		func(n: Node3D) -> void: n.set_meta("night_qualified", true),
		func(n: Node3D) -> void: n.get_node("Visual").position.x = 0.1,
		func(n: Node3D) -> void: n.get_node("Visual/RockLower").mesh.size.x += 0.01,
		func(n: Node3D) -> void: n.get_node("Visual/Pool").material_override.roughness = 0.2,
		func(n: Node3D) -> void: n.get_node("Collision").scale.y = 0.9,
		func(n: Node3D) -> void: n.get_node("Collision/WATERFALL_STONE").collision_layer = 0,
		func(n: Node3D) -> void:
			n.get_node("Collision/WATERFALL_STONE").constant_linear_velocity.x = 0.1,
		func(n: Node3D) -> void:
			n.get_node("Collision/WATERFALL_STONE/BasinFloor").shape.size.y = 0.3,
		func(n: Node3D) -> void: n.get_node("Collision/WATERFALL_STONE/BasinFront").disabled = true,
		func(n: Node3D) -> void:
			n.get_node("Collision/WATERFALL_STONE/SpillLip").shape.margin = 0.04,
		func(n: Node3D) -> void:
			n.get_node("Collision/WATERFALL_STONE/CatchLedge").position.z += 0.01,
		func(n: Node3D) -> void: n.get_node("BasinTrap").set_meta("maximum_reach", 0.1),
		func(n: Node3D) -> void: n.get_node("BasinTrap").set_meta("pocket", Rect2(-4, -2, 8, 4)),
		func(n: Node3D) -> void: n.get_node("BasinTrap").position.y = 0.1,
		func(n: Node3D) -> void:
			n.get_node("Collision/WATERFALL_STONE").add_child(CollisionShape3D.new())
	]
	for index in range(mutations.size()):
		var model: Node3D = M.create()
		add_child(model)
		mutations[index].call(model)
		_check(
			not M.valid(model),
			"malformed live proof cannot survive exact visual/physical seal %d" % index
		)
		model.free()
	_check(not M.valid(null), "null model fails closed")


func _physics(model: Node3D) -> void:
	var cases: Array[Array] = [
		[
			Vector3(0, 1.1, -1.05),
			Vector3(0, 0.25, -1.05),
			false,
			"true open-top descent reaches free channel"
		],
		[Vector3(-5, 0.4, -1), Vector3(-3, 0.4, -1), true, "left real basin rim blocks side entry"],
		[Vector3(5, 0.4, -1), Vector3(3, 0.4, -1), true, "right real basin rim blocks side entry"],
		[Vector3(0, 0.4, -3), Vector3(0, 0.4, -1), true, "front real basin rim ricochets"],
		[Vector3(0, 0.4, 3), Vector3(0, 0.4, 1.4), true, "rear real basin rim ricochets"],
		[
			Vector3(0, 0.4, -1),
			Vector3(0, 0.1, -1),
			true,
			"actual basin floor supports settled sphere"
		],
		[Vector3(0, 0.9, -2), Vector3(0, 0.9, 0), true, "lower rock has exact exposed solid face"],
		[Vector3(0, 1.8, -2), Vector3(0, 1.8, 0.5), true, "middle rock remains physical"],
		[
			Vector3(0, 3, -0.7),
			Vector3(0, 0.4, -0.7),
			true,
			"real catch ledge prevents false top-entry witness"
		],
		[
			Vector3(-1, 0.38, -0.95),
			Vector3(1, 0.38, -0.95),
			false,
			"pool and foam never create collision"
		],
		[
			Vector3(-1, 0.9, -0.78),
			Vector3(1, 0.9, -0.78),
			false,
			"lower falling water and rills never create collision"
		],
		[
			Vector3(-1, 2.5, -0.416),
			Vector3(1, 2.5, -0.416),
			false,
			"upper falling water and rills never create collision"
		],
		[
			Vector3(4.35, 0.4, -3),
			Vector3(4.35, 0.4, 3),
			false,
			"empty reserve margin is not an enclosing collider"
		],
		[Vector3(-4, 4.0, -3), Vector3(4, 4.0, 3), false, "above original crown remains clear"],
		[
			Vector3(0, 0.7 + RADIUS + 0.01, -3),
			Vector3(0, 0.7 + RADIUS + 0.01, -1),
			false,
			"above rim lip is truly open"
		],
		[
			Vector3(0, 0.7 + RADIUS - 0.01, -3),
			Vector3(0, 0.7 + RADIUS - 0.01, -1),
			true,
			"radius-aware rim graze contacts actual stone"
		]
	]
	for row: Array in cases:
		_check(_blocked(row[0], row[1], RADIUS) == row[2], row[3])
	var clear: bool = true
	for x: float in [-3.6, 0.0, 3.6]:
		for z: float in [-1.5, -1.1, -0.7]:
			for y: float in [0.2 + RADIUS + 0.004, 0.4, 0.7 - RADIUS - 0.02]:
				var point: Vector3 = Vector3(x, y, z)
				clear = (
					clear
					and M.basin_contains_local(point, RADIUS)
					and not _blocked(point, point, RADIUS)
				)
	_check(
		clear, "twenty-seven free-channel full spheres are outside every actual native stone solid"
	)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		Vector3(0, 0.5, -1.05), Vector3(0, 0, -1.05), 1
	)
	var floor_hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	_check(
		(
			not floor_hit.is_empty()
			and absf(floor_hit.position.y - 0.2) < EPS
			and floor_hit.normal.y > 0.99
		),
		"native support contact lies on real visible floor at y=0.20, not water surface"
	)
	var contact_query: PhysicsShapeQueryParameters3D = _query(
		Vector3(0, 0.4, -1.9 - RADIUS + 0.006), RADIUS
	)
	var contact: Dictionary = get_world_3d().direct_space_state.get_rest_info(contact_query)
	_check(
		not contact.is_empty() and contact.normal.z < -0.99 and absf(contact.point.z + 1.9) < 0.002,
		"native sphere contact provides exact front-stone contact point and outward normal"
	)
	# A grounded radius-.32 sphere has its centre at .32 and spans rim height.
	_check(
		(
			not _blocked(Vector3(0, 0.32, -2.225), Vector3(0, 0.32, -2.225), 0.32)
			and _blocked(Vector3(0, 0.32, -2.20), Vector3(0, 0.32, -2.20), 0.32)
		),
		"real native rim blocks a defender body exactly at the analytical legal exterior boundary"
	)
	await _each_native_solid(model)
	model.transform = Transform3D(Basis.IDENTITY, Vector3(-10.2, 0, 19.4))
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(
		(
			M.valid(model)
			and not _blocked(
				model.to_global(Vector3(0, 1.1, -1.05)),
				model.to_global(Vector3(0, 0.25, -1.05)),
				RADIUS
			)
		),
		"candidate centre(-10.2,0,19.4) yaw0 keeps actual open aperture"
	)
	_check(
		_blocked(
			model.to_global(Vector3(0, 0.4, -3)), model.to_global(Vector3(0, 0.4, -1)), RADIUS
		),
		"candidate placement preserves native rim contact without scaled geometry"
	)
	_check(
		not (
			M
			. trap_entry_local(
				model.to_local(model.to_global(Vector3(0, 1.1, -1.05))),
				model.to_local(model.to_global(Vector3(0, 0.25, -1.05))),
				RADIUS
			)
			. is_empty()
		),
		"translated live candidate has identical local witnessed-entry semantics"
	)


func _each_native_solid(model: Node3D) -> void:
	var body: StaticBody3D = model.get_node("Collision/WATERFALL_STONE")
	for id: String in EXPECTED_SOLIDS:
		# Isolate each genuine attached shape to prove even occluded rocks/ledges,
		# not merely whichever outer solid a broad sphere sweep hits first.
		for shape: CollisionShape3D in body.get_children():
			shape.disabled = str(shape.name) != id
		await get_tree().physics_frame
		await get_tree().physics_frame
		var center: Vector3 = Contract.EXPECTED[id][0]
		var size: Vector3 = Contract.EXPECTED[id][1]
		for axis in range(3):
			for sign_axis: float in [-1.0, 1.0]:
				var normal: Vector3 = Vector3.ZERO
				normal[axis] = sign_axis
				var start: Vector3 = center + normal * (size[axis] / 2 + RADIUS + 0.05)
				var stop: Vector3 = center + normal * (size[axis] / 2 - 0.01)
				_check(
					_blocked(start, stop, RADIUS),
					"native sphere sweeps hit authored %s axis%d side%.0f" % [id, axis, sign_axis]
				)
				var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
					start, stop, 1
				)
				var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
				_check(
					(
						not hit.is_empty()
						and hit.collider == body
						and body.shape_owner_get_owner(body.shape_find_owner(hit.shape)).name == id
						and hit.position.distance_to(center + normal * size[axis] / 2) < EPS
						and hit.normal.dot(normal) > 0.999
					),
					"native contact point/normal matches exact visible %s face" % id
				)
	for shape: CollisionShape3D in body.get_children():
		shape.disabled = false
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(
		M.valid(model), "isolated native-shape proof restores complete exact candidate unchanged"
	)


func _native_drop(model: Node3D) -> void:
	# Actual free dynamics. Configure ONCE before insertion, then observe only.
	# Retained ball mass/material and zero replacement damping are used; no manual
	# sleeping, repositioning, velocity clamp, spring, water drag or scoring adapter.
	var ball: RigidBody3D = RigidBody3D.new()
	ball.name = "ObservedNativeDrop"
	ball.mass = 0.020
	ball.collision_layer = 2
	ball.collision_mask = 1
	ball.continuous_cd = true
	ball.contact_monitor = true
	ball.max_contacts_reported = 8
	ball.can_sleep = true
	ball.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	ball.linear_damp = 0.0
	ball.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	ball.angular_damp = 0.0
	var material: PhysicsMaterial = PhysicsMaterial.new()
	material.bounce = 0.52
	material.friction = 0.42
	ball.physics_material_override = material
	var shape: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = RADIUS
	sphere.margin = 0.0
	shape.shape = sphere
	ball.add_child(shape)
	var previous: Vector3 = Vector3(0, 1.1, -1.075)
	ball.position = model.to_global(previous)
	add_child(ball)
	var stone: StaticBody3D = model.get_node("Collision/WATERFALL_STONE")
	var witness: StadiumWaterfallTrapWitness = Witness.new()
	var proved: Dictionary = {}
	var entry: Dictionary = {}
	var entry_at: float = -1.0
	var quiet_since: float = -1.0
	var quiet_travel: float = 0.0
	var quiet_dwell: float = 0.0
	var support: bool = false
	var success: bool = false
	var elapsed: float = 0.0
	var observation_count: int = 0
	var lowest_y: float = previous.y
	var lowest_speed: float = INF
	var reached_floor: bool = false
	var observed_rebound: bool = false
	var final_point: Vector3 = previous
	var ticks: float = float(Engine.physics_ticks_per_second)
	for frame in range(1, int(ceil(4.0 * ticks)) + 1):
		await get_tree().physics_frame
		elapsed = frame / ticks
		observation_count += 1
		var point: Vector3 = model.to_local(ball.global_position)
		var speed: float = ball.linear_velocity.length()
		lowest_y = minf(lowest_y, point.y)
		lowest_speed = minf(lowest_speed, speed)
		final_point = point
		if entry.is_empty():
			entry = M.trap_entry_local(previous, point, RADIUS)
			if not entry.is_empty():
				entry_at = elapsed
		if point.y < 0.2 + RADIUS + 0.01 or ball.get_colliding_bodies().has(stone):
			reached_floor = true
		if reached_floor and ball.linear_velocity.y > 0.1:
			observed_rebound = true
		support = false
		var floor_contact: bool = false
		var current_floor_overlap: bool = false
		# Contact-monitor lists can lag a physics step. Query the CURRENT sphere
		# against the exact issued floor shape rather than inventing broad tolerance.
		for overlap: Dictionary in get_world_3d().direct_space_state.intersect_shape(
			_query(ball.global_position, RADIUS), 16
		):
			if (
				overlap.collider == stone
				and (
					stone.shape_owner_get_owner(stone.shape_find_owner(overlap.shape)).name
					== "BasinFloor"
				)
			):
				current_floor_overlap = true
		if ball.get_colliding_bodies().has(stone) or current_floor_overlap:
			var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
				ball.global_position + Vector3.UP * 0.02,
				ball.global_position - Vector3.UP * (RADIUS + 0.02),
				1
			)
			var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
			floor_contact = (
				not hit.is_empty()
				and hit.collider == stone
				and hit.normal.y > 0.999
				and absf(model.to_local(hit.position).y - 0.2) < EPS
				and (
					stone.shape_owner_get_owner(stone.shape_find_owner(hit.shape)).name
					== "BasinFloor"
				)
			)
		support = floor_contact and M.trap_contains_local(point, RADIUS)
		var contact: String = (
			"support"
			if support and speed <= Witness.SPEED
			else ("floor_impact" if floor_contact else "none")
		)
		var pending_count: int = witness._samples.size()
		proved = witness.observe(
			{
				"copy": "NATIVE-DROP-PAID-COPY-CONTROL",
				"serial": 1,
				"frame": frame,
				"time": elapsed,
				"previous": previous,
				"position": point,
				"velocity": ball.linear_velocity,
				"radius": RADIUS,
				"active": true,
				"contact": contact
			}
		)
		if pending_count > 0 and witness._samples.is_empty():
			print(
				(
					"ST046_WITNESS_RESET_DIAGNOSTIC "
					+ JSON.stringify(
						{
							"frame": frame,
							"time": elapsed,
							"point": str(point),
							"contact": contact,
							"floor_contact": floor_contact,
							"speed": speed,
							"previous": str(previous)
						}
					)
				)
			)
		var quiet: bool = (
			not entry.is_empty()
			and support
			and speed <= 0.05
			and M.trap_contains_local(point, RADIUS)
		)
		if not quiet:
			quiet_since = -1.0
			quiet_travel = 0.0
		elif quiet_since < 0.0:
			quiet_since = elapsed
			quiet_travel = 0.0
		else:
			quiet_travel += point.distance_to(previous)
			if quiet_travel > 0.005:
				quiet_since = elapsed
				quiet_travel = 0.0
		quiet_dwell = elapsed - quiet_since if quiet_since >= 0.0 else 0.0
		previous = point
		if quiet and quiet_dwell + M.EPS >= 0.30 and not proved.is_empty():
			success = true
			break
	_drop_result = {
		"settled_supported_pocket": success,
		"witnessed_top_entry": not entry.is_empty(),
		"entry_at": entry_at,
		"observation_seconds": elapsed,
		"observation_count": observation_count,
		"quiet_dwell": quiet_dwell,
		"whole_quiet_travel": quiet_travel,
		"final_speed": ball.linear_velocity.length(),
		"final_local_point": str(final_point),
		"lowest_y": lowest_y,
		"lowest_speed": lowest_speed,
		"native_floor_support": support,
		"witness_pending_samples": witness._samples.size(),
		"witness_quiet_since": witness._quiet_since,
		"same_witness_proved": not proved.is_empty(),
		"same_witness_replay": Witness.replay(proved),
		"natural_rebound": observed_rebound,
		"naturally_sleeping": ball.sleeping,
		"post_launch_forcing": false,
		"awards_or_game_integration": false
	}
	print("ST046_LIVE_NATIVE_DROP " + JSON.stringify(_drop_result))
	_check(
		not entry.is_empty() and entry_at > 0.0 and entry.aperture == "BASIN_TOP",
		"unforced native rigid sphere genuinely witnesses downward full-sphere top entry"
	)
	_check(
		reached_floor and observed_rebound,
		"native gravity and ordinary ball material cause actual floor impact and rebound"
	)
	_check(
		(
			success
			and support
			and M.trap_contains_local(final_point, RADIUS)
			and ball.linear_velocity.length() <= 0.05
			and quiet_travel <= 0.005
			and quiet_dwell + M.EPS >= 0.30
			and elapsed <= 4.0
		),
		(
			"within four seconds the actual unforced sphere settles supported and unreachable for "
			+ "a whole 0.30-second quiet dwell"
		)
	)
	_check(
		not proved.is_empty() and Witness.replay(proved),
		"same strict replayable witness accepts actual unforced native entry and settlement"
	)
	_check(
		not entry.has("terminal") and not entry.has("role") and M.valid(model),
		"native drop is a geometry witness only, never award authority or a changed model"
	)
	ball.queue_free()
	await get_tree().physics_frame


func _query(from: Vector3, radius: float) -> PhysicsShapeQueryParameters3D:
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = radius
	sphere.margin = 0.0
	query.shape = sphere
	query.margin = 0.0
	query.collision_mask = 1
	query.transform.origin = from
	return query


func _blocked(from: Vector3, to: Vector3, radius: float) -> bool:
	var query: PhysicsShapeQueryParameters3D = _query(from, radius)
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty():
		return true
	query.motion = to - from
	var result: PackedFloat32Array = space.cast_motion(query)
	return result.size() != 2 or result[0] < 1.0


func _visual_signature(root: Node3D) -> PackedByteArray:
	var rows: Array = []
	for id: String in Contract.EXPECTED:
		var node: MeshInstance3D = root.get_node(id)
		rows.append(
			[
				id,
				node.transform,
				node.mesh.size,
				node.material_override.albedo_color,
				node.material_override.roughness,
				node.material_override.transparency
			]
		)
	return var_to_bytes(rows)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(label)
		push_error("ST046 live geometry: " + label)
