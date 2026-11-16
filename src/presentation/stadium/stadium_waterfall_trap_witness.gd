class_name StadiumWaterfallTrapWitness
extends RefCounted
## Bounded, replayable physical-observation predicate, NOT an award authority.
## Production must bind observations to the current owned model, ball, play, native
## contact router and launch serial before calling this helper or consuming proof.
## Calibration is Working, not a finalized user balancing decision.
const Geometry = preload("res://src/presentation/stadium/stadium_waterfall_live_models.gd")
const VERSION: int = 1
const SPEED: float = 0.05
const TRAVEL: float = 0.005
const DWELL: float = 0.30
const MAX_GAP: float = 0.15
# Continuity only, never trap containment: bounded solver recovery on issued floor contact.
const FLOOR_CONTACT_RECOVERY: float = 0.015
const MAX_SAMPLES: int = 256
const EPS: float = 0.00001
const KEYS: Array[String] = [
	"copy",
	"serial",
	"frame",
	"time",
	"previous",
	"position",
	"velocity",
	"radius",
	"active",
	"contact"
]
var _samples: Array[Dictionary] = []
var _entry: Dictionary = {}
var _quiet_since: float = -1.0
var _quiet_travel: float = 0.0
var _proof: Dictionary = {}


func reset() -> void:
	_samples.clear()
	_entry.clear()
	_proof.clear()
	_quiet_since = -1.0
	_quiet_travel = 0.0


func observe(sample: Dictionary) -> Dictionary:
	if not _valid_sample(sample) or not sample.active:
		reset()
		return {}
	if not _samples.is_empty():
		var last: Dictionary = _samples.back()
		if (
			sample.copy != last.copy
			or sample.serial != last.serial
			or sample.radius != last.radius
			or sample.frame <= last.frame
			or sample.time <= last.time
			or sample.time - last.time > MAX_GAP + EPS
			or sample.previous.distance_to(last.position) > EPS
			or _samples.size() >= MAX_SAMPLES
		):
			reset()
			return {}  # A discontinuity cannot immediately re-arm from the same sample.
	if (
		not Geometry.basin_contains_local(sample.position, sample.radius)
		and not _floor_recovery(sample)
	):
		reset()
		return {}
	if _samples.is_empty():
		_entry = Geometry.trap_entry_local(sample.previous, sample.position, sample.radius)
		if _entry.is_empty() or sample.contact in ["impact", "floor_impact"]:
			reset()
			return {}
		_samples.append(sample.duplicate(true))
		return {}  # Witnessed admission is never itself a terminal result.
	return _observe_dwell(sample)


func _observe_dwell(sample: Dictionary) -> Dictionary:
	var last: Dictionary = _samples.back()
	var dt: float = sample.time - last.time
	var quiet: bool = (
		sample.contact not in ["impact", "floor_impact"]
		and Geometry.trap_contains_local(sample.position, sample.radius)
		and sample.velocity.length() <= SPEED + EPS
		and sample.position.distance_to(last.position) / dt <= SPEED + EPS
	)
	if not quiet:
		_quiet_since = -1.0
		_quiet_travel = 0.0
	elif _quiet_since < 0:
		_quiet_since = sample.time
		_quiet_travel = 0.0
	else:
		_quiet_travel += sample.position.distance_to(last.position)
		if _quiet_travel > TRAVEL + EPS:
			_quiet_since = sample.time
			_quiet_travel = 0.0
	_samples.append(sample.duplicate(true))
	_proof.clear()
	if not quiet or sample.time - _quiet_since + EPS < DWELL:
		return {}
	_proof = {
		"version": VERSION,
		"copy": sample.copy,
		"serial": sample.serial,
		"volume": Geometry.TRAP_ID,
		"entry": _entry.duplicate(true),
		"quiet_since": _quiet_since,
		"observed_at": sample.time,
		"frame": sample.frame,
		"position": sample.position,
		"radius": sample.radius,
		"samples": _samples.duplicate(true)
	}
	return _proof.duplicate(true)


static func replay(proof: Dictionary) -> bool:
	var expected: Array[String] = [
		"version",
		"copy",
		"serial",
		"volume",
		"entry",
		"quiet_since",
		"observed_at",
		"frame",
		"position",
		"radius",
		"samples"
	]
	if (
		not _exact_keys(proof, expected)
		or proof.version != VERSION
		or not proof.samples is Array
		or proof.samples.is_empty()
		or proof.samples.size() > MAX_SAMPLES
	):
		return false
	var witness: StadiumWaterfallTrapWitness = StadiumWaterfallTrapWitness.new()
	var rebuilt: Dictionary = {}
	for row: Variant in proof.samples:
		if not row is Dictionary:
			return false
		rebuilt = witness.observe(row)
	return not rebuilt.is_empty() and rebuilt == proof


static func support_contact(
	shape_name: String, point: Vector3, normal: Vector3, velocity: Vector3, radius: float
) -> bool:
	# Caller must supply a real current native contact, never a metadata marker.
	return (
		shape_name == "BasinFloor"
		and point.is_finite()
		and normal.is_finite()
		and velocity.is_finite()
		and absf(point.y - Geometry.basin_volume().position.y) <= Geometry.SUPPORT_TOLERANCE
		and normal.distance_to(Vector3.UP) <= 0.001
		and velocity.length() <= SPEED + EPS
		and Geometry.trap_contains_local(point + Vector3.UP * radius, radius)
	)


static func _floor_recovery(sample: Dictionary) -> bool:
	# Only a previously admitted ball with verified CURRENT native BasinFloor
	# contact may survive the brief solver penetration. No proof is emitted here.
	if sample.contact != "floor_impact":
		return false
	var volume: AABB = Geometry.basin_volume()
	var p: Vector3 = sample.position
	var r: float = sample.radius
	return (
		p.y >= volume.position.y + r - minf(FLOOR_CONTACT_RECOVERY, r * 0.5)
		and p.y < volume.position.y + r
		and p.x > volume.position.x + r + EPS
		and p.x < volume.end.x - r - EPS
		and p.z > volume.position.z + r + EPS
		and p.z < volume.end.z - r - EPS
	)


static func _valid_sample(sample: Dictionary) -> bool:
	if (
		not _exact_keys(sample, KEYS)
		or not sample.copy is String
		or sample.copy.is_empty()
		or not sample.serial is int
		or sample.serial <= 0
		or not sample.frame is int
		or sample.frame < 0
		or not sample.active is bool
		or not sample.contact is String
		or sample.contact not in ["none", "support", "impact", "floor_impact"]
	):
		return false
	for field: String in ["previous", "position", "velocity"]:
		if not sample[field] is Vector3 or not sample[field].is_finite():
			return false
	for field: String in ["time", "radius"]:
		if (
			not (sample[field] is float or sample[field] is int)
			or not is_finite(float(sample[field]))
		):
			return false
	return sample.time >= 0 and sample.radius > EPS


static func _exact_keys(value: Dictionary, keys: Array[String]) -> bool:
	if value.size() != keys.size():
		return false
	for key: String in keys:
		if not value.has(key):
			return false
	return true
