class_name StadiumLiveFurnishingRuntime
extends RefCounted
## Shared exact-copy furnishing contacts. The existing boundary owns flight and event issuance.

const WATER_SURFACE: String = "ST007_WATER_VOLUME_v1"
const WATER_ROLE: String = "HOT_TUB_WATER"
const EPS: float = 0.00001


static func capture_water(model: Node3D, retire: Callable) -> Dictionary:
	var carrier: Node3D = model.get_node_or_null("WaterVolume")
	var visual: MeshInstance3D = model.get_node_or_null("Visual/TubWater")
	if carrier == null or visual == null or visual.mesh == null:
		return {}
	if not visual.mesh.changed.is_connected(retire):
		visual.mesh.changed.connect(retire)
	return {
		"carrier": carrier,
		"visual": visual,
		"mesh": visual.mesh,
		"visual_pose": visual.transform,
		"visual_parent": visual.get_parent(),
		"visual_parent_pose": (visual.get_parent() as Node3D).transform,
		"retire": retire
	}


static func water_intact(model: Node3D, seal: Dictionary) -> bool:
	if seal.is_empty() or not is_instance_valid(model):
		return false
	var carrier: Node3D = seal.carrier
	var visual: MeshInstance3D = seal.visual
	return (
		is_instance_valid(carrier)
		and model.get_node_or_null("WaterVolume") == carrier
		and carrier.transform == Transform3D.IDENTITY
		and not carrier.is_queued_for_deletion()
		and carrier.get_meta("volume_id", "") == WATER_SURFACE
		and carrier.get_meta("floor", -1.0) == StadiumLiveFurnishingModels.TUB_FLOOR
		and carrier.get_meta("height", -1.0) == StadiumLiveFurnishingModels.TUB_WATER
		and (
			carrier.get_meta("polygon", PackedVector2Array())
			== StadiumLiveFurnishingModels.water_polygon()
		)
		and is_instance_valid(visual)
		and not visual.is_queued_for_deletion()
		and is_instance_valid(seal.visual_parent)
		and not seal.visual_parent.is_queued_for_deletion()
		and model.get_node_or_null("Visual") == seal.visual_parent
		and visual.get_parent() == seal.visual_parent
		and seal.visual_parent.transform == seal.visual_parent_pose
		and model.get_node_or_null("Visual/TubWater") == visual
		and visual.transform == seal.visual_pose
		and visual.mesh == seal.mesh
		and visual.mesh.changed.is_connected(seal.retire)
	)


static func event(
	property: StadiumPropertyGeometry,
	previous: Vector3,
	current: Vector3,
	radius: float,
	allow_water: bool = true
) -> Dictionary:
	if (
		not property.props_intact()
		or not property.is_inside_tree()
		or not previous.is_finite()
		or not current.is_finite()
		or not is_finite(radius)
		or radius <= 0
	):
		return {}
	var candidates: Array[Dictionary] = []
	for copy: String in property.objects:
		var model: Node3D = property.objects[copy]
		var item: String = model.get_meta("stadium_item", "")
		if not StadiumLiveFurnishingItems.PRICES.has(item) or not _live(model):
			continue
		var box: AABB = model.global_transform * StadiumLiveFurnishingModels.envelope(item)
		var path: AABB = AABB(previous, Vector3.ZERO).expand(current).grow(radius + EPS)
		if not path.intersects(box.grow(EPS)):
			continue
		for body: StaticBody3D in model.get_node("Collision").get_children():
			var hit: Dictionary = _sweep(property, body, previous, current, radius)
			if not hit.is_empty():
				candidates.append(hit)
		if item == "ST-007" and allow_water:
			var water: Dictionary = water_entry(model, previous, current, radius)
			if not water.is_empty():
				candidates.append(water)
	candidates.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return StadiumTimberDugoutBoundary.precedes(a, b, previous.distance_to(current))
	)
	return {} if candidates.is_empty() else candidates[0]


