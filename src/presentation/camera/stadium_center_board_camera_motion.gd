class_name StadiumCenterBoardCameraMotion
extends BallInPlayCamera
## New candidate-only coverage selection; the ordinary bounded integrator is untouched.


func prepare(defense: bool, ball: Vector3, launch: Vector3) -> void:
	super.prepare(defense, ball, launch)
	# Generic air coverage crosses the launch corridor. At this raised center
	# board that can put the opposite mast/bearing between a defense camera and
	# the far shoulder. Choose the open launch-side corridor before moving;
	# acceleration, speed, turn, framing and exact LOS still use the usual update.
	if defense and launch.z > 0 and launch.y > 3 and absf(launch.x) > 1:
		_side = signf(launch.x)
