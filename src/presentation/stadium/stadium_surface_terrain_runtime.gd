class_name StadiumSurfaceTerrainRuntime
extends RefCounted
## Exact issued daylight terrain. Full paid/snapshot equality at delivery/report boundaries.
## Same-generation bulk edits are refused there; native resource replacement is immediate.

enum Phase { CONFIGURED, STAGING, ACTIVE, ABANDONED }

const BOUND: StringName = &"owned_surface_terrain_bound_v1"
const OWNER: StringName = &"owned_surface_terrain_owner_v1"
const BALL: StringName = &"owned_surface_terrain_ball_v1"
var phase: Phase = Phase.CONFIGURED
var _lab: WeakRef
var _state: MatchState
var _paid: ClubAssetLedger
var _generation: int = -1
var _paid_data: String
var _paid_state: String
var _snapshot: Dictionary
var _snapshot_data: String
var _field: FieldDefinition
var _field_values: Array
var _host: StarterFieldLabGeometry
var _property: StadiumPropertyGeometry
var _terrain: Node3D
var _visual: MeshInstance3D
var _body: StaticBody3D
var _shape_node: CollisionShape3D
var _shape: ConcavePolygonShape3D
var _mesh: ArrayMesh
var _material: ShaderMaterial
var _shader: Shader
var _shader_code: String
var _texture: Texture2D
var _texture_data: PackedByteArray
var _material_values: Array
var _faces: PackedVector3Array
var _normals: PackedVector3Array
var _mode: String
var _fielder: FielderController
var _pitcher: Node3D
var _pitch: PitchFlightActor
var _parameters: PitchLaunchParameters
var _resolver: BallPlayResolver
var _boundary: Node3D
var _observer: Callable
var _clip: Callable
var _candidate: WeakRef
var _play: BallPlayState


static func current(lab: PitchBatLab) -> StadiumSurfaceTerrainRuntime:
	if not is_instance_valid(lab) or not lab.has_meta(OWNER):
		return null
	var value: Variant = lab.get_meta(OWNER)
	return (
		value
		if (
			value is StadiumSurfaceTerrainRuntime
			and value.get_script() == StadiumSurfaceTerrainRuntime
		)
		else null
	)


static func configure(lab: PitchBatLab, paid: ClubAssetLedger) -> bool:
	if (
		not is_instance_valid(lab)
		or lab.get_parent() != null
		or lab.is_inside_tree()
		or lab.is_queued_for_deletion()
		or lab.get_script() != PitchBatLab
		or lab.has_meta(OWNER)
		or lab.has_meta(BOUND)
		or lab.has_meta("stadium_property")
		or lab._match_state != null
		or lab._configured_match == null
		or lab._configured_match.get_script() != MatchState
		or lab._stadium_ledger != paid
		or paid == null
		or paid.get_script() != ClubAssetLedger
		or paid.mutation_generation() < 0
		or lab._field_id != PitchBatLab.FIELD_ID
	):
		return false
	var snapshot: Dictionary = StadiumLayoutSnapshot.terrain_normalized(
		lab._configured_match.stadium
	)
	var field: FieldDefinition = ContentDB.get_field(PitchBatLab.FIELD_ID)
	if (
		snapshot.is_empty()
		or snapshot.version != StadiumLayoutSnapshot.TERRAIN_FIXTURE_VERSION
		or not StadiumLayoutSnapshot.matches(snapshot, paid)
		or field == null
	):
		return false
	var owner: StadiumSurfaceTerrainRuntime = StadiumSurfaceTerrainRuntime.new()
	owner._lab = weakref(lab)
	owner._state = lab._configured_match
	owner._paid = paid
	owner._generation = paid.mutation_generation()
	owner._paid_data = JSON.stringify(paid.to_data(), "", true, true)
	owner._paid_state = StadiumSurfaceNightRuntime._ledger_state(paid)
	owner._snapshot = snapshot.duplicate(true)
	owner._snapshot_data = JSON.stringify(snapshot, "", true, true)
	owner._field = field
	owner._field_values = owner._fields()
	lab.set_meta(OWNER, owner)
	return true


