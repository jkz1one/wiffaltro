class_name StadiumJunkCarRuntime
extends RefCounted
## Exact current-copy car contacts. Entry only admits a ball; quiet dwell proves trapping.

const TRAP_ROLE: String = "JUNK_CAR_UNDERBODY_TRAP"
const SETTLED_SPEED: float = 0.05
const SETTLED_TRAVEL: float = 0.005
const SETTLED_DWELL: float = 0.30
const OBSERVATION_EXPIRY: float = 0.15
const EPS: float = 0.00001


static func capture_trap(model: Node3D, retire: Callable) -> Dictionary:
	var carrier: Node3D = model.get_node_or_null("UnderbodyTrap")
	var visual: Node3D = model.get_node_or_null("Visual")
	if carrier == null or visual == null:
		return {}
	var nodes: Array[Dictionary] = []
	var descendants: Array[Node] = [visual]
	descendants.append_array(visual.find_children("*", "Node3D", true, false))
	for node: Node3D in descendants:
		var row: Dictionary = {
			"node": node,
			"parent": node.get_parent(),
			"pose": node.transform,
			"visible": node.visible,
			"children": node.get_child_count()
		}
		if node is MeshInstance3D:
			row["mesh"] = node.mesh
			if node.mesh == null:
				return {}
			if not node.mesh.changed.is_connected(retire):
				node.mesh.changed.connect(retire)
		nodes.append(row)
	return {
		"carrier": carrier,
		"visual": visual,
		"nodes": nodes,
		"retire": retire,
		"children": model.get_child_count()
	}


static func trap_intact(model: Node3D, seal: Dictionary) -> bool:
	if seal.is_empty() or not is_instance_valid(model) or model.get_child_count() != seal.children:
		return false
	var carrier: Node3D = seal.carrier
	if (
		not is_instance_valid(carrier)
		or carrier.is_queued_for_deletion()
		or model.get_node_or_null("UnderbodyTrap") != carrier
		or carrier.get_parent() != model
		or carrier.transform != Transform3D.IDENTITY
		or carrier.get_child_count() != 0
		or carrier.get_meta("volume_id", "") != StadiumJunkCarModels.TRAP_ID
		or carrier.get_meta("floor", -1.0) != StadiumJunkCarModels.TRAP_FLOOR
		or carrier.get_meta("height", -1.0) != StadiumJunkCarModels.TRAP_HEIGHT
		or carrier.get_meta("polygon", PackedVector2Array()) != StadiumJunkCarModels.trap_polygon()
		or carrier.get_meta("apertures", []) != StadiumJunkCarModels.trap_apertures()
		or model.get_node_or_null("Visual") != seal.visual
	):
		return false
	for row: Dictionary in seal.nodes:
		var node: Node3D = row.node
		if (
			not is_instance_valid(node)
			or node.is_queued_for_deletion()
			or node.get_parent() != row.parent
			or node.transform != row.pose
			or node.visible != row.visible
			or node.get_child_count() != row.children
		):
			return false
		if (
			row.has("mesh")
			and (node.mesh != row.mesh or not row.mesh.changed.is_connected(seal.retire))
		):
			return false
	return true


static func _live(model: Node3D) -> bool:
	return (
		is_instance_valid(model)
		and model.get_meta("stadium_item", "") == "ST-005"
		and model.get_meta("site", "") == StadiumSalvageCarItems.SITE
		and not model.get_meta("scenery_only", true)
		and model.has_node("UnderbodyTrap")
	)


static func native_event(
	property: StadiumPropertyGeometry, body: StaticBody3D, point: Vector3, fraction: float = 1.0
) -> Dictionary:
	if (
		body == null
		or not point.is_finite()
		or not property.props_intact()
		or not property._issued_contacts.has(body)
	):
		return {}
	var copy: String = body.get_meta("owned_copy", "")
	var model: Node3D = property.objects.get(copy)
	if (
		not _live(model)
		or body.get_parent() != model.get_node("Collision")
		or body.get_meta("stadium_item", "") != "ST-005"
		or body.get_meta("surface_id", "") != StadiumJunkCarModels.SURFACE
	):
		return {}
	return {
		"segment": copy + ":" + StadiumJunkCarModels.SURFACE,
		"surface": StadiumJunkCarModels.SURFACE,
		"role": "LIVE_RICOCHET",
		"position": point,
		"fraction": fraction,
		"priority": 400,
		"kind": "junk_car_solid",
		"swept_contact": true,
		"body_id": body.get_instance_id(),
		"owned_copy": copy
	}


