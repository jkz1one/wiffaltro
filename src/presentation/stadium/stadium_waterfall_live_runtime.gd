class_name StadiumWaterfallLiveRuntime
extends RefCounted
## Current owned/native authority around the independent, replayable predicate.
## A floor impact may preserve admission, but cannot contribute quiet time.
const Geometry = preload("res://src/presentation/stadium/stadium_waterfall_live_models.gd")
const Witness = preload("res://src/presentation/stadium/stadium_waterfall_trap_witness.gd")
const TRAP_ROLE: String = "WATERFALL_BASIN_TRAP"
const EPS: float = 0.00001
const FLOAT_ENCODING: String = "ieee754-binary64-le-hex-v1"
const NODE_FIELDS: Array[String] = ["transform", "visible", "top_level", "process_mode"]


static func capture_trap(model: Node3D, retire: Callable) -> Dictionary:
	if not Geometry.valid(model) or not _live(model) or not retire.is_valid():
		return {}
	var nodes: Array[Dictionary] = []
	var resources: Array[Dictionary] = []
	var all: Array[Node] = [model]
	all.append_array(model.find_children("*", "Node3D", true, false))
	for node: Node3D in all:
		var fields: Dictionary = {}
		for field: String in NODE_FIELDS:
			fields[field] = node.get(field)
		var metadata: Dictionary = {}
		for key: StringName in node.get_meta_list():
			metadata[key] = node.get_meta(key)
		if node is MeshInstance3D:
			for field: String in StadiumWaterfallMotionOwner.NODE_FIELDS:
				fields[field] = node.get(field)
			fields["mesh"] = node.mesh
			fields["material_override"] = node.material_override
			for resource: Resource in [node.mesh, node.material_override]:
				if not resource.changed.is_connected(retire):
					resource.changed.connect(retire)
				resources.append(
					{
						"resource": resource,
						"fields": StadiumWaterfallMotionOwner._resource_fields(resource)
					}
				)
		if node is StaticBody3D:
			for field: String in [
				"collision_layer",
				"collision_mask",
				"physics_material_override",
				"constant_linear_velocity",
				"constant_angular_velocity"
			]:
				fields[field] = node.get(field)
		if node is CollisionShape3D:
			fields["shape"] = node.shape
			fields["disabled"] = node.disabled
			if not node.shape.changed.is_connected(retire):
				node.shape.changed.connect(retire)
			resources.append(
				{
					"resource": node.shape,
					"fields": StadiumWaterfallMotionOwner._resource_fields(node.shape)
				}
			)
		nodes.append(
			{
				"node": node,
				"parent": node.get_parent(),
				"name": node.name,
				"children": node.get_child_count(),
				"metadata": metadata,
				"fields": fields
			}
		)
	return {
		"model": model,
		"nodes": nodes,
		"resources": resources,
		"retire": retire,
		"carrier": model.get_node("BasinTrap"),
		"body": model.get_node("Collision/" + Geometry.SURFACE)
	}


static func trap_intact(model: Node3D, seal: Dictionary) -> bool:
	if seal.is_empty() or not _live(model) or seal.get("model") != model:
		return false
	for row: Dictionary in seal.nodes:
		var node: Node3D = row.node
		if (
			not is_instance_valid(node)
			or node.is_queued_for_deletion()
			or node.get_script() != null
			or node.get_parent() != row.parent
			or node.name != row.name
			or node.get_child_count() != row.children
			or not StadiumWaterfallMotionOwner._fields_equal(node, row.fields)
		):
			return false
		for key: StringName in row.metadata:
			if (
				not node.has_meta(key)
				or typeof(node.get_meta(key)) != typeof(row.metadata[key])
				or node.get_meta(key) != row.metadata[key]
			):
				return false
		if node is MeshInstance3D and node.get_surface_override_material(0) != null:
			return false
	for row: Dictionary in seal.resources:
		if (
			not is_instance_valid(row.resource)
			or not row.resource.changed.is_connected(seal.retire)
			or not StadiumWaterfallMotionOwner._fields_equal(row.resource, row.fields)
		):
			return false
	var body: StaticBody3D = seal.body
	if body.get_shape_owners().size() != Geometry.SOLID_IDS.size():
		return false
	for index in range(Geometry.SOLID_IDS.size()):
		var shape: CollisionShape3D = body.get_node(Geometry.SOLID_IDS[index])
		var owner: int = body.shape_find_owner(index)
		if (
			body.shape_owner_get_owner(owner) != shape
			or body.is_shape_owner_disabled(owner)
			or body.shape_owner_get_shape_count(owner) != 1
			or body.shape_owner_get_shape(owner, 0) != shape.shape
			or body.shape_owner_get_transform(owner) != shape.transform
		):
			return false
	return true