static func _live(model: Node3D) -> bool:
	var site: String = model.get_meta("site", "")
	return site in ["O-L1", "O-L2", "O-R1", "O-R2", "OL-L", "OL-R"]


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
	var item: String = body.get_meta("stadium_item", "")
	if (
		not is_instance_valid(model)
		or not StadiumLiveFurnishingItems.PRICES.has(item)
		or model.get_meta("stadium_item", "") != item
		or not _live(model)
		or body.get_parent() != model.get_node("Collision")
	):
		return {}
	return {
		"segment": copy + ":" + body.get_meta("surface_id", ""),
		"surface": body.get_meta("surface_id", ""),
		"role": "LIVE_RICOCHET",
		"position": point,
		"fraction": fraction,
		"priority": 400,
		"kind": "furnishing_solid",
		"swept_contact": true,
		"body_id": body.get_instance_id(),
		"owned_copy": copy
	}


static func _sweep(
	property: StadiumPropertyGeometry,
	body: StaticBody3D,
	previous: Vector3,
	current: Vector3,
	radius: float,
	emitter: Callable = Callable()
) -> Dictionary:
	var contact_event: Callable = native_event if not emitter.is_valid() else emitter
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = SphereShape3D.new()
	query.shape.radius = radius
	query.shape.margin = 0
	query.margin = 0
	query.collision_mask = body.collision_layer
	query.transform.origin = previous
	var excluded: Array[RID] = []
	for other: Node in property.find_children("*", "CollisionObject3D", true, false):
		if other != body:
			excluded.append((other as CollisionObject3D).get_rid())
	query.exclude = excluded
	var space: PhysicsDirectSpaceState3D = property.get_world_3d().direct_space_state
	var overlaps: Array[Dictionary] = space.intersect_shape(query, 1)
	if not overlaps.is_empty():
		return (
			contact_event.call(property, body, previous, 0.0)
			if overlaps[0].get("collider") == body
			else {}
		)
	query.motion = current - previous
	var motion: PackedFloat32Array = space.cast_motion(query)
	if motion.size() != 2 or motion[0] >= 1:
		return {}
	query.transform.origin = previous.lerp(
		current, minf(1.0, motion[1] + EPS / maxf(previous.distance_to(current), EPS))
	)
	query.motion = Vector3.ZERO
	var witness: Dictionary = space.get_rest_info(query)
	if (
		witness.is_empty()
		or witness.get("collider_id", 0) != body.get_instance_id()
		or witness.get("rid") != body.get_rid()
		or not witness.get("point") is Vector3
	):
		return {}
	return contact_event.call(property, body, witness.point, motion[0])


static func water_distance_squared(local: Vector3) -> float:
	var polygon: PackedVector2Array = StadiumLiveFurnishingModels.water_polygon()
	var point: Vector2 = Vector2(local.x, local.z)
	var inside: bool = true
	var horizontal: float = INF
	for index in range(polygon.size()):
		var start: Vector2 = polygon[index]
		var edge: Vector2 = polygon[(index + 1) % polygon.size()] - start
		var offset: Vector2 = point - start
		if edge.cross(offset) < 0:
			inside = false
		var nearest: Vector2 = start + edge * clampf(offset.dot(edge) / edge.length_squared(), 0, 1)
		horizontal = minf(horizontal, point.distance_squared_to(nearest))
	if inside:
		horizontal = 0
	var vertical: float = maxf(
		maxf(
			StadiumLiveFurnishingModels.TUB_FLOOR - local.y,
			local.y - StadiumLiveFurnishingModels.TUB_WATER
		),
		0
	)
	return horizontal + vertical * vertical


