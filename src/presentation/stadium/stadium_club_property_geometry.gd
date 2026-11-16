class_name StadiumClubPropertyGeometry
extends StadiumPropertyGeometry
## Explicit lab-only adapter for the complete candidate; never accepted by saved-layout factories.

const CAMERA_LAYER: int = 64
var boundary: StadiumClubBoundaryStudy
var receiver: StadiumClubPitchReceiver
var display: StadiumScoreboardDisplay
var _routes: Array[Dictionary] = []


func configure_candidate(lab: PitchBatLab) -> bool:
	if is_instance_valid(boundary) or not has_meta("candidate_venue"):
		return false
	boundary = get_node("ClubBoundary")
	var pair: Dictionary = {}
	for model: Node3D in boundary.items:
		if model.get_meta("stadium_item", "") in ["ST-026", "ST-073"]:
			pair[model.get_meta("stadium_item")] = model
			model.set_meta("owned_copy", model.get_meta("candidate_instance"))
			for body: StaticBody3D in model.get_node("Collision").get_children():
				body.set_meta("owned_copy", model.get_meta("candidate_instance"))
	if pair.size() != 2:
		return false
	for body: StaticBody3D in find_children("*", "StaticBody3D", true, false):
		body.collision_layer |= CAMERA_LAYER
	receiver = StadiumClubPitchReceiver.new()
	receiver.name = "PitchReceiverPresentation"
	add_child(receiver)
	if not receiver.configure_pair(pair["ST-026"], pair["ST-073"], lab._sounds):
		return false
	receiver.camera_protection = func() -> bool:
		return lab._camera_director.shot == MatchCameraDirector.Shot.BATTING
	boundary.contact_applied.connect(_present)
	for model: Node3D in find_children("*", "Node3D", true, false):
		if model.has_meta("candidate_instance") and model.get_meta("stadium_item", "") == "ST-039":
			display = model.get_node("Visual/ScoreDisplay")
			display.bind_match(lab._match_state)
	# Conservative continuous disc chain retains the empty cup instead of a giant net bounding disc.
	for ends: Array in StadiumReceiverNetModels.PANELS.values():
		var pieces: int = ceili(ends[0].distance_to(ends[1]) / 0.3)
		for index in range(pieces + 1):
			var point: Vector2 = ends[0].lerp(ends[1], float(index) / pieces)
			_routes.append({"center": Vector3(point.x, 0, point.y), "radius": 0.8})
	_bounds_obstacle(pair["ST-026"].global_transform * StadiumTargetModels.ENVELOPE)
	for body: StaticBody3D in pair["ST-073"].get_node("Collision").get_children():
		if String(body.get_meta("surface_id")).begins_with("ST073_ANCHOR"):
			var shape: CollisionShape3D = body.get_child(0)
			var size: Vector3 = (shape.shape as BoxShape3D).size
			_bounds_obstacle(shape.global_transform * AABB(-size / 2, size))
	return true


func bind_ball(ball: BattedBallBody, resolver: BallPlayResolver) -> void:
	boundary.bind_ball(ball, resolver)


func route_obstacles() -> Array[Dictionary]:
	return _routes.duplicate(true)


func observe(resolver: BallPlayResolver, from: Vector3, to: Vector3) -> void:
	StadiumClubBoundarySweep.observe(boundary, resolver, from, to)


func _present(event: Dictionary, resolver: BallPlayResolver) -> void:
	if event.get("kind") != "receiver":
		return
	for body: StaticBody3D in boundary.bodies:
		if body.get_meta("club_surface") == event.segment:
			receiver.present_contact({"copy": body.get_meta("owned_copy"),
				"surface": body.get_meta("surface_id"), "position": event.position,
				"elapsed": resolver.state.elapsed_seconds}, "batted")
			return


func _bounds_obstacle(bounds: AABB) -> void:
	_routes.append({"center": bounds.get_center(), "radius": Vector2(bounds.size.x,
		bounds.size.z).length() / 2 + StadiumDefenderRoutes.BODY_RADIUS})


func rebind_display(state: MatchState) -> void:
	if is_instance_valid(display) and display._match != state:
		display.bind_match(state)