static func _live(model: Node3D) -> bool:
	return (
		is_instance_valid(model)
		and not model.is_queued_for_deletion()
		and model.get_meta("stadium_item", "") == Geometry.ITEM
		and model.get_meta("site", "") == StadiumWaterfallLiveSites.SITE
		and model.get_meta("waterfall_live_version", -1) == Geometry.VERSION
		and model.get_meta("live_furnishing", false)
		and not model.get_meta("scenery_only", true)
		and not String(model.get_meta("owned_copy", "")).is_empty()
		and model.has_node("BasinTrap")
		and StadiumPoolPartyAssetIntegrity.rigid(
			model.global_transform if model.is_inside_tree() else model.transform
		)
		and (
			(model.global_basis.y if model.is_inside_tree() else model.basis.y).distance_to(
				Vector3.UP
			)
			<= EPS
		)
	)


static func native_event(
	property: StadiumPropertyGeometry, body: StaticBody3D, point: Vector3, fraction: float = 1.0
) -> Dictionary:
	if (
		not is_instance_valid(property)
		or not is_instance_valid(body)
		or not point.is_finite()
		or not is_finite(fraction)
		or fraction < 0
		or fraction > 1
		or not property.props_intact()
		or not property.has_meta("waterfall_live_layout")
		or not property._issued_contacts.has(body)
	):
		return {}
	var copy: String = body.get_meta("owned_copy", "")
	var model: Node3D = property.objects.get(copy)
	if (
		not _live(model)
		or model.get_meta("owned_copy", "") != copy
		or model.get_node_or_null("Collision/" + Geometry.SURFACE) != body
		or body.get_meta("stadium_item", "") != Geometry.ITEM
		or body.get_meta("surface_id", "") != Geometry.SURFACE
		or body.get_meta("surface_role", "") != Geometry.LIVE
	):
		return {}
	return {
		"segment": copy + ":" + Geometry.SURFACE,
		"surface": Geometry.SURFACE,
		"role": Geometry.LIVE,
		"position": point,
		"fraction": fraction,
		"priority": 400,
		"kind": "waterfall_solid",
		"swept_contact": true,
		"body_id": body.get_instance_id(),
		"owned_copy": copy,
		"frame": Engine.get_physics_frames(),
		"observed_at":
		-1.0 if property._props_play == null else property._props_play.elapsed_seconds
	}


static func _bound_current(
	property: StadiumPropertyGeometry, bound: Dictionary, current: Vector3, radius: float
) -> bool:
	if (
		bound.is_empty()
		or not bound.get("ball") is WeakRef
		or not bound.get("resolver") is BallPlayResolver
		or not bound.get("serial") is int
		or bound.serial <= 0
	):
		return false
	var ball: BattedBallBody = bound.ball.get_ref() as BattedBallBody
	var resolver: BallPlayResolver = bound.resolver
	return (
		is_instance_valid(ball)
		and ball.is_inside_tree()
		and not ball.is_queued_for_deletion()
		and ball._started
		and not ball.freeze
		and ball.linear_velocity.is_finite()
		and resolver.state != null
		and resolver.state == bound.get("state")
		and not resolver.state.dead
		and resolver.field == bound.get("field")
		and ball.get_parent() == bound.get("parent")
		and is_finite(resolver.state.elapsed_seconds)
		and resolver.state.elapsed_seconds >= 0
		and property._props_ball != null
		and property._props_ball.get_ref() == ball
		and property._props_resolver == resolver
		and property._props_play == resolver.state
		and ball.get_parent() == property._props_ball_parent
		and property.global_transform == property._props_world
		and ball.global_position.distance_to(current) <= EPS
		and radius == StadiumTimberDugoutBoundary.ball_radius(ball)
	)


