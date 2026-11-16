class_name StadiumLiveFurnishingWobble
extends Node3D
## Contact-driven presentation only. Its pivot and every physical body stay fixed.

const DURATION: float = 0.42
const MAX_ANGLE: float = 0.055
const MAX_SQUASH: float = 0.025

var _elapsed: float = DURATION
var _axis: Vector3 = Vector3.RIGHT


func _init() -> void:
	set_process(false)


func _ready() -> void:
	set_process(_elapsed < DURATION)


func react(local_hit: Vector3) -> void:
	if not local_hit.is_finite():
		return
	var radial: Vector3 = Vector3(local_hit.x, 0, local_hit.z)
	_axis = (
		Vector3.UP.cross(radial).normalized()
		if radial.length_squared() > 0.000001
		else Vector3.RIGHT
	)
	_elapsed = 0.0
	set_process(true)
	apply_elapsed(0.0)


func _process(delta: float) -> void:
	apply_elapsed(_elapsed + delta)


func apply_elapsed(seconds: float) -> void:
	if not is_finite(seconds):
		return
	_elapsed = clampf(seconds, 0.0, DURATION)
	var progress: float = _elapsed / DURATION
	if progress >= 1.0:
		basis = Basis.IDENTITY
		set_process(false)
		return
	var decay: float = (1.0 - progress) * (1.0 - progress)
	var wave: float = sin(progress * TAU)
	var compression: float = MAX_SQUASH * wave * wave * decay
	# Each singular scale is <= 1: all vertices remain inside the rest sphere.
	basis = (
		Basis(_axis, MAX_ANGLE * wave * decay)
		* Basis.from_scale(
			Vector3(1.0 - compression * 0.2, 1.0 - compression, 1.0 - compression * 0.2)
		)
	)
