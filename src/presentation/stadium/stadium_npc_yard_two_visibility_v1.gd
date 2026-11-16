class_name StadiumNpcYardTwoVisibilityV1
extends BallTrackingVisibility
## Candidate-only desired target policy; inherited visibility and motion remain unchanged.

var property_ref: WeakRef
var lab_ref: WeakRef
var motion_ref: WeakRef


func clear_position(desired: Vector3, ball: Vector3) -> Vector3:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	var motion: StadiumNpcYardTwoCameraMotionV1 = (
		motion_ref.get_ref() as StadiumNpcYardTwoCameraMotionV1 if motion_ref != null else null
	)
	if (
		lab != null
		and motion != null
		and property_ref != null and property_ref.get_ref() != null
		and property_ref.get_ref().visibility == self
		and property_ref.get_ref().callback_intact()
		and motion.property_ref != null
		and motion.property_ref.get_ref() == property_ref.get_ref()
		and lab._camera_director != null
		and lab._camera_director.tracking_visibility == self
		and lab._camera_director._live_coverage == motion
		and lab._camera_director.shot == MatchCameraDirector.Shot.BALL_IN_PLAY
		and lab._camera_director._shot_before_inspection < 0
	):
		desired = motion.constrain_target(desired)
	return super.clear_position(desired, ball)


class RetainedView extends StadiumRecipeBoundary:
	## Presentation adapter only; the template's physics, dimensions and identity remain unchanged.
	func polygon() -> PackedVector2Array:
		return PackedVector2Array(StadiumNpcYardGraphV1.VERTICES)

	func segments() -> Array[Dictionary]:
		return StadiumNpcYardGraphV1.segments()

	func outer_vertex(index: int) -> Vector2:
		return StadiumNpcYardGraphV1.outer_vertex(index)

	func identity() -> String:
		return StadiumNpcYardGraphV1.ID


func configure(geometry: Node) -> void:
	super.configure(geometry)
	var property: StadiumNpcYardTwoPropertyV1 = (
		property_ref.get_ref() as StadiumNpcYardTwoPropertyV1 if property_ref != null else null)
	if property == null or not property.is_inside_tree() \
		or property.get_parent() != geometry or property.visibility != self \
		or not property.boundary is StadiumNpcYardBoundaryV1 \
		or property.boundary.get_parent() != property.construction:
		return
	_obstacles.clear()
	_uprights.clear()
	_wall_bounds.clear()
	_recipe = RetainedView.new()
	_wall_prisms = StadiumWallViewPrisms.new(_recipe)
	for model: Node3D in property.objects.values():
		_collect(model.get_node("Visual"), false)
