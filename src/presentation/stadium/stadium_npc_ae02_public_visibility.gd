class_name StadiumNpcAe02PublicVisibility
extends StadiumNpcRetainedVisibility
## Authored current-side target projection over unchanged shared visibility and live integration.
## Issued authority replaces per-frame source hashing and private-candidate geometry gates.

const SIDES: Array[String] = ["SIDE-R-01", "SIDE-L-01"]
var _sides: Array[Dictionary] = []
var _boundary: StadiumNpcExpandedBoundaryV1


func configure_property(value: StadiumNpcRetainedProperty) -> void:
	super.configure_property(value)
	_sides.clear()
	_boundary = null
	if not value is StadiumNpcPublicProperty or value.venue_id != "AE-02" \
		or not value.boundary is StadiumNpcExpandedBoundaryV1:
		return
	_boundary = value.boundary
	for identity: String in SIDES:
		var row: Dictionary = _boundary.graph.segment(identity)
		var a: Vector2 = Vector2(8, -6) if identity == "SIDE-R-01" else Vector2(-24, 23.4)
		var b: Vector2 = Vector2(24, 23.4) if identity == "SIDE-R-01" else Vector2(-8, -6)
		if row.get("a") != a or row.get("b") != b \
			or row.get("role") != "SIDE_RETURN_LIVE" or row.get("height") != 1.2:
			_sides.clear()
			return
		_sides.append({"id": identity, "a": a, "b": b,
			"normal": StadiumRecipeBoundary.inward(row),
			"body": _boundary.get_node_or_null(NodePath(identity))})


func clear_position(desired: Vector3, ball: Vector3) -> Vector3:
	return super.clear_position(constrain_target(desired), ball)


func constrain_target(desired: Vector3) -> Vector3:
	if not active():
		return desired
	# Same right-then-left half-plane projection; no live teleport or integrator change.
	var result: Vector3 = desired
	for row: Dictionary in _sides:
		var normal: Vector2 = row.normal
		var gap: float = (Vector2(result.x, result.z) - row.a).dot(normal)
		if gap < WALL_CAMERA_CLEARANCE:
			var offset: Vector2 = normal * (WALL_CAMERA_CLEARANCE - gap)
			result.x += offset.x
			result.z += offset.y
	return result


func active() -> bool:
	var owner: StadiumNpcPublicProperty = property as StadiumNpcPublicProperty
	var lab: PitchBatLab = owner.lab_ref.get_ref() as PitchBatLab if owner != null \
		and owner.lab_ref != null else null
	var director: StadiumNpcAe02PublicCamera = lab._camera_director \
		as StadiumNpcAe02PublicCamera if lab != null else null
	if owner == null or director == null or director.bound_property() != owner:
		return false
	var coverage: BallInPlayCamera = director._live_coverage
	return lab._match_state != null and lab._ball_play_resolver != null \
		and not lab.get_tree().paused and director.tracking_visibility == self \
		and director.shot == MatchCameraDirector.Shot.BALL_IN_PLAY \
		and director._shot_before_inspection < 0 and coverage != null \
		and coverage.get_script() == StadiumNpcAe02PublicCamera.COVERAGE \
		and not coverage._defense and not lab._player_is_pitching() \
		and is_instance_valid(lab._batted_ball) and lab._batted_ball.get_parent() == lab \
		and lab._match_state.phase == MatchState.Phase.BALL_IN_PLAY \
		and lab._ball_play_resolver.state != null and not lab._ball_play_resolver.state.dead \
		and owners_intact()


func owners_intact() -> bool:
	if property == null or property.venue_id != "AE-02" or _sides.size() != 2 \
		or not is_instance_valid(_boundary) or property.boundary != _boundary \
		or _boundary.get_script() != StadiumNpcExpandedBoundaryV1 \
		or _boundary.get_parent() != property.construction:
		return false
	for index in range(2):
		var row: Dictionary = _sides[index]
		var a: Vector2 = Vector2(8, -6) if index == 0 else Vector2(-24, 23.4)
		var b: Vector2 = Vector2(24, 23.4) if index == 0 else Vector2(-8, -6)
		var current: Dictionary = {"a": a, "b": b}
		if row.id != SIDES[index] or row.a != current.a or row.b != current.b \
			or row.normal != StadiumRecipeBoundary.inward(current) \
			or not is_instance_valid(row.body) \
			or _boundary.get_node_or_null(NodePath(row.id)) != row.body:
			return false
	return true


func side_state() -> Array:
	return [_boundary, _sides.duplicate(true)]


func canonical_side_state() -> Array:
	var result: Array = []
	for row: Dictionary in _sides:
		result.append([row.id, row.a, row.b, row.normal])
	return result


func geometry_intact() -> bool:
	return owners_intact()
