class_name BattedBallLaunch
extends RefCounted

var position: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
var angular_velocity: Vector3 = Vector3.ZERO
var orientation: Quaternion = Quaternion.IDENTITY
var contact_quality: float = 0.0
var is_foul: bool = false


static func from_contact(result: ContactResult, pitch_state: PitchState = null) -> BattedBallLaunch:
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = result.contact_position
	launch.velocity = result.exit_velocity
	launch.angular_velocity = Vector3(
		-result.backspin_rad_s,
		-result.spray_degrees * 0.62,
		result.horizontal_error_m * 38.0
	)
	if pitch_state != null:
		# Preserve the physical ball's hole orientation at contact so similarly
		# struck balls can still carry or fade differently by incoming Pitch.
		launch.orientation = pitch_state.orientation
	launch.contact_quality = result.quality
	launch.is_foul = result.outcome == ContactResult.Outcome.FOUL
	return launch
