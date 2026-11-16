class_name StadiumHillsidePrivateRuntime
extends Node
## Explicit private ordinary-lab owner. No public/save/earned-venue admission.

const NODE_NAME: StringName = &"HillsidePrivateRuntime"
const PROFILE: String = "hill"
const ANCHOR_INDEX: int = 7

var blocked: bool = true
var last_error: String = "Private Hillside installation has not completed."
var terrain: Node3D
var boundary: StadiumHillsideBoundaryBody
var ground: StadiumHillsideGroundContact
var _lab: PitchBatLab
var _field: FieldDefinition
var _resolver: BallPlayResolver
var _primary: FielderController
var _pitcher: Node3D
var _primary_motion: StadiumHillsideDefenderMotion
var _pitcher_motion: StadiumHillsideDefenderMotion
var _ball: BattedBallBody
var _state: BallPlayState
var _installing: bool = false
var _closing: bool = false
var _lab_process_mode: int
var _terrain_process_mode: int
var _boundary_process_mode: int


func install(lab: PitchBatLab) -> bool:
	if (
		get_parent() != null
		or get_script() != StadiumHillsidePrivateRuntime
		or not is_instance_valid(lab)
		or not lab.is_inside_tree()
		or lab.global_transform != Transform3D.IDENTITY
		or lab.hillside_private_runtime != null
		or lab._hillside_private_owner_identity != null
		or lab.has_node(NodePath(NODE_NAME))
		or not StadiumPropertyRuntime.authoring_delivery_idle(lab)
		or is_instance_valid(lab._batted_ball)
		or not _private_context(lab)
		or lab._field_definition == null
		or lab._ball_play_resolver == null
		or not is_instance_valid(lab._primary_fielder)
		or lab._primary_fielder.active
		or not is_instance_valid(lab._pitcher_marker)
	):
		last_error = "An idle ordinary private lab with unchanged actual actors is required."
		return false
	var old: StarterFieldLabGeometry = lab.get_node_or_null("StarterFieldGeometry")
	if old == null or old.global_transform != Transform3D.IDENTITY:
		last_error = "The ordinary identity-transform field host is required."
		return false
	terrain = StadiumHillsideTerrainModels.create(PROFILE)
	boundary = StadiumHillsideBoundaryBody.new()
	if terrain == null or not boundary.build_hillside(PROFILE):
		if is_instance_valid(terrain):
			terrain.free()
		boundary.free()
		last_error = "The retained terrain and same-XZ boundary must build successfully."
		return false
	_lab = lab
	_field = lab._field_definition
	_resolver = lab._ball_play_resolver
	_primary = lab._primary_fielder
	_pitcher = lab._pitcher_marker
	_lab_process_mode = lab.process_mode
	_terrain_process_mode = terrain.process_mode
	_boundary_process_mode = boundary.process_mode
	# Only the static replacement geometry remains in physics while gameplay is held.
	terrain.process_mode = Node.PROCESS_MODE_ALWAYS
	boundary.process_mode = Node.PROCESS_MODE_ALWAYS
	_installing = true
	name = NODE_NAME
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -100
	process_physics_priority = -100
	lab.hillside_private_runtime = self
	lab._hillside_private_owner_identity = weakref(self)
	lab.add_child(self)
	lab.process_mode = Node.PROCESS_MODE_DISABLED
	# Remove only the ordinary colliders/markings replaced by this private surface.
	for id: String in [
		"Ground",
		"BackWall",
		"LiveObjectPole",
		"SafeBoundary",
		"DeepAirBoundary",
		"RightFoulLine",
		"LeftFoulLine"
	]:
		var node: Node = old.get_node_or_null(NodePath(id))
		if node != null:
			old.remove_child(node)
			node.queue_free()
	old.add_child(terrain)
	boundary.name = "HillsideBoundary"
	old.add_child(boundary)
	_resolver.segment_observer = boundary.graph.observe
	_primary.stadium_boundary_clip = boundary.graph.clip
	# Physics-space registration is required before the retained support probes.
	await lab.get_tree().physics_frame
	return _finish_installation(lab, old)