static func water_entry(
	model: Node3D, previous: Vector3, current: Vector3, radius: float
) -> Dictionary:
	if (
		not is_instance_valid(model)
		or model.get_meta("stadium_item", "") != "ST-007"
		or not _live(model)
		or radius <= EPS
		or not previous.is_finite()
		or not current.is_finite()
	):
		return {}
	var inverse: Transform3D = model.global_transform.affine_inverse()
	var a: Vector3 = inverse * previous
	var b: Vector3 = inverse * current
	var limit: float = (radius - EPS) * (radius - EPS)
	var fraction: float = 0
	if water_distance_squared(a) >= limit:
		# Squared distance to this convex authored polygon-prism is convex on a segment.
		# Locate its minimum, then the first strictly positive sphere/water overlap.
		var lo: float = 0
		var hi: float = 1
		for iteration in range(40):
			var left: float = (2 * lo + hi) / 3
			var right: float = (lo + 2 * hi) / 3
			if water_distance_squared(a.lerp(b, left)) <= water_distance_squared(a.lerp(b, right)):
				hi = right
			else:
				lo = left
		var minimum: float = (lo + hi) * 0.5
		if water_distance_squared(b) < water_distance_squared(a.lerp(b, minimum)):
			minimum = 1
		if water_distance_squared(a.lerp(b, minimum)) >= limit:
			return {}
		lo = 0
		hi = minimum
		for iteration in range(40):
			var middle: float = (lo + hi) * 0.5
			if water_distance_squared(a.lerp(b, middle)) < limit:
				hi = middle
			else:
				lo = middle
		fraction = hi
	var point: Vector3 = previous.lerp(current, fraction)
	var carrier: Node3D = model.get_node_or_null("WaterVolume")
	if carrier == null or water_distance_squared(inverse * point) >= radius * radius:
		return {}
	return {
		"segment": model.get_meta("owned_copy", "") + ":" + WATER_SURFACE,
		"surface": WATER_SURFACE,
		"role": WATER_ROLE,
		"position": point,
		"fraction": fraction,
		"priority": -1,
		"kind": "furnishing_water",
		"swept_contact": false,
		"body_id": carrier.get_instance_id(),
		"owned_copy": model.get_meta("owned_copy", "")
	}


static func apply(
	property: StadiumPropertyGeometry, resolver: BallPlayResolver, selected: Dictionary
) -> bool:
	if (
		not property.props_intact()
		or resolver == null
		or resolver.state == null
		or resolver.state.dead
	):
		return false
	var ball: BattedBallBody = (
		property._props_ball.get_ref() if property._props_ball != null else null
	)
	if (
		not is_instance_valid(ball)
		or ball.get_instance_id() != selected.get("ball", -1)
		or property._props_resolver != resolver
		or property._props_play != resolver.state
		or ball.get_parent() != property._props_ball_parent
		or property.global_transform != property._props_world
	):
		return false
	var copy: String = selected.get("owned_copy", "")
	var model: Node3D = property.objects.get(copy)
	if not is_instance_valid(model) or not _live(model):
		return false
	if selected.kind == "furnishing_solid":
		var body: StaticBody3D = instance_from_id(selected.body_id) as StaticBody3D
		if native_event(property, body, selected.position).is_empty():
			return false
		var applied: bool = StadiumSurfaceRules.apply(
			resolver, "LIVE_RICOCHET", copy, selected.position, selected.surface
		)
		if applied and model.get_meta("stadium_item", "") == "ST-002":
			StadiumLiveFurnishingModels.wobble(model)
		return applied
	if (
		selected.kind != "furnishing_water"
		or model.get_meta("stadium_item", "") != "ST-007"
		or selected.surface != WATER_SURFACE
		or model.get_node("WaterVolume").get_instance_id() != selected.body_id
	):
		return false
	resolver.state.record_stadium_contact(
		"item", copy, WATER_SURFACE, WATER_ROLE, selected.position, "contact"
	)
	if resolver.state.is_foul_play:
		resolver._resolve_foul(&"hot_tub_water_foul", selected.position)
	else:
		resolver.state.raise_result_floor(BallPlayState.ResultFloor.DOUBLE)
		resolver._resolve_floor(&"hot_tub_water_minimum_double", selected.position)
	return true
