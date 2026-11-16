class_name StadiumNpcRuntime
extends RefCounted
## Explicit raw fixture17 qualification only. No ordinary dispatcher admits this family.
# gdlint: disable=max-returns

const REMOVED: Array[String] = [
	"Ground",
	"BackWall",
	"LiveObjectPole",
	"Plate",
	"MoundMarker",
	"SafeBoundary",
	"DeepAirBoundary",
	"RightFoulLine",
	"LeftFoulLine"
]
const CAMERA_STATE: Array[String] = [
	"shot",
	"_field_focus",
	"_batter_side",
	"_presentation_motion",
	"_presentation_progress",
	"_presentation_transition_speed",
	"_pitch_focus",
	"_live_coverage",
	"_standard_fov",
	"_tracking_height",
	"_shot_before_inspection"
]



static func _construct(lab: PitchBatLab, id: String) -> StadiumNpcBoundProperty:
	if id not in ["AY-01", "AE-01", "AC-01"] \
		or StadiumNpcVenues.definition(id, 2).is_empty():
		return null
	var property: StadiumNpcBoundProperty = StadiumNpcBoundProperty.new()
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
	if not StadiumNpcCandidateConstructionV2.remap(property):
		property.free()
		return null
	return property


static func _references(property: StadiumNpcBoundProperty) -> bool:
	if not is_instance_valid(property) or property.get_script() != StadiumNpcBoundProperty \
		or property.venue_id not in ["AY-01", "AE-01", "AC-01"] \
		or not is_instance_valid(property.construction) or not is_instance_valid(property.boundary):
		return false
	var construction: Script = {"AY-01": StadiumNpcYardV1, "AE-01": StadiumNpcExpandedV1,
		"AC-01": StadiumNpcClubV1}[property.venue_id]
	var boundary: Script = {"AY-01": StadiumNpcYardBoundaryV1,
		"AE-01": StadiumNpcExpandedBoundaryV1,
		"AC-01": StadiumNpcRetainedClubBoundary}[property.venue_id]
	if property.construction.get_script() != construction \
		or property.boundary.get_script() != boundary:
		return false
	if property.venue_id == "AY-01":
		return property.receiver == null and property.display == null
	if not property.receiver is Node or not is_instance_valid(property.receiver) \
		or not is_instance_valid(property.display):
		return false
	if property.venue_id == "AE-01":
		return property.receiver.get_script() == StadiumNpcRetainedReceiver \
			and property.display.get_script() == StadiumNpcExpandedDisplayV1 \
			and property.boundary.graph != null
	return property.receiver.get_script() == StadiumNpcRetainedClubReceiver \
		and property.display.get_script() == StadiumNpcClubDisplayV1 \
		and is_instance_valid(property.boundary.source) and property.boundary.graph != null


static func _complete(lab: PitchBatLab, property: StadiumNpcBoundProperty) -> bool:
	if (
		not _references(property)
		or property.field == null
		or not is_instance_valid(property.boundary)
		or property.construction.get_parent() != property
		or not _boundary_complete(property)
		or not StadiumNpcCandidateConstructionV2.valid(property)
	):
		return false
	if (
		(property.venue_id == "AC-01" and not property.receiver is StadiumNpcRetainedClubReceiver)
		or (property.venue_id == "AE-01" and not property.receiver is StadiumNpcRetainedReceiver)
	):
		return false
	var expected: StadiumNpcBoundProperty = _construct(lab, property.venue_id)
	if expected == null:
		return false
	var same: bool = StadiumNpcRetainedGeometry.same(property, expected)
	if property.is_inside_tree():
		var actual_view: StadiumNpcRetainedVisibility = (
			lab._camera_director.tracking_visibility as StadiumNpcRetainedVisibility
		)
		var expected_view: StadiumNpcRetainedVisibility = StadiumNpcRetainedVisibility.new()
		expected_view.configure_property(expected)
		same = (
			same
			and actual_view != null
			and actual_view._wall_prisms != null
			and actual_view._obstacles == expected_view._obstacles
			and actual_view._uprights == expected_view._uprights
			and actual_view._wall_bounds == expected_view._wall_bounds
			and actual_view.field_wall_z == expected_view.field_wall_z
			and actual_view._groups == expected_view._groups
			and actual_view._rails == expected_view._rails
			and actual_view._wall_prisms.walls == expected_view._wall_prisms.walls
		)
	for key: String in StadiumNpcYardV1.FIELD:
		same = same and property.field.get(key) == expected.field.get(key)
	same = same and property.objects.size() == expected.objects.size()
	for identity: String in expected.objects:
		var model: Node3D = property.objects.get(identity)
		same = (
			same
			and is_instance_valid(model)
			and property.construction.is_ancestor_of(model)
			and model.get_meta("npc_instance", "") == identity
		)
	if property.venue_id != "AY-01":
		var prefix: String = "npc:" + property.venue_id + ":r2:"
		same = (
			same
			and property.receiver != null
			and property.receiver.chair == property.objects.get(prefix + "RECEIVER-PRIMARY")
			and property.receiver.net == property.objects.get(prefix + "RECEIVER-CATCH")
			and property.receiver.sounds == lab._sounds
			and property.boundary.graph.get_script() == expected.boundary.graph.get_script()
			and property.boundary.graph.segments() == expected.boundary.graph.segments()
			and property.boundary.graph.polygon() == expected.boundary.graph.polygon()
			and (
				property.display
				== property.objects.get(prefix + board_site(property.venue_id)).get_node(
					"Visual/ScoreDisplay"
				)
			)
		)
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