func _finish_installation(lab: PitchBatLab, old: StarterFieldLabGeometry) -> bool:
	if not _installation_identity() or not boundary.retained_valid(terrain):
		return hold("The private terrain/boundary changed during attachment.")
	if not _primary.bind_hillside_motion(_field, terrain, ANCHOR_INDEX, PROFILE):
		return hold("The existing deep-center slot lacks valid retained support.")
	_primary_motion = _primary.hillside_motion
	if not lab.bind_hillside_pitcher_motion():
		return hold("The actual pitcher could not bind the retained support.")
	_pitcher_motion = lab.hillside_pitcher_motion
	ground = StadiumHillsideGroundContact.new()
	if not ground.install(lab, terrain, PROFILE):
		ground.free()
		ground = null
		return hold("The physical ground adapter rejected this private lab.")
	lab._fielder_anchor_index = ANCHOR_INDEX
	_add_markings(old)
	terrain.tree_exiting.connect(_invalidate)
	boundary.tree_exiting.connect(_invalidate)
	ground.tree_exiting.connect(_invalidate)
	var shape: ConcavePolygonShape3D = terrain.get_node("TerrainCollision/ClosedTerrainShape").shape
	shape.changed.connect(_invalidate)
	lab._camera_director.tracking_visibility.configure(old)
	lab.process_mode = _lab_process_mode
	_restore_installation_processing()
	_installing = false
	blocked = false
	last_error = ""
	lab._refresh_markers()
	lab._refresh_config()
	return true


static func _private_context(lab: PitchBatLab) -> bool:
	return (
		not lab._managed_match
		and lab._automation == null
		and lab._npc_season == null
		and lab._configured_match == null
		and not lab.has_meta("stadium_property")
		and not lab.has_meta("stadium_snapshot")
		and not lab.has_meta(StadiumNpcPublicRuntime.PUBLIC_BOUND)
		and not lab.has_meta(StadiumNpcYardTwoRuntimeV1.PUBLIC_BOUND)
		and not lab.has_meta(StadiumNpcYardThreeRuntimeV1.PUBLIC_BOUND)
		and lab.pool_active_receipt == null
		and lab.pool_controller_active == null
		and not lab.pool_bound_startup_failed
		and not lab.yard_bound_startup_failed
		and (lab._match_state == null or lab._match_state.stadium.is_empty())
	)


func _installation_identity() -> bool:
	return (
		is_instance_valid(_lab)
		and _lab.is_inside_tree()
		and not _lab.is_queued_for_deletion()
		and _private_context(_lab)
		and _lab.global_transform == Transform3D.IDENTITY
		and _lab.hillside_private_runtime == self
		and get_parent() == _lab
		and _lab.get_node_or_null(NodePath(NODE_NAME)) == self
		and get_script() == StadiumHillsidePrivateRuntime
		and _lab._field_definition == _field
		and _lab._ball_play_resolver == _resolver
		and is_instance_valid(_primary)
		and _lab._primary_fielder == _primary
		and _primary.is_inside_tree()
		and _primary.get_parent() == _lab
		and not _primary.is_queued_for_deletion()
		and is_instance_valid(_pitcher)
		and _lab._pitcher_marker == _pitcher
		and _pitcher.is_inside_tree()
		and _pitcher.get_parent() == _lab
		and not _pitcher.is_queued_for_deletion()
		and is_instance_valid(terrain)
		and is_instance_valid(boundary)
		and _lab.is_ancestor_of(terrain)
		and _lab.is_ancestor_of(boundary)
		and _resolver.segment_observer == Callable(boundary.graph, "observe")
		and _primary.stadium_boundary_clip == Callable(boundary.graph, "clip")
	)


func automatic_tracking_valid(lab: PitchBatLab, motion: StadiumHillsideDefenderMotion) -> bool:
	return (
		lab == _lab
		and not blocked
		and not _installing
		and _installation_identity()
		and boundary.retained_valid(terrain)
		and is_instance_valid(ground)
		and ground.get_script() == StadiumHillsideGroundContact
		and not ground.blocked
		and ground._installed_valid()
		and ground._terrain_valid()
		and _primary.hillside_motion == _primary_motion
		and lab.hillside_pitcher_motion == _pitcher_motion
		and _primary_motion != null
		and _pitcher_motion != null
		and not _primary_motion.blocked
		and not _pitcher_motion.blocked
		and motion != null
		and motion in [_primary_motion, _pitcher_motion]
	)


func admits_action() -> bool:
	if not automatic_tracking_valid(_lab, _primary_motion):
		return hold("The private Hillside owner, support or route binding changed.")
	return true


func bind_ball(lab: PitchBatLab, ball: BattedBallBody, resolver: BallPlayResolver) -> bool:
	if (
		lab != _lab
		or resolver != _resolver
		or not admits_action()
		or not is_instance_valid(ball)
		or ball != lab._batted_ball
		or ball.get_script() != BattedBallBody
		or ball.get_parent() != lab
		or not ball.is_inside_tree()
		or ball.is_queued_for_deletion()
		or resolver.state == null
		or resolver.state.dead
		or ball._started
	):
		return hold("The private candidate ball must bind before launch.")
	_ball = ball
	_state = resolver.state
	boundary.bind_ball(ball, resolver)
	if not ground.bind_ball(lab, ball, resolver) or not launch_binding_valid(ball, _state):
		return hold("The actual boundary/ground contact routing could not bind.")
	return true