static func event(
	property: StadiumPropertyGeometry,
	previous: Vector3,
	current: Vector3,
	radius: float,
	bound: Dictionary,
	allow_trap: bool = true
) -> Dictionary:
	if (
		not is_instance_valid(property)
		or not property.props_intact()
		or not property.is_inside_tree()
		or not previous.is_finite()
		or not current.is_finite()
		or not is_finite(radius)
		or radius <= EPS
	):
		bound.erase("waterfall_trap")
		return {}
	var current_bound: bool = _bound_current(property, bound, current, radius)
	if not current_bound:
		bound.erase("waterfall_trap")
	for copy: String in property.objects:
		var model: Node3D = property.objects[copy]
		if not _live(model):
			continue
		var path: AABB = AABB(previous, Vector3.ZERO).expand(current).grow(radius + EPS)
		if not path.intersects((model.global_transform * Geometry.envelope()).grow(EPS)):
			bound.erase("waterfall_trap")
			continue
		var body: StaticBody3D = model.get_node("Collision/" + Geometry.SURFACE)
		var solid: Dictionary = StadiumLiveFurnishingRuntime._sweep(
			property, body, previous, current, radius, native_event
		)
		if not current_bound:
			return solid
		var ball: BattedBallBody = bound.ball.get_ref()
		var native: Dictionary = _current_native(property, model, ball, radius)
		# Sustained exact floor support is not a fresh collision. The first contact,
		# any penetration/rebound, and every other solid still take solid priority.
		var supported_path: bool = (
			native.contact == "support"
			and Geometry.trap_contains_local(model.to_local(previous), radius)
			and (
				previous.distance_to(current)
				<= Witness.SPEED / Engine.physics_ticks_per_second + EPS
			)
		)
		if supported_path:
			solid = {}
		var trapped: Dictionary = _observe(
			model, previous, current, radius, bound, native, solid, allow_trap
		)
		if not solid.is_empty():
			return solid
		return trapped
	bound.erase("waterfall_trap")
	return {}


static func _current_native(
	property: StadiumPropertyGeometry, model: Node3D, ball: BattedBallBody, radius: float
) -> Dictionary:
	var body: StaticBody3D = model.get_node("Collision/" + Geometry.SURFACE)
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = SphereShape3D.new()
	query.shape.radius = radius
	query.shape.margin = 0
	query.margin = 0
	query.transform.origin = ball.global_position
	query.collision_mask = body.collision_layer
	var excluded: Array[RID] = [ball.get_rid()]
	for other: Node in property.find_children("*", "CollisionObject3D", true, false):
		if other != body:
			excluded.append((other as CollisionObject3D).get_rid())
	query.exclude = excluded
	var space: PhysicsDirectSpaceState3D = property.get_world_3d().direct_space_state
	var floor_overlap: bool = false
	var other_overlap: bool = false
	for hit: Dictionary in space.intersect_shape(query, 32):
		if hit.get("collider") != body:
			continue
		var owner: Node = body.shape_owner_get_owner(body.shape_find_owner(hit.shape))
		if owner == body.get_node("BasinFloor"):
			floor_overlap = true
		else:
			other_overlap = true
	if other_overlap:
		return {"contact": "impact", "floor": false}
	var local: Vector3 = model.to_local(ball.global_position)
	var floor_contact: bool = false
	var support_y: float = Geometry.basin_volume().position.y + radius
	if floor_overlap or ball.get_colliding_bodies().has(body):
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			ball.global_position + Vector3.UP * 0.02,
			ball.global_position - Vector3.UP * (radius + 0.02),
			body.collision_layer,
			excluded
		)
		var hit: Dictionary = space.intersect_ray(ray)
		floor_contact = (
			not hit.is_empty()
			and hit.get("collider") == body
			and hit.get("normal", Vector3.ZERO).distance_to(Vector3.UP) <= 0.001
			and absf(model.to_local(hit.position).y - Geometry.basin_volume().position.y) <= EPS
			and (
				body.shape_owner_get_owner(body.shape_find_owner(hit.shape))
				== body.get_node("BasinFloor")
			)
		)
		# Native sphere queries include tangency. Require current exact-floor
		# contact and a nonpenetrating centre, never a penetration/recovery epsilon.
		if (
			floor_overlap
			and floor_contact
			and local.y >= support_y
			and local.y <= _native_support_ceiling(radius)
			and Witness.support_contact(
				"BasinFloor",
				model.to_local(hit.position),
				model.global_basis.inverse() * hit.normal,
				model.global_basis.inverse() * ball.linear_velocity,
				radius
			)
			and Geometry.trap_contains_local(local, radius)
		):
			return {"contact": "support", "floor": true}
	if floor_contact:
		return {"contact": "floor_impact", "floor": true}
	# The predicate permits geometry-only replay; authority requires actual support.
	return {
		"contact": "impact" if Geometry.trap_contains_local(local, radius) else "none",
		"floor": false
	}