func _configured(lab: PitchBatLab, state: MatchState) -> bool:
	return (
		phase == Phase.CONFIGURED
		and is_instance_valid(lab)
		and _lab != null
		and _lab.get_ref() == lab
		and not lab.is_queued_for_deletion()
		and current(lab) == self
		and lab.get_script() == PitchBatLab
		and not lab.has_meta(BOUND)
		and not lab.has_meta("stadium_property")
		and state == _state
		and (
			(lab._configured_match == _state and lab._match_state == null)
			or (lab._configured_match == null and lab._match_state == _state)
		)
		and _paid != null
		and _paid.get_script() == ClubAssetLedger
		and lab._stadium_ledger == _paid
		and _generation >= 0
		and _paid.mutation_generation() == _generation
		and lab._field_id == PitchBatLab.FIELD_ID
		and ContentDB.get_field(PitchBatLab.FIELD_ID) == _field
		and (lab._field_definition == null or lab._field_definition == _field)
		and _fields() == _field_values
		and ClubCareer.same(_state.stadium, _snapshot)
		and JSON.stringify(_snapshot, "", true, true) == _snapshot_data
		and StadiumSurfaceNightRuntime._ledger_state(_paid) == _paid_state
		and JSON.stringify(_paid.to_data(), "", true, true) == _paid_data
		and StadiumLayoutSnapshot.matches(_snapshot, _paid)
	)


static func requested(lab: PitchBatLab) -> bool:
	return (
		is_instance_valid(lab)
		and (
			lab.has_meta(BOUND)
			or lab.has_meta(OWNER)
			or (
				lab._match_state != null
				and StadiumLayoutSnapshot.is_terrain(lab._match_state.stadium)
			)
		)
	)


static func action_allowed(lab: PitchBatLab) -> bool:
	if not requested(lab):
		return true
	var owner: StadiumSurfaceTerrainRuntime = current(lab)
	return owner != null and owner._guard(lab)


static func boundary_allowed(lab: PitchBatLab) -> bool:
	if not requested(lab):
		return true
	var owner: StadiumSurfaceTerrainRuntime = current(lab)
	if owner == null or not owner._guard(lab) or not owner._full(lab):
		if owner != null:
			owner._abandon()
		return false
	return true


static func continue_action(
	lab: PitchBatLab, owner: StadiumSurfaceTerrainRuntime, state: MatchState
) -> bool:
	if owner == null:
		return is_instance_valid(lab) and not requested(lab)
	if (
		is_instance_valid(lab)
		and current(lab) == owner
		and lab._match_state == state
		and owner._guard(lab)
	):
		return true
	owner._abandon()
	return false


static func continue_boundary(
	lab: PitchBatLab, owner: StadiumSurfaceTerrainRuntime, state: MatchState
) -> bool:
	return continue_action(lab, owner, state) and boundary_allowed(lab)


static func continue_startup(
	lab: PitchBatLab, owner: StadiumSurfaceTerrainRuntime, state: MatchState
) -> bool:
	if owner != null and owner.phase == Phase.CONFIGURED:
		if owner._configured(lab, state):
			return true
		owner._abandon()
		return false
	return continue_action(lab, owner, state)


static func installed_bound(lab: PitchBatLab, snapshot: Dictionary) -> bool:
	var owner: StadiumSurfaceTerrainRuntime = current(lab)
	return owner != null and ClubCareer.same(snapshot, owner._snapshot) and boundary_allowed(lab)


