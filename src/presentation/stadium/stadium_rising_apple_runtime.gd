class_name StadiumRisingAppleRuntime
extends Node
## Exact paid apple presentation. The existing home-run clock owns all elapsed time.

enum Phase { IDLE, RISING, HOLDING, LOWERING, RETIRED }
const NODE: String = "RisingAppleRuntime"
var phase: Phase = Phase.IDLE
var accepted_events: int = 0
var last_play: BallPlayState
var _lab: WeakRef
var _property: StadiumPropertyGeometry
var _model: Node3D
var _moving: Node3D
var _copy: String
var _state: MatchState
var _paid: ClubAssetLedger
var _generation: int
var _paid_state: String
var _titles: Dictionary
var _snapshot: Dictionary
var _resolver: BallPlayResolver
var _clock: PitchBatLabHomeRun
var _seal: Dictionary
var _pose_row: Dictionary
var _pose_index: int = -1
var _visibility_index: int = -1
var _height: float = 0.0
var _writing: bool = false


static func required(lab: PitchBatLab) -> bool:
	return lab._match_state != null and _rows(lab._match_state.stadium).size() == 1


static func current(lab: PitchBatLab) -> StadiumRisingAppleRuntime:
	if not is_instance_valid(lab) or not lab.has_meta("stadium_property"):
		return null
	var property: Variant = lab.get_meta("stadium_property")
	if not is_instance_valid(property) or not property is StadiumPropertyGeometry:
		return null
	return property.get_node_or_null(NODE) as StadiumRisingAppleRuntime


static func install(lab: PitchBatLab, property: StadiumPropertyGeometry) -> bool:
	if not required(lab):
		return true
	if current(lab) != null or property.has_node(NODE):
		return false
	var rows: Array = _rows(lab._match_state.stadium)
	var model: Node3D = property.objects.get(rows[0].copy)
	if (
		not is_instance_valid(model)
		or model.get_meta("stadium_item", "") != "ST-047"
		or not property.props_intact()
		or not StadiumLayoutSnapshot.matches(lab._match_state.stadium, lab._stadium_ledger)
	):
		return false
	var owner: StadiumRisingAppleRuntime = StadiumRisingAppleRuntime.new()
	owner.name = NODE
	owner._lab = weakref(lab)
	owner._property = property
	owner._model = model
	owner._moving = model.get_node("RisingAssembly")
	owner._copy = rows[0].copy
	owner._state = lab._match_state
	owner._snapshot = owner._state.stadium.duplicate(true)
	owner._paid = lab._stadium_ledger
	owner._generation = owner._paid.mutation_generation()
	owner._paid_state = StadiumSurfaceNightRuntime._ledger_state(owner._paid)
	owner._titles = owner._paid._championships.duplicate(true)
	owner._resolver = lab._ball_play_resolver
	owner._clock = lab._home_run
	for seal: Dictionary in property._infrastructure:
		if seal.root == model:
			owner._seal = seal
			for row: Dictionary in seal.rows:
				if row.node == owner._moving:
					owner._pose_row = row
					owner._pose_index = row.fields.find(&"transform")
					owner._visibility_index = row.fields.find(&"visible")
	if (
		owner._pose_row.is_empty()
		or owner._pose_index < 0
		or owner._visibility_index < 0
		or owner._moving.transform != Transform3D.IDENTITY
		or owner._moving.visible
		or owner._resolver == null
		or owner._resolver.get_script() != BallPlayResolver
		or owner._clock == null
		or owner._clock.get_script() != PitchBatLabHomeRun
		or not StadiumMountedPresentationContract._scorer_ready(lab)
	):
		owner.free()
		return false
	property.add_child(owner)
	owner._resolver.play_resolved.connect(owner._on_resolved)
	if not owner.intact():
		owner.retire()
		return false
	return true


static func before_pitch(lab: PitchBatLab) -> bool:
	var owner: StadiumRisingAppleRuntime = current(lab)
	if owner == null:
		return not required(lab)
	return owner._reset_owned()


static func cleanup_current(lab: PitchBatLab) -> void:
	var owner: StadiumRisingAppleRuntime = current(lab)
	if owner != null:
		owner._reset_owned()


static func sync_clock(lab: PitchBatLab, clock: PitchBatLabHomeRun) -> void:
	var owner: StadiumRisingAppleRuntime = current(lab)
	if owner != null:
		owner._sync(clock)


func height() -> float:
	return _height


func intact() -> bool:
	if (
		get_script() != StadiumRisingAppleRuntime
		or phase == Phase.RETIRED
		or _lab == null
		or not is_inside_tree()
		or not is_instance_valid(_property)
		or not _property.is_inside_tree()
		or get_parent() != _property
		or _property.get_node_or_null(NODE) != self
	):
		return false
	var lab: PitchBatLab = _lab.get_ref() as PitchBatLab
	return (
		is_instance_valid(lab)
		and lab.get_script() == PitchBatLab
		and lab.is_inside_tree()
		and lab.has_meta("stadium_property")
		and lab.get_meta("stadium_property") == _property
		and lab._match_state == _state
		and _state.get_script() == MatchState
		and ClubCareer.same(_state.stadium, _snapshot)
		and lab._stadium_ledger == _paid
		and _paid != null
		and _paid.mutation_generation() == _generation
		and StadiumSurfaceNightRuntime._ledger_state(_paid) == _paid_state
		and ClubCareer.same(_paid._championships, _titles)
		and lab._ball_play_resolver == _resolver
		and _resolver.get_script() == BallPlayResolver
		and lab._home_run == _clock
		and _clock.get_script() == PitchBatLabHomeRun
		and _listeners_intact(lab)
		and is_instance_valid(_model)
		and _property.objects.get(_copy) == _model
		and _model.get_parent() == _property
		and _model.get_node_or_null("RisingAssembly") == _moving
		and _property._infrastructure.has(_seal)
		and _seal.rows.has(_pose_row)
		and _pose_row.values[_pose_index] == Transform3D(Basis.IDENTITY, Vector3(0, _height, 0))
		and _pose_row.values[_visibility_index] == (_height > 0.0)
		and _property.props_intact()
	)


