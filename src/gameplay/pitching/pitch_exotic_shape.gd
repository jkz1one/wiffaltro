class_name PitchExoticShape
extends RefCounted
## Explicit project-fiction transverse forces, never real MLB/league aerodynamics.
## Uses current depth/speed only. No future target-error steering or position snap.


static func acceleration(
	position_z: float, velocity: Vector3, parameters: PitchLaunchParameters
) -> Vector3:
	if parameters.exotic_shape.is_empty() or parameters.exotic_strength <= 0.0:
		return Vector3.ZERO
	var distance: float = maxf(0.001, parameters.release_z - parameters.target_z)
	var progress: float = clampf((parameters.release_z - position_z) / distance, 0.0, 1.0)
	var force: Vector3 = Vector3.ZERO
	match parameters.exotic_shape:
		&"switchback":
			# Early arm-side acceleration yields to a stronger late glove-side pull.
			# The aimed trajectory must show one lateral-velocity reversal, not flutter.
			force.x = 4.8 * (1.0 - smoothstep(0.25, 0.50, progress))
			force.x -= 26.0 * smoothstep(0.40, 0.62, progress)
		&"corkscrew":
			# One smooth extra-motion revolution in p=.10..80; phase derivatives
			# vanish at both ends, leaving a readable settling approach.
			var t: float = clampf((progress - 0.10) / 0.70, 0.0, 1.0)
			var phase: float = TAU * (6.0 * pow(t, 5) - 15.0 * pow(t, 4) + 10.0 * pow(t, 3))
			var phase_first: float = TAU * 30.0 * t * t * (1.0 - t) * (1.0 - t) / 0.70
			var phase_second: float = TAU * (60.0 * t - 180.0 * t * t + 120.0 * t * t * t) / 0.49
			var rate: float = absf(velocity.z) / distance
			var radius: float = 0.55
			force = radius * rate * rate * Vector3(
				-sin(phase) * phase_first * phase_first + cos(phase) * phase_second,
				cos(phase) * phase_first * phase_first + sin(phase) * phase_second, 0.0)
		&"trapdoor":
			# Smooth delayed dive, later than ordinary Splitter/Forkball envelopes.
			force.y = -45.0 * smoothstep(0.64, 0.82, progress)
		_:
			return Vector3.ZERO
	force.x *= -1.0 if parameters.is_left_handed else 1.0
	return force * parameters.exotic_strength * parameters.mastery_movement_scale * (
		1.0 + parameters.mastery_late_bias * (2.0 * progress - 1.0))
