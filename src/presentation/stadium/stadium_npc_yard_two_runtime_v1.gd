class_name StadiumNpcYardTwoRuntimeV1
extends RefCounted
## AY02/r1 public saved-fixture admission and separate explicit private qualification.
# gdlint: disable=max-returns

const OPT_IN: String = "stadium_npc_ay02_installed_lab_only"
const RETAINED_OPT_IN: String = "stadium_npc_retained_lab_only"
const INSTALLING: String = "stadium_npc_ay02_installing"
const PUBLIC_BOUND: String = "stadium_npc_ay02_bound"
const REMOVED: Array[String] = ["Ground", "BackWall", "LiveObjectPole", "Plate", "MoundMarker",
	"SafeBoundary", "DeepAirBoundary", "RightFoulLine", "LeftFoulLine"]
const CAMERA_KEYS: Array[String] = ["shot", "_field_focus", "_batter_side", "_presentation_motion",
	"_presentation_progress", "_presentation_transition_speed", "_pitch_focus", "_standard_fov",
	"_tracking_height", "_shot_before_inspection"]


static func _opted_in(lab: PitchBatLab) -> bool:
	return lab.has_meta(OPT_IN) and typeof(lab.get_meta(OPT_IN)) == TYPE_BOOL \
		and lab.get_meta(OPT_IN) == true and lab.has_meta(RETAINED_OPT_IN) \
		and typeof(lab.get_meta(RETAINED_OPT_IN)) == TYPE_BOOL \
		and lab.get_meta(RETAINED_OPT_IN) == true


static func _live_lab(lab: PitchBatLab) -> bool:
	return is_instance_valid(lab) and lab.is_inside_tree() and not lab.is_queued_for_deletion() \
		and lab.global_transform == Transform3D.IDENTITY \
		and is_instance_valid(lab._pitch_actor) and is_instance_valid(lab._primary_fielder) \
		and is_instance_valid(lab._ball_play_resolver) and is_instance_valid(lab._camera) \
		and is_instance_valid(lab._camera_director) \
		and is_instance_valid(lab._release_controller) \
		and lab._release_controller.get_script() == PitchReleaseController \
		and is_instance_valid(lab._at_bat_cadence) \
		and lab._at_bat_cadence.get_script() == AtBatCadenceController \
		and lab.get_node_or_null("PitchFlightActor") == lab._pitch_actor \
		and lab.get_node_or_null("PrimaryFielder") == lab._primary_fielder \
		and lab.get_node_or_null("LabCamera") == lab._camera \
		and lab._pitch_actor.get_script() == PitchFlightActor \
		and lab._primary_fielder.get_script() == FielderController \
		and lab._ball_play_resolver.get_script() == BallPlayResolver \
		and lab._match_state != null and lab._match_state.get_script() == MatchState


static func _idle(lab: PitchBatLab) -> bool:
	return _live_lab(lab) and not lab._pitch_actor.running \
		and (lab._release_controller == null or (is_instance_valid(lab._release_controller) \
			and not lab._release_controller.active)) \
		and (lab._at_bat_cadence == null or (is_instance_valid(lab._at_bat_cadence) \
			and lab._at_bat_cadence.state == AtBatCadenceController.State.IDLE))


