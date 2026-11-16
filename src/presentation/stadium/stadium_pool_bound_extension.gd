class_name StadiumPoolBoundExtension
extends RefCounted
## Explicit private configuration before ordinary startup. No public save/purchase dispatcher.
## Staged geometry and complete footprint validate off-tree; original nodes survive rollback.
# gdlint: disable=max-returns

const REQUEST: StringName = &"stadium_pool_bound_request"
const PROPERTY: StringName = &"stadium_pool_bound_property"
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
const META: Array[StringName] = [
	&"stadium_property",
	&"stadium_snapshot",
	&"boundary_signature",
	&"stadium_environment",
	PROPERTY
]
const VISIBILITY: Array[StringName] = [
	&"field_wall_z", &"_obstacles", &"_uprights", &"_recipe", &"_wall_bounds", &"_wall_prisms"
]
var _owner: WeakRef
var _token: StadiumPoolBoundEntitlement
var _enabled: bool = false
var _options: PackedByteArray


static func configure(
	lab: PitchBatLab, entitlement: StadiumPoolBoundEntitlement, active_enabled: bool = false
) -> bool:
	if (
		lab == null
		or entitlement == null
		or lab.is_inside_tree()
		or lab.get_parent() != null
		or lab._configured_match == null
		or not lab._match_mode
		or lab.has_meta(REQUEST)
		or lab.pool_controller_active != null
		or lab.has_meta("stadium_property")
	):
		return false
	if not entitlement.configure_for(lab, lab._configured_match.stadium):
		return false
	var request: StadiumPoolBoundExtension = StadiumPoolBoundExtension.new()
	request._owner = weakref(lab)
	request._token = entitlement
	request._enabled = active_enabled
	request._options = var_to_bytes([entitlement.get_instance_id(), active_enabled])
	lab.set_meta(REQUEST, request)
	return true


static func requested(lab: PitchBatLab) -> bool:
	return lab != null and lab.has_meta(REQUEST)


static func current(lab: PitchBatLab) -> StadiumPoolBoundProperty:
	var value: Variant = lab.get_meta(PROPERTY) if lab != null and lab.has_meta(PROPERTY) else null
	if not value is StadiumPoolBoundProperty:
		return null
	return value as StadiumPoolBoundProperty if is_instance_valid(value) else null


static func prepare_match_start(lab: PitchBatLab) -> bool:
	if not requested(lab):
		return true
	var property: StadiumPoolBoundProperty = current(lab)
	if property != null:
		if property.valid_owner(lab):
			return true
		# A new MatchState, missing ledger or changed snapshot cannot inherit this token.
		# Keep ordinary installed geometry intact, but do not begin a stale private match.
		_revoke(lab, property)
		return false
	return StadiumPropertyRuntime.install_bound(lab)


static func install_bound(lab: PitchBatLab) -> bool:
	var request: StadiumPoolBoundExtension = _request(lab)
	if request == null or not _admissible(lab, request):
		return false
	var property: StadiumPoolBoundProperty = StadiumPoolBoundProperty.new()
	if not property.build_private(lab, request._token) or not _admissible(lab, request):
		property.free()
		return false
	var host: StarterFieldLabGeometry = lab.get_node("StarterFieldGeometry")
	_capture(lab, host, property)
	# No old node is queued/freed. _attach cannot find its destructive default targets.
	for id: String in REMOVED:
		var old: Node = host.get_node_or_null(NodePath(id))
		if old != null:
			host.remove_child(old)
			property.old_nodes.append(old)
	if not StadiumPropertyRuntime._attach(
		lab, host, property, property.frozen_snapshot.layout, property.receiver
	):
		_rollback(lab, host, property)
		return false
	lab._ball_play_resolver.segment_observer = StadiumBoundaryObserver.observe
	lab._primary_fielder.stadium_boundary_clip = StadiumBoundaryGraph.clip
	lab.set_meta("boundary_signature", StadiumBoundaryGraph.signature())
	lab.set_meta("stadium_snapshot", property.frozen_snapshot.duplicate(true))
	lab.set_meta(PROPERTY, property)
	StadiumLightRuntime.bind(lab, property.frozen_snapshot)
	if (
		not property.bind_owner(lab, host)
		or not property.valid_owner(lab)
		or not property.plain_actors(lab)
	):
		_rollback(lab, host, property)
		return false
	var adapter: StadiumPoolControllerActive = StadiumPoolControllerActive.new()
	if not adapter.install_bound(lab, property):
		_rollback(lab, host, property)
		return false
	adapter.enabled = request._enabled
	adapter.freeflight_enabled = true
	return true


