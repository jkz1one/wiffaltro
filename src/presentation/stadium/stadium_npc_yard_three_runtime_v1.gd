class_name StadiumNpcYardThreeRuntimeV1
extends RefCounted
## AY03/r1 public saved-fixture admission and separate explicit private qualification.
# gdlint: disable=max-returns

const OPT_IN: String = "stadium_npc_ay03_installed_lab_only"
const RETAINED_OPT_IN: String = "stadium_npc_retained_lab_only"
const PUBLIC_BOUND: String = "stadium_npc_ay03_bound"
const REMOVED: Array[String] = ["Ground", "BackWall", "LiveObjectPole", "Plate", "MoundMarker",
	"SafeBoundary", "DeepAirBoundary", "RightFoulLine", "LeftFoulLine"]


static func install(lab: PitchBatLab, id: String = "AY-03", revision: int = 1) -> bool:
	var staged: StadiumNpcYardThreePropertyV1 = _stage(lab, id, revision)
	if staged == null:
		return false
	if not _commit(lab, staged):
		staged.free()
		return false
	return true


static func install_bound(lab: PitchBatLab) -> bool:
	var property: StadiumNpcYardThreePropertyV1 = _stage(lab, "AY-03", 1, true)
	if property == null:
		return false
	if not _commit(lab, property):
		property.free()
		return false
	return true


static func refuse_bound_start(lab: PitchBatLab) -> void:
	# Cold startup failure only; the shared caller has not begun a delivery or automation.
	if not is_instance_valid(lab):
		return
	lab.set_meta(PUBLIC_BOUND, true)
	lab.set_meta("stadium_npc_runtime_interrupted", true)
	lab.process_mode = Node.PROCESS_MODE_DISABLED
	lab._automation = null


static func _property(lab: PitchBatLab) -> StadiumNpcYardThreePropertyV1:
	if not is_instance_valid(lab) or not lab.has_meta("stadium_property"):
		return null
	return lab.get_meta("stadium_property") as StadiumNpcYardThreePropertyV1


static func installed_bound(lab: PitchBatLab, snapshot: Dictionary) -> bool:
	var property: StadiumNpcYardThreePropertyV1 = _property(lab)
	return is_instance_valid(property) and property.public_bound \
		and property.public_snapshot == snapshot and installed(lab)


static func _live_lab(lab: PitchBatLab) -> bool:
	return is_instance_valid(lab) and is_instance_valid(lab._pitch_actor) \
		and is_instance_valid(lab._primary_fielder) and is_instance_valid(lab._ball_play_resolver) \
		and is_instance_valid(lab._camera) and is_instance_valid(lab._camera_director)


static func _public_context(lab: PitchBatLab, property: StadiumNpcYardThreePropertyV1 = null,
	strict: bool = true) -> bool:
	if not is_instance_valid(lab) or lab.get_script() != PitchBatLab \
		or lab._match_state == null or lab._match_state.get_script() != MatchState \
		or not lab._match_mode or lab._configured_match != null \
		or lab._npc_season == null or lab._npc_season.get_script() != SeasonState \
		or (not lab._managed_match and lab._automation == null) \
		or lab.has_meta(OPT_IN) or lab.has_meta(RETAINED_OPT_IN) \
		or lab.has_meta("stadium_candidate_only") or lab._stadium_ledger != null \
		or lab.pool_active_receipt != null or lab.pool_controller_active != null \
		or StadiumPoolBoundExtension.requested(lab) or StadiumPoolOwnedExtension.requested(lab):
		return false
	var snapshot: Dictionary = lab._match_state.stadium
	if not SeasonOwnership._whole(snapshot.get("version"),
		StadiumNpcSnapshot.PUBLIC_FIXTURE_VERSION, StadiumNpcSnapshot.PUBLIC_FIXTURE_VERSION) \
		or not snapshot.get("manifest") is Dictionary \
		or snapshot.manifest.get("id") != "AY-03" \
		or not SeasonOwnership._whole(snapshot.manifest.get("revision"), 1, 1) \
		or not snapshot.get("binding") is Dictionary \
		or snapshot.binding.get("venue_id") != "AY-03" \
		or not SeasonOwnership._whole(snapshot.binding.get("venue_revision"), 1, 1) \
		or not SeasonOwnership._whole(snapshot.binding.get("fixture"), 0, 31):
		return false
	if lab._managed_match and (lab._player_home or snapshot.binding.get("away") != 0):
		return false
	var fixture: Dictionary = SeasonVenues.fixture_for_id(lab._npc_season,
		int(snapshot.binding.fixture))
	if property != null and (not property.public_bound \
		or property.public_season != lab._npc_season \
		or property.public_automation != lab._automation \
		or property.public_managed != lab._managed_match \
		or property.public_snapshot != snapshot \
		or property.public_assignments != lab._npc_season.npc_venues \
		or property.public_fixture != fixture):
		return false
	if lab._automation != null and (lab._automation.get_script() != MatchAutomation \
		or lab._automation.seed != snapshot.binding.get("match_seed")):
		return false
	if not strict and property != null:
		# Current data is compared each call; there is no cached validity or geometry token.
		return lab._npc_season.season_seed == snapshot.binding.get("season_seed") \
			and SeasonVenues.run_for(lab._npc_season) == snapshot.binding.get("career_run")
	var normalized: Dictionary = StadiumNpcSnapshot.normalized(snapshot)
	return not normalized.is_empty() \
		and StadiumNpcSnapshot.matches_fixture(normalized, lab._npc_season, fixture)