static func _boundary_complete(property: StadiumNpcBoundProperty) -> bool:
	if property.venue_id != "AC-01":
		return property.boundary == property.construction.get_node_or_null("BoundaryGraph")
	var source: StadiumNpcClubBoundaryV1 = property.construction.get_node_or_null("ClubBoundary")
	return (
		property.boundary is StadiumNpcRetainedClubBoundary
		and source != null
		and property.boundary.source == source
		and property.boundary.graph == source.graph
		and property.boundary.bodies == source.bodies
		and property.boundary.contact_applied.is_connected(property._club_contact)
		and property.boundary.contact_applied.get_connections().size() == 1
	)



static func install_bound(lab: PitchBatLab, context: StadiumNpcQualificationContext) -> bool:
	var property: StadiumNpcBoundProperty = _stage(lab, context)
	if property == null:
		return false
	if not _commit(lab, property, context):
		property.free()
		return false
	return true


static func _startup(lab: PitchBatLab) -> bool:
	return is_instance_valid(lab) and lab.get_script() == PitchBatLab \
		and lab._match_state != null and lab._match_mode \
		and lab._configured_match == null and lab._pitch_actor != null \
		and not lab._pitch_actor.running and not is_instance_valid(lab._batted_ball) \
		and (lab._release_controller == null or not lab._release_controller.active) \
		and (lab._at_bat_cadence == null or lab._at_bat_cadence.state in [
			AtBatCadenceController.State.IDLE, AtBatCadenceController.State.DELIVERY]) \
		and lab._primary_fielder != null and lab._ball_play_resolver != null \
		and lab._camera_director != null and is_instance_valid(lab._camera) \
		and lab._camera_director.presentation_override.is_null() \
		and lab._throw_number == (0 if lab._automation == null else lab._automation.seed * 1000) \
		and (lab._automation == null or lab._automation.releases.is_empty()) \
		and lab._play_records.is_empty()


static func _origin_clean(lab: PitchBatLab) -> bool:
	if not StadiumMountedScoreboardContract.origin_clean(lab):
		return false
	for marker: StringName in StadiumScoreboardRuntime.AUTHORING + [
		&"stadium_npc_retained_lab_only", &"stadium_snapshot",
		&"stadium_npc_runtime_interrupted", &"stadium_npc_runtime_restoring"]:
		if lab.has_meta(marker):
			return false
	return true


static func _admissible(lab: PitchBatLab, context: StadiumNpcQualificationContext) -> bool:
	if not _startup(lab) or not _origin_clean(lab) or context == null \
		or not context.validated(lab) or not context.fresh() \
		or lab._field_id != PitchBatLab.FIELD_ID or lab.has_meta("stadium_property"):
		return false
	var host: StarterFieldLabGeometry = lab.get_node_or_null("StarterFieldGeometry")
	if host == null or host.get_script() != StarterFieldLabGeometry \
		or not host.is_inside_tree() or host.global_transform != Transform3D.IDENTITY \
		or not host.has_node("PitchReceiverDebug") or host.has_node("HomeProperty"):
		return false
	for body: CollisionObject3D in host.find_children("*", "CollisionObject3D", true, false):
		if body.get_parent() != host or String(body.name) not in REMOVED:
			return false
	return true


