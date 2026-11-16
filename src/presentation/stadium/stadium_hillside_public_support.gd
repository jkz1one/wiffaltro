class_name StadiumHillsidePublicSupport
extends RefCounted
## Subordinate support lease. Only StadiumNpcPublicProperty may issue or retire play.

const PROFILE: String = "hill"
const ANCHOR_INDEX: int = 7
const FIELDER_STATE: Array[String] = ["transform", "anchor_position", "target_position",
	"velocity", "active", "stationary", "first_step", "last_reaction_margin_seconds",
	"_play_elapsed_seconds", "stadium_pool_fielder_route", "stadium_pool_pitcher_route"]

const RESTORE_LEASE: StringName = &"stadium_hillside_restore_lease"

var pending: bool = true
var restored: bool = false
var ground: StadiumHillsideGroundContact
var primary_motion: StadiumHillsideDefenderMotion
var pitcher_motion: StadiumHillsideDefenderMotion
var _owner: StadiumNpcPublicProperty
var _lab: PitchBatLab
var _state: MatchState
var _resolver: BallPlayResolver
var _primary: FielderController
var _pitcher: Node3D
var _terrain: Node3D
var _field: FieldDefinition
var _before: Dictionary = {}
var _old_primary_motion: StadiumHillsideDefenderMotion
var _old_pitcher_motion: StadiumHillsideDefenderMotion
var _old_pitcher_transform: Transform3D
var _old_pitcher_target: Vector3
var _old_anchor_index: int
var _old_process_mode: int
var _construction_process_mode: int
var _host: Node
var _actor: PitchFlightActor
var _camera: Camera3D
var _release: PitchReleaseController
var _cadence: AtBatCadenceController
var _cleanup_abandoned: bool = false
var _cleanup_restoring: bool = false


func prepare(lab: PitchBatLab, owner: StadiumNpcPublicProperty) -> bool:
	if _owner != null or not is_instance_valid(lab) or not is_instance_valid(owner) \
		or owner.get_script() != StadiumNpcPublicProperty or owner.venue_id != "HILLSIDE" \
		or owner.get_parent() != null or not is_instance_valid(lab._primary_fielder) \
		or not is_instance_valid(lab._pitcher_marker) or lab._primary_fielder.active \
		or lab.hillside_private_runtime != null or lab._hillside_private_owner_identity != null \
		or lab.has_node("HillsidePrivateRuntime") or lab.has_node("HillsideGroundContact") \
		or not StadiumPropertyRuntime.authoring_delivery_idle(lab) \
		or is_instance_valid(lab._batted_ball):
		return false
	_owner = owner
	_lab = lab
	_state = lab._match_state
	_resolver = lab._ball_play_resolver
	_host = lab.get_node_or_null("StarterFieldGeometry")
	_actor = lab._pitch_actor
	_camera = lab._camera
	_release = lab._release_controller
	_cadence = lab._at_bat_cadence
	_primary = lab._primary_fielder
	_pitcher = lab._pitcher_marker
	_terrain = owner.construction.terrain
	_field = owner.field
	for key: String in FIELDER_STATE:
		var value: Variant = _primary.get(key)
		_before[key] = value.duplicate(true) if value is Dictionary else value
	_old_primary_motion = _primary.hillside_motion
	_old_pitcher_motion = lab.hillside_pitcher_motion
	_old_pitcher_transform = _pitcher.transform
	_old_pitcher_target = lab.hillside_pitcher_target
	_old_anchor_index = lab._fielder_anchor_index
	_old_process_mode = lab.process_mode
	_construction_process_mode = owner.construction.process_mode
	# Keep only the static candidate geometry registered while gameplay is held.
	owner.construction.process_mode = Node.PROCESS_MODE_ALWAYS
	lab.hillside_public_pending = owner
	lab._hillside_public_install_state = _state
	lab._hillside_public_install_reported = false
	lab.process_mode = Node.PROCESS_MODE_DISABLED
	return true