static func _public_fresh(lab: PitchBatLab) -> bool:
	if not _public_context(lab) or not StadiumMountedScoreboardContract.origin_clean(lab) \
		or lab._throw_number != 0 or not lab._play_records.is_empty() \
		or (lab._automation != null and not lab._automation.releases.is_empty()):
		return false
	# Reuse only the complete first-play predicate, never raw qualification authority.
	var fresh: StadiumNpcQualificationContext = StadiumNpcQualificationContext.new()
	fresh._match = lab._match_state
	return fresh.fresh()


static func _admissible(lab: PitchBatLab, public_bound: bool = false) -> bool:
	if not _live_lab(lab) or not StadiumPropertyRuntime.authoring_delivery_idle(lab):
		return false
	if public_bound:
		if not _public_fresh(lab) or lab.has_meta("stadium_snapshot") \
			or lab.has_meta(PUBLIC_BOUND):
			return false
	elif typeof(lab.get_meta(OPT_IN, false)) != TYPE_BOOL \
		or typeof(lab.get_meta("stadium_npc_retained_lab_only", false)) != TYPE_BOOL \
		or lab.get_meta("stadium_npc_retained_lab_only", false) != true \
		or lab.get_meta(OPT_IN, false) != true or lab._managed_match \
		or lab._automation != null or lab._match_state == null \
		or not lab._match_state.stadium.is_empty() or lab.has_meta(PUBLIC_BOUND):
		return false
	if lab._field_id != PitchBatLab.FIELD_ID \
		or lab.has_meta("stadium_property") or lab.has_meta("stadium_npc_runtime_interrupted") \
		or lab.has_meta("stadium_npc_runtime_restoring") or is_instance_valid(lab._batted_ball) \
		or lab._pitch_actor.receiver_router.is_valid() or lab.get_meta("stadium_candidate_only", false):
		return false
	var host: StarterFieldLabGeometry = lab.get_node_or_null("StarterFieldGeometry")
	if host == null or not host.is_inside_tree() or host.global_transform != Transform3D.IDENTITY \
		or not host.has_node("PitchReceiverDebug") or lab._match_state == null:
		return false
	for body: CollisionObject3D in host.find_children("*", "CollisionObject3D", true, false):
		if body.get_parent() != host or String(body.name) not in REMOVED:
			return false
	return true


static func _stage(lab: PitchBatLab, id: String, revision: int = 1,
	public_bound: bool = false) -> StadiumNpcYardThreePropertyV1:
	if not _admissible(lab, public_bound):
		return null
	var property: StadiumNpcYardThreePropertyV1 = _construct(lab, id, revision)
	if property != null and public_bound:
		property.public_bound = true
		property.public_snapshot = lab._match_state.stadium.duplicate(true)
		property.public_season = lab._npc_season
		property.public_assignments = lab._npc_season.npc_venues.duplicate(true)
		property.public_fixture = SeasonVenues.fixture_for_id(lab._npc_season,
			int(property.public_snapshot.binding.fixture))
		property.public_automation = lab._automation
		property.public_managed = lab._managed_match
	return property


