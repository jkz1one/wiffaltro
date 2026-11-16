extends Node3D
## Solid lower/roof candidates. Hosting, upper states and venue activation remain gated.

var _failures: int = 0


func _ready() -> void:
	for site: String in StadiumBaselineSites.SITES:
		_check(StadiumBaselineSites.fits(site, "club", true)
			and not StadiumBaselineSites.fits(site, "expanded"), "explicit baseline property eligibility")
		var pose: Transform3D = StadiumBaselineSites.pose(site)
		_check(is_equal_approx(pose.basis.determinant(), 1)
			and pose.basis.get_scale().is_equal_approx(Vector3.ONE), "positive unit-scale handed bay")
	var lower: Node3D = StadiumBaselineStandModels.lower()
	add_child(lower)
	_bounds(lower, StadiumBaselineSites.LOWER_BOUNDS)
	_check(lower.get_meta("represented_seats") == 50,
		"represented bundled seats are not individual-seat grants or crowd income")
	var roof: Node3D = StadiumBaselineStandModels.lower_canopy()
	add_child(roof)
	_bounds(roof, StadiumBaselineSites.LOWER_ROOF_BOUNDS)
	_check(is_equal_approx(roof.get_node("Visual/RearColumn-1").position.y - 1.2, 6),
		"lower canopy columns start at the actual rear deck, not the superseded AV profile")
	_check(is_equal_approx(roof.get_node("Visual/RoofBeam-1").position.y - 0.09 - 6, 2.4),
		"authored roof underside clears the six-meter rear deck by 2.4 meters")
	for row in range(10):
		var step: MeshInstance3D = lower.get_node("Visual/SolidRow%d" % row)
		_check(is_equal_approx(step.position.y - step.mesh.size.y / 2, 0),
			"permanent row blocks have solid bases without repeated rectangular holes")
	_check(await StadiumAssetCapture.save(self,
		StadiumBaselineSites.LOWER_BOUNDS.merge(StadiumBaselineSites.LOWER_ROOF_BOUNDS),
		"ST-029-lower-roof", Vector3(1, 0.6, -1)), "native lower-plus-owned-roof candidate preview")
	roof.queue_free()
	await get_tree().process_frame
	_check(await StadiumAssetCapture.save(self, StadiumBaselineSites.LOWER_BOUNDS,
		"ST-029-lower", Vector3(1, 0.6, -1)), "native standalone finished lower bay preview")
	lower.queue_free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro baseline stand models passed: solid lower bay, access and host-specific roof.")
	get_tree().quit(0 if _failures == 0 else 1)


func _bounds(root: Node3D, bounds: AABB) -> void:
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var pose: Transform3D = root.global_transform.affine_inverse() * mesh.global_transform
		var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for vertex: Vector3 in vertices:
			_check(bounds.grow(0.0001).has_point(pose * vertex), "mesh/audience stays inside complete bound")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