static func _request(lab: PitchBatLab) -> StadiumPoolBoundExtension:
	if lab == null or not lab.has_meta(REQUEST):
		return null
	var value: Variant = lab.get_meta(REQUEST)
	if not value is StadiumPoolBoundExtension:
		return null
	var request: StadiumPoolBoundExtension = value
	if (
		request._owner == null
		or request._owner.get_ref() != lab
		or request._token == null
		or request._options != var_to_bytes([request._token.get_instance_id(), request._enabled])
	):
		return null
	return request


static func _admissible(lab: PitchBatLab, request: StadiumPoolBoundExtension) -> bool:
	if (
		lab == null
		or request == null
		or not lab.is_inside_tree()
		or lab.get_script() != load("res://src/labs/pitch_bat_lab/pitch_bat_lab.gd")
		or not lab._match_mode
		or lab._match_state == null
		or lab._match_state.phase != MatchState.Phase.PRE_PITCH
		or not is_instance_valid(lab._pitch_actor)
		or not is_instance_valid(lab._pitcher_marker)
		or not is_instance_valid(lab._primary_fielder)
		or not is_instance_valid(lab._ball_play_resolver)
		or not StadiumPropertyRuntime.authoring_delivery_idle(lab)
		or lab._field_id != PitchBatLab.FIELD_ID
		or lab.global_transform != Transform3D.IDENTITY
		or lab.has_meta("stadium_property")
		or lab.has_meta(PROPERTY)
		or lab.pool_controller_active != null
		or is_instance_valid(lab._batted_ball)
		or not request._token.valid_for(lab, lab._match_state.stadium, "CONFIGURED")
		or not StadiumPoolBoundEntitlement.exact_base(lab._match_state.stadium, lab._stadium_ledger)
		or (
			request._token.descriptor().source_sha256
			!= StadiumPoolPartyAssetIntegrity.source_sha256()
		)
	):
		return false
	var host: StarterFieldLabGeometry = lab.get_node_or_null("StarterFieldGeometry")
	if (
		host == null
		or (
			host.get_script()
			!= preload("res://src/labs/pitch_bat_lab/starter_field_lab_geometry.gd")
		)
		or host.global_transform != Transform3D.IDENTITY
		or host.has_node("HomeProperty")
		or lab._pitch_actor.receiver_router.is_valid()
		or lab._ball_play_resolver.segment_observer.is_valid()
		or lab._primary_fielder.stadium_boundary_clip.is_valid()
		or not lab._primary_fielder.stadium_obstacles.is_empty()
	):
		return false
	if not StadiumPoolLabGroundProfile.matches(host.get_node_or_null("Ground") as StaticBody3D):
		return false
	for id: String in REMOVED:
		var node: Node = host.get_node_or_null(NodePath(id))
		if node == null or node.is_queued_for_deletion():
			return false
	for body: CollisionObject3D in host.find_children("*", "CollisionObject3D", true, false):
		if body.get_parent() != host or String(body.name) not in REMOVED:
			return false
	return true