static func install_bound(lab: PitchBatLab) -> bool:
	if not is_instance_valid(lab) or lab._match_state == null:
		return false
	if lab.has_meta(BOUND):
		return boundary_allowed(lab)
	var owner: StadiumSurfaceTerrainRuntime = current(lab)
	if owner == null or not owner._configured(lab, lab._match_state):
		retire_captured(lab, owner)
		return false
	var snapshot: Dictionary = owner._snapshot
	if (
		lab.has_meta("stadium_property")
		or is_instance_valid(lab._batted_ball)
		or not is_instance_valid(lab._pitch_actor)
		or lab._pitch_actor.running
		or not is_instance_valid(lab._primary_fielder)
		or not is_instance_valid(lab._pitcher_marker)
		or lab._field_id != PitchBatLab.FIELD_ID
	):
		return false
	var host: StarterFieldLabGeometry = lab.get_node_or_null("StarterFieldGeometry")
	if (
		host == null
		or lab._primary_fielder.hillside_motion != null
		or lab.hillside_pitcher_motion != null
	):
		return false
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	if not property.build(
		snapshot.tier, snapshot.layout, StadiumLayoutSnapshot.ownership(snapshot)
	):
		property.free()
		return false
	var boundary: Node3D = StadiumBoundaryRuntime.assemble(property)
	if (
		boundary == null
		or (
			boundary.get_script() != StadiumBoundaryPrototype
			and boundary.get_script() != StadiumBoundaryOwnedRuntime
		)
	):
		property.free()
		return false
	owner._host = host
	owner._property = property
	owner._terrain = property.get_node("OwnedSurfaceTerrain")
	owner._visual = owner._terrain.get_node("TerrainVisual")
	owner._body = owner._terrain.get_node("TerrainCollision")
	owner._shape_node = owner._body.get_node("ClosedTerrainShape")
	owner._shape = owner._shape_node.shape
	owner._mesh = owner._visual.mesh
	owner._material = owner._visual.material_override
	owner._shader = owner._material.shader
	owner._shader_code = owner._shader.code
	owner._texture = owner._material.get_shader_parameter("surface_noise")
	owner._texture_data = owner._texture.get_image().get_data()
	owner._material_values = owner._appearance()
	owner._mode = snapshot.terrain.mode
	var geometry: Dictionary = StadiumSurfaceTerrain.geometry(owner._mode)
	owner._faces = geometry.faces
	# ArrayMesh stores octahedrally encoded native normals. Capture the exact
	# constructor result before any external attachment callback; analytic normals stay pure.
	owner._normals = owner._mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	owner._fielder = lab._primary_fielder
	owner._pitcher = lab._pitcher_marker
	owner._pitch = lab._pitch_actor
	owner._resolver = lab._ball_play_resolver
	owner._boundary = boundary
	owner._observer = (
		boundary.observe
		if boundary is StadiumBoundaryOwnedRuntime
		else StadiumBoundaryObserver.observe
	)
	owner._clip = (
		boundary.graph.clip
		if boundary is StadiumBoundaryOwnedRuntime
		else StadiumBoundaryGraph.clip
	)
	for resource: Resource in [
		owner._shape, owner._mesh, owner._material, owner._shader, owner._texture
	]:
		resource.changed.connect(owner._changed)
	if not owner._configured(lab, lab._match_state):
		owner._abandon()
		property.free()
		return false
	owner.phase = Phase.STAGING
	lab.set_meta(BOUND, true)
	if (
		not owner.install_context(lab, property, host)
		or not StadiumPropertyRuntime._attach(lab, host, property, snapshot.layout, null, owner)
		or not owner.install_context(lab, property, host)
	):
		owner._abandon()
		return false
	lab._ball_play_resolver.segment_observer = owner._observer
	lab._primary_fielder.stadium_boundary_clip = owner._clip
	lab.set_meta(
		"boundary_signature",
		(
			boundary.graph.signature()
			if boundary is StadiumBoundaryOwnedRuntime
			else StadiumBoundaryGraph.signature()
		)
	)
	lab.set_meta("stadium_snapshot", snapshot.duplicate(true))
	owner._fielder.set_meta(BOUND, owner)
	owner._fielder.terrain_motion = owner
	owner.phase = Phase.ACTIVE
	if (
		not boundary_allowed(lab)
		or not owner.reset_pitcher(lab)
		or not owner.set_anchor(owner._fielder, owner._fielder.anchor_position)
	):
		owner._abandon()
		return false
	return true


func install_context(
	lab: PitchBatLab, property: StadiumPropertyGeometry, host: StarterFieldLabGeometry
) -> bool:
	return (
		phase == Phase.STAGING
		and _identity(lab)
		and property == _property
		and host == _host
		and (_property.get_parent() == null or _property.get_parent() == _host)
		and (not lab.has_meta("stadium_property") or lab.get_meta("stadium_property") == _property)
		and _geometry(true)
		and is_instance_valid(_boundary)
		and _boundary.get_parent() == _property
		and _boundary_identity()
	)