func _listeners_intact(lab: PitchBatLab) -> bool:
	# Same direct scorer-before-presentation contract used by mounted celebrations.
	var expected: Array[Callable] = [lab._on_ball_play_resolved, _on_resolved]
	var index: int = 0
	for row: Dictionary in _resolver.play_resolved.get_connections():
		var callback: Callable = row.callable
		if callback.get_object_id() != get_instance_id() and callback != lab._on_ball_play_resolved:
			continue
		if index >= expected.size() or callback != expected[index] or row.flags != 0:
			return false
		index += 1
	return index == expected.size()


func _on_resolved(outcome: BallPlayOutcome) -> void:
	if not intact():
		retire()
		return
	var lab: PitchBatLab = _lab.get_ref() as PitchBatLab
	var play: BallPlayState = _resolver.state
	if play == last_play:
		return
	if (
		outcome == null
		or outcome.get_script() != BallPlayOutcome
		or outcome.result != BallPlayOutcome.Result.HOME_RUN
	):
		return
	if (
		play == null
		or play.get_script() != BallPlayState
		or not play.dead
		or not play.is_fair
		or play.is_foul_play
		or play.result_floor != BallPlayState.ResultFloor.HOME_RUN
		or _property._props_play != play
		or _property._props_resolver != _resolver
		or _property._props_ball == null
		or _property._props_ball.get_ref() != lab._batted_ball
		or not is_instance_valid(lab._batted_ball)
		or lab._batted_ball.get_script() != BattedBallBody
		or not _clock.active
		or _clock.elapsed != 0.0
	):
		return
	if (
		lab._match_mode
		and (
			_state.phase
			not in [
				MatchState.Phase.PLAY_DEAD,
				MatchState.Phase.INNING_TRANSITION,
				MatchState.Phase.GAME_END
			]
		)
	):
		return  # The ordinary scorer must have completed its state transition.
	last_play = play
	accepted_events += 1
	phase = Phase.RISING
	_set_height(0.0)


func _sync(clock: PitchBatLabHomeRun) -> void:
	if not intact() or clock != _clock:
		retire()
		return
	var lab: PitchBatLab = _lab.get_ref() as PitchBatLab
	if lab._debug_paused or lab.get_tree().paused:
		return
	if last_play == null or not clock.active:
		_reset_owned()
		return
	if (
		_resolver.state != last_play
		or not last_play.dead
		or last_play.result_floor != BallPlayState.ResultFloor.HOME_RUN
	):
		retire()
		return
	var progress: float = clampf(clock.elapsed / PitchBatLabHomeRun.HOLD_SECONDS, 0.0, 1.0)
	var amount: float = 1.0
	if progress < 0.25:
		phase = Phase.RISING
		amount = progress / 0.25
	elif progress < 0.75:
		phase = Phase.HOLDING
	else:
		phase = Phase.LOWERING
		amount = (1.0 - progress) / 0.25
	_set_height(StadiumRisingAppleModels.MAX_RISE * amount)


func _set_height(value: float) -> bool:
	if (
		_writing
		or not is_finite(value)
		or value < 0
		or value > StadiumRisingAppleModels.MAX_RISE
		or not intact()
	):
		retire()
		return false
	var next: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0, value, 0))
	# Native Vector3 storage is authoritative. Only this pose and its reset visibility
	# are authorized; materials, collision layers/shapes and every other field stay sealed.
	_height = next.origin.y
	_pose_row.values[_pose_index] = next
	_pose_row.values[_visibility_index] = _height > 0.0
	_writing = true
	var written: bool = StadiumRisingAppleModels.set_rise(_model, value)
	_writing = false
	if not written or not intact():
		retire()
		return false
	return true


func _reset_owned() -> bool:
	if not _set_height(0.0):
		return false
	phase = Phase.IDLE
	return true


func retire() -> void:
	phase = Phase.RETIRED
	if is_instance_valid(_property):
		_property._retire_props()
	# A foreign pose/resource is never overwritten to manufacture a reset.


func _exit_tree() -> void:
	phase = Phase.RETIRED
	if is_instance_valid(_resolver) and _resolver.play_resolved.is_connected(_on_resolved):
		_resolver.play_resolved.disconnect(_on_resolved)
	_lab = null


static func _rows(snapshot: Dictionary) -> Array:
	var layout: Dictionary = snapshot.get("layout", {})
	if StadiumWaterfallAnimationLayout.is_family(layout):
		layout = StadiumWaterfallAnimationLayout.presentation_base(layout)
	var result: Array = layout.get("rising_apple", []).duplicate(true)
	if not (
		StadiumOutfieldPlazaItems.is_family(layout)
		or StadiumWaterfallLiveItems.is_family(layout)
		or StadiumLowWallLayout.is_family(layout)
	):
		return result
	var stock: StadiumStock = StadiumLayoutSnapshot.ownership(snapshot)
	if stock == null:
		return result
	for kit: Dictionary in layout.get("outfield_plaza", []):
		for child: Dictionary in kit.occupants:
			if stock.copies.has(child.copy) and stock.copies[child.copy].item == "ST-047":
				result.append(child.duplicate(true))
	return result
