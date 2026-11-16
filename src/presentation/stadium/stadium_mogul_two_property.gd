class_name StadiumMogulTwoProperty
extends StadiumClubPropertyGeometry
# gdlint: disable=max-returns
## Private AM02 lifecycle; shared contact, route and display algorithms stay unchanged.

var lab_ref: WeakRef
var actor_cutaway: StadiumActorCutawayStudy = StadiumNpcRetainedActorCutaway.new()
var ended: bool = false
var preflight_signature: String = ""
var _bound_balls: Array[WeakRef] = []


func configure_candidate(lab: PitchBatLab) -> bool:
	if (
		ended
		or lab == null
		or preflight_signature.is_empty()
		or StadiumMogulTwoIntegrity.signature(self) != preflight_signature
		or is_instance_valid(boundary)
		or field == null
		or field.get_script() != preload("res://src/content/definitions/field_definition.gd")
		or not ClubCareer.same(
			StadiumMogulTwoStudy.field_snapshot(field),
			StadiumMogulTwoStudy.field_snapshot(StadiumMogulTwoStudy.FIELD as FieldDefinition)
		)
		or not StadiumMogulTwoFixture.valid(
			StadiumMogulTwoFixture.capture(get_meta("candidate_venue", {}))
		)
	):
		return false
	boundary = get_node_or_null("ClubBoundary") as StadiumClubBoundaryStudy
	if boundary == null:
		return false
	var pair: Dictionary = {}
	for model: Node3D in boundary.items:
		var item: String = model.get_meta("stadium_item", "")
		if item not in ["ST-026", "ST-073"]:
			continue
		var identity: String = model.get_meta("candidate_instance", "")
		if objects.get(identity) != model or pair.has(item):
			return false
		pair[item] = model
		model.set_meta("owned_copy", identity)
		var collision: Node = model.get_node_or_null("Collision")
		if collision == null:
			return false
		for child: Node in collision.get_children():
			if not child is StaticBody3D:
				return false
			child.set_meta("owned_copy", identity)
	if pair.size() != 2:
		return false
	for child: Node in find_children("*", "StaticBody3D", true, false):
		if not child is StaticBody3D:
			return false
		(child as StaticBody3D).collision_layer |= CAMERA_LAYER
	var prepared: StadiumMogulTwoReceiver = StadiumMogulTwoReceiver.new()
	prepared.name = "PitchReceiverPresentation"
	add_child(prepared)
	if not prepared.configure_candidate(self, lab):
		prepared.free()
		return false
	receiver = prepared
	receiver.camera_protection = func() -> bool:
		return not ended and lab._camera_director.shot == MatchCameraDirector.Shot.BATTING
	boundary.contact_applied.connect(_present)
	var board: Node3D = objects.get(StadiumMogulTwoStudy.PREFIX + StadiumMogulTwoStudy.BOARD_SITE)
	if board == null:
		return false
	display = board.get_node_or_null("Visual/ScoreDisplay") as StadiumScoreboardDisplay
	if display == null:
		return false
	display.bind_match(lab._match_state)
	# Preserve the qualified cup-shaped route reservation, including target and anchors.
	for ends: Array in StadiumReceiverNetModels.PANELS.values():
		var pieces: int = ceili(ends[0].distance_to(ends[1]) / 0.3)
		for index in range(pieces + 1):
			var point: Vector2 = ends[0].lerp(ends[1], float(index) / pieces)
			_routes.append({"center": Vector3(point.x, 0, point.y), "radius": 0.8})
	_bounds_obstacle(pair["ST-026"].global_transform * StadiumTargetModels.ENVELOPE)
	for child: Node in pair["ST-073"].get_node("Collision").get_children():
		if not child is StaticBody3D:
			return false
		var body: StaticBody3D = child as StaticBody3D
		if String(body.get_meta("surface_id", "")).begins_with("ST073_ANCHOR"):
			var shape: CollisionShape3D = body.get_child(0) as CollisionShape3D
			if shape == null or not shape.shape is BoxShape3D:
				return false
			var size: Vector3 = (shape.shape as BoxShape3D).size
			_bounds_obstacle(shape.global_transform * AABB(-size / 2, size))
	return true


func bind_ball(ball: BattedBallBody, resolver: BallPlayResolver) -> void:
	if ended or not is_instance_valid(ball) or not is_instance_valid(boundary):
		return
	for reference: WeakRef in _bound_balls:
		if reference.get_ref() == ball:
			return
	_bound_balls.append(weakref(ball))
	super.bind_ball(ball, resolver)


func _process(_delta: float) -> void:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	if (
		not ended
		and lab != null
		and lab.has_meta("stadium_property")
		and lab.get_meta("stadium_property") == self
	):
		rebind_display(lab._match_state)


func _exit_tree() -> void:
	if ended:
		return
	ended = true
	actor_cutaway.restore_all()
	if is_instance_valid(receiver) and receiver is StadiumMogulTwoReceiver:
		(receiver as StadiumMogulTwoReceiver).release_actor()
	if is_instance_valid(display):
		display.bind_match(null)
	for reference: WeakRef in _bound_balls:
		var ball: BattedBallBody = reference.get_ref() as BattedBallBody
		if not is_instance_valid(ball):
			continue
		if ball.physics_contact_router.get_object() == boundary:
			ball.physics_contact_router = Callable()
		for signal_name: String in ["launch_started", "tree_exited"]:
			for connection: Dictionary in ball.get_signal_connection_list(signal_name):
				if connection.callable.get_object() == boundary:
					ball.disconnect(signal_name, connection.callable)
	_bound_balls.clear()
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	if lab == null:
		return
	if lab._camera_director is StadiumMogulTwoCamera:
		var camera: StadiumMogulTwoCamera = lab._camera_director as StadiumMogulTwoCamera
		if camera.actor_cutaway == actor_cutaway:
			camera.actor_cutaway = null
	if (
		is_instance_valid(receiver)
		and is_instance_valid(lab._pitch_actor)
		and lab._pitch_actor.receiver_router == receiver.route
	):
		lab._pitch_actor.receiver_router = Callable()
	if lab._ball_play_resolver != null and lab._ball_play_resolver.segment_observer == observe:
		lab._ball_play_resolver.segment_observer = Callable()
	if (
		is_instance_valid(boundary)
		and is_instance_valid(lab._primary_fielder)
		and lab._primary_fielder.stadium_boundary_clip == boundary.graph.clip
	):
		lab._primary_fielder.stadium_boundary_clip = Callable()
		lab._primary_fielder.stadium_obstacles = []
	if lab.has_meta("stadium_property") and lab.get_meta("stadium_property") == self:
		lab.remove_meta("stadium_property")