func _fields() -> Array:
	return (
		[]
		if _field == null
		else [
			_field.fair_half_angle_degrees,
			_field.safe_hit_z_m,
			_field.deep_air_z_m,
			_field.back_wall_z_m,
			_field.home_run_height_m,
			_field.dead_ball_z_m
		]
	)


func _identity(lab: PitchBatLab) -> bool:
	return (
		_lab != null
		and _lab.get_ref() == lab
		and is_instance_valid(lab)
		and not lab.is_queued_for_deletion()
		and lab.global_transform == Transform3D.IDENTITY
		and current(lab) == self
		and lab.has_meta(BOUND)
		and lab.get_meta(BOUND) == true
		and lab._match_state == _state
		and lab._stadium_ledger == _paid
		and _paid != null
		and _paid.get_script() == ClubAssetLedger
		and _generation >= 0
		and _paid.mutation_generation() == _generation
		and lab._field_definition == _field
		and ContentDB.get_field(PitchBatLab.FIELD_ID) == _field
		and _fields() == _field_values
		and lab._field_id == PitchBatLab.FIELD_ID
		and is_instance_valid(_host)
		and lab.get_node_or_null("StarterFieldGeometry") == _host
		and _host.get_parent() == lab
		and _host.get_script() == StarterFieldLabGeometry
		and _host.transform == Transform3D.IDENTITY
		and is_instance_valid(_property)
		and _property.get_script() == StadiumPropertyGeometry
		and _property.transform == Transform3D.IDENTITY
		and is_instance_valid(_fielder)
		and _fielder.get_script() == FielderController
		and lab._primary_fielder == _fielder
		and _fielder.get_parent() == lab
		and is_instance_valid(_pitcher)
		and lab._pitcher_marker == _pitcher
		and _pitcher.get_parent() == lab
		and is_instance_valid(_pitch)
		and _pitch.get_script() == PitchFlightActor
		and _pitch.get_parent() == lab
		and lab._pitch_actor == _pitch
		and _resolver != null
		and _resolver.get_script() == BallPlayResolver
		and lab._ball_play_resolver == _resolver
	)


func _appearance() -> Array:
	var values: Array = []
	for key: String in [
		"dirt_surface",
		"condition",
		"grass_height",
		"mowing_pattern",
		"mowing_width",
		"base_color",
		"terrain_wear"
	]:
		values.append(_material.get_shader_parameter(key))
	return values


func _geometry(full: bool) -> bool:
	if not is_instance_valid(_property) or not _property.props_intact():
		return false
	if (
		not is_instance_valid(_terrain)
		or _terrain.get_parent() != _property
		or _property.get_node_or_null("OwnedSurfaceTerrain") != _terrain
		or _terrain.is_queued_for_deletion()
		or _terrain.get_script() != null
		or _terrain.transform != Transform3D.IDENTITY
		or _terrain.get_child_count() != 2
		or not is_instance_valid(_visual)
		or _visual.get_script() != null
		or _visual.is_queued_for_deletion()
		or _visual.get_parent() != _terrain
		or _visual.transform != Transform3D.IDENTITY
		or _visual.mesh != _mesh
		or _visual.material_override != _material
		or _material.shader != _shader
		or _material.get_shader_parameter("surface_noise") != _texture
		or _appearance() != _material_values
		or not is_instance_valid(_body)
		or _body.get_parent() != _terrain
		or _body.get_script() != null
		or _body.is_queued_for_deletion()
		or _body.transform != Transform3D.IDENTITY
		or _body.collision_layer != (1 | StadiumSurfaceTerrain.QUERY_LAYER)
		or _body.physics_material_override != null
		or _body.constant_linear_velocity != Vector3.ZERO
		or _body.constant_angular_velocity != Vector3.ZERO
		or _body.collision_mask != 2
		or _body.get_meta("ball_surface", &"") != &"ground"
		or _body.get_child_count() != 1
		or not is_instance_valid(_shape_node)
		or _shape_node.get_script() != null
		or _shape_node.is_queued_for_deletion()
		or _shape_node.get_parent() != _body
		or _shape_node.transform != Transform3D.IDENTITY
		or _shape_node.disabled
		or _shape_node.shape != _shape
		or _shape.margin != 0.0
		or _shape.backface_collision
		or _property.has_node("PropertyGround")
		or _property.has_node("OwnedSurfaceFinish")
	):
		return false
	for resource: Resource in [_shape, _mesh, _material, _shader, _texture]:
		if not resource.changed.is_connected(_changed):
			return false
	if full:
		return (
			_shader.code == _shader_code
			and _texture.get_image().get_data() == _texture_data
			and _shape.get_faces() == _faces
			and _mesh.get_surface_count() == 1
			and _mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == _faces
			and _mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL] == _normals
			and ClubCareer.same(_terrain.get_meta("terrain", {}), _snapshot.terrain)
		)
	return true