func launch_binding_valid(ball: BattedBallBody, state: BallPlayState) -> bool:
	return (
		automatic_tracking_valid(_lab, _primary_motion)
		and is_instance_valid(ball)
		and ball == _ball
		and _lab._batted_ball == ball
		and ball.get_parent() == _lab
		and ball.is_inside_tree()
		and not ball.is_queued_for_deletion()
		and ball.get_script() == BattedBallBody
		and state != null
		and state == _state
		and _resolver.state == state
		and not state.dead
		and ground._binding_valid(ball, state)
		and ground._terrain_valid()
	)


func clear_ball(ball: BattedBallBody) -> void:
	if ball != _ball:
		return
	if is_instance_valid(ground):
		ground.clear_binding()
	_ball = null
	_state = null


func reject_candidate(ball: Variant, message: String) -> bool:
	# This is the captured candidate, never a callback-installed replacement.
	if (
		is_instance_valid(ball)
		and ball is BattedBallBody
		and is_instance_valid(_lab)
		and ball.get_script() == BattedBallBody
		and ball.get_parent() == _lab
	):
		ball.freeze = true
		if ball.surface_contact.is_connected(_lab._on_batted_surface_contact):
			ball.surface_contact.disconnect(_lab._on_batted_surface_contact)
		clear_ball(ball)
		if _lab._batted_ball == ball:
			_lab._batted_ball = null
		ball.queue_free()
	return hold(message)


func _restore_installation_processing() -> void:
	if not _installing:
		return
	if is_instance_valid(terrain):
		terrain.process_mode = _terrain_process_mode
	if is_instance_valid(boundary):
		boundary.process_mode = _boundary_process_mode


func hold(message: String) -> bool:
	_restore_installation_processing()
	blocked = true
	_installing = false
	last_error = message
	if is_instance_valid(ground):
		ground.clear_binding()
	if is_instance_valid(_lab) and not _closing:
		_lab.process_mode = Node.PROCESS_MODE_DISABLED
		if is_instance_valid(_ball) and _ball.get_parent() == _lab:
			_ball.freeze = true
		if is_instance_valid(_primary):
			_primary.active = false
			_primary.velocity = Vector3.ZERO
		if is_instance_valid(_lab._status_label):
			_lab._status_label.text = "Private Hillside held: " + message
	return false


func _process(_delta: float) -> void:
	_check_live_owner()


func _physics_process(_delta: float) -> void:
	_check_live_owner()


func _check_live_owner() -> void:
	if blocked or _installing or _closing:
		return
	if not admits_action():
		return
	if (
		_resolver.state != null
		and not _resolver.state.dead
		and is_instance_valid(_lab._batted_ball)
		and not launch_binding_valid(_lab._batted_ball, _resolver.state)
	):
		hold("The live ball lost its exact physical contact binding.")


func _invalidate() -> void:
	if not _closing:
		hold("The retained private surface or boundary was changed or removed.")


func _add_markings(host: Node3D) -> void:
	# Existing fair angle and scoring lines, lifted only by sampled physical support.
	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for z: float in [_field.safe_hit_z_m, _field.deep_air_z_m]:
		var half_width: float = z * tan(deg_to_rad(_field.fair_half_angle_degrees))
		mesh.surface_add_vertex(
			Vector3(
				-half_width,
				StadiumHillsideTerrain.support_height(Vector2(-half_width, z), PROFILE) + 0.01,
				z
			)
		)
		mesh.surface_add_vertex(
			Vector3(
				half_width,
				StadiumHillsideTerrain.support_height(Vector2(half_width, z), PROFILE) + 0.01,
				z
			)
		)
	for side: float in [-1.0, 1.0]:
		var previous: Vector3 = Vector3(0, 0.01, 0)
		for z: float in StadiumHillsideTerrain.knots():
			if z <= 0 or z > 23.4:
				continue
			var x: float = side * z * tan(deg_to_rad(_field.fair_half_angle_degrees))
			var at: Vector3 = Vector3(
				x, StadiumHillsideTerrain.support_height(Vector2(x, z), PROFILE) + 0.01, z
			)
			mesh.surface_add_vertex(previous)
			mesh.surface_add_vertex(at)
			previous = at
	mesh.surface_end()
	var drawing: MeshInstance3D = MeshInstance3D.new()
	drawing.name = "HillsideOrdinaryMarkings"
	drawing.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.9, 0.9, 0.78)
	drawing.material_override = material
	host.add_child(drawing)


func _exit_tree() -> void:
	_restore_installation_processing()
	if is_instance_valid(_lab) and not _lab.is_queued_for_deletion():
		hold("The private Hillside owner left the lab; enter a fresh private scene.")
	_closing = true
	blocked = true
	if is_instance_valid(ground):
		ground.clear_binding()