func owner_context_intact() -> bool:
	# Read-only identity leaf: never callback_intact(), tracking_valid() or full-tree audits.
	return not restored and is_instance_valid(_owner) and not _owner.suspended \
		and _owner.get_script() == StadiumNpcPublicProperty and _owner.venue_id == "HILLSIDE" \
		and _owner.hillside_support == self and is_instance_valid(_lab) \
		and _lab.is_inside_tree() and not _lab.is_queued_for_deletion() \
		and _owner.lab_ref != null and _owner.lab_ref.get_ref() == _lab \
		and StadiumNpcPublicRuntime._property(_lab) == _owner \
		and _owner.get_parent() == _lab.get_node_or_null("StarterFieldGeometry") \
		and _owner.is_inside_tree() and not _owner.is_queued_for_deletion() \
		and _owner.bound_state == _state and _lab._match_state == _state \
		and _lab._ball_play_resolver == _resolver and _lab._field_definition == _field \
		and _owner.field == _field and _owner.construction.terrain == _terrain \
		and is_instance_valid(_terrain) and _terrain.is_inside_tree() \
		and not _terrain.is_queued_for_deletion() \
		and _terrain.get_parent() == _owner.construction \
		and is_instance_valid(_primary) and _lab._primary_fielder == _primary \
		and _primary.get_parent() == _lab and not _primary.is_queued_for_deletion() \
		and is_instance_valid(_pitcher) and _lab._pitcher_marker == _pitcher \
		and _pitcher.get_parent() == _lab and not _pitcher.is_queued_for_deletion() \
		and _primary.stadium_boundary_clip == Callable(_owner, "clip") \
		and _resolver.segment_observer == Callable(_owner, "observe") \
		and _lab.hillside_private_runtime == null and _lab._hillside_private_owner_identity == null \
		and not _lab.has_node("HillsidePrivateRuntime")


func finish_registration() -> bool:
	if not pending or not owner_context_intact() or _lab.hillside_public_pending != _owner \
		or _primary.hillside_motion != _old_primary_motion \
		or _lab.hillside_pitcher_motion != _old_pitcher_motion \
		or _lab.process_mode != Node.PROCESS_MODE_DISABLED:
		return false
	primary_motion = StadiumHillsideDefenderMotion.new()
	_primary.hillside_motion = primary_motion
	if not primary_motion.configure(_primary, _field, _terrain, ANCHOR_INDEX, PROFILE, _owner):
		return false
	# Nine retained slots; only field-available selections require native support.
	for index in range(StadiumHillsideAnchorContract.SLOT_COUNT):
		var record: Dictionary = StadiumHillsideAnchorContract.anchor(_field, index, PROFILE)
		if record.is_empty() or typeof(record.get("available")) != TYPE_BOOL \
			or record.available != _field.is_fielder_anchor_available(index):
			return false
		if not record.available:
			continue
		if not primary_motion._physical_support(_primary, record.position):
			return false
	return _finish_registration_remaining_checks()


func _finish_registration_remaining_checks() -> bool:
	pitcher_motion = StadiumHillsideDefenderMotion.new()
	_lab.hillside_pitcher_motion = pitcher_motion
	if not pitcher_motion.configure_pitcher(_lab, _owner):
		return false
	ground = StadiumHillsideGroundContact.new()
	if not ground.install_public(_lab, _owner):
		if ground.get_parent() == null:
			ground.free()
		ground = null
		return false
	_lab._fielder_anchor_index = ANCHOR_INDEX
	_lab.hillside_pitcher_target = Vector3.INF
	pending = false
	_owner.construction.process_mode = _construction_process_mode
	return bound_intact()


func bound_intact() -> bool:
	return not pending and owner_context_intact() \
		and primary_motion != null and pitcher_motion != null \
		and primary_motion.get_script() == StadiumHillsideDefenderMotion \
		and pitcher_motion.get_script() == StadiumHillsideDefenderMotion \
		and _primary.hillside_motion == primary_motion \
		and _lab.hillside_pitcher_motion == pitcher_motion \
		and not primary_motion.blocked and not pitcher_motion.blocked \
		and primary_motion._structure_valid(_primary) \
		and pitcher_motion._pitcher_structure_valid(_lab) \
		and is_instance_valid(ground) and ground.get_script() == StadiumHillsideGroundContact \
		and not ground.blocked and ground._installed_valid() and ground._terrain_valid()


func resume_processing() -> bool:
	if not bound_intact() or _lab.hillside_public_pending != _owner:
		return false
	_lab.hillside_public_pending = null
	_lab.process_mode = _old_process_mode as Node.ProcessMode
	return true