static func _stage(lab: PitchBatLab,
	context: StadiumNpcQualificationContext) -> StadiumNpcBoundProperty:
	if not _admissible(lab, context) or not StadiumNpcRetainedCompatibility.valid():
		return null
	var property: StadiumNpcBoundProperty = _construct(lab, context._snapshot.manifest.id)
	if property == null:
		return null
	property.context = context
	property.frozen_snapshot = context._snapshot.duplicate(true)
	property.frozen_key = context._snapshot_key
	property.field = context._field
	property.construction.field = context._field
	property.process_priority = -100
	property.process_physics_priority = -100
	if not _complete(lab, property):
		property.free()
		return null
	return property


static func _commit(lab: PitchBatLab, property: StadiumNpcBoundProperty,
	context: StadiumNpcQualificationContext) -> bool:
	# Both authority and complete actual geometry are rechecked before detaching one node.
	if not _admissible(lab, context) or property == null \
		or property.get_parent() != null or not _bound_identity(property, context) \
		or not StadiumNpcRetainedCompatibility.valid() or not _complete(lab, property):
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
	property.old_receiver = lab._pitch_actor.receiver_router
	for id: String in REMOVED:
		var old: Node = host.get_node_or_null(NodePath(id))
		if old != null:
			host.remove_child(old)
			property.old_nodes.append(old)
	host.add_child(property)
	lab.set_meta("stadium_property", property)
	property.lab_ref = weakref(lab)
	lab._field_id = property.field.id
	lab._field_definition = property.field
	lab._ball_play_resolver.segment_observer = property.observe
	lab._primary_fielder.stadium_boundary_clip = property.clip
	lab._primary_fielder.stadium_obstacles = property.route_obstacles()
	lab._pitch_actor.receiver_router = Callable()
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
	if not installed(lab, context):
		_restore(lab, property)
		if property.get_parent() != null:
			property.get_parent().remove_child(property)
		return false
	return true


static func _bound_identity(property: StadiumNpcBoundProperty,
	context: StadiumNpcQualificationContext) -> bool:
	return context != null and _references(property) \
		and property.context == context \
		and property.frozen_key == context._snapshot_key \
		and property.frozen_snapshot == context._snapshot \
		and property.venue_id == context._snapshot.manifest.id \
		and property.field == context._field and property.construction.field == context._field