static func _construct(_lab: PitchBatLab, id: String, revision: int
	) -> StadiumNpcYardThreePropertyV1:
	if id != "AY-03" or revision != 1 \
		or StadiumNpcYardThreeCandidateV1.definition(id, revision).is_empty():
		return null
	var property: StadiumNpcYardThreePropertyV1 = StadiumNpcYardThreePropertyV1.new()
	property.name = "HomeProperty"
	property.venue_id = "AY-03"
	property.construction = StadiumNpcYardThreeV1.build()
	property.add_child(property.construction)
	property.objects = property.construction.objects
	property.field = property.construction.field
	property.tier = property.construction.tier
	property.boundary = property.construction.get_node("BoundaryGraph")
	# Compatibility contact keys refer only to NPC instances, never human entitlement.
	for identity: String in property.objects:
		var model: Node3D = property.objects[identity]
		model.set_meta("owned_copy", identity)
		for body: StaticBody3D in model.get_node("Collision").get_children():
			body.set_meta("owned_copy", identity)
	return property


static func _complete(lab: PitchBatLab, property: StadiumNpcYardThreePropertyV1) -> bool:
	if not is_instance_valid(lab) or not is_instance_valid(property) \
		or property.get_script() != StadiumNpcYardThreePropertyV1 \
		or property.venue_id != "AY-03" or property.tier != "backyard" \
		or not is_instance_valid(property.construction) \
		or not property.construction is StadiumNpcYardV1 \
		or property.construction.get_script() != StadiumNpcYardV1 \
		or not is_instance_valid(property.field) or not is_instance_valid(property.boundary) \
		or property.field.get_script() != FieldDefinition \
		or lab._camera_director == null \
		or property.field != property.construction.field \
		or property.construction.get_parent() != property \
		or property.boundary != property.construction.get_node_or_null("BoundaryGraph") \
		or property.receiver != null or property.display != null \
		or property.field.id != &"field.npc_venue" or not property.route_obstacles().is_empty():
		return false
	var expected: StadiumNpcYardThreePropertyV1 = _construct(lab, "AY-03", 1)
	var same: bool = StadiumNpcYardThreeInstalledGeometryV1.same(property, expected)
	for key: String in StadiumNpcYardV1.FIELD:
		same = same and typeof(property.field.get(key)) == typeof(expected.field.get(key)) \
			and property.field.get(key) == expected.field.get(key)
	same = same and property.objects.size() == 8
	for identity: String in expected.objects:
		var model: Variant = property.objects.get(identity)
		same = same and model is Node3D and is_instance_valid(model) \
			and model.get_parent() == property.construction \
			and model == property.construction.objects.get(identity) \
			and model.get_meta("npc_instance", "") == identity
	if property.is_inside_tree():
		var view: StadiumNpcRetainedVisibility = lab._camera_director.tracking_visibility \
			as StadiumNpcRetainedVisibility
		var reference: StadiumNpcRetainedVisibility = StadiumNpcRetainedVisibility.new()
		reference.configure_property(expected)
		same = same and view != null and view.get_script() == StadiumNpcRetainedVisibility \
			and view.property == property and view._recipe != null and view._wall_prisms != null
		if same:
			same = view._recipe.get_script() == reference._recipe.get_script() \
				and view._recipe.segments() == reference._recipe.segments() \
				and view._recipe.polygon() == reference._recipe.polygon() \
				and view._obstacles == reference._obstacles and view._uprights == reference._uprights \
				and view._wall_bounds == reference._wall_bounds \
				and view.field_wall_z == reference.field_wall_z \
				and view._groups == reference._groups and view._rails == reference._rails \
				and view._wall_prisms.walls == reference._wall_prisms.walls
	expected.free()
	return same


static func _commit(lab: PitchBatLab, property: StadiumNpcYardThreePropertyV1) -> bool:
	if not is_instance_valid(property) or not _admissible(lab, property.public_bound) \
		or (property.public_bound and not _public_context(lab, property)) \
		or property.get_parent() != null or not _complete(lab, property):
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
	if property.public_bound:
		lab.set_meta(PUBLIC_BOUND, true)
		lab.set_meta("stadium_snapshot", property.public_snapshot.duplicate(true))
	else:
		lab.set_meta("stadium_candidate_only", true)
	property.lab_ref = weakref(lab)
	lab._field_id = property.field.id
	lab._field_definition = property.field
	lab._ball_play_resolver.segment_observer = property.observe
	lab._primary_fielder.stadium_boundary_clip = property.clip
	lab._primary_fielder.stadium_obstacles = property.route_obstacles()
	lab._camera_director.tracking_visibility = StadiumNpcRetainedVisibility.new()
	lab._camera_director.tracking_visibility.configure(host)
	property.presentation_director = lab._camera_director
	property.presentation_camera = weakref(lab._camera)
	property.rebind(lab._match_state)
	PitchBatLabPresentation.refresh_markers(lab)
	StadiumPropertyRuntime.refresh_receiver_visibility(lab)
	if not installed(lab):
		_restore(lab, property)
		host.remove_child(property)
		return false
	return true


