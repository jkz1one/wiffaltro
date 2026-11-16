class_name StadiumNpcRetainedRuntime
extends RefCounted
## Explicit isolated qualification harness only. No fixture16/17 or production dispatcher.

const REMOVED: Array[String] = ["Ground", "BackWall", "LiveObjectPole", "Plate", "MoundMarker",
	"SafeBoundary", "DeepAirBoundary", "RightFoulLine", "LeftFoulLine"]
const CAMERA_STATE: Array[String] = ["shot", "_field_focus", "_batter_side", "_presentation_motion",
	"_presentation_progress", "_presentation_transition_speed", "_pitch_focus", "_live_coverage",
	"_standard_fov", "_tracking_height", "_shot_before_inspection"]


static func install(lab: PitchBatLab, id: String, revision: int = 1) -> bool:
	if not _admissible(lab):
		return false
	var staged: StadiumNpcRetainedProperty = _stage(lab, id, revision)
	if staged == null:
		return false
	if not _commit(lab, staged):
		staged.free()
		return false
	return true


static func _admissible(lab: PitchBatLab) -> bool:
	if not StadiumPropertyRuntime.authoring_delivery_idle(lab) \
		or not lab.get_meta("stadium_npc_retained_lab_only", false) \
		or lab._managed_match or lab._automation != null or lab._field_id != PitchBatLab.FIELD_ID \
		or lab.has_meta("stadium_property") or lab.has_meta("stadium_npc_runtime_interrupted") \
		or lab.has_meta("stadium_npc_runtime_restoring") or is_instance_valid(lab._batted_ball) \
		or lab._pitch_actor.receiver_router.is_valid() or lab.get_meta("stadium_candidate_only", false):
		return false
	var host: StarterFieldLabGeometry = lab.get_node_or_null("StarterFieldGeometry")
	if host != null:
		for body: CollisionObject3D in host.find_children("*", "CollisionObject3D", true, false):
			if body.get_parent() != host or String(body.name) not in REMOVED:
				return false
	return host != null and host.is_inside_tree() \
		and host.global_transform == Transform3D.IDENTITY and host.has_node("PitchReceiverDebug") \
		and lab._match_state != null and lab._match_state.stadium.is_empty()


static func _stage(lab: PitchBatLab, id: String, revision: int = 1) -> StadiumNpcRetainedProperty:
	if not _admissible(lab) or not StadiumNpcRetainedCompatibility.valid():
		return null
	return _construct(lab, id, revision)


static func _construct(lab: PitchBatLab, id: String, revision: int) -> StadiumNpcRetainedProperty:
	if revision != 1 or id not in ["AY-01", "AE-01", "AC-01"] \
		or StadiumNpcVenues.definition(id, revision).is_empty():
		return null
	var property: StadiumNpcRetainedProperty = StadiumNpcRetainedProperty.new()
	property.venue_id = id
	property.name = "HomeProperty"
	if id == "AC-01":
		property.construction = StadiumNpcClubV1.build()
	else:
		property.construction = StadiumNpcYardV1.build() if id == "AY-01" else (
			StadiumNpcExpandedV1.build())
	property.add_child(property.construction)
	property.objects = property.construction.objects
	property.field = property.construction.field
	property.tier = property.construction.tier
	if id == "AC-01":
		var boundary: StadiumNpcRetainedClubBoundary = StadiumNpcRetainedClubBoundary.new()
		boundary.name = "RetainedClubContactAdapter"
		property.add_child(boundary)
		if not boundary.configure(property.construction.get_node("ClubBoundary")):
			property.free()
			return null
		property.boundary = boundary
		boundary.contact_applied.connect(property._club_contact)
	else:
		property.boundary = property.construction.get_node("BoundaryGraph")
	# owned_copy is only the legacy contact-key spelling. No ledger/layout is constructed.
	for identity: String in property.objects:
		var model: Node3D = property.objects[identity]
		model.set_meta("owned_copy", identity)
		for body: StaticBody3D in model.find_children("*", "StaticBody3D", true, false):
			body.set_meta("owned_copy", identity)
	if id != "AY-01":
		property.receiver = StadiumNpcRetainedClubReceiver.new() if id == "AC-01" else (
			StadiumNpcRetainedReceiver.new())
		if id == "AC-01":
			property.receiver.camera_protection = property._receiver_camera_protection
		property.receiver.name = "PitchReceiverPresentation"
		property.add_child(property.receiver)
		if not property.receiver.configure_pair(property.objects["npc:" + id + ":r1:RECEIVER-PRIMARY"],
			property.objects["npc:" + id + ":r1:RECEIVER-CATCH"], lab._sounds):
			property.free()
			return null
		var board: String = StadiumNpcClubV1.BOARD_SITE if id == "AC-01" else "SCORE-SMALL"
		property.display = property.objects["npc:" + id + ":r1:" + board].get_node("Visual/ScoreDisplay")
		for body: StaticBody3D in property.find_children("*", "StaticBody3D", true, false):
			body.collision_layer |= 64
	return property