static func event(
	property: StadiumPropertyGeometry,
	previous: Vector3,
	current: Vector3,
	radius: float,
	bound: Dictionary,
	allow_trap: bool = true
) -> Dictionary:
	if (
		not property.props_intact()
		or not property.is_inside_tree()
		or not previous.is_finite()
		or not current.is_finite()
		or not is_finite(radius)
		or radius <= EPS
	):
		return {}
	for copy: String in property.objects:
		var model: Node3D = property.objects[copy]
		if not _live(model):
			continue
		var path: AABB = AABB(previous, Vector3.ZERO).expand(current).grow(radius + EPS)
		if not path.intersects(
			(model.global_transform * StadiumJunkCarModels.envelope()).grow(EPS)
		):
			bound.erase("junk_car_trap")
			return {}
		var solid: Dictionary = StadiumLiveFurnishingRuntime._sweep(
			property,
			model.get_node("Collision/" + StadiumJunkCarModels.SURFACE),
			previous,
			current,
			radius,
			native_event
		)
		var trapped: Dictionary = _trap(model, previous, current, radius, bound, solid, allow_trap)
		if not solid.is_empty():
			return solid  # A genuine native solid always precedes a coincident trap completion.
		return trapped
	bound.erase("junk_car_trap")
	return {}


static func interrupt_dwell(bound: Dictionary) -> void:
	if bound.has("junk_car_trap"):
		bound.junk_car_trap["quiet_since"] = -1.0


static func _trap(
	model: Node3D,
	previous: Vector3,
	current: Vector3,
	radius: float,
	bound: Dictionary,
	solid: Dictionary,
	allow_trap: bool
) -> Dictionary:
	if bound.is_empty():
		return {}
	var ball: BattedBallBody = bound.ball.get_ref()
	var resolver: BallPlayResolver = bound.resolver
	if (
		not is_instance_valid(ball)
		or not ball._started
		or ball.freeze
		or resolver.state != bound.state
		or resolver.state.dead
		or not ball.linear_velocity.is_finite()
	):
		bound.erase("junk_car_trap")
		return {}
	var inverse: Transform3D = model.global_transform.affine_inverse()
	var local: Vector3 = inverse * current
	if not StadiumJunkCarModels.trap_contains_local(local, radius):
		bound.erase("junk_car_trap")
		return {}  # A fast pass-through or rebound that exits is still a live ball.
	var now: float = resolver.state.elapsed_seconds
	var pending: Dictionary = bound.get("junk_car_trap", {})
	if (
		not pending.is_empty()
		and (
			pending.serial != bound.serial
			or pending.copy != model.get_meta("owned_copy", "")
			or now < pending.last_time
			or now - float(pending.last_time) > OBSERVATION_EXPIRY
		)
	):
		bound.erase("junk_car_trap")
		pending = {}
	if pending.is_empty():
		var entry: Dictionary = StadiumJunkCarModels.trap_entry_local(
			inverse * previous, local, radius
		)
		if (
			entry.is_empty()
			or (not solid.is_empty() and float(solid.fraction) <= float(entry.fraction) + EPS)
		):
			return {}
		pending = {
			"serial": bound.serial,
			"copy": model.get_meta("owned_copy", ""),
			"last_time": now,
			"last_position": current,
			"quiet_since": -1.0,
			"aperture": entry.aperture,
			"carrier": model.get_node("UnderbodyTrap").get_instance_id()
		}
		bound["junk_car_trap"] = pending
		return {}  # Admission is never itself a scoring event.
	var dt: float = now - float(pending.last_time)
	var travelled: float = current.distance_to(pending.last_position)
	var quiet: bool = (
		allow_trap
		and solid.is_empty()
		and ball.linear_velocity.length() <= SETTLED_SPEED
		and travelled / maxf(dt, 1.0 / Engine.physics_ticks_per_second) <= SETTLED_SPEED
	)
	if not quiet:
		pending.quiet_since = -1.0
	elif (
		float(pending.quiet_since) < 0
		or current.distance_to(pending.get("quiet_position", current)) > SETTLED_TRAVEL
	):
		# Near-rest means at most 5mm over the whole dwell, not a slow pass-through.
		pending.quiet_since = now
		pending["quiet_position"] = current
	pending.last_time = now
	pending.last_position = current
	if not quiet or now - float(pending.quiet_since) + EPS < SETTLED_DWELL:
		return {}
	return {
		"segment": pending.copy + ":" + StadiumJunkCarModels.TRAP_ID,
		"surface": StadiumJunkCarModels.TRAP_ID,
		"role": TRAP_ROLE,
		"position": current,
		"fraction": 1.0,
		"priority": -1,
		"kind": "junk_car_trap",
		"swept_contact": false,
		"body_id": pending.carrier,
		"owned_copy": pending.copy,
		"frame": Engine.get_physics_frames(),
		"observed_at": now
	}