static func installed(lab: PitchBatLab, id: String = "AY-03", revision: int = 1) -> bool:
	return _installed(lab, id, revision, true)


static func _binding_mode(lab: PitchBatLab, property: StadiumNpcYardThreePropertyV1,
	strict: bool = true) -> bool:
	if property.public_bound:
		return _public_context(lab, property, strict) \
			and lab.get_meta(PUBLIC_BOUND, false) == true \
			and typeof(lab.get_meta(PUBLIC_BOUND, false)) == TYPE_BOOL \
			and lab.has_meta("stadium_snapshot") \
			and lab.get_meta("stadium_snapshot") == property.public_snapshot \
			and not lab.has_meta("stadium_npc_runtime_interrupted") \
			and not lab.has_meta("stadium_npc_runtime_restoring") \
			and (not strict or StadiumMountedScoreboardContract.origin_clean(lab))
	return typeof(lab.get_meta(OPT_IN, false)) == TYPE_BOOL \
		and typeof(lab.get_meta("stadium_npc_retained_lab_only", false)) == TYPE_BOOL \
		and lab.get_meta("stadium_npc_retained_lab_only", false) == true \
		and lab.get_meta(OPT_IN, false) == true \
		and lab.get_meta("stadium_candidate_only", false) \
		and lab._match_state != null and lab._match_state.stadium.is_empty() \
		and not lab.has_meta(PUBLIC_BOUND)


static func _installed(lab: PitchBatLab, id: String, revision: int, check_state: bool) -> bool:
	if not is_instance_valid(lab) or id != "AY-03" or revision != 1 \
		or not lab.has_meta("stadium_property"):
		return false
	var property: StadiumNpcYardThreePropertyV1 = lab.get_meta("stadium_property") \
		as StadiumNpcYardThreePropertyV1
	if not is_instance_valid(property) or not _binding_mode(lab, property):
		return false
	var host: Node3D = lab.get_node_or_null("StarterFieldGeometry")
	if not is_instance_valid(property) or not is_instance_valid(host) \
		or not is_instance_valid(lab._pitch_actor) or not is_instance_valid(lab._primary_fielder) \
		or not is_instance_valid(lab._ball_play_resolver) or not is_instance_valid(lab._camera) \
		or not is_instance_valid(lab._camera_director) or property.get_parent() != host \
		or host.global_transform != Transform3D.IDENTITY or property.transform != Transform3D.IDENTITY \
		or property.lab_ref == null or property.lab_ref.get_ref() != lab \
		or lab._match_state == null \
		or (check_state and property.bound_state != lab._match_state) \
		or not _complete(lab, property) or property.presentation_director != lab._camera_director \
		or lab._camera_director != property.old_camera or property.presentation_camera == null \
		or property.presentation_camera.get_ref() != lab._camera \
		or not is_instance_valid(property.actor_cutaway) \
		or not is_instance_valid(property.ball_readability) \
		or property.actor_cutaway.get_script() != StadiumNpcRetainedActorCutaway \
		or property.ball_readability.get_script() != StadiumNpcRetainedBallReadability:
		return false
	var count: int = 1
	for node: Node in property.host_children:
		if not is_instance_valid(node):
			return false
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
		or lab._primary_fielder.stadium_obstacles != property.route_obstacles() \
		or lab._pitch_actor.receiver_router.is_valid():
		return false
	for reference: WeakRef in property.bound_balls:
		var ball: BattedBallBody = reference.get_ref() as BattedBallBody
		if not is_instance_valid(ball):
			continue
		if ball.physics_contact_router != property.boundary._contact_batch.bind(lab._ball_play_resolver) \
			or not ball.body_entered.is_connected(property._ball_contact.bind(
				ball, lab._ball_play_resolver)):
			return false
	return true


static func rebind_match(lab: PitchBatLab) -> bool:
	if not _live_lab(lab) or not StadiumPropertyRuntime.authoring_delivery_idle(lab) \
		or lab._automation != null \
		or is_instance_valid(lab._batted_ball) or not _installed(lab, "AY-03", 1, false):
		return false
	var property: StadiumNpcYardThreePropertyV1 = lab.get_meta("stadium_property")
	# A saved fixture cannot adopt a replacement MatchState in this installation.
	if property.public_bound:
		return property.bound_state == lab._match_state and installed(lab)
	property.disconnect_balls()
	property.rebind(lab._match_state)
	return installed(lab)