func _full(lab: PitchBatLab) -> bool:
	return (
		_identity(lab)
		and _geometry(true)
		and ClubCareer.same(_state.stadium, _snapshot)
		and JSON.stringify(_snapshot, "", true, true) == _snapshot_data
		and StadiumSurfaceNightRuntime._ledger_state(_paid) == _paid_state
		and JSON.stringify(_paid.to_data(), "", true, true) == _paid_data
		and StadiumLayoutSnapshot.matches(_snapshot, _paid)
	)


func _guard(lab: PitchBatLab) -> bool:
	if (
		phase != Phase.ACTIVE
		or not _identity(lab)
		or not _geometry(false)
		or _property.get_parent() != _host
		or not lab.has_meta("stadium_property")
		or lab.get_meta("stadium_property") != _property
		or not _fielder.has_meta(BOUND)
		or _fielder.get_meta(BOUND) != self
		or _fielder.terrain_motion != self
		or not is_instance_valid(_boundary)
		or not _boundary_identity()
		or _boundary.get_parent() != _property
		or _property.get_node_or_null("BoundaryGraph") != _boundary
		or _resolver.segment_observer != _observer
		or _fielder.stadium_boundary_clip != _clip
	):
		_abandon()
		return false
	return true


func _changed() -> void:
	_abandon()


func _abandon() -> void:
	phase = Phase.ABANDONED
	if (
		_parameters != null
		and is_instance_valid(_pitch)
		and _lab != null
		and is_instance_valid(_lab.get_ref())
		and _pitch.get_parent() == _lab.get_ref()
		and _pitch.get_script() == PitchFlightActor
		and _pitch.parameters == _parameters
	):
		_pitch.running = false
	if _candidate != null:
		var ball: Object = _candidate.get_ref()
		if (
			is_instance_valid(ball)
			and ball.get_script() == BattedBallBody
			and _lab != null
			and is_instance_valid(_lab.get_ref())
			and ball.get_parent() == _lab.get_ref()
			and ball.has_meta(BALL)
			and ball.get_meta(BALL) == self
		):
			ball.freeze = true


static func retire(lab: PitchBatLab, _reason: String = "") -> void:
	var owner: StadiumSurfaceTerrainRuntime = current(lab)
	if owner != null and owner._lab != null and owner._lab.get_ref() == lab:
		owner._abandon()


static func retire_captured(lab: PitchBatLab, owner: StadiumSurfaceTerrainRuntime) -> void:
	if (
		owner != null
		and owner.get_script() == StadiumSurfaceTerrainRuntime
		and owner._lab != null
		and owner._lab.get_ref() == lab
	):
		owner._abandon()


func guard_actor(actor: Node3D) -> bool:
	var lab: PitchBatLab = _lab.get_ref() if _lab != null else null
	return is_instance_valid(lab) and actor in [_fielder, _pitcher] and _guard(lab)


func support_record(at: Vector2) -> Dictionary:
	var lab: PitchBatLab = _lab.get_ref() if _lab != null else null
	if not is_instance_valid(lab) or not _guard(lab):
		return {}
	var record: Dictionary = StadiumSurfaceTerrain.support(at, _mode)
	if record.is_empty():
		return {}
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		record.position + Vector3.UP,
		record.position + Vector3.DOWN,
		StadiumSurfaceTerrain.QUERY_LAYER
	)
	var hit: Dictionary = lab.get_world_3d().direct_space_state.intersect_ray(ray)
	# Layer 512 is shared with mutually exclusive Hillside; collider identity is authority.
	if (
		hit.get("collider") != _body
		or not hit.get("position") is Vector3
		or (
			(hit.position as Vector3).distance_to(record.position)
			> StadiumHillsideDefenderMotion.SUPPORT_RAY_ERROR_M
		)
	):
		_abandon()
		return {}
	return record


