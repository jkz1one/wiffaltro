class_name StadiumMountedPresentationContract
extends RefCounted
## Exact normal-center motion and callback identity. Evolving flight/hold state is not a credential.


static func camera_target(lab: PitchBatLab) -> bool:
	return is_instance_valid(lab) and is_instance_valid(lab._camera) \
		and lab._camera.is_inside_tree() and lab._camera.get_parent() == lab \
		and lab.get_node_or_null("LabCamera") == lab._camera


static func preflight(lab: PitchBatLab) -> bool:
	return camera_target(lab) and lab._camera_director != null \
		and lab._camera_director.get_script() == MatchCameraDirector \
		and _scorer_ready(lab) and lab._camera_director._live_coverage != null \
		and lab._camera_director.presentation_override.is_null() \
		and lab._camera_director._live_coverage.position_filter.is_null() \
		and lab._camera_director._live_coverage.framing_lead_degrees == 0 \
		and lab._camera_director._live_coverage.get_script() == BallInPlayCamera


static func bind(lab: PitchBatLab, property: StadiumScoreboardPropertyGeometry,
	frozen: Dictionary) -> void:
	if StadiumScoreboardAssembly.center_model(property) == null:
		return
	lab._camera_director._live_coverage = StadiumMountedCameraMotion.new()
	property.celebration = StadiumMountedScoreboardCelebration.new()
	property.celebration.name = "MountedScoreboardCelebration"
	property.add_child(property.celebration)
	property.celebration._bind(lab, property, frozen)


static func capture(lab: PitchBatLab, property: StadiumScoreboardPropertyGeometry) -> Dictionary:
	var director: MatchCameraDirector = lab._camera_director
	if director == null:
		return {}
	return {"director": director.get_instance_id(), "script": _id(director.get_script()),
		"camera": _id(lab._camera),
		"motion": _motion(director._live_coverage),
		"override": _callback(director.presentation_override),
		"helper": _helper(property.celebration)}


static func matches(lab: PitchBatLab, property: StadiumScoreboardPropertyGeometry,
	frozen: Dictionary, identity: Variant) -> bool:
	var actual: Dictionary = capture(lab, property)
	if not camera_target(lab) or not StadiumMountedScoreboardIntegrity.equal(actual, identity):
		return false
	var center: Node3D = StadiumScoreboardAssembly.center_model(property)
	var expected: BallInPlayCamera = StadiumMountedCameraMotion.new() if center != null \
		else BallInPlayCamera.new()
	var motion: Dictionary = _motion(expected)
	if actual.motion.is_empty():
		return false
	motion.id = actual.motion.id
	if not StadiumMountedScoreboardIntegrity.equal(actual.motion, motion) \
		or lab._camera_director.get_script() != MatchCameraDirector:
		return false
	if center == null:
		return property.celebration == null and lab._camera_director.presentation_override.is_null()
	var helper: StadiumMountedScoreboardCelebration = property.celebration
	if not is_instance_valid(helper) or helper.get_parent() != property \
		or property.get_node_or_null("MountedScoreboardCelebration") != helper \
		or helper.get_script() != StadiumMountedScoreboardCelebration \
		or helper._lab != lab or helper._property != property or helper._board != center \
		or helper._camera != lab._camera or helper._director != lab._camera_director \
		or helper._resolver != lab._ball_play_resolver \
		or helper._match != lab._match_state or not ClubCareer.same(helper._frozen, frozen) \
		or helper.process_mode != Node.PROCESS_MODE_PAUSABLE or helper.process_priority != -100 \
		or not helper.is_processing() \
		or lab._camera_director.presentation_override != helper._update_camera:
		return false
	return listeners_match(helper)


static func _motion(value: BallInPlayCamera) -> Dictionary:
	if value == null:
		return {}
	return {"id": value.get_instance_id(), "script": _id(value.get_script()),
		"filter_empty": value.position_filter.is_null(), "framing_lead": value.framing_lead_degrees}


static func _helper(value: StadiumMountedScoreboardCelebration) -> Dictionary:
	if not is_instance_valid(value):
		return {"id": 0}
	return {"id": value.get_instance_id(), "parent": _id(value.get_parent()),
		"script": _id(value.get_script()), "lab": _id(value._lab), "board": _id(value._board),
		"property": _id(value._property), "camera": _id(value._camera),
		"director": _id(value._director),
		"resolver": _id(value._resolver), "fixture": value._frozen.duplicate(true),
		"policy": StadiumScoreboardCelebrationCore.POLICY, "mode": value.process_mode,
		"priority": value.process_priority, "processing": value.is_processing(),
		"listeners": _listeners(value)}


static func _listeners(value: StadiumMountedScoreboardCelebration) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value._resolver == null:
		return result
	for row: Dictionary in value._resolver.play_resolved.get_connections():
		var callback: Callable = row.callable
		if callback.get_object_id() == value.get_instance_id() or (
			is_instance_valid(value._lab) and callback == value._lab._on_ball_play_resolved):
			result.append({"callback": _callback(callback), "flags": row.flags})
	return result


static func _scorer_ready(lab: PitchBatLab) -> bool:
	if lab._ball_play_resolver == null:
		return false
	var matches_count: int = 0
	for row: Dictionary in lab._ball_play_resolver.play_resolved.get_connections():
		if row.callable == lab._on_ball_play_resolved:
			if row.flags != 0:
				return false
			matches_count += 1
	return matches_count == 1


static func listeners_match(value: StadiumMountedScoreboardCelebration) -> bool:
	return is_instance_valid(value._lab) and StadiumMountedScoreboardIntegrity.equal(
		_listeners(value), [
			{"callback": _callback(value._lab._on_ball_play_resolved), "flags": 0},
			{"callback": _callback(value._on_resolved), "flags": 0}])


static func _callback(value: Callable) -> Dictionary:
	return {"object": value.get_object_id(), "method": String(value.get_method()),
		"bound": value.get_bound_arguments(), "unbound": value.get_unbound_arguments_count(),
		"custom": value.is_custom(), "null": value.is_null()}


static func _id(value: Object) -> int:
	return value.get_instance_id() if is_instance_valid(value) else 0