static func _commit(lab: PitchBatLab, property: StadiumNpcRetainedProperty) -> bool:
	# Recheck both admission and actual staged geometry immediately before changing any live object.
	if not _admissible(lab) or not StadiumNpcRetainedCompatibility.valid() \
		or property == null or property.get_parent() != null \
		or not _complete(lab, property):
		return false
	var host: StarterFieldLabGeometry = lab.get_node("StarterFieldGeometry")
	property.host_children.assign(host.get_children())
	property.old_field_id = lab._field_id
	property.old_field = lab._field_definition
	property.old_camera_mask = lab._camera.cull_mask
	property.old_camera = lab._camera_director
	property.old_visibility = lab._camera_director.tracking_visibility
	property.old_observer = lab._ball_play_resolver.segment_observer
	property.old_clip = lab._primary_fielder.stadium_boundary_clip
	property.old_obstacles = lab._primary_fielder.stadium_obstacles.duplicate(true)
	for id: String in REMOVED:
		var old: Node = host.get_node_or_null(NodePath(id))
		if old != null:
			host.remove_child(old)
			property.old_nodes.append(old)
	host.add_child(property)
	lab.set_meta("stadium_property", property)
	lab.set_meta("stadium_candidate_only", true)
	property.lab_ref = weakref(lab)
	lab._field_definition = property.field
	lab._ball_play_resolver.segment_observer = property.observe
	lab._primary_fielder.stadium_boundary_clip = property.clip
	lab._primary_fielder.stadium_obstacles = property.route_obstacles()
	if property.receiver != null:
		lab._pitch_actor.receiver_router = property.receiver.route
		var camera: StadiumClubCameraDirector = StadiumClubCameraDirector.new() \
			if property.venue_id == "AC-01" else StadiumExpandedCameraDirector.new()
		camera.camera_mask |= 64
		for key: String in CAMERA_STATE:
			camera.set(key, lab._camera_director.get(key))
		lab._camera_director = camera
	lab._camera_director.tracking_visibility = StadiumNpcRetainedVisibility.new()
	lab._camera_director.tracking_visibility.configure(host)
	property.presentation_director = lab._camera_director
	property.presentation_camera = weakref(lab._camera)
	property.rebind(lab._match_state)
	PitchBatLabPresentation.refresh_markers(lab)
	StadiumPropertyRuntime.refresh_receiver_visibility(lab)
	return true


