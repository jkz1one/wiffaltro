class_name StadiumWaterfallAnimationRuntime
extends Node
## Exact paid47 presentation clock. No wall-clock shader, scoring, collision or Night authority.
const NODE: String = "OwnedWaterfallAnimation"
const UPDATE_SECONDS: float = 0.1
var retired: bool = false
var _lab: WeakRef
var _property: StadiumPropertyGeometry
var _lease: StadiumWaterfallAnimationLease
var _state: MatchState
var _paid: ClubAssetLedger
var _generation: int
var _paid_state: String
var _titles: Dictionary
var _snapshot_ref: Dictionary
var _snapshot: Dictionary
var _pitch: PitchFlightActor
var _resolver: BallPlayResolver
var _release: PitchReleaseController
var _cadence: AtBatCadenceController
var _pending: float = 0.0


static func property_claim(lab: PitchBatLab) -> Node:
	if not is_instance_valid(lab) or not lab.has_meta("stadium_property"):
		return null
	var claim: Variant = lab.get_meta("stadium_property")
	return claim if claim is Node and is_instance_valid(claim) else null


static func claim_matches(lab: PitchBatLab, property: Node) -> bool:
	return is_instance_valid(property) and is_same(property_claim(lab), property)


static func current(lab: PitchBatLab) -> StadiumWaterfallAnimationRuntime:
	var property: Node = property_claim(lab)
	if property == null:
		return null
	var owner: StadiumWaterfallAnimationRuntime = (
		property.get_node_or_null(NODE) as StadiumWaterfallAnimationRuntime
	)
	return (
		owner
		if (
			owner != null
			and owner._lab != null
			and is_same(owner._lab.get_ref(), lab)
			and is_same(owner._property, property)
		)
		else null
	)


static func required(lab: PitchBatLab) -> bool:
	if (
		not is_instance_valid(lab)
		or lab._match_state == null
		or not StadiumWaterfallAnimationSnapshot.is_family(lab._match_state.stadium)
	):
		return false
	var layout: Variant = lab._match_state.stadium.get("layout")
	return (
		layout is Dictionary
		and layout.get("waterfall_motion") is Array
		and not layout.waterfall_motion.is_empty()
	)


static func install(lab: PitchBatLab, property: StadiumPropertyGeometry) -> bool:
	if not required(lab):
		return true
	if (
		current(lab) != null
		or property.has_node(NODE)
		or property.get_script() != StadiumWaterfallAnimationProperty
		or not property.props_intact()
		or not StadiumWaterfallAnimationSnapshot.matches(
			lab._match_state.stadium, lab._stadium_ledger
		)
		or property._waterfall_animation == null
	):
		return false
	var owner: StadiumWaterfallAnimationRuntime = StadiumWaterfallAnimationRuntime.new()
	owner.name = NODE
	owner._lab = weakref(lab)
	owner._property = property
	owner._lease = property._waterfall_animation
	owner._state = lab._match_state
	owner._snapshot_ref = owner._state.stadium
	owner._snapshot = owner._state.stadium.duplicate(true)
	owner._paid = lab._stadium_ledger
	owner._generation = owner._paid.mutation_generation()
	owner._paid_state = (property as StadiumWaterfallAnimationProperty)._context_paid_state
	owner._titles = (property as StadiumWaterfallAnimationProperty)._context_titles.duplicate(true)
	owner._pitch = lab._pitch_actor
	owner._resolver = lab._ball_play_resolver
	owner._release = lab._release_controller
	owner._cadence = lab._at_bat_cadence
	property.add_child(owner)
	if not owner._lease.bind_runtime(owner) or not owner.intact():
		owner.retire()
		return false
	return true


func intact() -> bool:
	if (
		retired
		or get_script() != StadiumWaterfallAnimationRuntime
		or _lab == null
		or not is_inside_tree()
		or not is_instance_valid(_property)
		or _property.get_script() != StadiumWaterfallAnimationProperty
		or not _property.is_inside_tree()
		or get_parent() != _property
		or _property.get_node_or_null(NODE) != self
		or _lease != _property._waterfall_animation
		or _lease == null
		or not _lease._runtime_bound
		or not is_same(_lease.runtime_owner(), self)
		or not _lease.presentation_intact()
	):
		return false
	var lab: PitchBatLab = _lab.get_ref() as PitchBatLab
	return (
		is_instance_valid(lab)
		and lab.get_script() == PitchBatLab
		and lab.is_inside_tree()
		and claim_matches(lab, _property)
		and lab._match_state == _state
		and _state != null
		and _state.get_script() == MatchState
		and ClubCareer.same(_state.stadium, _snapshot)
		and lab._stadium_ledger == _paid
		and _paid != null
		and _paid.get_script() == ClubAssetLedger
		and _paid.mutation_generation() == _generation
		and StadiumSurfaceNightRuntime._ledger_state(_paid) == _paid_state
		and ClubCareer.same(_paid._championships, _titles)
		and _property._waterfall_animation_copies == _snapshot.layout.waterfall_motion
		and lab._pitch_actor == _pitch
		and is_instance_valid(_pitch)
		and _pitch.get_script() == PitchFlightActor
		and lab._ball_play_resolver == _resolver
		and _resolver != null
		and _resolver.get_script() == BallPlayResolver
		and lab._release_controller == _release
		and lab._at_bat_cadence == _cadence
	)