func clear_ball(ball: BattedBallBody) -> void:
	if is_instance_valid(ground) and ground._ball == ball:
		ground.clear_binding()
	if primary_motion != null:
		primary_motion.reset_tracking()
	if pitcher_motion != null:
		pitcher_motion.reset_tracking()
	if cleanup_owned() and _lab.hillside_pitcher_motion == pitcher_motion:
		_lab.hillside_pitcher_target = Vector3.INF


func retire() -> void:
	if restored:
		return
	restored = true
	pending = false
	if is_instance_valid(ground):
		ground.clear_binding()
		ground.blocked = true
	if primary_motion != null:
		primary_motion.reset_tracking()
		primary_motion.blocked = true
	if pitcher_motion != null:
		pitcher_motion.reset_tracking()
		pitcher_motion.blocked = true
		pitcher_motion.presentation_active = false
	restore_actors()
	report_install.call_deferred(false)
	if is_instance_valid(_owner) and is_instance_valid(_owner.construction):
		_owner.construction.process_mode = _construction_process_mode


func restore_actors() -> void:
	if not cleanup_owned():
		return
	if is_instance_valid(_primary):
		if _primary.hillside_motion == primary_motion:
			_primary.hillside_motion = _old_primary_motion
		for key: String in FIELDER_STATE:
			_primary.set(key, _before[key])
	if is_instance_valid(_pitcher):
		_pitcher.transform = _old_pitcher_transform
	if is_instance_valid(_lab):
		if _lab.hillside_pitcher_motion == pitcher_motion:
			_lab.hillside_pitcher_motion = _old_pitcher_motion
		_lab.hillside_pitcher_target = _old_pitcher_target
		_lab._fielder_anchor_index = _old_anchor_index
		if _lab.hillside_public_pending == _owner:
			_lab.hillside_public_pending = null
		_lab.process_mode = Node.PROCESS_MODE_DISABLED


func staging_actors_intact() -> bool:
	return not restored and is_instance_valid(_lab) and _lab.is_inside_tree() \
		and not _lab.is_queued_for_deletion() and _lab._match_state == _state \
		and _lab._ball_play_resolver == _resolver \
		and is_instance_valid(_primary) and _lab._primary_fielder == _primary \
		and _primary.get_parent() == _lab and not _primary.is_queued_for_deletion() \
		and is_instance_valid(_pitcher) and _lab._pitcher_marker == _pitcher \
		and _pitcher.get_parent() == _lab and not _pitcher.is_queued_for_deletion() \
		and _lab.hillside_public_pending == _owner


func cleanup_owned() -> bool:
	# A cleanup lease cannot follow a new match, owner, host or reused actor slot.
	# No callback audit, source hash or tree walk; failure permanently abandons lab writes.
	if _cleanup_abandoned:
		return false
	var same: bool = is_instance_valid(_lab) and _lab._match_state == _state \
		and _lab._hillside_public_install_state == _state \
		and _lab._ball_play_resolver == _resolver \
		and is_instance_valid(_host) and _lab.get_node_or_null("StarterFieldGeometry") == _host \
		and is_instance_valid(_primary) and _lab._primary_fielder == _primary \
		and _primary.get_parent() == _lab \
		and is_instance_valid(_pitcher) and _lab._pitcher_marker == _pitcher \
		and _pitcher.get_parent() == _lab \
		and is_instance_valid(_actor) and _lab._pitch_actor == _actor \
		and is_instance_valid(_camera) and _lab._camera == _camera \
		and _lab._release_controller == _release and _lab._at_bat_cadence == _cadence
	if same:
		if _cleanup_restoring:
			same = not _lab.has_meta("stadium_property") \
				and _lab.get_meta(RESTORE_LEASE, null) == self
		else:
			same = is_instance_valid(_owner) \
				and _lab.get_meta("stadium_property", null) == _owner \
				and _owner.hillside_support == self and _owner.bound_state == _state
	if not same:
		_cleanup_abandoned = true
	return same


func begin_restore() -> bool:
	if not cleanup_owned():
		return false
	_lab.set_meta(RESTORE_LEASE, self)
	_lab.remove_meta("stadium_property")
	_cleanup_restoring = true
	return true


func end_restore() -> void:
	if cleanup_owned():
		_lab.remove_meta(RESTORE_LEASE)
	_cleanup_abandoned = true


func report_install(success: bool) -> void:
	# A late failure must not make SeasonApp close a replacement match in the same lab.
	if cleanup_owned():
		_lab._report_hillside_public_install(success, _state)
