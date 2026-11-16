extends RefCounted
## Unchanged historical11x11 metric with reversible whole-lab and real-physics witnesses.

const Freeze = preload("res://src/tests/stadium_mogul_one_capture_freeze.gd")
const Archive = preload("res://src/tests/stadium_mogul_one_history_archive.gd")


static func contrast(
	owner: Node, camera: Camera3D, ball: BattedBallBody, label: String, context: Dictionary
) -> float:
	# Unchanged11x11 contrast metric; save failing inputs and freeze paired presentation.
	var lab: PitchBatLab = ball.get_parent() as PitchBatLab
	var study: StadiumActorCutawayStudy = (
		(lab.get_meta("stadium_property") as StadiumMogulOneProperty).actor_cutaway
	)
	var frozen_before: bool = study.frozen
	study.frozen = true
	var lock: Dictionary = Freeze.lock(lab)
	owner._check(
		Freeze.intact(lab, lock),
		"readback lock retains all bodies and positive ray/sphere controls"
	)
	var rendered_before: Dictionary = Freeze.snapshot(lab, ball)
	owner._check(
		rendered_before.unsupported.is_empty(),
		"paired capture supports every changing descendant: " + str(rendered_before.unsupported)
	)
	if not rendered_before.unsupported.is_empty():
		owner._check(Freeze.unlock(lab, lock), "unsupported readback restores capture lock")
		study.frozen = frozen_before
		return 0
	var original_visible: bool = ball.visible
	var state_before: Array[Dictionary] = owner._presentation_snapshot(lab)
	var before: Vector3 = ball.global_position
	ball.visible = true
	await RenderingServer.frame_post_draw
	var shown: Image = owner.get_viewport().get_texture().get_image()
	owner._check(
		state_before == owner._presentation_snapshot(lab),
		"visible contrast frame preserves exact actor receiver materials alpha shadows and poses"
	)
	owner._check(
		Freeze.intact(lab, lock) and Freeze.snapshot(lab, ball) == rendered_before,
		"visible frame retains exact full render snapshot and real physics membership"
	)
	ball.visible = false
	await RenderingServer.frame_post_draw
	var hidden: Image = owner.get_viewport().get_texture().get_image()
	owner._check(
		state_before == owner._presentation_snapshot(lab),
		"hidden contrast frame cannot change actor or receiver alpha pose or rendering state"
	)
	owner._check(
		Freeze.intact(lab, lock) and Freeze.snapshot(lab, ball) == rendered_before,
		"hidden frame retains exact full render snapshot and real physics membership"
	)
	await RenderingServer.frame_post_draw
	var hidden_control: Image = owner.get_viewport().get_texture().get_image()
	owner._check(
		Freeze.intact(lab, lock) and Freeze.snapshot(lab, ball) == rendered_before,
		"hidden control retains exact full render snapshot and real physics membership"
	)
	ball.visible = original_visible
	study.frozen = frozen_before
	owner._check(
		Freeze.unlock(lab, lock),
		"paired capture restores callback flags tweens tree pause and attached physics bodies"
	)
	owner._check(
		Freeze.snapshot(lab, ball) == rendered_before,
		"readback unlock preserves every rendered source exactly"
	)
	if (
		shown == null
		or hidden == null
		or hidden_control == null
		or shown.is_empty()
		or hidden.is_empty()
		or hidden_control.is_empty()
	):
		owner._check(false, "all three actual native readbacks exist")
		return 0
	var expected: Vector2i = owner._native._expected_content_size(owner.get_window().size)
	owner._check(
		(
			shown.get_size() == expected
			and hidden.get_size() == expected
			and hidden_control.get_size() == expected
		),
		"all paired images match acknowledged native content"
	)
	var stationary: bool = hidden.get_data() == hidden_control.get_data()
	owner._check(stationary, "same-pose hidden/hidden full-frame negative excludes renderer motion")
	print(
		"MOGUL_ONE_SYNTHETIC_STATIONARY label=",
		label,
		" hidden_frames_identical=",
		stationary,
		" rendered_nodes=",
		rendered_before.nodes,
		" snapshot_bytes=",
		rendered_before.bytes.size()
	)
	var logical: Vector2 = camera.unproject_position(ball.global_position)
	var viewport_size: Vector2 = camera.get_viewport().get_visible_rect().size
	var screen: Vector2i = Vector2i(logical * Vector2(shown.get_size()) / viewport_size)
	var difference: float = 0
	var peak: Vector2i = screen
	for x in range(maxi(0, screen.x - 5), mini(shown.get_width(), screen.x + 6)):
		for y in range(maxi(0, screen.y - 5), mini(shown.get_height(), screen.y + 6)):
			var a: Color = shown.get_pixel(x, y)
			var b: Color = hidden.get_pixel(x, y)
			var delta: float = Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
			if delta > difference:
				difference = delta
				peak = Vector2i(x, y)
	print(
		"MOGUL_ONE_SYNTHETIC_CONTRAST_SAMPLE context=",
		context,
		" window=",
		owner.get_window().size,
		" image=",
		shown.get_size(),
		" logical_extent=",
		viewport_size,
		" projected=",
		logical,
		" content_pixel=",
		screen,
		" peak=",
		peak,
		" camera=",
		camera.global_transform,
		" fov=",
		camera.fov,
		" ball_before=",
		before,
		" ball_after=",
		ball.global_position,
		" visible_in_tree=",
		ball.is_visible_in_tree(),
		" contrast=",
		difference
	)
	var receipt: Dictionary = {
		"label": label,
		"source_context": context,
		"camera": camera.global_transform,
		"fov": camera.fov,
		"logical_extent": viewport_size,
		"projected": logical,
		"content_pixel": [screen.x, screen.y],
		"peak_pixel": [peak.x, peak.y],
		"ball_before": before,
		"ball_after": ball.global_position,
		"visible_in_tree": ball.is_visible_in_tree(),
		"contrast": difference,
		"hidden_control_identical": stationary,
		"render_snapshot_nodes": rendered_before.nodes,
		"render_snapshot_bytes": rendered_before.bytes.size(),
		"render_snapshot_sha256": Archive._sha256(rendered_before.bytes)
	}
	var images: Array[Image] = [shown, hidden, hidden_control]
	owner._native_evidence.record_pair(owner, images, label, receipt)
	if difference < 0.03:
		var visuals: Array[Dictionary] = []
		for mesh: MeshInstance3D in ball.get_parent().find_children(
			"*", "MeshInstance3D", true, false
		):
			if ball.is_ancestor_of(mesh) or not mesh.is_visible_in_tree():
				continue
			var inverse: Transform3D = mesh.global_transform.affine_inverse()
			var point: Variant = mesh.get_aabb().intersects_segment(
				inverse * camera.global_position, inverse * ball.global_position
			)
			if point == null:
				continue
			var material: StandardMaterial3D = mesh.material_override as StandardMaterial3D
			visuals.append(
				{
					"mesh": String(mesh.get_path()),
					"local_hit": point,
					"world_hit": mesh.global_transform * point,
					"alpha": material.albedo_color.a if material != null else -1,
					"bounds": mesh.get_aabb()
				}
			)
		print(
			"MOGUL_ONE_SYNTHETIC_CONTRAST_VISUAL_CANDIDATES context=",
			context,
			" window=",
			owner.get_window().size,
			" intersections=",
			visuals
		)
	return difference