static func interrupt_dwell(bound: Dictionary) -> void:
	var pending: Dictionary = bound.get("waterfall_trap", {})
	if pending.is_empty():
		return
	pending["interrupted"] = true
	pending["proof"] = {}
	var witness: StadiumWaterfallTrapWitness = pending.witness
	witness._quiet_since = -1.0
	witness._quiet_travel = 0.0
	witness._proof.clear()


static func native_impact(
	property: StadiumPropertyGeometry, ball: BattedBallBody, bound: Dictionary
) -> bool:
	var radius: float = StadiumTimberDugoutBoundary.ball_radius(ball)
	if (
		not property.props_intact()
		or not _bound_current(property, bound, ball.global_position, radius)
	):
		bound.erase("waterfall_trap")
		return false
	for copy: String in property.objects:
		var model: Node3D = property.objects[copy]
		if not _live(model):
			continue
		var native: Dictionary = _current_native(property, model, ball, radius)
		if native.contact in ["impact", "floor_impact"]:
			interrupt_dwell(bound)
			return true
	return false


static func _observe(
	model: Node3D,
	previous: Vector3,
	current: Vector3,
	radius: float,
	bound: Dictionary,
	native: Dictionary,
	solid: Dictionary,
	allow_trap: bool
) -> Dictionary:
	var ball: BattedBallBody = bound.ball.get_ref()
	var resolver: BallPlayResolver = bound.resolver
	var pending: Dictionary = bound.get("waterfall_trap", {})
	var frame: int = Engine.get_physics_frames()
	var now: float = resolver.state.elapsed_seconds
	if (
		not pending.is_empty()
		and (
			pending.serial != bound.serial
			or pending.model != model
			or pending.parent != model.get_parent()
			or pending.world != model.global_transform
			or pending.copy != model.get_meta("owned_copy", "")
			or pending.radius != radius
		)
	):
		bound.erase("waterfall_trap")
		return {}
	if pending.is_empty():
		pending = {
			"serial": bound.serial,
			"model": model,
			"parent": model.get_parent(),
			"world": model.global_transform,
			"copy": model.get_meta("owned_copy", ""),
			"radius": radius,
			"witness": Witness.new(),
			"proof": {},
			"interrupted": false
		}
		bound["waterfall_trap"] = pending
	var witness: StadiumWaterfallTrapWitness = pending.witness
	if not witness._samples.is_empty() and witness._samples.back().frame == frame:
		return {}  # Router and observer cannot manufacture two observations in one physics frame.
	var contact: String = native.contact
	if (
		(not allow_trap or pending.interrupted or not solid.is_empty())
		and contact != "floor_impact"
	):
		contact = "impact"
	pending.interrupted = false
	var inverse: Transform3D = model.global_transform.affine_inverse()
	var proof: Dictionary = witness.observe(
		{
			"copy": pending.copy,
			"serial": bound.serial,
			"frame": frame,
			"time": now,
			"previous": inverse * previous,
			"position": inverse * current,
			"velocity": inverse.basis * ball.linear_velocity,
			"radius": radius,
			"active": true,
			"contact": contact
		}
	)
	pending.proof = proof.duplicate(true)
	if witness._samples.is_empty():
		bound.erase("waterfall_trap")
		return {}
	if proof.is_empty() or not native_proof_valid(proof) or not solid.is_empty() or not allow_trap:
		return {}
	return {
		"segment": pending.copy + ":" + Geometry.TRAP_ID,
		"surface": Geometry.TRAP_ID,
		"role": TRAP_ROLE,
		"position": current,
		"fraction": 1.0,
		"priority": -1,
		"kind": "waterfall_trap",
		"swept_contact": false,
		"body_id": model.get_node("BasinTrap").get_instance_id(),
		"owned_copy": pending.copy,
		"frame": frame,
		"observed_at": now,
		"waterfall_proof": proof.duplicate(true)
	}