static func _public_context(lab: PitchBatLab, property: StadiumNpcYardTwoPropertyV1 = null,
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
		or snapshot.manifest.get("id") != "AY-02" \
		or not SeasonOwnership._whole(snapshot.manifest.get("revision"), 1, 1) \
		or not snapshot.get("binding") is Dictionary \
		or snapshot.binding.get("venue_id") != "AY-02" \
		or not SeasonOwnership._whole(snapshot.binding.get("venue_revision"), 1, 1) \
		or not SeasonOwnership._whole(snapshot.binding.get("fixture"), 0, 31):
		return false
	if lab._managed_match and (lab._player_home or snapshot.binding.get("away") != 0):
		return false
	var fixture: Dictionary = SeasonVenues.fixture_for_id(lab._npc_season,
		int(snapshot.binding.fixture))
	if property != null and (not property.public_bound \
		or not property.public_context_intact() \
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
	if lab._npc_season.season_seed != snapshot.binding.get("season_seed") \
		or SeasonVenues.run_for(lab._npc_season) != snapshot.binding.get("career_run"):
		return false
	if property != null and (not strict or property.public_context_issued()):
		# Exact equality to frozen, fully validated installation inputs above. No
		# mutable success bit: custom callbacks and unissued callers still normalize.
		return true
	return StadiumNpcSnapshot.matches_fixture(snapshot, lab._npc_season, fixture)


static func _public_fresh(lab: PitchBatLab) -> bool:
	if not _public_context(lab) or not StadiumMountedScoreboardContract.origin_clean(lab) \
		or lab._throw_number != 0 or not lab._play_records.is_empty() \
		or (lab._automation != null and not lab._automation.releases.is_empty()):
		return false
	# Reuse the existing complete first-play predicate, not its raw-envelope authority.
	var fresh: StadiumNpcQualificationContext = StadiumNpcQualificationContext.new()
	fresh._match = lab._match_state
	return fresh.fresh()


static func _admissible(lab: PitchBatLab, public_bound: bool = false) -> bool:
	if not _idle(lab):
		return false
	if public_bound:
		if not _public_fresh(lab) or lab.has_meta("stadium_snapshot") \
			or lab.has_meta(PUBLIC_BOUND):
			return false
	elif not _opted_in(lab) or lab._managed_match or lab._automation != null \
		or not lab._match_state.stadium.is_empty():
		return false
	if lab._field_id != PitchBatLab.FIELD_ID or lab.has_meta("stadium_property") \
		or lab.has_meta("stadium_candidate_only") or lab.has_meta(INSTALLING) \
		or lab.has_meta("stadium_npc_runtime_interrupted") \
		or lab.has_meta("stadium_npc_runtime_restoring") or is_instance_valid(lab._batted_ball) \
		or lab._pitch_actor.receiver_router.is_valid() \
		or lab._ball_play_resolver.segment_observer.is_valid() \
		or lab._primary_fielder.stadium_boundary_clip.is_valid() \
		or not lab._primary_fielder.stadium_obstacles.is_empty() \
		or lab._camera_director.get_script() != MatchCameraDirector \
		or lab._camera_director.presentation_override.is_valid() \
		or not is_instance_valid(lab._camera_director._live_coverage) \
		or lab._camera_director._live_coverage.get_script() != BallInPlayCamera \
		or lab._camera_director._live_coverage.position_filter.is_valid() \
		or lab._camera_director._live_coverage.framing_lead_degrees != 0 \
		or not is_instance_valid(lab._camera_director.tracking_visibility) \
		or lab._camera_director.tracking_visibility.get_script() != BallTrackingVisibility:
		return false
	var host: StarterFieldLabGeometry = lab.get_node_or_null("StarterFieldGeometry")
	if host == null or host.get_script() != StarterFieldLabGeometry or not host.is_inside_tree() \
		or host.is_queued_for_deletion() or host.global_transform != Transform3D.IDENTITY \
		or not host.has_node("PitchReceiverDebug") or host.has_node("HomeProperty") \
		or host.has_node("AY02InstalledProperty") or lab._field_definition == null \
		or lab._field_definition.get_script() != FieldDefinition:
		return false
	for key: String in StadiumNpcYardV1.FIELD:
		if lab._field_definition.get(key) != StadiumNpcYardV1.FIELD[key]:
			return false
	for node: Node in host.find_children("*", "Node", true, false):
		if node is CollisionObject3D and (node.get_parent() != host or String(node.name) not in REMOVED):
			return false
		if node is CollisionShape3D and (node.get_parent().get_parent() != host \
			or String(node.get_parent().name) not in REMOVED):
			return false
	var expected: BallTrackingVisibility = BallTrackingVisibility.new()
	expected.configure(host)
	return _view_data(lab._camera_director.tracking_visibility) == _view_data(expected)


static func install(lab: PitchBatLab, id: String = "AY-02", revision: int = 1) -> bool:
	var property: StadiumNpcYardTwoPropertyV1 = _stage(lab, id, revision)
	if property == null:
		return false
	if not _commit(lab, property):
		property.free()
		return false
	return true


static func install_bound(lab: PitchBatLab) -> bool:
	var property: StadiumNpcYardTwoPropertyV1 = _stage(lab, "AY-02", 1, true)
	if property == null:
		return false
	if not _commit(lab, property):
		property.free()
		return false
	return true


static func installed_bound(lab: PitchBatLab, snapshot: Dictionary) -> bool:
	var property: StadiumNpcYardTwoPropertyV1 = _property(lab)
	return property != null and property.public_bound \
		and property.public_snapshot == snapshot and installed(lab)


static func _construct(_lab: PitchBatLab, id: String = "AY-02", revision: int = 1
	) -> StadiumNpcYardTwoPropertyV1:
	if id != "AY-02" or revision != 1 \
		or StadiumNpcYardTwoCandidateV1.definition(id, revision).is_empty():
		return null
	var property: StadiumNpcYardTwoPropertyV1 = StadiumNpcYardTwoPropertyV1.new()
	property.name = "AY02InstalledProperty"
	property.venue_id = id
	property.construction = StadiumNpcYardTwoInstalledGeometryV1.expected(false)
	property.add_child(property.construction)
	property.objects = property.construction.objects
	property.field = property.construction.field
	property.tier = property.construction.tier
	property.boundary = property.construction.get_node("BoundaryGraph")
	property.pin_construction()
	property.receiver = StadiumNpcYardTwoReceiverV1.new()
	property.receiver.name = "PitchReceiverPresentation"
	property.add_child(property.receiver)
	property.motion = StadiumNpcYardTwoCameraMotionV1.new()
	property.camera = StadiumNpcYardTwoCameraV1.new()
	property.visibility = StadiumNpcYardTwoVisibilityV1.new()
	property.actor_presentation = StadiumNpcYardTwoActorPresentationV1.new()
	property.actor_presentation.name = "AY02ActorPresentation"
	property.add_child(property.actor_presentation)
	property.pin_support()
	return property


static func _bind_components(lab: PitchBatLab, property: StadiumNpcYardTwoPropertyV1) -> bool:
	if not is_instance_valid(property) or property.get_parent() != null \
		or not property.support_intact() or property.receiver_configured \
		or not property.receiver.configure_candidate(
			property, lab._sounds if lab != null else null):
		return false
	property.receiver_configured = true
	if not property.motion.bind_candidate(property) or not property.camera.bind_candidate(property):
		return false
	property.camera._live_coverage = property.motion
	property.camera.tracking_visibility = property.visibility
	property.camera.actor_cutaway = property.actor_cutaway
	property.camera.lab_ref = weakref(lab) if lab != null else null
	property.visibility.property_ref = weakref(property)
	property.visibility.lab_ref = weakref(lab) if lab != null else null
	property.visibility.motion_ref = weakref(property.motion)
	property.actor_presentation.property_ref = weakref(property)
	property.actor_presentation.lab_ref = weakref(lab) if lab != null else null
	property.actor_presentation.actor_cutaway = property.actor_cutaway
	return true


static func _stage(lab: PitchBatLab, id: String = "AY-02", revision: int = 1,
	public_bound: bool = false
	) -> StadiumNpcYardTwoPropertyV1:
	if not _admissible(lab, public_bound):
		return null
	var property: StadiumNpcYardTwoPropertyV1 = _construct(lab, id, revision)
	if property == null:
		return null
	if public_bound:
		property.public_bound = true
		property.public_snapshot = lab._match_state.stadium.duplicate(true)
		property.public_season = lab._npc_season
		property.public_assignments = lab._npc_season.npc_venues.duplicate(true)
		property.public_fixture = SeasonVenues.fixture_for_id(lab._npc_season,
			int(property.public_snapshot.binding.fixture))
		property.public_automation = lab._automation
		property.public_managed = lab._managed_match
	if not _bind_components(lab, property) or not _complete(lab, property):
		property.free()
		return null
	return property


static func _complete(lab: PitchBatLab, property: StadiumNpcYardTwoPropertyV1) -> bool:
	return is_instance_valid(lab) and is_instance_valid(property) \
		and property.support_intact() and property.geometry_intact() \
		and _components_bound(lab, property, true)


static func _components_bound(lab: PitchBatLab, property: StadiumNpcYardTwoPropertyV1,
	strict: bool = false) -> bool:
	return property.receiver_configured and property.receiver.structure_bound() \
		and property.receiver.sounds == lab._sounds \
		and property.motion.structure_bound(strict) and property.camera.property_ref != null \
		and property.camera.property_ref.get_ref() == property \
		and property.camera.lab_ref != null and property.camera.lab_ref.get_ref() == lab \
		and property.camera.actor_cutaway == property.actor_cutaway \
		and property.camera._live_coverage == property.motion \
		and property.camera.tracking_visibility == property.visibility \
		and not property.camera.presentation_override.is_valid() \
		and property.visibility.property_ref != null \
		and property.visibility.property_ref.get_ref() == property \
		and property.visibility.motion_ref != null \
		and property.visibility.motion_ref.get_ref() == property.motion \
		and property.visibility.lab_ref != null and property.visibility.lab_ref.get_ref() == lab \
		and property.actor_presentation.property_ref != null \
		and property.actor_presentation.property_ref.get_ref() == property \
		and property.actor_presentation.lab_ref != null \
		and property.actor_presentation.lab_ref.get_ref() == lab \
		and property.actor_presentation.actor_cutaway == property.actor_cutaway \
		and property.actor_presentation.process_mode == Node.PROCESS_MODE_ALWAYS \
		and property.actor_presentation.process_priority == 100


static func _commit(lab: PitchBatLab, property: StadiumNpcYardTwoPropertyV1) -> bool:
	if not is_instance_valid(property) or not _admissible(lab, property.public_bound) \
		or (property.public_bound and not _public_context(lab, property)) \
		or property.get_parent() != null \
		or not _complete(lab, property):
		return false
	lab.set_meta(INSTALLING, true)
	var host: StarterFieldLabGeometry = lab.get_node("StarterFieldGeometry")
	property.host_children.assign(host.get_children())
	property.old_field_id = lab._field_id
	property.old_field = lab._field_definition
	property.old_camera_mask = lab._camera.cull_mask
	property.old_camera_transform = lab._camera.transform
	property.old_camera_fov = lab._camera.fov
	property.old_camera = lab._camera_director
	property.old_visibility = lab._camera_director.tracking_visibility
	property.old_observer = lab._ball_play_resolver.segment_observer
	property.old_router = lab._pitch_actor.receiver_router
	property.old_clip = lab._primary_fielder.stadium_boundary_clip
	property.old_obstacles = lab._primary_fielder.stadium_obstacles.duplicate(true)
	for key: String in CAMERA_KEYS:
		property.camera.set(key, property.old_camera.get(key))
	for id: String in REMOVED:
		var old: Node = host.get_node_or_null(NodePath(id))
		if old != null:
			host.remove_child(old)
			property.old_nodes.append(old)
	host.add_child(property)
	property.pin_lab(lab)
	lab.set_meta("stadium_property", property)
	if property.public_bound:
		lab.set_meta(PUBLIC_BOUND, true)
		lab.set_meta("stadium_snapshot", property.public_snapshot.duplicate(true))
	else:
		lab.set_meta("stadium_candidate_only", true)
	lab._field_id = property.field.id
	lab._field_definition = property.field
	lab._ball_play_resolver.segment_observer = property.observe
	lab._primary_fielder.stadium_boundary_clip = property.clip
	lab._primary_fielder.stadium_obstacles = property.route_obstacles()
	lab._camera_director = property.camera
	property.visibility.configure(host)
	property.pin_visibility()
	property.rebind(lab._match_state)
	var bound: bool = property.receiver.bind_actor(lab._pitch_actor)
	if bound:
		property.pin_signals()
	if not bound or not installed(lab):
		_restore(lab, property)
		host.remove_child(property)
		lab.remove_meta(INSTALLING)
		return false
	StadiumWallRenderQuality.attach(property.boundary)
	property.camera.acquire_precontact_entry()
	PitchBatLabPresentation.refresh_markers(lab)
	StadiumPropertyRuntime.refresh_receiver_visibility(lab)
	lab.remove_meta(INSTALLING)
	if not installed(lab) or not property.issue_installation():
		_restore(lab, property)
		host.remove_child(property)
		return false
	return true


static func _binding_mode(lab: PitchBatLab, property: StadiumNpcYardTwoPropertyV1,
	strict: bool) -> bool:
	if property.public_bound:
		return _public_context(lab, property, strict) \
			and lab.has_meta(PUBLIC_BOUND) and lab.get_meta(PUBLIC_BOUND) == true \
			and lab.has_meta("stadium_snapshot") \
			and lab.get_meta("stadium_snapshot") == property.public_snapshot \
			and (not strict or StadiumMountedScoreboardContract.origin_clean(lab))
	return _opted_in(lab) and not lab._managed_match and lab._match_state.stadium.is_empty() \
		and lab.has_meta("stadium_candidate_only") and lab.get_meta("stadium_candidate_only") == true \
		and not lab.has_meta(PUBLIC_BOUND)


static func binding_valid(lab: PitchBatLab, property: StadiumNpcYardTwoPropertyV1,
	check_state: bool = true, strict: bool = true) -> bool:
	if not _live_lab(lab) or not is_instance_valid(property) \
		or not _binding_mode(lab, property, strict) or property._exit_had_owned_activity \
		or not lab.has_meta("stadium_property") or lab.get_meta("stadium_property") != property \
		or lab.has_meta("stadium_npc_runtime_interrupted") \
		or lab.has_meta("stadium_npc_runtime_restoring") \
		or property.lab_ref == null or property.lab_ref.get_ref() != lab \
		or not is_instance_valid(property._host) or not property._host.is_inside_tree() \
		or property._host != lab.get_node_or_null("StarterFieldGeometry") \
		or property.get_parent() != property._host or not property.is_inside_tree() \
		or property._host.global_transform != Transform3D.IDENTITY \
		or property._host.get_script() != StarterFieldLabGeometry \
		or property._actor != lab._pitch_actor or property._resolver != lab._ball_play_resolver \
		or property._fielder != lab._primary_fielder or property._lab_camera != lab._camera \
		or property._sounds != lab._sounds \
		or property._release != lab._release_controller or property._cadence != lab._at_bat_cadence \
		or property.camera != lab._camera_director or not property.support_intact() \
		or (check_state and property.bound_state != lab._match_state) \
		or lab._field_id != property.field.id or lab._field_definition != property.field \
		or property.presentation_director != property.camera or property.presentation_camera == null \
		or property.presentation_camera.get_ref() != lab._camera:
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
			if node.get_parent() != property._host:
				return false
	if strict:
		for node: Node in property._host.find_children("*", "Node", true, false):
			if (node is CollisionObject3D or node is CollisionShape3D) \
				and not property.is_ancestor_of(node):
				return false
	return property._host.get_child_count() == count \
		and (not strict or property.visibility_intact())


static func installed(lab: PitchBatLab, id: String = "AY-02", revision: int = 1) -> bool:
	return _installed(lab, id, revision, true)


static func _installed(lab: PitchBatLab, id: String, revision: int, check_state: bool) -> bool:
	if not is_instance_valid(lab) or id != "AY-02" or revision != 1 \
		or not lab.has_meta("stadium_property"):
		return false
	var property: StadiumNpcYardTwoPropertyV1 = lab.get_meta("stadium_property") \
		as StadiumNpcYardTwoPropertyV1
	return is_instance_valid(property) and property.audit_installation(check_state)


static func _installed_body(lab: PitchBatLab, property: StadiumNpcYardTwoPropertyV1,
	check_state: bool = true) -> bool:
	# Full boundary authority, independent of callback_intact's issued hot-path choice.
	if not binding_valid(lab, property, check_state, true) or not _complete(lab, property) \
		or not property.routing_intact() \
		or not property.receiver.actor_wiring(lab._pitch_actor):
		return false
	for reference: WeakRef in property.bound_balls:
		var ball: BattedBallBody = reference.get_ref() as BattedBallBody
		var router: Callable = property._boundary_contact_batch.bind(lab._ball_play_resolver)
		if is_instance_valid(ball) and (ball.physics_contact_router != router \
			or not ball.body_entered.is_connected(property._ball_contact.bind(
				ball, lab._ball_play_resolver))):
			return false
	return true


static func _owned_idle(property: StadiumNpcYardTwoPropertyV1) -> bool:
	var receiver: StadiumNpcYardTwoReceiverV1 = property._owned_receiver()
	if receiver == null or property._exit_had_owned_activity:
		return false
	return not receiver.has_owned_activity()


static func rebind_match(lab: PitchBatLab) -> bool:
	if not _idle(lab) or lab._automation != null or is_instance_valid(lab._batted_ball) \
		or not _installed(lab, "AY-02", 1, false):
		return false
	var property: StadiumNpcYardTwoPropertyV1 = lab.get_meta("stadium_property")
	# A saved fixture never rebinds to another MatchState in the same physical installation.
	if property.public_bound:
		return property.bound_state == lab._match_state and installed(lab)
	if not _owned_idle(property):
		return false
	# Revocation precedes every supported binding write. No old play ticket survives.
	property.retire_installation("idle match rebind")
	var generation: int = property.installation_generation
	property.disconnect_balls()
	property.rebind(lab._match_state)
	if property.installation_generation != generation or property.phase != &"retired" \
		or lab.has_meta("stadium_npc_runtime_interrupted"):
		return false
	property.phase = &"staging"
	return installed(lab) and property.issue_installation()


static func teardown(lab: PitchBatLab) -> bool:
	if not _idle(lab) or lab._automation != null or is_instance_valid(lab._batted_ball) \
		or not lab.has_meta("stadium_property"):
		return false
	var property: StadiumNpcYardTwoPropertyV1 = lab.get_meta("stadium_property") \
		as StadiumNpcYardTwoPropertyV1
	if not is_instance_valid(property) or property.lab_ref == null \
		or property.lab_ref.get_ref() != lab \
		or property.get_parent() != lab.get_node_or_null("StarterFieldGeometry"):
		return false
	if not property._exit_had_owned_activity and not _owned_idle(property):
		return false
	# A genuine child-only interruption is cleanup, never a return to ordinary operation.
	_restore(lab, property)
	property.free()
	return true


static func _view_data(view: BallTrackingVisibility) -> Array:
	return [view._obstacles.duplicate(), view._uprights.duplicate(), view._wall_bounds.duplicate(),
		view.field_wall_z, view._recipe, view._wall_prisms]


static func _restore(lab: PitchBatLab, property: StadiumNpcYardTwoPropertyV1,
	deferred: bool = false) -> void:
	# Shared cleanup for explicit teardown and unexpected property removal. The latter can
	# occur inside a busy parent notification, so restore original siblings deferred.
	var owned_activity: bool = property._exit_had_owned_activity or not _owned_idle(property)
	property.retire_installation("restore or teardown")
	property.disconnect_balls()
	var receiver: StadiumNpcYardTwoReceiverV1 = property._owned_receiver()
	if receiver != null:
		receiver.cancel_owned()
	property.lab_ref = null
	if is_instance_valid(property.display):
		property.display.bind_match(null)
	if is_instance_valid(lab._pitch_actor):
		if not lab._pitch_actor.receiver_router.is_valid() or (receiver != null \
			and lab._pitch_actor.receiver_router == receiver.route):
			lab._pitch_actor.receiver_router = property.old_router
	if is_instance_valid(lab._ball_play_resolver):
		lab._ball_play_resolver.segment_observer = property.old_observer
	if is_instance_valid(lab._primary_fielder):
		lab._primary_fielder.stadium_boundary_clip = property.old_clip
		lab._primary_fielder.stadium_obstacles = property.old_obstacles
	lab._field_id = property.old_field_id
	lab._field_definition = property.old_field
	if is_instance_valid(lab._camera):
		lab._camera.cull_mask = property.old_camera_mask
		lab._camera.transform = property.old_camera_transform
		lab._camera.fov = property.old_camera_fov
	lab._camera_director = property.old_camera
	if is_instance_valid(lab._camera_director):
		lab._camera_director.tracking_visibility = property.old_visibility
	lab.remove_meta("stadium_property")
	lab.remove_meta("stadium_candidate_only")
	if property.public_bound:
		# The saved game cannot continue on restored starter geometry or settle a result.
		lab.remove_meta("stadium_snapshot")
		lab.set_meta(PUBLIC_BOUND, true)
	else:
		# A lab that held private gameplay remains report-quarantined after every cleanup.
		lab.set_meta(RETAINED_OPT_IN, true)
		lab.set_meta(OPT_IN, true)
	var originals: Array[Node] = property.old_nodes.duplicate()
	var order: Array[Node] = property.host_children.duplicate()
	property.old_nodes.clear()
	if deferred or owned_activity or property.public_bound:
		var live: bool = property.public_bound or owned_activity or not _idle(lab) \
			or is_instance_valid(lab._batted_ball) or lab._automation != null
		var previous_mode: int = lab.process_mode
		lab.process_mode = Node.PROCESS_MODE_DISABLED
		lab.set_meta("stadium_npc_runtime_restoring", true)
		if live:
			lab.set_meta("stadium_npc_runtime_interrupted", true)
		_restore_originals.call_deferred(weakref(lab), originals, order, previous_mode, live)
	else:
		_restore_originals(weakref(lab), originals, order)


static func unexpected_exit(lab: PitchBatLab, property: StadiumNpcYardTwoPropertyV1) -> void:
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


static func _property(lab: PitchBatLab) -> StadiumNpcYardTwoPropertyV1:
	return lab.get_meta("stadium_property") as StadiumNpcYardTwoPropertyV1 \
		if is_instance_valid(lab) and lab.has_meta("stadium_property") else null


static func applies(lab: PitchBatLab) -> bool:
	# Other venues use the unchanged lab path. Interrupted AY02 remains quarantined.
	return _property(lab) != null or (is_instance_valid(lab) \
		and ((lab.has_meta(OPT_IN) and lab.get_meta(OPT_IN) == true) \
			or (lab.has_meta(PUBLIC_BOUND) and lab.get_meta(PUBLIC_BOUND) == true)) \
		and lab.has_meta("stadium_npc_runtime_interrupted"))


static func validate_play(lab: PitchBatLab, generation: int = -1,
	owner: StadiumNpcYardTwoPropertyV1 = null) -> bool:
	var property: StadiumNpcYardTwoPropertyV1 = _property(lab)
	# A stale continuation has no authority over a replacement installation or play.
	if (owner != null and property != owner) or (generation >= 0 \
		and (property == null or property.play_generation != generation)):
		return false
	if not applies(lab):
		return true
	if property != null:
		# Ordinary public continuations share the issued lifecycle. Launch/outcome,
		# installed/report and commit boundaries retain their full geometry audits.
		var valid: bool = property.callback_intact() if property.public_bound else (
			property.audit_installation())
		if valid:
			return true
	interrupt(lab, property)
	return false


static func launch_pitch(lab: PitchBatLab) -> bool:
	if not applies(lab):
		return true
	if is_instance_valid(lab._pitch_actor) and lab._pitch_actor.running:
		return false
	if lab._match_mode and lab._match_state != null \
		and lab._match_state.phase != MatchState.Phase.PRE_PITCH:
		return false
	var property: StadiumNpcYardTwoPropertyV1 = _property(lab)
	if property == null or not property.begin_play(&"pitch_pending"):
		interrupt(lab, property)
		return false
	return true


static func bind_live_pitch(lab: PitchBatLab, generation: int = -1,
	owner: StadiumNpcYardTwoPropertyV1 = null) -> bool:
	if (owner != null and _property(lab) != owner) or (generation >= 0 \
		and (_property(lab) == null or _property(lab).play_generation != generation)):
		return false
	if not applies(lab):
		return true
	var property: StadiumNpcYardTwoPropertyV1 = _property(lab)
	if property == null or property._play_kind != &"pitch_pending" \
		or not validate_play(lab) or not lab._pitch_actor.running \
		or lab._pitch_actor.state == null or lab._pitch_actor.state.get_script() != PitchState \
		or lab._pitch_actor.parameters == null \
		or lab._pitch_actor.parameters.get_script() != PitchLaunchParameters:
		interrupt(lab, property)
		return false
	property._play_pitch = lab._pitch_actor.state
	property._play_parameters = lab._pitch_actor.parameters
	property._play_kind = &"pitch"
	return property.callback_intact()


static func launch_ball(lab: PitchBatLab) -> bool:
	if not applies(lab):
		return true
	var property: StadiumNpcYardTwoPropertyV1 = _property(lab)
	if property == null or not property.begin_play(&"ball_pending"):
		interrupt(lab, property)
		return false
	return true


static func prepare_ball_camera(lab: PitchBatLab, generation: int = -1,
	owner: StadiumNpcYardTwoPropertyV1 = null) -> bool:
	if (owner != null and _property(lab) != owner) or (generation >= 0 \
		and (_property(lab) == null or _property(lab).play_generation != generation)):
		return false
	if not applies(lab):
		return true
	var property: StadiumNpcYardTwoPropertyV1 = _property(lab)
	# Cleanup can call arbitrary lifecycle code: audit AFTER it, immediately before prepare.
	if property == null or property._play_kind != &"ball_pending" or not validate_play(lab):
		interrupt(lab, property)
		return false
	property._camera_launch_generation = property.play_generation
	return true


static func bind_live_ball(lab: PitchBatLab, generation: int = -1,
	owner: StadiumNpcYardTwoPropertyV1 = null) -> bool:
	if (owner != null and _property(lab) != owner) or (generation >= 0 \
		and (_property(lab) == null or _property(lab).play_generation != generation)):
		return false
	if not applies(lab):
		return true
	var property: StadiumNpcYardTwoPropertyV1 = _property(lab)
	# add_child/ready/launch/bind are not assumed pure. Re-audit after those callbacks.
	if property == null or property._play_kind != &"ball_pending" or not validate_play(lab) \
		or not is_instance_valid(lab._batted_ball) \
		or lab._batted_ball.get_script() != BattedBallBody or not lab._batted_ball._started \
		or lab._batted_ball.get_parent() != lab or lab._ball_play_resolver.state == null \
		or lab._ball_play_resolver.state.get_script() != BallPlayState \
		or lab._ball_play_resolver.field != property.field:
		interrupt(lab, property)
		return false
	property._play_ball = lab._batted_ball
	property._play_state = lab._ball_play_resolver.state
	property._play_kind = &"ball"
	return property._ball_owned(lab._batted_ball, lab._ball_play_resolver)


static func outcome_gate(lab: PitchBatLab, kind: StringName) -> bool:
	if not applies(lab):
		return true
	var property: StadiumNpcYardTwoPropertyV1 = _property(lab)
	if property == null or kind not in [&"plate", &"noncontact", &"ball"] \
		or not property.audit_installation():
		interrupt(lab, property)
		return false
	if property.phase == &"playing":
		if property._outcome_generation == property.play_generation:
			return false
		if not property._play_bindings_intact() \
			or (kind == &"ball" and (property._play_kind != &"ball" \
				or not property._play_state.dead)) \
			or (kind != &"ball" and property._play_kind != &"pitch"):
			interrupt(lab, property)
			return false
		property._outcome_generation = property.play_generation
	# Unissued direct actor-start diagnostic callers just paid the full strict audit.
	return true


static func interrupt(lab: PitchBatLab, property: StadiumNpcYardTwoPropertyV1) -> void:
	if not is_instance_valid(lab) or (property != null and _property(lab) != property):
		return
	if property != null:
		property.retire_installation("invalid installation during gameplay")
	if lab.has_meta("stadium_npc_runtime_interrupted"):
		return
	lab.set_meta("stadium_npc_runtime_interrupted", true)
	if (property != null and property.public_bound) or lab.has_meta(PUBLIC_BOUND) \
		or (lab._match_state != null and StadiumNpcSnapshot.is_public(lab._match_state.stadium)):
		lab.set_meta(PUBLIC_BOUND, true)
	else:
		lab.set_meta(RETAINED_OPT_IN, true)
		lab.set_meta(OPT_IN, true)
	lab.process_mode = Node.PROCESS_MODE_DISABLED
	lab._automation = null
	if is_instance_valid(lab._pitch_actor):
		lab._pitch_actor.running = false
		lab._pitch_actor.visible = false
		# The plate signal stack still reads state.velocity after scoring returns. Keep
		# that state alive until unwound, but swallow its exact owned receiver continuation.
		lab._pitch_actor.receiver_router = _interrupted_route.bind(
			weakref(lab), weakref(property) if property != null else null)
	if is_instance_valid(lab._status_label):
		lab._status_label.text = "AY02 INSTALLATION INVALID • play interrupted; reinstall required"
	var generation: int = property.installation_generation if property != null else -1
	_finish_interruption.call_deferred(weakref(lab),
		weakref(property) if property != null else null, generation)


static func _interrupted_route(actor: PitchFlightActor, _start: Vector3, _velocity: Vector3,
	lab_ref: WeakRef, property_ref: WeakRef) -> bool:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab
	var property: StadiumNpcYardTwoPropertyV1 = property_ref.get_ref() \
		as StadiumNpcYardTwoPropertyV1 if property_ref != null else null
	if not is_instance_valid(lab) or not is_instance_valid(actor) or actor != lab._pitch_actor \
		or not lab.has_meta("stadium_npc_runtime_interrupted"):
		return false
	var current: Variant = lab.get_meta("stadium_property") \
		if lab.has_meta("stadium_property") else null
	# Unexpected exit clears metadata before this same-stack continuation. A detached
	# retired owner still swallows its pitch, but never a replacement installation.
	if current != null and current != property:
		return false
	return property == null or property.phase == &"retired"


static func _finish_interruption(lab_ref: WeakRef, property_ref: WeakRef, generation: int) -> void:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab
	var property: StadiumNpcYardTwoPropertyV1 = property_ref.get_ref() \
		as StadiumNpcYardTwoPropertyV1 if property_ref != null else null
	if not is_instance_valid(lab) or not lab.has_meta("stadium_npc_runtime_interrupted"):
		return
	# Never reset a newer binding/play after a deferred callback from an old installation.
	if property_ref != null and (property == null or _property(lab) != property \
		or property.installation_generation != generation or property.phase != &"retired"):
		return
	if property != null:
		property.disconnect_balls()
		var receiver: StadiumNpcYardTwoReceiverV1 = property._owned_receiver()
		if receiver != null:
			receiver.cancel_owned()
	if is_instance_valid(lab._pitch_actor):
		lab._pitch_actor.reset_pitch()
	if is_instance_valid(lab._release_controller):
		lab._release_controller.cancel()
	if is_instance_valid(lab._at_bat_cadence):
		lab._at_bat_cadence.stop()
	_cancel_ball(lab)


static func abandon_launch(lab: PitchBatLab, generation: int = -1,
	owner: StadiumNpcYardTwoPropertyV1 = null) -> void:
	var property: StadiumNpcYardTwoPropertyV1 = _property(lab)
	if (owner != null and property != owner) or (generation >= 0 \
		and (property == null or property.play_generation != generation)):
		return
	if property != null and property.phase == &"playing" \
		and property._play_kind == &"pitch_pending":
		property.play_generation += 1
		property._clear_play()
		property.phase = &"ready"


static func cleanup_play(lab: PitchBatLab, preserve_pending: bool = false) -> bool:
	if not applies(lab):
		return true
	var property: StadiumNpcYardTwoPropertyV1 = _property(lab)
	if property == null or not validate_play(lab):
		return false
	var pending: StringName = property._play_kind
	if not preserve_pending or pending not in [&"pitch_pending", &"ball_pending"]:
		property.play_generation += 1
		property._clear_play()
		property._play_kind = &"reset_pending"
		property.phase = &"playing"
	var generation: int = property.installation_generation
	var play: int = property.play_generation
	property.receiver.reset_play()
	if property.installation_generation != generation or property.play_generation != play \
		or not validate_play(lab):
		return false
	if property._play_kind == &"reset_pending":
		property._clear_play()
		property.phase = &"ready"
	return true