func actionable() -> bool:
	var lab: PitchBatLab = _lab.get_ref() as PitchBatLab
	if not is_instance_valid(lab):
		return true
	# Freeze all pre-pitch aiming/delivery as well as pitch and batted-ball flight.
	return (
		(
			_state.phase
			in [
				MatchState.Phase.PRE_PITCH,
				MatchState.Phase.PITCH_IN_FLIGHT,
				MatchState.Phase.BALL_IN_PLAY
			]
		)
		or _pitch.running
		or (_release != null and _release.active)
		or (_cadence != null and _cadence.state != AtBatCadenceController.State.IDLE)
		or (
			is_instance_valid(lab._batted_ball)
			and _resolver.state != null
			and not _resolver.state.dead
		)
	)


func _binding_intact() -> bool:
	if (
		retired
		or get_script() != StadiumWaterfallAnimationRuntime
		or _lab == null
		or not is_inside_tree()
		or not is_instance_valid(_property)
		or get_parent() != _property
		or _property.get_node_or_null(NODE) != self
		or _property._waterfall_animation != _lease
	):
		return false
	var lab: PitchBatLab = _lab.get_ref() as PitchBatLab
	return (
		is_instance_valid(lab)
		and lab.get_script() == PitchBatLab
		and lab.is_inside_tree()
		and claim_matches(lab, _property)
		and lab._match_state == _state
		and _state != null
		and is_same(_state.stadium, _snapshot_ref)
		and lab._stadium_ledger == _paid
		and _paid != null
		and _paid.mutation_generation() == _generation
		and lab._pitch_actor == _pitch
		and is_instance_valid(_pitch)
		and lab._ball_play_resolver == _resolver
		and lab._release_controller == _release
		and lab._at_bat_cadence == _cadence
		and _issued_binding_intact(lab)
	)


func _issued_binding_intact(lab: PitchBatLab) -> bool:
	var property: StadiumWaterfallAnimationProperty = _property as StadiumWaterfallAnimationProperty
	return (
		property != null
		and (
			property.issued_props_intact(lab)
			if property._issued_ever
			else property.motion_context_intact(false)
		)
	)


func _process(delta: float) -> void:
	if not is_finite(delta) or delta < 0 or not _binding_intact():
		retire()
		return
	var lab: PitchBatLab = _lab.get_ref() as PitchBatLab
	if delta > 0.25 or lab._debug_paused or get_tree().paused or actionable():
		_pending = 0.0
		return
	_pending += delta
	if _pending < UPDATE_SECONDS:
		return
	var step: float = _pending
	_pending = 0.0
	if not _lease.advance(step, false, false):
		retire()


static func before_pitch(lab: PitchBatLab) -> bool:
	var property: Node = property_claim(lab)
	var observer: Object = (
		lab._ball_play_resolver.segment_observer.get_object()
		if (
			is_instance_valid(lab)
			and lab._ball_play_resolver != null
			and lab._ball_play_resolver.segment_observer.is_valid()
		)
		else null
	)
	var issued47: bool = (
		StadiumWaterfallAnimationInstall.requested(lab)
		or (is_instance_valid(lab) and lab.has_meta(StadiumWaterfallAnimationInstall.BOUND))
		or property is StadiumWaterfallAnimationProperty
		or observer is StadiumWaterfallAnimationBoundary
		or observer is StadiumWaterfallAnimationLowBoundary
	)
	# Empty motion selections still own a47 property and need the same deep
	# pre-pitch proof even though no presentation clock is legitimately installed.
	if (
		issued47
		and (
			not property is StadiumWaterfallAnimationProperty
			or property.get_script() != StadiumWaterfallAnimationProperty
			or not (property as StadiumWaterfallAnimationProperty).deep_props_intact()
		)
	):
		var failed: StadiumWaterfallAnimationRuntime = current(lab)
		if failed != null:
			failed.retire()
		return false
	var owner: StadiumWaterfallAnimationRuntime = current(lab)
	if owner == null:
		return not required(lab)
	owner._pending = 0.0
	if (
		not owner.intact()
		or not (owner._property as StadiumWaterfallAnimationProperty).deep_props_intact()
	):
		owner.retire()
		return false
	return true


func retire() -> void:
	retired = true
	_pending = 0.0
	set_process(false)
	if _lease != null:
		_lease.retire()


func _exit_tree() -> void:
	retired = true
	_pending = 0.0
	_lab = null
