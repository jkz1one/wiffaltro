class_name StadiumHillsideAnchorProbe
extends Node3D
## Private placement/reset lifecycle around the unchanged physically supported H3 actor.
## No live controller, movement command, interception, ball treatment or public admission.

var probe_actor: StadiumHillsideProbeActor
var state: String = "stopped"
var selected_index: int = -1
var last_error: String = ""
var anchor_record: Dictionary = {}
var _field: FieldDefinition
var _terrain: Node3D
var _profile: String = "hill"
var _terrain_signature: String = ""


func _ready() -> void:
	probe_actor = StadiumHillsideProbeActor.new()
	probe_actor.name = "SupportedAnchorActor"
	add_child(probe_actor)
	set_meta("production_ready", false)
	set_meta("geometry_status", "Working")


func configure(field: FieldDefinition, terrain: Node3D,
	profile: String = "hill") -> bool:
	if state != "stopped" and state != "blocked":
		return _reject("Stop before changing the private terrain binding.")
	if field == null or not is_instance_valid(terrain) \
		or not StadiumHillsideTerrain.PROFILES.has(profile) \
		or not is_inside_tree() or not is_instance_valid(probe_actor):
		return _reject("A field, supported profile and ready probe/terrain are required.")
	var signature: String = StadiumHillsideTerrain.signature(profile)
	if not _valid_terrain(terrain, profile, signature):
		return _reject("Expected the untransformed retained terrain binding and collider structure.")
	stop()
	_field = field
	_terrain = terrain
	_profile = profile
	_terrain_signature = signature
	selected_index = -1
	anchor_record = {}
	last_error = ""
	return true


func start(index: int) -> bool:
	if state != "stopped" and state != "blocked":
		return _reject("Start requires a stopped or blocked probe.")
	return _place(index, "idle")


func set_anchor(index: int) -> bool:
	if state != "idle":
		return _reject("Anchor switches are allowed only while idle.")
	return _place(index, "idle")


func begin_play() -> bool:
	if state != "idle":
		return _reject("Begin requires an idle selected anchor.")
	return _place(selected_index, "playing")


func end_play() -> bool:
	if state != "playing":
		return _reject("End requires a playing selected anchor.")
	return _place(selected_index, "idle")


func stop() -> void:
	_quiet_actor()
	state = "stopped"
	last_error = ""


func restart() -> bool:
	if state != "stopped" and state != "blocked":
		return _reject("Restart requires a stopped or blocked selected anchor.")
	return _place(selected_index, "idle")


func _physics_process(_delta: float) -> void:
	if state != "idle" and state != "playing":
		return
	if not is_instance_valid(probe_actor) or not probe_actor.active:
		_block("The retained supported actor stopped.")
		return
	# The actor remains a stationary physical support probe in this bounded slice.
	probe_actor.command = Vector2.ZERO
	var point: Vector2 = Vector2(probe_actor.global_position.x, probe_actor.global_position.z)
	var record: Dictionary = StadiumHillsideAnchorContract.support(point, _profile)
	if record.is_empty() or not _physical_support(record):
		_block("Bound terrain support was removed, changed or left.")


func _place(index: int, next_state: String) -> bool:
	var record: Dictionary = StadiumHillsideAnchorContract.anchor(_field, index, _profile)
	if record.is_empty() or not bool(record.get("available", false)):
		return _reject("The requested existing slot is unavailable or outside the terrain.")
	if not is_instance_valid(probe_actor) or not _physical_support(record):
		return _reject("The selected anchor has no matching bound physical support.")
	var at: Vector3 = record["position"]
	if not probe_actor.place(Vector2(at.x, at.z), _profile):
		return _reject(probe_actor.last_error)
	selected_index = index
	anchor_record = record.duplicate(true)
	state = next_state
	last_error = ""
	return true


func _physical_support(record: Dictionary) -> bool:
	if not is_inside_tree() or not is_instance_valid(_terrain) \
		or not _valid_terrain(_terrain, _profile, _terrain_signature):
		return false
	var at: Vector3 = record["position"]
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		at + Vector3.UP * 3.0, at - Vector3.UP * 3.0,
		StadiumHillsideTerrainModels.QUERY_LAYER)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit["collider"] != _terrain.get_node("TerrainCollision"):
		return false
	var position: Vector3 = hit["position"]
	return position.distance_to(at) <= 0.0002


func _valid_terrain(terrain: Node3D, profile: String, signature: String) -> bool:
	if (
		(
			not is_instance_valid(terrain) or terrain.is_queued_for_deletion() \
					or not terrain.is_inside_tree() or not is_inside_tree()
		)
		or (
			not terrain.has_meta("terrain_profile") or not terrain.has_meta("terrain_signature")
		)
		or (
			terrain.global_transform != Transform3D.IDENTITY \
					or global_transform != Transform3D.IDENTITY \
					or terrain.get_meta("terrain_profile") != profile \
					or terrain.get_meta("terrain_signature") != signature
		)
	):
		return false
	var body: StaticBody3D = terrain.get_node_or_null("TerrainCollision") as StaticBody3D
	if (
		(
			body == null or body.is_queued_for_deletion() \
					or body.transform != Transform3D.IDENTITY
		)
		or (
			not body.has_meta("ball_surface") or not body.has_meta("terrain_profile")
		)
		or (
			body.get_meta("ball_surface") != StadiumHillsideTerrainModels.SURFACE \
					or body.get_meta("terrain_profile") != profile
		)
	):
		return false
	var required_layer: int = 1 | StadiumHillsideTerrainModels.QUERY_LAYER
	if (body.collision_layer & required_layer) != required_layer:
		return false
	var shape: CollisionShape3D = body.get_node_or_null("ClosedTerrainShape") as CollisionShape3D
	return shape != null and not shape.is_queued_for_deletion() and not shape.disabled \
		and shape.transform == Transform3D.IDENTITY and shape.shape is ConcavePolygonShape3D


func _quiet_actor() -> void:
	if is_instance_valid(probe_actor):
		probe_actor.active = false
		probe_actor.command = Vector2.ZERO
		probe_actor.velocity = Vector3.ZERO


func _block(message: String) -> void:
	_quiet_actor()
	state = "blocked"
	last_error = message


func _reject(message: String) -> bool:
	last_error = message
	return false