static func _complete(lab: PitchBatLab, property: StadiumNpcRetainedProperty) -> bool:
	if not is_instance_valid(property.construction) or property.field == null \
		or property.construction.get_parent() != property \
		or not _boundary_complete(property):
		return false
	if (property.venue_id == "AC-01" and not property.receiver is StadiumNpcRetainedClubReceiver) \
		or (property.venue_id == "AE-01" and not property.receiver is StadiumNpcRetainedReceiver):
		return false
	var expected: StadiumNpcRetainedProperty = _construct(lab, property.venue_id, 1)
	if expected == null:
		return false
	var same: bool = StadiumNpcRetainedGeometry.same(property, expected)
	if property.is_inside_tree():
		var actual_view: StadiumNpcRetainedVisibility = lab._camera_director.tracking_visibility \
			as StadiumNpcRetainedVisibility
		var expected_view: StadiumNpcRetainedVisibility = StadiumNpcRetainedVisibility.new()
		expected_view.configure_property(expected)
		same = same and actual_view != null and actual_view._wall_prisms != null \
			and actual_view._obstacles == expected_view._obstacles \
			and actual_view._uprights == expected_view._uprights \
			and actual_view._wall_bounds == expected_view._wall_bounds \
			and actual_view.field_wall_z == expected_view.field_wall_z \
			and actual_view._groups == expected_view._groups \
			and actual_view._rails == expected_view._rails \
			and actual_view._wall_prisms.walls == expected_view._wall_prisms.walls
	for key: String in StadiumNpcYardV1.FIELD:
		same = same and property.field.get(key) == expected.field.get(key)
	same = same and property.objects.size() == expected.objects.size()
	for identity: String in expected.objects:
		var model: Node3D = property.objects.get(identity)
		same = same and is_instance_valid(model) and property.construction.is_ancestor_of(model) \
			and model.get_meta("npc_instance", "") == identity
	if property.venue_id != "AY-01":
		var prefix: String = "npc:" + property.venue_id + ":r1:"
		same = same and property.receiver != null \
			and property.receiver.chair == property.objects.get(prefix + "RECEIVER-PRIMARY") \
			and property.receiver.net == property.objects.get(prefix + "RECEIVER-CATCH") \
			and property.receiver.sounds == lab._sounds \
			and property.boundary.graph.get_script() == expected.boundary.graph.get_script() \
			and property.boundary.graph.segments() == expected.boundary.graph.segments() \
			and property.boundary.graph.polygon() == expected.boundary.graph.polygon() \
			and property.display == property.objects.get(prefix + board_site(property.venue_id)).get_node(
				"Visual/ScoreDisplay")
	if property.venue_id == "AC-01":
		same = same and property.receiver.camera_protection == property._receiver_camera_protection
		var source: Node3D = property.boundary.source
		var reference: Node3D = expected.boundary.source
		same = same and source.bodies.size() == reference.bodies.size()
		for index in range(mini(source.bodies.size(), reference.bodies.size())):
			var path: NodePath = reference.get_path_to(reference.bodies[index])
			same = same and source.get_node_or_null(path) == source.bodies[index]
	expected.free()
	return same


static func board_site(id: String) -> String:
	return StadiumNpcClubV1.BOARD_SITE if id == "AC-01" else "SCORE-SMALL"


static func _boundary_complete(property: StadiumNpcRetainedProperty) -> bool:
	if property.venue_id != "AC-01":
		return property.boundary == property.construction.get_node_or_null("BoundaryGraph")
	var source: StadiumNpcClubBoundaryV1 = property.construction.get_node_or_null("ClubBoundary")
	return property.boundary is StadiumNpcRetainedClubBoundary and source != null \
		and property.boundary.source == source and property.boundary.graph == source.graph \
		and property.boundary.bodies == source.bodies \
		and property.boundary.contact_applied.is_connected(property._club_contact) \
		and property.boundary.contact_applied.get_connections().size() == 1