static func installed(lab: PitchBatLab, context: StadiumNpcQualificationContext) -> bool:
	if not is_instance_valid(lab) or lab.get_script() != PitchBatLab \
		or not _origin_clean(lab) or context == null or not context.validated(lab) \
		or lab._camera_director == null or not is_instance_valid(lab._camera) \
		or lab._ball_play_resolver == null or not is_instance_valid(lab._primary_fielder) \
		or not is_instance_valid(lab._pitch_actor) or not lab.has_meta("stadium_property"):
		return false
	var id: String = context._snapshot.manifest.id
	var property: StadiumNpcBoundProperty = (
		lab.get_meta("stadium_property") as StadiumNpcBoundProperty
	)
	var host: Node3D = lab.get_node_or_null("StarterFieldGeometry")
	if (
		property == null
		or property.suspended
		or not _bound_identity(property, context)
		or property.venue_id != id
		or host == null
		or host.get_script() != StarterFieldLabGeometry
		or property.lab_ref == null or property.lab_ref.get_ref() != lab
		or property.process_mode != Node.PROCESS_MODE_INHERIT
		or not property.is_processing() or not property.is_physics_processing()
		or property.process_priority != -100 or property.process_physics_priority != -100
		or property.get_parent() != host
		or host.global_transform != Transform3D.IDENTITY
		or property.transform != Transform3D.IDENTITY
		or not _complete(lab, property)
		or property.presentation_director != lab._camera_director
		or property.presentation_camera == null
		or property.presentation_camera.get_ref() != lab._camera
		or not lab._camera_director.presentation_override.is_null()
		or lab._camera.cull_mask != property.old_camera_mask
		or not property.actor_cutaway is StadiumNpcRetainedActorCutaway
		or not property.ball_readability is StadiumNpcRetainedBallReadability
	):
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
	if (
		host.get_child_count() != count
		or lab._field_id != property.field.id
		or lab._field_definition != property.field
		or lab._ball_play_resolver.segment_observer != property.observe
		or not lab._ball_play_resolver.play_resolved.is_connected(lab._on_ball_play_resolved)
		or lab._primary_fielder.stadium_boundary_clip != property.clip
		or lab._primary_fielder.stadium_obstacles != property.route_obstacles()
	):
		return false
	var bound_ids: Dictionary = {}
	for reference: WeakRef in property.bound_balls:
		var ball: BattedBallBody = reference.get_ref() as BattedBallBody
		if not is_instance_valid(ball):
			continue
		if bound_ids.has(ball.get_instance_id()) or ball.get_parent() != lab:
			return false
		bound_ids[ball.get_instance_id()] = true
		if (
			(
				ball.physics_contact_router
				!= property.boundary._contact_batch.bind(lab._ball_play_resolver)
			)
			or (
				id != "AC-01"
				and not ball.body_entered.is_connected(
					property._ball_contact.bind(ball, lab._ball_play_resolver)
				)
			)
		):
			return false
		if id != "AC-01" and not ball.tree_exited.is_connected(
			property.boundary._forget.bind(ball.get_instance_id())):
			return false
		if id == "AC-01":
			var ball_id: int = ball.get_instance_id()
			var resolver_id: int = lab._ball_play_resolver.get_instance_id()
			if (
				not ball.launch_started.is_connected(property.boundary._seed.bind(ball_id))
				or not ball.tree_exited.is_connected(
					property.boundary._forget.bind(ball_id, resolver_id)
				)
				or property.boundary._resolver_ids.get(ball_id) != resolver_id
				or not property.boundary._bound_balls.has(ball_id)
				or property.boundary._bound_balls[ball_id].get_ref() != ball
				or not property.boundary._previous.has(ball_id)
				or not property.boundary._previous[ball_id] is Vector3
				or not property.boundary._previous[ball_id].is_finite()
			):
				return false
	if id == "AC-01":
		for maps: Dictionary in [property.boundary._bound_balls,
			property.boundary._resolver_ids, property.boundary._previous]:
			if maps.size() != bound_ids.size():
				return false
			for ball_id: int in maps:
				if not bound_ids.has(ball_id):
					return false
		for resolver_id: int in property.boundary.last_live:
			if bound_ids.is_empty() or resolver_id != lab._ball_play_resolver.get_instance_id():
				return false
	var visibility: StadiumNpcRetainedVisibility = (
		lab._camera_director.tracking_visibility as StadiumNpcRetainedVisibility
	)
	if (
		visibility == null
		or visibility.property != property
		or visibility._recipe == null
		or visibility._wall_prisms == null
	):
		return false
	var graph: StadiumRecipeBoundary = property.view_graph()
	if (
		visibility._recipe.get_script() != graph.get_script()
		or visibility._recipe.segments() != graph.segments()
		or visibility._recipe.polygon() != graph.polygon()
		or visibility._wall_prisms.walls != StadiumNpcRetainedVisibility.prisms(graph, id).walls
	):
		return false
	if id == "AY-01":
		return not lab._pitch_actor.receiver_router.is_valid() and property.receiver == null
	return (
		lab._pitch_actor.receiver_router == property.receiver.route
		and property.display._match == lab._match_state
		and (
			(id == "AC-01" and lab._camera_director.get_script() == StadiumClubCameraDirector)
			or (id == "AE-01" and lab._camera_director.get_script() == StadiumExpandedCameraDirector)
		)
		and lab._camera_director.camera_mask == 80
	)



static func bind_ball(lab: PitchBatLab, ball: BattedBallBody, resolver: BallPlayResolver,
	context: StadiumNpcQualificationContext) -> bool:
	if not installed(lab, context) or not is_instance_valid(ball) \
		or not ball.is_inside_tree() or ball.get_parent() != lab or lab._batted_ball != ball \
		or resolver == null or resolver != lab._ball_play_resolver or resolver.state == null \
		or resolver.field != context._field or resolver.state.dead:
		return false
	var property: StadiumNpcBoundProperty = lab.get_meta("stadium_property")
	property.bind_contacts(ball, resolver)
	return _ball_wiring(property, ball, resolver)


static func _ball_wiring(property: StadiumNpcBoundProperty, ball: BattedBallBody,
	resolver: BallPlayResolver) -> bool:
	if ball.physics_contact_router != property.boundary._contact_batch.bind(resolver):
		return false
	var id: int = ball.get_instance_id()
	if property.venue_id != "AC-01":
		return ball.body_entered.is_connected(property._ball_contact.bind(ball, resolver)) \
			and ball.tree_exited.is_connected(property.boundary._forget.bind(id))
	return ball.launch_started.is_connected(property.boundary._seed.bind(id)) \
		and ball.tree_exited.is_connected(property.boundary._forget.bind(
			id, resolver.get_instance_id())) \
		and property.boundary._resolver_ids.get(id) == resolver.get_instance_id() \
		and property.boundary._bound_balls.get(id) is WeakRef \
		and property.boundary._bound_balls[id].get_ref() == ball \
		and property.boundary._previous.get(id) is Vector3 \
		and property.boundary._previous[id].is_finite()