static func _capture(lab: PitchBatLab, host: Node, property: StadiumPoolBoundProperty) -> void:
	property.old_order.assign(host.get_children())
	property.saved_state = {
		"observer": lab._ball_play_resolver.segment_observer,
		"clip": lab._primary_fielder.stadium_boundary_clip,
		"obstacles": lab._primary_fielder.stadium_obstacles.duplicate(true),
		"receiver": lab._pitch_actor.receiver_router,
		"metadata": {},
		"visibility": {}
	}
	for key: StringName in META:
		property.saved_state.metadata[key] = {
			"present": lab.has_meta(key), "value": lab.get_meta(key) if lab.has_meta(key) else null
		}
	for key: StringName in VISIBILITY:
		var value: Variant = lab._camera_director.tracking_visibility.get(key)
		property.saved_state.visibility[key] = value.duplicate(true) if value is Array else value


static func _rollback(lab: PitchBatLab, host: Node, property: StadiumPoolBoundProperty) -> void:
	property.restoring = true
	if lab.pool_controller_active != null and lab.pool_controller_active._bound_profile == property:
		lab.pool_controller_active.detach()
	property.detach_ball_callbacks()
	property.entitlement.retire()
	if property.get_parent() != null:
		property.get_parent().remove_child(property)
	for old: Node in property.old_nodes:
		if is_instance_valid(old) and old.get_parent() == null:
			host.add_child(old)
	for index in range(property.old_order.size()):
		var node: Node = property.old_order[index]
		if is_instance_valid(node) and node.get_parent() == host:
			host.move_child(node, index)
	property.old_nodes.clear()
	lab._ball_play_resolver.segment_observer = property.saved_state.observer
	lab._primary_fielder.stadium_boundary_clip = property.saved_state.clip
	lab._primary_fielder.stadium_obstacles = property.saved_state.obstacles
	lab._pitch_actor.receiver_router = property.saved_state.receiver
	for key: StringName in META:
		var prior: Dictionary = property.saved_state.metadata[key]
		if prior.present:
			lab.set_meta(key, prior.value)
		elif lab.has_meta(key):
			lab.remove_meta(key)
	for key: StringName in VISIBILITY:
		lab._camera_director.tracking_visibility.set(key, property.saved_state.visibility[key])
	property.free()


static func _revoke(lab: PitchBatLab, property: StadiumPoolBoundProperty) -> void:
	if lab.pool_controller_active != null and lab.pool_controller_active._bound_profile == property:
		lab.pool_controller_active.detach()
	if property.entitlement != null:
		property.entitlement.retire()


static func property_exiting(property: StadiumPoolBoundProperty) -> void:
	var lab: PitchBatLab = (
		property._lab_ref.get_ref() as PitchBatLab if property._lab_ref != null else null
	)
	if lab != null:
		_revoke(lab, property)
	property.detach_ball_callbacks()
	if lab == null:
		return
	# Teardown removes only callbacks and metadata owned by this exact property.
	if (
		is_instance_valid(lab._pitch_actor)
		and is_instance_valid(property.receiver)
		and lab._pitch_actor.receiver_router == property.receiver.route
	):
		lab._pitch_actor.receiver_router = Callable()
	if lab.has_meta("stadium_property") and lab.get_meta("stadium_property") == property:
		if (
			is_instance_valid(lab._ball_play_resolver)
			and lab._ball_play_resolver.segment_observer == StadiumBoundaryObserver.observe
		):
			lab._ball_play_resolver.segment_observer = Callable()
		if is_instance_valid(lab._primary_fielder):
			if lab._primary_fielder.stadium_boundary_clip == StadiumBoundaryGraph.clip:
				lab._primary_fielder.stadium_boundary_clip = Callable()
			if lab._primary_fielder.stadium_obstacles == property.route_obstacles():
				lab._primary_fielder.stadium_obstacles.clear()
		var snapshot: Dictionary = bytes_to_var(property._snapshot_bytes)
		var expected: Dictionary = {
			"stadium_property": property,
			PROPERTY: property,
			"stadium_snapshot": snapshot,
			"boundary_signature": snapshot.boundary,
			"stadium_environment": "day"
		}
		for key: StringName in META:
			if lab.has_meta(key) and lab.get_meta(key) == expected[key]:
				lab.remove_meta(key)
	var request: StadiumPoolBoundExtension = _request(lab)
	if request != null and request._token == property.entitlement:
		lab.remove_meta(REQUEST)