static func apply(
	property: StadiumPropertyGeometry,
	resolver: BallPlayResolver,
	selected: Dictionary,
	bound: Dictionary
) -> bool:
	if (
		not property.props_intact()
		or resolver == null
		or resolver.state == null
		or resolver.state.dead
		or bound.is_empty()
		or property._props_resolver != resolver
		or property._props_play != resolver.state
	):
		return false
	var ball: BattedBallBody = (
		property._props_ball.get_ref() if property._props_ball != null else null
	)
	if (
		not is_instance_valid(ball)
		or bound.ball.get_ref() != ball
		or ball.get_instance_id() != selected.get("ball", -1)
		or ball.get_parent() != property._props_ball_parent
		or property.global_transform != property._props_world
	):
		return false
	var model: Node3D = property.objects.get(selected.get("owned_copy", ""))
	if not _live(model):
		return false
	if selected.kind == "junk_car_solid":
		var body: StaticBody3D = instance_from_id(selected.body_id) as StaticBody3D
		if native_event(property, body, selected.position).is_empty():
			return false
		interrupt_dwell(bound)
		return StadiumSurfaceRules.apply(
			resolver, "LIVE_RICOCHET", selected.owned_copy, selected.position, selected.surface
		)
	var pending: Dictionary = bound.get("junk_car_trap", {})
	var radius: float = StadiumTimberDugoutBoundary.ball_radius(ball)
	if (
		selected.kind != "junk_car_trap"
		or pending.is_empty()
		or pending.serial != bound.serial
		or selected.surface != StadiumJunkCarModels.TRAP_ID
		or selected.role != TRAP_ROLE
		or selected.body_id != model.get_node("UnderbodyTrap").get_instance_id()
		or selected.body_id != pending.carrier
		or selected.owned_copy != pending.copy
		or selected.get("frame", -1) != Engine.get_physics_frames()
		or not is_equal_approx(selected.get("observed_at", -1.0), resolver.state.elapsed_seconds)
		or float(pending.quiet_since) < 0
		or resolver.state.elapsed_seconds - float(pending.quiet_since) + EPS < SETTLED_DWELL
		or ball.freeze
		or not ball._started
		or ball.linear_velocity.length() > SETTLED_SPEED
		or ball.global_position.distance_to(selected.position) > EPS
		or not StadiumJunkCarModels.trap_contains_local(
			model.to_local(ball.global_position), radius
		)
	):
		return false
	bound.erase("junk_car_trap")
	resolver.state.record_stadium_contact(
		"item", selected.owned_copy, selected.surface, TRAP_ROLE, selected.position, "contact"
	)
	StadiumDugoutBoundary.dead_area(
		resolver,
		selected.position,
		(
			&"junk_car_underbody_foul"
			if resolver.state.is_foul_play
			else &"junk_car_underbody_minimum_single"
		)
	)
	return true
