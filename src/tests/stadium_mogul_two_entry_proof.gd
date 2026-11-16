extends RefCounted
## Actual installed pre-contact entry and separately labeled static ball diagnostics.
## No source launch, contact-time snap, live camera override or new readability minimum.

const Evidence = preload("res://src/tests/stadium_mogul_two_evidence.gd")
const Freeze = preload("res://src/tests/stadium_mogul_two_capture_freeze.gd")
const Actors = preload("res://src/tests/stadium_mogul_two_actor_proof.gd")


static func run(owner: Node) -> void:
	# Every readback and full-resolution ball triplet is retained by the explicit full profile.
	for left: bool in [false, true]:
		await _hand(owner, left)
	print(
		"MOGUL_TWO_AUTHORED_ENTRY_SCOPE precontact=true static_ball_diagnostics=true ",
		"genuine_launched_physics_owned_by_history_proof=true ",
		"readability_minimum=UNSPECIFIED actual_native_image_review_required=true"
	)


static func _hand(owner: Node, left: bool) -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_mogul_two_lab_only", true)
	owner.add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	owner._hide_overlay(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	var installed: bool = StadiumMogulTwoLab.install(lab)
	owner._check(installed, "authored entry uses real complete installed AM-02")
	if not installed:
		await _dispose(owner, lab)
		return
	lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
	lab._match_state.batter().definition.bats = (
		PlayerDefinition.Handedness.LEFT if left else PlayerDefinition.Handedness.RIGHT
	)
	PitchBatLabPresentation.sync_players(lab)
	# This is normal role setup before any pitch or batted ball, never contact-time repair.
	PitchBatLabPresentation.apply_role_camera(lab)
	lab._camera_director.snap(lab._camera)
	StadiumPropertyRuntime.refresh_receiver_visibility(lab)
	lab._batter_avatar.set_process(false)
	lab._bat_actor.set_process(false)
	await owner.get_tree().physics_frame
	await owner.get_tree().physics_frame
	var camera: Camera3D = lab._camera
	var expected: Vector3 = Vector3(-0.18 if left else 0.18, 2.10, -6.5)
	var aim: Vector3 = Vector3(0, 1.10, 7.1)
	owner._check(
		(
			camera.global_position.is_equal_approx(expected)
			and (-camera.global_basis.z).is_equal_approx((aim - expected).normalized())
			and is_equal_approx(camera.fov, 75.0)
			and camera.projection == Camera3D.PROJECTION_PERSPECTIVE
		),
		"installed authored entry keeps exact handed position aim and75degree perspective"
	)
	owner._check(
		(
			lab._camera_director.shot == MatchCameraDirector.Shot.BATTING
			and not is_instance_valid(lab._batted_ball)
			and not lab._pitch_actor.running
		),
		"entry acquired genuinely before pitch/contact and without a live ball"
	)
	owner._check(Actors.actors(lab).size() == 4, "entry retains all four actual actors")
	owner._check(owner._near_clear(camera), "actual authored entry near volume clears physical cup")
	owner._check(Freeze.physics_proof(lab), "entry independent opaque ray and sphere controls hit")
	var zone: Array[MeshInstance3D] = _zone(lab)
	owner._check(zone.size() == 4, "entry uses four real installed strike-zone bars")
	if zone.size() != 4:
		await _dispose(owner, lab)
		return
	var target: Vector3 = _zone_center(zone)
	_precontact_receiver(owner, lab, target)
	var entry_pose: Transform3D = camera.global_transform
	for extent: Vector2i in [Vector2i(1280, 720), Vector2i(700, 400)]:
		owner._check(await owner._native.resize(extent), "entry actual native resize acknowledged")
		var content: Vector2i = owner._native._expected_content_size(extent)
		_readability_geometry(owner, lab, zone, content, left)
		if DisplayServer.get_name() != "headless":
			await _native_readability(owner, lab, zone, content, left)
		owner._check(
			camera.global_transform == entry_pose, "native size never alters authored entry"
		)
	owner._check(await owner._native.resize(Vector2i(1280, 720)), "entry native extent restored")
	await _static_ball_diagnostic(owner, lab, target, left)
	owner._check(
		camera.global_transform == entry_pose, "static diagnostic never moves entry camera"
	)
	await _dispose(owner, lab)


static func _zone(lab: PitchBatLab) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for name_value: String in ["ZoneLeft", "ZoneRight", "ZoneBottom", "ZoneTop"]:
		var mesh: MeshInstance3D = lab.get_node_or_null("StarterFieldGeometry/" + name_value)
		if mesh != null and mesh.mesh != null and mesh.is_visible_in_tree():
			result.append(mesh)
	return result


static func _zone_center(zone: Array[MeshInstance3D]) -> Vector3:
	var result: Vector3 = Vector3.ZERO
	for mesh: MeshInstance3D in zone:
		result += mesh.global_transform * mesh.get_aabb().get_center()
	return result / zone.size()


static func _precontact_receiver(owner: Node, lab: PitchBatLab, target: Vector3) -> void:
	var property: StadiumMogulTwoProperty = lab.get_meta("stadium_property")
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		lab._camera.global_position, target, StadiumClubPropertyGeometry.CAMERA_LAYER
	)
	var hit: Dictionary = lab.get_world_3d().direct_space_state.intersect_ray(ray)
	owner._check(
		(
			(property.receiver as StadiumMogulTwoReceiver).intact()
			and not hit.is_empty()
			and property.receiver.net.is_ancestor_of(hit.get("collider"))
		),
		"authored entry really sits behind actual receiver cup collision"
	)
	for model: Node3D in [property.receiver.net, property.receiver.chair]:
		owner._check(_hidden_receiver(model), "pre-pitch actual receiver hidden with shadows off")
	owner._check(
		_precontact_clear(owner, property, ray.from, ray.to),
		"independent pre-pitch ray skips only proven hidden receiver and rejects farther opacity"
	)
	# The physical collider remains even while its actual render subtree is hidden.
	owner._check(
		not owner._clear_after_fades(property, ray.from, ray.to),
		"fade-only physical checker does not misclassify hidden receiver as a live fade"
	)
	var faces: Dictionary = {}
	var actor_hits: Dictionary = {}
	for role: String in Actors.actors(lab):
		var count: int = 0
		for mesh: MeshInstance3D in Actors.actors(lab)[role].find_children(
			"*", "MeshInstance3D", true, false
		):
			count += Actors._triangle_hits(mesh, ray.from, ray.to, faces)
		actor_hits[role] = count
		owner._check(count == 0, "pre-pitch strike center clear of actual " + role + " triangles")
	print("MOGUL_TWO_AUTHORED_ENTRY_ACTORS strike_center=", target, " triangle_hits=", actor_hits)