static func teardown(lab: PitchBatLab) -> bool:
	if not _live_lab(lab) or not StadiumPropertyRuntime.authoring_delivery_idle(lab) \
		or lab._automation != null \
		or is_instance_valid(lab._batted_ball) or not lab.has_meta("stadium_property"):
		return false
	var property: StadiumNpcYardThreePropertyV1 = lab.get_meta("stadium_property") \
		as StadiumNpcYardThreePropertyV1
	if not is_instance_valid(property) or property.lab_ref == null \
		or property.lab_ref.get_ref() != lab \
		or property.get_parent() != lab.get_node_or_null("StarterFieldGeometry"):
		return false
	_restore(lab, property)
	property.free()
	return true


static func _restore(lab: PitchBatLab, property: StadiumNpcYardThreePropertyV1,
	deferred: bool = false) -> void:
	# Shared cleanup for explicit teardown and unexpected property removal. The latter can
	# occur inside a busy parent notification, so restore original siblings deferred.
	property.disconnect_balls()
	property.lab_ref = null
	if is_instance_valid(property.display):
		property.display.bind_match(null)
	if is_instance_valid(lab._pitch_actor):
		lab._pitch_actor.receiver_router = Callable()
	if is_instance_valid(lab._ball_play_resolver):
		lab._ball_play_resolver.segment_observer = property.old_observer
	if is_instance_valid(lab._primary_fielder):
		lab._primary_fielder.stadium_boundary_clip = property.old_clip
		lab._primary_fielder.stadium_obstacles = property.old_obstacles
	lab._field_id = property.old_field_id
	lab._field_definition = property.old_field
	if is_instance_valid(lab._camera):
		lab._camera.cull_mask = property.old_camera_mask
	lab._camera_director = property.old_camera
	if is_instance_valid(lab._camera_director):
		lab._camera_director.tracking_visibility = property.old_visibility
	lab.remove_meta("stadium_property")
	lab.remove_meta("stadium_candidate_only")
	if property.public_bound:
		# Restored starter geometry cannot continue or report the saved public game.
		lab.remove_meta("stadium_snapshot")
		lab.set_meta(PUBLIC_BOUND, true)
	var originals: Array[Node] = property.old_nodes.duplicate()
	var order: Array[Node] = property.host_children.duplicate()
	property.old_nodes.clear()
	if deferred or property.public_bound:
		var live: bool = property.public_bound or not is_instance_valid(lab._pitch_actor) \
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


static func unexpected_exit(lab: PitchBatLab, property: StadiumNpcYardThreePropertyV1) -> void:
	if is_instance_valid(lab) and is_instance_valid(property) \
		and lab.has_meta("stadium_property") and lab.get_meta("stadium_property") == property:
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
		if is_instance_valid(lab) and not lab.is_queued_for_deletion():
			lab.process_mode = Node.PROCESS_MODE_DISABLED
			lab.set_meta("stadium_npc_runtime_interrupted", true)
			lab.remove_meta("stadium_npc_runtime_restoring")
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
			if is_instance_valid(lab._pitch_actor):
				lab._pitch_actor.reset_pitch()
			if is_instance_valid(lab._release_controller):
				lab._release_controller.cancel()
			if is_instance_valid(lab._at_bat_cadence):
				lab._at_bat_cadence.stop()
			_cancel_ball(lab)
		else:
			lab.process_mode = previous_mode as Node.ProcessMode
		lab.remove_meta("stadium_npc_runtime_restoring")


static func _cancel_ball(lab: PitchBatLab) -> void:
	# Mirror ordinary cleanup while tolerating actors destroyed before deferred restoration.
	if is_instance_valid(lab._ball_visibility):
		lab._ball_visibility.clear()
	if is_instance_valid(lab._home_run):
		lab._home_run.active = false
	if is_instance_valid(lab._pitcher_marker):
		lab._pitcher_marker.position = PitchBatLab.MOUND_ORIGIN
		lab._pitcher_marker.rotation = Vector3.ZERO
	if is_instance_valid(lab._batted_ball):
		if lab._batted_ball.surface_contact.is_connected(lab._on_batted_surface_contact):
			lab._batted_ball.surface_contact.disconnect(lab._on_batted_surface_contact)
		lab._batted_ball.queue_free()
	lab._batted_ball = null
	if is_instance_valid(lab._primary_fielder):
		lab._primary_fielder.end_play()
	lab._settled_seconds = 0.0
