class_name StadiumYardTwoTrackingVisibility
extends StadiumYardFieldVisibility
## Candidate-only desired target policy; inherited visibility and motion remain unchanged.

var lab_ref: WeakRef
var motion_ref: WeakRef


func clear_position(desired: Vector3, ball: Vector3) -> Vector3:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	var motion: StadiumYardTwoCameraMotion = (
		motion_ref.get_ref() as StadiumYardTwoCameraMotion if motion_ref != null else null
	)
	if (
		lab != null
		and motion != null
		and lab._camera_director != null
		and lab._camera_director.tracking_visibility == self
		and lab._camera_director._live_coverage == motion
		and lab._camera_director.shot == MatchCameraDirector.Shot.BALL_IN_PLAY
		and lab._camera_director._shot_before_inspection < 0
	):
		desired = motion.constrain_target(desired)
	return super.clear_position(desired, ball)