static func _hidden_receiver(model: Node3D) -> bool:
	if model.get_meta("receiver_render_state", "") != "hidden":
		return false
	var visual: Node3D = model.get_node("Visual")
	if visual.visible or visual.get_child_count() == 0:
		return false
	for mesh: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
		if (
			mesh.is_visible_in_tree()
			or mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		):
			return false
	for body: StaticBody3D in model.get_node("Collision").get_children():
		if (
			body.collision_layer & 1 == 0
			or body.collision_layer & StadiumClubPropertyGeometry.CAMERA_LAYER == 0
		):
			return false
	return true


static func _precontact_clear(
	owner: Node, property: StadiumMogulTwoProperty, from: Vector3, to: Vector3
) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, to, StadiumClubPropertyGeometry.CAMERA_LAYER
	)
	var ignored: Array[RID] = []
	for index: int in range(property.find_children("*", "StaticBody3D", true, false).size() + 1):
		query.exclude = ignored
		var hit: Dictionary = property.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return true
		var hidden: bool = false
		for model: Node3D in [property.receiver.net, property.receiver.chair]:
			if model.get_node("Collision").get_children().has(hit.collider):
				hidden = hidden or _hidden_receiver(model)
		if ignored.has(hit.rid) or not (hidden or owner._verified_fade(property, hit.collider)):
			return false
		ignored.append(hit.rid)
	return false


static func _readability_geometry(
	owner: Node, lab: PitchBatLab, zone: Array[MeshInstance3D], content: Vector2i, left: bool
) -> void:
	var groups: Dictionary = {
		"strike_zone": zone,
		"batter": lab._batter_avatar.find_children("*", "MeshInstance3D", true, false),
		"bat": lab._bat_actor.find_children("*", "MeshInstance3D", true, false),
		"pitcher": lab._pitcher_avatar.find_children("*", "MeshInstance3D", true, false)
	}
	for label: String in groups:
		var footprint: Dictionary = _footprint(lab._camera, groups[label], content)
		owner._check(
			footprint.meshes > 0 and footprint.hidden == 0 and footprint.outside == 0,
			"real " + label + " visible geometry keeps unchanged24content-pixel framing"
		)
		print(
			"MOGUL_TWO_AUTHORED_ENTRY_GEOMETRY left=",
			left,
			" content=",
			content,
			" subject=",
			label,
			" projected_real_mesh_bounds=",
			footprint,
			" minimum_readability_size=UNSPECIFIED"
		)


