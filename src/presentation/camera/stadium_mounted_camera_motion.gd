class_name StadiumMountedCameraMotion
extends BallInPlayCamera
## Exact raised-center coverage choice; the existing bounded integrator is unchanged.


func prepare(defense: bool, ball: Vector3, launch: Vector3) -> void:
	super.prepare(defense, ball, launch)
	if defense and launch.z > 0 and launch.y > 3 and absf(launch.x) > 1:
		_side = signf(launch.x)
