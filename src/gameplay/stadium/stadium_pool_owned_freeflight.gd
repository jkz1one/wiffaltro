class_name StadiumPoolOwnedFreeflight
extends RefCounted
## Pose-normalized reuse of the audited chronological subset, never an alternate trajectory.
## Only exact half-meter translations and signed-permutation quarter turns are supported.


static func supported_pose(pose: Transform3D) -> bool:
	if not pose.is_finite() or pose.origin.y != 0.0:
		return false
	if not StadiumPoolControllerActive.FreeflightEntry.bounded_point(pose.origin):
		return false
	if pose.origin.x * 2 != roundf(pose.origin.x * 2):
		return false
	if pose.origin.z * 2 != roundf(pose.origin.z * 2):
		return false
	return pose.basis in [
		Basis.IDENTITY,
		Basis(Vector3(0, 0, -1), Vector3.UP, Vector3(1, 0, 0)),
		Basis(Vector3(-1, 0, 0), Vector3.UP, Vector3(0, 0, -1)),
		Basis(Vector3(0, 0, 1), Vector3.UP, Vector3(-1, 0, 0))
	]


static func normalized(pose: Transform3D, world: Vector3) -> Vector3:
	# Exact signed permutation: no trigonometric basis or tolerance-expanded geometry.
	var local: Vector3 = pose.basis.transposed() * (world - pose.origin)
	return Vector3(float(local.x) + 12.0, local.y, float(local.z) + 18.0)


static func path_clear(
	pose: Transform3D, previous: Vector3, current: Vector3, radius: float
) -> bool:
	return (
		supported_pose(pose)
		and StadiumPoolControllerActive.FreeflightEntry.bounded_point(previous)
		and StadiumPoolControllerActive.FreeflightEntry.bounded_point(current)
		and StadiumPoolControllerActive.FreeflightEntry.path_clear(
			normalized(pose, previous), normalized(pose, current), radius
		)
	)


static func evaluate(
	pose: Transform3D, previous: Vector3, current: Vector3, radius: float
) -> Dictionary:
	if not path_clear(pose, previous, current, radius):
		return StadiumPoolControllerActive.FreeflightEntry.declined("OWNED_POSE_OR_PATH_UNPROVEN")
	var entry: Dictionary = StadiumPoolControllerActive.FreeflightEntry.evaluate(
		normalized(pose, previous), normalized(pose, current), radius
	)
	if entry.status != "ENTRY":
		return entry
	# Fraction is chronological on the real world segment, not a transformed endpoint award.
	var witness: Vector3 = StadiumPoolControllerActive.FreeflightEntry.point_at(
		previous, current, entry.fraction
	)
	var local: Vector3 = pose.basis.transposed() * (witness - pose.origin)
	var sample: Dictionary = StadiumPoolInteriorV2.sample_local(local, radius)
	if (
		not StadiumPoolControllerActive.FreeflightEntry.bounded_point(witness)
		or not StadiumPoolControllerActive.FreeflightEntry.interior_clear(
			normalized(pose, witness), radius
		)
		or not sample.valid
		or not sample.positive_overlap
		or witness.y <= current.y
		or witness.y >= StadiumPoolContract.WATER_HEIGHT + radius
	):
		return StadiumPoolControllerActive.FreeflightEntry.declined("OWNED_WORLD_WITNESS_UNPROVEN")
	entry["position"] = witness
	entry["owned_pose"] = pose
	return entry