static func _footprint(camera: Camera3D, meshes: Array, content: Vector2i) -> Dictionary:
	var minimum: Vector2 = Vector2(INF, INF)
	var maximum: Vector2 = Vector2(-INF, -INF)
	var result: Dictionary = {"meshes": 0, "hidden": 0, "outside": 0}
	var scale: Vector2 = Vector2(content) / camera.get_viewport().get_visible_rect().size
	var safe: Rect2 = Rect2(Vector2(24, 24), Vector2(content) - Vector2(48, 48))
	for mesh: MeshInstance3D in meshes:
		result.meshes += 1
		result.hidden += int(not mesh.is_visible_in_tree() or mesh.mesh == null)
		if mesh.mesh == null:
			continue
		for index: int in range(8):
			var world: Vector3 = mesh.global_transform * mesh.get_aabb().get_endpoint(index)
			var screen: Vector2 = camera.unproject_position(world) * scale
			minimum = minimum.min(screen)
			maximum = maximum.max(screen)
			result.outside += int(camera.is_position_behind(world) or not safe.has_point(screen))
	result.rect = Rect2(minimum, maximum - minimum)
	return result


static func _native_readability(
	owner: Node, lab: PitchBatLab, zone: Array[MeshInstance3D], content: Vector2i, left: bool
) -> void:
	var lock: Dictionary = Freeze.lock(lab)
	owner._check(Freeze.intact(lab, lock), "native pre-pitch freeze retains actual physics bodies")
	var before: Array[Dictionary] = owner._presentation_snapshot(lab)
	await RenderingServer.frame_post_draw
	var shown: Image = owner.get_viewport().get_texture().get_image()
	owner._check(
		shown != null and not shown.is_empty() and shown.get_size() == content,
		"pre-pitch readback is actual acknowledged native content"
	)
	if shown == null or shown.is_empty() or shown.get_size() != content:
		owner._check(Freeze.unlock(lab, lock), "failed native pre-pitch readback restores freeze")
		return
	if not owner._capture_dir.is_empty():
		owner._check(
			Evidence.save(
				shown,
				owner._capture_dir.path_join(
					(
						"mogul-two-authored-entry-%s-%dx%d.png"
						% ["left" if left else "right", content.x, content.y]
					)
				)
			),
			"actual pre-pitch image retained within explicit full-native budget for visual review"
		)
	var subjects: Dictionary = {
		"strike_zone": zone,
		"batter": [lab._batter_avatar, lab._bat_actor],
		"pitcher": [lab._pitcher_avatar]
	}
	for label: String in subjects:
		await _subject_pixels(owner, lab, subjects[label], shown, label, left)
	owner._check(
		before == owner._presentation_snapshot(lab),
		"pre-pitch image witnesses restore exact transforms materials alpha shadows and visibility"
	)
	owner._check(Freeze.intact(lab, lock), "native pre-pitch witnesses retain full capture lock")
	owner._check(
		Freeze.unlock(lab, lock), "native pre-pitch witnesses restore callbacks and physics"
	)