static func installed(lab: PitchBatLab, id: String, revision: int = 1) -> bool:
	if lab == null or revision != 1 or not lab.get_meta("stadium_npc_retained_lab_only", false) \
		or not lab.get_meta("stadium_candidate_only", false) or not lab.has_meta("stadium_property"):
		return false
	var property: StadiumNpcRetainedProperty = lab.get_meta("stadium_property") \
		as StadiumNpcRetainedProperty
	var host: Node3D = lab.get_node_or_null("StarterFieldGeometry")
	if property == null or property.venue_id != id or host == null \
		or property.get_parent() != host or host.global_transform != Transform3D.IDENTITY \
		or property.transform != Transform3D.IDENTITY or not _complete(lab, property) \
		or property.presentation_director != lab._camera_director \
		or property.presentation_camera == null \
		or property.presentation_camera.get_ref() != lab._camera \
		or not property.actor_cutaway is StadiumNpcRetainedActorCutaway \
		or not property.ball_readability is StadiumNpcRetainedBallReadability:
		return false
	var count: int = 1
	for node: Node in property.host_children:
		if property.old_nodes.has(node):
			if node.get_parent() != null:
				return false
		else:
			count += 1
			if node.get_parent() != host:
				return false
	for body: CollisionObject3D in host.find_children("*", "CollisionObject3D", true, false):
		if not property.is_ancestor_of(body):
			return false
	if host.get_child_count() != count or lab._field_id != property.field.id \
		or lab._field_definition != property.field \
		or lab._ball_play_resolver.segment_observer != property.observe \
		or lab._primary_fielder.stadium_boundary_clip != property.clip \
		or lab._primary_fielder.stadium_obstacles != property.route_obstacles():
		return false
	for reference: WeakRef in property.bound_balls:
		var ball: BattedBallBody = reference.get_ref() as BattedBallBody
		if not is_instance_valid(ball):
			continue
		if ball.physics_contact_router != property.boundary._contact_batch.bind(lab._ball_play_resolver) \
			or (id != "AC-01" and not ball.body_entered.is_connected(
				property._ball_contact.bind(ball, lab._ball_play_resolver))):
			return false
		if id == "AC-01":
			var ball_id: int = ball.get_instance_id()
			var resolver_id: int = lab._ball_play_resolver.get_instance_id()
			if not ball.launch_started.is_connected(property.boundary._seed.bind(ball_id)) \
				or not ball.tree_exited.is_connected(property.boundary._forget.bind(
					ball_id, resolver_id)) \
				or property.boundary._resolver_ids.get(ball_id) != resolver_id \
				or not property.boundary._bound_balls.has(ball_id) \
				or property.boundary._bound_balls[ball_id].get_ref() != ball \
				or not property.boundary._previous.has(ball_id) \
				or not property.boundary._previous[ball_id] is Vector3 \
				or not property.boundary._previous[ball_id].is_finite():
				return false
	var visibility: StadiumNpcRetainedVisibility = lab._camera_director.tracking_visibility \
		as StadiumNpcRetainedVisibility
	if visibility == null or visibility.property != property or visibility._recipe == null \
		or visibility._wall_prisms == null:
		return false
	var graph: StadiumRecipeBoundary = property.view_graph()
	if visibility._recipe.get_script() != graph.get_script() \
		or visibility._recipe.segments() != graph.segments() \
		or visibility._recipe.polygon() != graph.polygon() \
		or visibility._wall_prisms.walls != StadiumNpcRetainedVisibility.prisms(graph, id).walls:
		return false
	if id == "AY-01":
		return not lab._pitch_actor.receiver_router.is_valid() and property.receiver == null
	return lab._pitch_actor.receiver_router == property.receiver.route \
		and property.display._match == lab._match_state \
		and ((id == "AC-01" and lab._camera_director.get_script() == StadiumClubCameraDirector) \
			or (id == "AE-01" and lab._camera_director is StadiumExpandedCameraDirector)) \
		and lab._camera_director.camera_mask == 80