func _planned_support(at: Vector2) -> Dictionary:
	return StadiumSurfaceTerrain.support(at, _mode)


func set_anchor(actor: FielderController, point: Vector3) -> bool:
	if actor != _fielder or not guard_actor(actor) or not point.is_finite():
		return false
	var record: Dictionary = StadiumSurfaceTerrain.support(Vector2(point.x, point.z), _mode)
	if record.is_empty():
		return false
	actor.anchor_position = record.position
	actor.target_position = record.position
	if not actor.active:
		actor.global_position = record.position
	return guard_actor(actor)


func reset_pitcher(lab: PitchBatLab) -> bool:
	if not _guard(lab):
		return false
	var record: Dictionary = StadiumSurfaceTerrain.support(
		Vector2(PitchBatLab.MOUND_ORIGIN.x, PitchBatLab.MOUND_ORIGIN.z), _mode
	)
	if record.is_empty():
		return false
	_pitcher.global_position = record.position
	_pitcher.rotation = Vector3.ZERO
	return _guard(lab)


func finish_step(actor: Node3D, previous: Vector3, target: Vector3, budget: float) -> Vector3:
	if not guard_actor(actor):
		return previous
	var result: Dictionary = StadiumSurfaceTerrain.path(previous, target, budget, _mode)
	if result.is_empty():
		return previous
	var record: Dictionary = support_record(Vector2(result.position.x, result.position.z))
	return record.position if not record.is_empty() else previous


func control_frame(actor: Node3D, ball: Vector3) -> Dictionary:
	if not guard_actor(actor) or not ball.is_finite():
		return {}
	var record: Dictionary = support_record(Vector2(ball.x, ball.z))
	if record.is_empty():
		return {}
	return {
		"height_m": ball.y - actor.global_position.y,
		"minimum_height_m": float(record.support_height) - actor.global_position.y
	}


func planning_providers(actor: Node3D) -> Dictionary:
	return (
		{"support": _planned_support, "arrival": _arrival.bind(actor)} if guard_actor(actor) else {}
	)


func _arrival(
	_ball: Vector3,
	feet: Vector3,
	seconds: float,
	speed: float,
	reach: float,
	stationary: bool,
	_grounded: bool,
	actor: Node3D
) -> Dictionary:
	if not guard_actor(actor):
		return {}
	var path: Dictionary = StadiumSurfaceTerrain.path(
		actor.global_position, feet, 0.0 if stationary else speed * seconds, _mode
	)
	if path.is_empty():
		return {}
	return {
		"feet_target": feet,
		"position": path.position,
		"reason": "surface_distance",
		"elapsed": 0.0 if speed == 0 else float(path.distance) / speed,
		"reached": Vector2(path.position.x - feet.x, path.position.z - feet.z).length() <= reach,
		"support_segments": path.segments,
		"support_checks": path.segments + 1
	}


func claim_ball(lab: PitchBatLab, ball: BattedBallBody, play: BallPlayState) -> bool:
	if (
		not _guard(lab)
		or not is_instance_valid(ball)
		or lab._batted_ball != ball
		or ball.get_parent() != null
		or ball.get_script() != BattedBallBody
		or ball.has_meta(BALL)
		or _resolver.state != play
	):
		return false
	ball.set_meta(BALL, self)
	_candidate = weakref(ball)
	_play = play
	return true


func bind_ball(lab: PitchBatLab, ball: BattedBallBody, resolver: BallPlayResolver) -> bool:
	if (
		not _guard(lab)
		or not is_instance_valid(ball)
		or ball != lab._batted_ball
		or ball.get_parent() != lab
		or ball.get_script() != BattedBallBody
		or resolver != _resolver
		or resolver.state == null
		or _candidate == null
		or _candidate.get_ref() != ball
		or _play != resolver.state
	):
		return false
	_property.bind_ball(ball, resolver)
	if _boundary is StadiumBoundaryOwnedRuntime:
		_boundary.bind_ball(ball, resolver)
	return ball_context(lab, ball, _play)