static func _subject_pixels(
	owner: Node, lab: PitchBatLab, subjects: Array, shown: Image, label: String, left: bool
) -> void:
	var flags: Array[bool] = []
	for subject: Node3D in subjects:
		flags.append(subject.visible)
		subject.visible = false
	await RenderingServer.frame_post_draw
	var hidden: Image = owner.get_viewport().get_texture().get_image()
	await RenderingServer.frame_post_draw
	var control: Image = owner.get_viewport().get_texture().get_image()
	for index: int in range(subjects.size()):
		subjects[index].visible = flags[index]
	await RenderingServer.frame_post_draw
	var restored: Image = owner.get_viewport().get_texture().get_image()
	if hidden == null or control == null or restored == null:
		owner._check(false, "pre-pitch native subject witness readbacks all exist")
		return
	owner._check(
		(
			hidden.get_size() == shown.get_size()
			and control.get_size() == shown.get_size()
			and restored.get_size() == shown.get_size()
			and hidden.get_data() == control.get_data()
			and shown.get_data() == restored.get_data()
		),
		"pre-pitch native hidden/hidden and restored full-frame controls exclude incidental motion"
	)
	if hidden.get_size() != shown.get_size():
		return
	var changed: int = 0
	var peak: float = 0
	for y: int in range(shown.get_height()):
		for x: int in range(shown.get_width()):
			var a: Color = shown.get_pixel(x, y)
			var b: Color = hidden.get_pixel(x, y)
			var difference: float = Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
			changed += int(difference > 0)
			peak = maxf(peak, difference)
	owner._check(
		changed > 0, "actual " + label + " contributes native pixels; no size minimum claimed"
	)
	owner._check(
		(
			not owner._capture_dir.is_empty()
			and Evidence.record_readbacks(
				[shown, hidden, control, restored],
				{
					"kind": "AM02_ENTRY_SUBJECT_FULL_FRAME_WITNESS",
					"left": left,
					"subject": label,
					"changed_pixels": changed,
					"peak_delta": peak,
					"camera": lab._camera.global_transform,
					"hidden_control_identical": hidden.get_data() == control.get_data(),
					"shown_restored_identical": shown.get_data() == restored.get_data()
				},
				owner._capture_dir.path_join(
					(
						"entry-witness-%s-%s-%dx%d"
						% [str(left), label, shown.get_width(), shown.get_height()]
					)
				)
			)
		),
		"every pre-pitch subject readback has an exact raw hash receipt"
	)
	print(
		"MOGUL_TWO_AUTHORED_ENTRY_PIXELS left=",
		left,
		" content=",
		shown.get_size(),
		" subject=",
		label,
		" changed_pixels=",
		changed,
		" peak_delta=",
		peak,
		" camera=",
		lab._camera.global_transform,
		" visual_review_required=true"
	)


static func _static_ball_diagnostic(
	owner: Node, lab: PitchBatLab, target: Vector3, left: bool
) -> void:
	# A frozen diagnostic at the actual zone center. This is explicitly NOT a physical launch.
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	lab.add_child(ball)
	lab._batted_ball = ball
	ball.global_position = target
	StadiumPropertyRuntime.refresh_receiver_visibility(lab)
	var property: StadiumMogulTwoProperty = lab.get_meta("stadium_property")
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		lab._camera.global_position, target, StadiumClubPropertyGeometry.CAMERA_LAYER
	)
	var hit: Dictionary = lab.get_world_3d().direct_space_state.intersect_ray(query)
	owner._check(
		(
			not hit.is_empty()
			and property.receiver.net.is_ancestor_of(hit.get("collider"))
			and owner._verified_fade(property, hit.get("collider"))
		),
		"static entry diagnostic crosses actual net body with qualified live-style fade"
	)
	owner._check(
		owner._clear_after_fades(property, query.from, query.to),
		"static diagnostic rejects every opaque physical blocker beyond authentic net fade"
	)
	var audit: Dictionary = Actors.audit(lab, {})
	owner._check(
		audit.actors == 4 and audit.hidden == 0 and audit.opaque == 0,
		"static diagnostic independently checks all authentic actor triangles and opacity"
	)
	owner._check(
		owner._near_clear(lab._camera), "static diagnostic keeps unchanged near-volume gate"
	)
	for content: Vector2i in [Vector2i(1280, 720), Vector2i(700, 393)]:
		var scale: Vector2 = Vector2(content) / lab._camera.get_viewport().get_visible_rect().size
		owner._check(
			(
				not lab._camera.is_position_behind(target)
				and Rect2(Vector2(24, 24), Vector2(content) - Vector2(48, 48)).has_point(
					lab._camera.unproject_position(target) * scale
				)
			),
			"static diagnostic retains24content-pixel ball margin at both native extents"
		)
	if DisplayServer.get_name() != "headless":
		var contrast: float = await owner._representative_contrast(
			lab._camera,
			ball,
			"mogul-two-static-entry-zone-%s" % ("left" if left else "right"),
			{
				"kind": "STATIC_DIAGNOSTIC_NOT_LAUNCHED_PHYSICS",
				"left": left,
				"source": "real-zone-center"
			}
		)
		owner._check(
			contrast >= 0.03, "static entry native ball contrast retains unchanged0.03 gate"
		)
	print(
		"MOGUL_TWO_STATIC_ENTRY_DIAGNOSTIC left=",
		left,
		" target=",
		target,
		" frozen=",
		ball.freeze,
		" actor_audit=",
		audit,
		" launched_physics=false"
	)

static func _dispose(owner: Node, lab: PitchBatLab) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	lab.queue_free()
	await owner.get_tree().process_frame
	await owner.get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw

