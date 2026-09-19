class_name BattedBallLaunch
extends RefCounted

var position: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
var angular_velocity: Vector3 = Vector3.ZERO
var orientation: Quaternion = Quaternion.IDENTITY
var contact_quality: float = 0.0

static func from_contact(result: ContactResult) -> BattedBallLaunch:
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = result.contact_position
	launch.velocity = result.exit_velocity
	launch.angular_velocity = Vector3(
		-result.backspin_rad_s,
		0.0,
		0.0
	)
	launch.contact_quality = result.quality
	return launch
