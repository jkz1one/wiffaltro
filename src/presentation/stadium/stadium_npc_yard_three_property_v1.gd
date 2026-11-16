class_name StadiumNpcYardThreePropertyV1
extends StadiumNpcRetainedProperty
## AY03/r1 adapter. Separate saved-fixture and private admission; ordinary Yard behavior.

var bound_state: MatchState
var public_bound: bool = false
var public_snapshot: Dictionary = {}
var public_season: SeasonState
var public_assignments: Dictionary = {}
var public_fixture: Dictionary = {}
var public_automation: MatchAutomation
var public_managed: bool = false


func route_obstacles() -> Array[Dictionary]:
	return []


func view_graph() -> StadiumRecipeBoundary:
	return StadiumNpcYardV1.TemplateView.new()


func clip(from: Vector3, to: Vector3) -> Vector3:
	return StadiumNpcYardGraphV1.clip(from, to)


func bind_ball(ball: BattedBallBody, resolver: BallPlayResolver) -> void:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	if lab == null or not is_instance_valid(ball) or not is_instance_valid(resolver) \
		or resolver != lab._ball_play_resolver \
		or not StadiumNpcYardThreeRuntimeV1.installed(lab):
		return
	super.bind_ball(ball, resolver)


func observe(resolver: BallPlayResolver, previous: Vector3, current: Vector3) -> Dictionary:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	if lab == null or lab._match_state != bound_state or resolver != lab._ball_play_resolver \
		or lab._field_definition != field \
		or (public_bound and not StadiumNpcYardThreeRuntimeV1._binding_mode(lab, self, false)):
		return {}
	return super.observe(resolver, previous, current)


func rebind(state: MatchState) -> void:
	# Called only by this adapter's checked install/rebind seam.
	bound_state = state


func refresh_receiver_presentation(lab: PitchBatLab, _force_visible: bool = false) -> void:
	# AY03 has the free empty receiver. Never auto-admit a replacement MatchState.
	if lab != null and lab._match_state == bound_state \
		and (not public_bound or StadiumNpcYardThreeRuntimeV1._binding_mode(lab, self, false)):
		refresh_actor_presentation(lab)
	else:
		restore_presentations()


func _process(_delta: float) -> void:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	refresh_receiver_presentation(lab)


func _exit_tree() -> void:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	if is_instance_valid(lab):
		StadiumNpcYardThreeRuntimeV1.unexpected_exit(lab, self)
	disconnect_balls()
	bound_state = null
	for node: Node in old_nodes:
		if is_instance_valid(node) and node.get_parent() == null:
			node.free()
	old_nodes.clear()