func ball_context(lab: PitchBatLab, ball: BattedBallBody, play: BallPlayState) -> bool:
	var good: bool = (
		_guard(lab)
		and _candidate != null
		and _candidate.get_ref() == ball
		and is_instance_valid(ball)
		and ball.get_script() == BattedBallBody
		and ball.has_meta(BALL)
		and ball.get_meta(BALL) == self
		and ball.get_parent() == lab
		and not ball.is_queued_for_deletion()
		and lab._batted_ball == ball
		and _resolver.state == play
		and _play == play
	)
	if not good:
		_abandon()
	return good


static func continue_pitch(
	lab: PitchBatLab,
	owner: StadiumSurfaceTerrainRuntime,
	state: MatchState,
	actor: PitchFlightActor,
	parameters: PitchLaunchParameters
) -> bool:
	if owner == null:
		return is_instance_valid(lab) and not requested(lab)
	var valid_owner: bool = continue_boundary(lab, owner, state)
	var same_launch: bool = (
		is_instance_valid(lab)
		and is_instance_valid(actor)
		and actor == owner._pitch
		and actor.get_parent() == lab
		and actor.get_script() == PitchFlightActor
		and actor.parameters == parameters
	)
	if valid_owner and same_launch:
		return true
	if same_launch:
		actor.running = false
	return false


func claim_pitch(lab: PitchBatLab, parameters: PitchLaunchParameters) -> bool:
	if not _guard(lab) or parameters == null or _pitch.running:
		return false
	_parameters = parameters
	return true


static func actor_allowed(actor: FielderController) -> bool:
	if not is_instance_valid(actor):
		return false
	if actor.has_meta(BOUND):
		var owner: Variant = actor.get_meta(BOUND)
		return (
			owner is StadiumSurfaceTerrainRuntime
			and actor.terrain_motion == owner
			and owner.guard_actor(actor)
		)
	return (
		actor.terrain_motion == null
		and not (actor.get_parent() is PitchBatLab and actor.get_parent().has_meta(BOUND))
	)


func _boundary_identity() -> bool:
	if not is_instance_valid(_boundary):
		return false
	if (
		StadiumBoundaryItems.is_family(_snapshot.get("layout"))
		or (
			StadiumReceiverOwnedItems.is_family(_snapshot.get("layout"))
			or (
				StadiumFloodlightOwnedItems.is_family(_snapshot.get("layout"))
				or (
					StadiumLandscapeOwnedItems.is_family(_snapshot.get("layout"))
					or (
						StadiumLiveFurnishingItems.is_family(_snapshot.get("layout"))
						or (
							StadiumSmallYardSceneryItems.is_family(_snapshot.get("layout"))
							or (
								StadiumMoldedSeatItems.is_family(_snapshot.get("layout"))
								or (
									StadiumGroundBoxItems.is_family(_snapshot.get("layout"))
									or (
										StadiumPracticeFacilityItems.is_family(
											_snapshot.get("layout")
										)
										or (
											StadiumTreehouseItems.is_family(_snapshot.get("layout"))
											or (
												StadiumLandmarkItems.is_family(
													_snapshot.get("layout")
												)
												or (
													StadiumOutfieldBleacherItems.is_family(
														_snapshot.get("layout")
													)
													or (
														StadiumRisingAppleItems.is_family(
															_snapshot.get("layout")
														)
														or (
															StadiumWallTopTerraceItems.is_family(
																_snapshot.get("layout")
															)
															or (
																StadiumPlayerTunnelItems.is_family(
																	_snapshot.get("layout")
																)
																or (
																	(
																		StadiumMountedDisplayItems
																		. is_family(
																			_snapshot.get("layout")
																		)
																	)
																	or (
																		StadiumStringLightItems
																		. is_family(
																			_snapshot.get("layout")
																		)
																	)
																)
															)
														)
													)
												)
											)
										)
									)
								)
							)
						)
					)
				)
			)
		)
	):
		return _boundary.get_script() == StadiumBoundaryOwnedRuntime and _boundary.intact()
	return _boundary.get_script() == StadiumBoundaryPrototype