static func rebind_match(lab: PitchBatLab,
	replacement: StadiumNpcQualificationContext) -> bool:
	if not _startup(lab) or not _origin_clean(lab) or replacement == null \
		or not replacement.validated(lab) or not replacement.fresh() \
		or not lab.has_meta("stadium_property"):
		return false
	var property: StadiumNpcBoundProperty = lab.get_meta("stadium_property") \
		as StadiumNpcBoundProperty
	if property == null or property.context == null \
		or not property.context.same_fixture(replacement) or not _complete(lab, property):
		return false
	property.disconnect_balls()
	var previous: StadiumNpcQualificationContext = property.context
	var suspended: bool = property.suspended
	var observer: Callable = lab._ball_play_resolver.segment_observer
	var receiver: Callable = lab._pitch_actor.receiver_router
	var resolved_flags: int = property.quarantined_resolved_flags
	property.context = replacement
	property.suspended = false
	if suspended:
		lab._ball_play_resolver.segment_observer = property.observe
		lab._pitch_actor.receiver_router = (Callable() if property.receiver == null
			else property.receiver.route)
	property.rebind(lab._match_state)
	property.restore_resolved_connection(lab)
	if not installed(lab, replacement):
		property.context = previous
		property.suspended = suspended
		lab._ball_play_resolver.segment_observer = observer
		lab._pitch_actor.receiver_router = receiver
		if resolved_flags >= 0:
			if lab._ball_play_resolver.play_resolved.is_connected(lab._on_ball_play_resolved):
				lab._ball_play_resolver.play_resolved.disconnect(lab._on_ball_play_resolved)
			property.quarantined_resolved_flags = resolved_flags
		if is_instance_valid(property.display):
			property.display.bind_match(null)
		return false
	if property.resume_mode >= 0:
		lab.process_mode = property.resume_mode as Node.ProcessMode
		property.resume_mode = -1
	return true


static func teardown(lab: PitchBatLab) -> bool:
	if not is_instance_valid(lab) or not StadiumPropertyRuntime.authoring_delivery_idle(lab) \
		or is_instance_valid(lab._batted_ball) or not lab.has_meta("stadium_property"):
		return false
	var property: StadiumNpcBoundProperty = lab.get_meta("stadium_property") \
		as StadiumNpcBoundProperty
	if property == null:
		return false
	_restore(lab, property)
	property.free()
	return true


static func _restore(lab: PitchBatLab, property: StadiumNpcBoundProperty,
	deferred: bool = false) -> void:
	property.disconnect_balls()
	property.restore_resolved_connection(lab)
	property.lab_ref = null
	if is_instance_valid(property.display):
		property.display.bind_match(null)
	if is_instance_valid(lab._pitch_actor):
		lab._pitch_actor.receiver_router = property.old_receiver
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
	if lab.get_meta("stadium_property", null) == property:
		lab.remove_meta("stadium_property")
	var originals: Array[Node] = property.old_nodes.duplicate()
	var order: Array[Node] = property.host_children.duplicate()
	property.old_nodes.clear()
	property.context = null
	property.frozen_snapshot.clear()
	property.frozen_key = ""
	if deferred:
		var live: bool = not StadiumPropertyRuntime.authoring_delivery_idle(lab) \
			or is_instance_valid(lab._batted_ball) or lab._automation != null or property.suspended
		var mode: int = lab.process_mode
		lab.process_mode = Node.PROCESS_MODE_DISABLED
		lab.set_meta("stadium_npc_runtime_restoring", true)
		if live:
			lab.set_meta("stadium_npc_runtime_interrupted", true)
		_restore_originals.call_deferred(weakref(lab), originals, order, mode, live)
	else:
		_restore_originals(weakref(lab), originals, order)


static func unexpected_exit(lab: PitchBatLab, property: StadiumNpcBoundProperty) -> void:
	if lab.get_meta("stadium_property", null) == property:
		if is_instance_valid(lab._batted_ball) or lab._pitch_actor.running:
			property.pause_invalid()
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
	PitchBatLabPresentation.refresh_markers(lab)
	if previous_mode >= 0:
		if interrupted:
			lab._automation = null
			lab._pitch_actor.reset_pitch()
			lab._release_controller.cancel()
			lab._at_bat_cadence.stop()
			lab._cleanup_batted_ball()
		else:
			lab.process_mode = previous_mode as Node.ProcessMode
		lab.remove_meta("stadium_npc_runtime_restoring")