static func apply(
	property: StadiumPropertyGeometry,
	resolver: BallPlayResolver,
	selected: Dictionary,
	bound: Dictionary
) -> bool:
	if (
		not is_instance_valid(property)
		or not property.props_intact()
		or resolver == null
		or resolver.state == null
		or resolver.state.dead
		or bound.get("resolver") != resolver
		or not selected.get("position") is Vector3
		or not selected.position.is_finite()
	):
		return false
	var ball: BattedBallBody = bound.ball.get_ref() if bound.get("ball") is WeakRef else null
	if not is_instance_valid(ball):
		return false
	var radius: float = StadiumTimberDugoutBoundary.ball_radius(ball)
	if (
		not _bound_current(property, bound, ball.global_position, radius)
		or selected.get("ball", -1) != ball.get_instance_id()
		or selected.get("serial", -1) != bound.serial
		or selected.get("flight", -1) != resolver.get_instance_id()
		or selected.get("play", -1) != resolver.state.get_instance_id()
		or selected.get("frame", -1) != Engine.get_physics_frames()
		or selected.get("observed_at", -1.0) != resolver.state.elapsed_seconds
	):
		return false
	var model: Node3D = property.objects.get(selected.get("owned_copy", ""))
	if not _live(model):
		return false
	if selected.get("kind", "") == "waterfall_solid":
		var body: StaticBody3D = instance_from_id(selected.get("body_id", 0)) as StaticBody3D
		if (
			selected.get("role") != Geometry.LIVE
			or selected.get("surface") != Geometry.SURFACE
			or native_event(property, body, selected.position).is_empty()
		):
			return false
		interrupt_dwell(bound)
		return StadiumSurfaceRules.apply(
			resolver, Geometry.LIVE, selected.owned_copy, selected.position, selected.surface
		)
	var pending: Dictionary = bound.get("waterfall_trap", {})
	if (
		selected.get("kind") != "waterfall_trap"
		or pending.is_empty()
		or pending.interrupted
		or pending.serial != bound.serial
		or pending.model != model
		or pending.parent != model.get_parent()
		or pending.world != model.global_transform
		or pending.copy != selected.owned_copy
		or pending.radius != radius
		or selected.get("surface") != Geometry.TRAP_ID
		or selected.get("role") != TRAP_ROLE
		or selected.get("body_id") != model.get_node("BasinTrap").get_instance_id()
		or not selected.get("waterfall_proof") is Dictionary
		or pending.proof != selected.waterfall_proof
		or not Witness.replay(pending.proof)
		or ball.global_position.distance_to(selected.position) > EPS
		or not Geometry.trap_contains_local(model.to_local(ball.global_position), radius)
		or _current_native(property, model, ball, radius).contact != "support"
	):
		return false
	var proof: Dictionary = proof_to_data(pending.proof)
	if proof.is_empty():
		return false
	bound.erase("waterfall_trap")  # Consume before any callback can attempt a second application.
	resolver.state.record_stadium_contact(
		"item", selected.owned_copy, Geometry.TRAP_ID, TRAP_ROLE, selected.position, "contact"
	)
	var record: Dictionary = resolver.state.stadium_contacts.back()
	record["waterfall_proof"] = proof
	record["earned_floor"] = int(resolver.state.result_floor)
	record["waterfall_floor_evidence"] = (
		bound
		. get("waterfall_floor", {"version": 1, "serial": bound.serial, "events": []})
		. duplicate(true)
	)
	record["waterfall_layout_hash"] = (
		JSON.stringify(property.get_meta("waterfall_live_layout", {}), "", true, true).sha256_text()
	)
	StadiumDugoutBoundary.dead_area(
		resolver,
		selected.position,
		(
			&"waterfall_basin_foul"
			if resolver.state.is_foul_play
			else &"waterfall_basin_minimum_single"
		)
	)
	return true


static func record_bands(
	property: StadiumPropertyGeometry,
	bound: Dictionary,
	previous: Vector3,
	current: Vector3,
	before_floor: int
) -> void:
	if (
		not previous.is_finite()
		or not current.is_finite()
		or bound.is_empty()
		or not bound.get("ball") is WeakRef
	):
		return
	var ball: BattedBallBody = bound.ball.get_ref() as BattedBallBody
	if (
		not is_instance_valid(ball)
		or not property.props_intact()
		or not _bound_current(
			property, bound, ball.global_position, StadiumTimberDugoutBoundary.ball_radius(ball)
		)
	):
		return
	var resolver: BallPlayResolver = bound.resolver
	var after_floor: int = int(resolver.state.result_floor)
	if after_floor <= before_floor:
		return
	var evidence: Dictionary = bound.get(
		"waterfall_floor", {"version": 1, "serial": bound.serial, "events": []}
	)
	if evidence.serial != bound.serial or evidence.events.size() >= 2:
		return  # The fixed two ordinary bands cannot yield more than two increases.
	evidence.events.append(
		{
			"frame": Engine.get_physics_frames(),
			"time": resolver.state.elapsed_seconds,
			"previous": _vector_data(previous),
			"position": _vector_data(current),
			"grounded": resolver.state.has_grounded,
			"touched": resolver.state.defender_touched,
			"foul": resolver.state.is_foul_play,
			"before": before_floor,
			"after": after_floor
		}
	)
	bound["waterfall_floor"] = evidence