static func teardown(lab: PitchBatLab) -> bool:
	if not StadiumPropertyRuntime.authoring_delivery_idle(lab) or lab._automation != null \
		or is_instance_valid(lab._batted_ball) or not lab.has_meta("stadium_property"):
		return false
	var property: StadiumNpcRetainedProperty = lab.get_meta("stadium_property") \
		as StadiumNpcRetainedProperty
	if property == null:
		return false
	_restore(lab, property)
	property.free()
	return true


static func _restore(lab: PitchBatLab, property: StadiumNpcRetainedProperty,
	deferred: bool = false) -> void:
	# Shared cleanup for explicit teardown and unexpected property removal. The latter can
	# occur inside a busy parent notification, so restore original siblings deferred.
	property.disconnect_balls()
	property.lab_ref = null
	if is_instance_valid(property.display):
		property.display.bind_match(null)
	if is_instance_valid(lab._pitch_actor):
		lab._pitch_actor.receiver_router = Callable()
	if lab._ball_play_resolver != null:
		lab._ball_play_resolver.segment_observer = property.old_observer
	if is_instance_valid(lab._primary_fielder):
		lab._primary_fielder.stadium_boundary_clip = property.old_clip
		lab._primary_fielder.stadium_obstacles = property.old_obstacles
	lab._field_id = property.old_field_id
	lab._field_definition = property.old_field
	if is_instance_valid(lab._camera):
		lab._camera.cull_mask = property.old_camera_mask
	lab._camera_director = property.old_camera
	lab._camera_director.tracking_visibility = property.old_visibility
	lab.remove_meta("stadium_property")
	lab.remove_meta("stadium_candidate_only")
	var originals: Array[Node] = property.old_nodes.duplicate()
	var order: Array[Node] = property.host_children.duplicate()
	property.old_nodes.clear()
	if deferred:
		var live: bool = not is_instance_valid(lab._pitch_actor) \
			or not StadiumPropertyRuntime.authoring_delivery_idle(lab) \
			or is_instance_valid(lab._batted_ball) or lab._automation != null
		var previous_mode: int = lab.process_mode
		lab.process_mode = Node.PROCESS_MODE_DISABLED
		lab.set_meta("stadium_npc_runtime_restoring", true)
		if live:
			lab.set_meta("stadium_npc_runtime_interrupted", true)
		_restore_originals.call_deferred(weakref(lab), originals, order, previous_mode, live)
	else:
		_restore_originals(weakref(lab), originals, order)


static func unexpected_exit(lab: PitchBatLab, property: StadiumNpcRetainedProperty) -> void:
	if lab.has_meta("stadium_property") and lab.get_meta("stadium_property") == property:
		_restore(lab, property, true)


static func _restore_originals(reference: WeakRef, originals: Array[Node], order: Array[Node],
	previous_mode: int = -1, interrupted: bool = false) -> void:
	var lab: PitchBatLab = reference.get_ref() as PitchBatLab
	var host: Node = lab.get_node_or_null("StarterFieldGeometry") if is_instance_valid(lab) else null
	if not is_instance_valid(lab) or lab.is_queued_for_deletion() or not lab.is_inside_tree() \
		or not is_instance_valid(host) or host.is_queued_for_deletion():
		for node: Node in originals:
			if is_instance_valid(node) and node.get_parent() == null:
				node.free()
		return
	for node: Node in originals:
		if is_instance_valid(node) and node.get_parent() == null:
			host.add_child(node)
	for index in range(order.size()):
		if is_instance_valid(order[index]) and order[index].get_parent() == host:
			host.move_child(order[index], mini(index, host.get_child_count() - 1))
	if previous_mode >= 0:
		if interrupted:
			# Never resume or manufacture a result for a game whose physical venue vanished.
			lab._automation = null
			lab._pitch_actor.reset_pitch()
			lab._release_controller.cancel()
			lab._at_bat_cadence.stop()
			lab._cleanup_batted_ball()
		else:
			lab.process_mode = previous_mode as Node.ProcessMode
		lab.remove_meta("stadium_npc_runtime_restoring")