static func floor_evidence_valid(
	value: Variant, proof: Dictionary, earned_floor: int, field: FieldDefinition
) -> bool:
	if (
		not Witness.replay(proof)
		or not value is Dictionary
		or not Witness._exact_keys(value, ["version", "serial", "events"])
		or not _whole(value.version)
		or int(value.version) != 1
		or not _whole(value.serial)
		or value.serial != proof.get("serial", -1)
		or not value.events is Array
		or value.events.size() > 2
		or field == null
		or not is_finite(field.safe_hit_z_m)
		or not is_finite(field.deep_air_z_m)
		or field.safe_hit_z_m <= 0
		or field.deep_air_z_m <= field.safe_hit_z_m
		or earned_floor < 0
		or earned_floor > BallPlayState.ResultFloor.DOUBLE
	):
		return false
	var floor_value: int = BallPlayState.ResultFloor.NONE
	var last_frame: int = -1
	var last_time: float = -1.0
	var grounded: bool = false
	var touched: bool = false
	var observer: BallPlayResolver = BallPlayResolver.new()
	for event: Variant in value.events:
		if (
			not event is Dictionary
			or not Witness._exact_keys(
				event,
				[
					"frame",
					"time",
					"previous",
					"position",
					"grounded",
					"touched",
					"foul",
					"before",
					"after"
				]
			)
			or not _whole(event.frame)
			or int(event.frame) <= last_frame
			or int(event.frame) > proof.get("frame", -1)
			or not (event.time is int or event.time is float)
			or not is_finite(float(event.time))
			or event.time < 0
			or event.time <= last_time
			or event.time > proof.get("observed_at", -1.0)
			or not _data_vector(event.previous)
			or not _data_vector(event.position)
			or not event.grounded is bool
			or not event.touched is bool
			or not event.foul is bool
			or event.foul
			or (grounded and not event.grounded)
			or (touched and not event.touched)
			or not _whole(event.before)
			or not _whole(event.after)
			or int(event.before) != floor_value
			or int(event.after) <= floor_value
			or event.after > BallPlayState.ResultFloor.DOUBLE
		):
			return false
		var previous: Vector3 = Vector3(event.previous[0], event.previous[1], event.previous[2])
		var current: Vector3 = Vector3(event.position[0], event.position[1], event.position[2])
		var safe: Vector3 = observer._forward_plane_crossing(previous, current, field.safe_hit_z_m)
		var deep: Vector3 = observer._forward_plane_crossing(previous, current, field.deep_air_z_m)
		if safe != Vector3.INF and field.is_fair_point(safe):
			floor_value = maxi(floor_value, BallPlayState.ResultFloor.SINGLE)
		if (
			deep != Vector3.INF
			and field.is_fair_point(deep)
			and not event.grounded
			and not event.touched
		):
			floor_value = maxi(floor_value, BallPlayState.ResultFloor.DOUBLE)
		if floor_value != int(event.after):
			return false
		last_frame = int(event.frame)
		last_time = float(event.time)
		grounded = event.grounded
		touched = event.touched
	return floor_value == earned_floor


static func _native_support_ceiling(radius: float) -> float:
	# Vector3 positions are binary32. The least representable centre at or above
	# the exact floor-plus-radius sum is native-admissible nonpenetrating support.
	# Native queries include tangency, not a millimetre-scale hovering allowance.
	var exact: float = Geometry.basin_volume().position.y + radius
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(4)
	bytes.encode_float(0, exact)
	if bytes.decode_float(0) < exact:
		bytes.encode_u32(0, bytes.decode_u32(0) + 1)
	return bytes.decode_float(0)


static func native_proof_valid(proof: Dictionary) -> bool:
	if not Witness.replay(proof):
		return false
	var supported: int = 0
	for sample: Dictionary in proof.samples:
		if sample.time < proof.quiet_since:
			continue
		var exact: float = Geometry.basin_volume().position.y + float(sample.radius)
		if (
			sample.contact != "support"
			or sample.position.y < exact
			or sample.position.y > _native_support_ceiling(sample.radius)
		):
			return false
		supported += 1
	return supported >= 2


static func proof_to_data(proof: Dictionary) -> Dictionary:
	if not native_proof_valid(proof):
		return {}
	var data: Dictionary = proof.duplicate(true)
	data["float_encoding"] = FLOAT_ENCODING
	for key: String in ["quiet_since", "observed_at", "radius"]:
		data[key] = _float_data(float(data[key]))
	data.entry.fraction = _float_data(float(data.entry.fraction))
	data.position = _vector_data(proof.position)
	data.entry.position = _vector_data(proof.entry.position)
	for row: Dictionary in data.samples:
		for key: String in ["time", "radius"]:
			row[key] = _float_data(float(row[key]))
		for key: String in ["previous", "position", "velocity"]:
			row[key] = _vector_data(row[key])
	return data


static func proof_from_data(value: Variant) -> Dictionary:
	if (
		not value is Dictionary
		or not value.get("samples") is Array
		or value.samples.is_empty()
		or value.samples.size() > Witness.MAX_SAMPLES
		or not value.get("entry") is Dictionary
		or value.get("float_encoding") != FLOAT_ENCODING
	):
		return {}
	var proof: Dictionary = value.duplicate(true)
	proof.erase("float_encoding")
	for key: String in ["quiet_since", "observed_at", "radius"]:
		if not _float_data_valid(proof.get(key)):
			return {}
		proof[key] = String(proof[key]).hex_decode().decode_double(0)
	if not _float_data_valid(proof.entry.get("fraction")):
		return {}
	proof.entry.fraction = String(proof.entry.fraction).hex_decode().decode_double(0)
	for key: String in ["version", "serial", "frame"]:
		if not _whole(proof.get(key)):
			return {}
		proof[key] = int(proof[key])
	if not _data_vector(proof.get("position")) or not _data_vector(proof.entry.get("position")):
		return {}
	proof.position = Vector3(proof.position[0], proof.position[1], proof.position[2])
	proof.entry.position = Vector3(
		proof.entry.position[0], proof.entry.position[1], proof.entry.position[2]
	)
	var typed_samples: Array[Dictionary] = []
	for sample: Variant in proof.samples:
		if not sample is Dictionary:
			return {}
		for key: String in ["time", "radius"]:
			if not _float_data_valid(sample.get(key)):
				return {}
			sample[key] = String(sample[key]).hex_decode().decode_double(0)
		for key: String in ["serial", "frame"]:
			if not _whole(sample.get(key)):
				return {}
			sample[key] = int(sample[key])
		for key: String in ["previous", "position", "velocity"]:
			if not _data_vector(sample.get(key)):
				return {}
			sample[key] = Vector3(sample[key][0], sample[key][1], sample[key][2])
		typed_samples.append(sample)
	proof.samples = typed_samples
	return proof if native_proof_valid(proof) else {}


static func _float_data(value: float) -> String:
	# Godot JSON's decimal parser can alter binary64 samples by one ULP even
	# with full_precision=true. Exact fixed-size scalar bytes avoid relaxing replay.
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	return bytes.hex_encode()


static func _float_data_valid(value: Variant) -> bool:
	if not value is String or value.length() != 16:
		return false
	for index in range(value.length()):
		if String(value)[index] not in "0123456789abcdef":
			return false
	var bytes: PackedByteArray = String(value).hex_decode()
	return (
		bytes.size() == 8
		and is_finite(bytes.decode_double(0))
		and _float_data(bytes.decode_double(0)) == value
	)


static func _whole(value: Variant) -> bool:
	return (
		(value is int or value is float)
		and is_finite(float(value))
		and value >= 0
		and value <= 9007199254740991
		and float(value) == floorf(float(value))
	)


static func _data_vector(value: Variant) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for coordinate: Variant in value:
		if (
			not (coordinate is int or coordinate is float)
			or not is_finite(float(coordinate))
			or absf(float(coordinate)) > 10000
		):
			return false
	return true


static func _vector_data(value: Vector3) -> Array:
	return [value.x, value.y, value.z]
