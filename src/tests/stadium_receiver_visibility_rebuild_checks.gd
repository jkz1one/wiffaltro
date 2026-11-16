class_name StadiumReceiverVisibilityRebuildChecks
extends RefCounted
## Bounded support for the shared receiver fixture. Never starts a runner/game.

const EXPECTED_CHECKS: int = 44
const STEPS: int = 48
const DT: float = 1.0 / 30.0


static func run(
	root: Node3D,
	check: Callable,
	lab: PitchBatLab,
	adapter: StadiumReceiverOwnedVisibility,
	capture: Callable = Callable()
) -> void:
	var camera: Camera3D = lab._camera
	var director: MatchCameraDirector = lab._camera_director
	var property: StadiumPropertyGeometry = lab.get_meta("stadium_property")
	var models: Array[Node3D] = adapter._models.duplicate()
	var saved: Dictionary = {
		"camera": camera.global_transform,
		"fov": camera.fov,
		"projection": camera.projection,
		"size": camera.size,
		"shot": director.shot,
		"inspection": director._shot_before_inspection,
		"motion": director._presentation_motion,
		"progress": director._presentation_progress,
		"speed": director._presentation_transition_speed,
		"ball": lab._batted_ball,
		"process": lab.is_processing(),
		"physics": lab.is_physics_processing()
	}
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._batted_ball = null
	var physical: Array = _physical(models)
	check.call(
		adapter.intact() and models.size() == 1,
		"owned visibility installs once on the exact selected catcher"
	)
	check.call(
		director.get_script() == MatchCameraDirector,
		"owned receivers retain the ordinary camera director"
	)
	director._shot_before_inspection = -1
	director.clear_presentation_motion()
	director.set_shot(MatchCameraDirector.Shot.BATTING)
	director.snap(camera)
	check.call(
		_refresh_unchanged(adapter, camera) and _hidden(models),
		"initial batting render hides exact catchers without changing the camera"
	)
	check.call(_shadows(models, true), "hidden catchers suppress every owned geometry shadow")
	check.call(
		_scope(adapter, models, true),
		"only exact hidden catcher identities are excluded from tracking"
	)
	check.call(
		adapter.refresh(true) and _hidden(models),
		"force-visible binding cannot flash a catcher in the protected batting view"
	)
	for motion: MatchCameraDirector.PresentationMotion in [
		MatchCameraDirector.PresentationMotion.ZOOM_IN,
		MatchCameraDirector.PresentationMotion.ZOOM_OUT
	]:
		director.set_presentation_motion(motion, 1.0)
		var safe: bool = true
		for step in range(STEPS):
			director.update(camera, DT, false, Vector3.ZERO)
			safe = _refresh_unchanged(adapter, camera) and _hidden(models) and safe
		check.call(
			safe, "complete existing batting zoom stays hidden without camera or FOV compensation"
		)
		check.call(
			_physical(models) == physical,
			"zoom visibility leaves all collider geometry and masks unchanged"
		)
		if capture.is_valid():
			await capture.call(
				(
					"receiver_batting_zoom_in"
					if motion == MatchCameraDirector.PresentationMotion.ZOOM_IN
					else "receiver_batting_zoom_out"
				)
			)
	director.clear_presentation_motion()
	director.snap(camera)
	adapter.refresh()
	director.set_shot(MatchCameraDirector.Shot.SIDE)
	check.call(
		(
			adapter.refresh()
			and (
				_hidden(models)
				if models[0].get_meta("stadium_item") == "ST-072"
				else _visible(models)
			)
		),
		"outgoing batting route protects real member crossings and restores a clear net cup"
	)
	var departed: bool = false
	var unchanged: bool = true
	for step in range(STEPS):
		director.update(camera, DT, false, Vector3.ZERO)
		unchanged = _refresh_unchanged(adapter, camera) and unchanged
		departed = departed or _visible(models)
	check.call(
		departed and _visible(models), "actual completed departure restores inspection visuals"
	)
	check.call(
		unchanged and _shadows(models, false),
		"departure restores original shadows and never corrects camera motion"
	)
	check.call(
		_scope(adapter, models, false),
		"clear visible catchers return to ordinary tracking obstacles"
	)
	# Reverse before arrival, then cancel back out. The actual route determines reveal.
	director.set_shot(MatchCameraDirector.Shot.BATTING)
	director.update(camera, DT, false, Vector3.ZERO)
	check.call(
		adapter.refresh() and _hidden(models),
		"interrupted return protects the incoming batting route immediately"
	)
	director.set_shot(MatchCameraDirector.Shot.SIDE)
	for step in range(STEPS):
		director.update(camera, DT, false, Vector3.ZERO)
		adapter.refresh()
	check.call(
		_visible(models), "cancelled batting transition restores when the real route is clear"
	)
	var rapid: bool = true
	for shot: MatchCameraDirector.Shot in [
		MatchCameraDirector.Shot.BATTING,
		MatchCameraDirector.Shot.PITCHING,
		MatchCameraDirector.Shot.BATTING,
		MatchCameraDirector.Shot.ESTABLISHING,
		MatchCameraDirector.Shot.BATTING
	]:
		director.set_shot(shot)
		director.update(camera, DT, false, Vector3.ZERO)
		rapid = _refresh_unchanged(adapter, camera) and rapid
		if shot == MatchCameraDirector.Shot.BATTING:
			rapid = _hidden(models) and rapid
	check.call(rapid, "rapid reversed camera routes never expose an actionable batting catcher")
	director.clear_presentation_motion()
	director.set_shot(MatchCameraDirector.Shot.BATTING)
	director.snap(camera)
	director._shot_before_inspection = int(MatchCameraDirector.Shot.BATTING)
	adapter.refresh()
	adapter.refresh()
	check.call(
		_visible(models), "paused batting inspection restores at its genuinely clear camera pose"
	)
	director.restore_after_pause()
	check.call(
		adapter.refresh() and _hidden(models),
		"closing inspection protects batting before another rendered frame"
	)
	var ball: BattedBallBody = BattedBallBody.new()
	lab.add_child(ball)
	ball.position = Vector3(0, 1.1, 0.2)
	lab._batted_ball = ball
	StadiumPropertyRuntime.refresh_receiver_visibility(lab, true)
	check.call(
		_hidden(models) and adapter.intact(),
		"real runtime force-visible seam cannot reveal on live-ball rebind"
	)
	StadiumPropertyRuntime.refresh_receiver_visibility(lab, true)
	check.call(_hidden(models), "repeated live rebind stays protected without a one-frame flash")
	lab._batted_ball = null
	ball.free()
	# Field-facing capture is an explicit inspection camera, with no geometry moves.
	director._shot_before_inspection = int(MatchCameraDirector.Shot.BATTING)
	director.shot = MatchCameraDirector.Shot.SIDE
	camera.global_position = Vector3(0, 3.6, 7.0)
	camera.look_at(Vector3(0, 1.6, -2.65), Vector3.UP)
	adapter.refresh()
	adapter.refresh()
	check.call(
		_visible(models) and _shadows(models, false),
		"field-facing inspection shows the complete outward cage and unchanged net"
	)
	if capture.is_valid():
		await capture.call("receiver_field_facing")
	var fade_ball: BattedBallBody = BattedBallBody.new()
	lab.add_child(fade_ball)
	fade_ball.global_position = Vector3(0, 1.5, -6.0)
	lab._batted_ball = fade_ball
	check.call(
		adapter.refresh() and _faded(models),
		"clear inspection sightline fades exact catcher materials and shadows around a live ball"
	)
	var originals_unchanged: bool = true
	for material: Dictionary in adapter._materials:
		originals_unchanged = (
			StadiumReceiverOwnedVisibility._material_state(material.original) == material.baseline
			and originals_unchanged
		)
	check.call(
		originals_unchanged, "fading never mutates saved or unrelated shared source materials"
	)
	lab._batted_ball = null
	fade_ball.free()
	check.call(
		adapter.refresh() and _visible(models) and _shadows(models, false),
		"ending the live sightline restores exact owned opacity and original shadows"
	)
	for model: Node3D in models:
		var surface: String = (
			"ST072_REAR_MESH" if model.get_meta("stadium_item") == "ST-072" else "ST073_CENTER_NET"
		)
		check.call(
			adapter.flex_owned(model, surface, 0.1, Vector3(0, 1.5, 0)) and adapter.intact(),
			"authorized owned flex replaces only its captured panel mesh"
		)
		check.call(
			adapter.flex_owned(model, surface, 1.0, Vector3.ZERO) and adapter.intact(),
			"owned flex settles without stale visibility ownership"
		)
	check.call(
		_physical(models) == physical,
		"all transition and flex checks preserve physical receiver geometry"
	)
	check.call(
		property == lab.get_meta("stadium_property") and director == lab._camera_director,
		"shared installed runtime and camera ownership remain unchanged"
	)
	# Isolated adversarial holders share no live model/material resources with the
	# installed fixture. An off-tree lab holder never runs _ready or starts a match.
	for mutation: String in [
		"material", "material_value", "shadow", "visual", "model", "multimesh", "camera"
	]:
		_adversarial(root, check, mutation)
	camera.global_transform = saved.camera
	camera.fov = saved.fov
	camera.projection = saved.projection
	camera.size = saved.size
	director.shot = saved.shot
	director._shot_before_inspection = saved.inspection
	director.set_presentation_motion(saved.motion, saved.progress, saved.speed)
	lab._batted_ball = saved.ball
	adapter.refresh()
	adapter.refresh()
	lab.set_process(saved.process)
	lab.set_physics_process(saved.physics)
	check.call(adapter.intact(), "shared adapter remains usable after bounded isolation checks")


static func _refresh_unchanged(adapter: StadiumReceiverOwnedVisibility, camera: Camera3D) -> bool:
	var before: Array = [
		camera.global_transform,
		camera.fov,
		camera.projection,
		camera.size,
		camera.near,
		camera.far,
		camera.cull_mask
	]
	return (
		adapter.refresh()
		and (
			before
			== [
				camera.global_transform,
				camera.fov,
				camera.projection,
				camera.size,
				camera.near,
				camera.far,
				camera.cull_mask
			]
		)
	)


static func _hidden(models: Array[Node3D]) -> bool:
	for model: Node3D in models:
		if (
			model.get_node("Visual").visible
			or model.get_meta("receiver_render_state", "") != "hidden"
		):
			return false
	return true


static func _visible(models: Array[Node3D]) -> bool:
	for model: Node3D in models:
		if (
			not model.get_node("Visual").visible
			or model.get_meta("receiver_render_state", "") != "visible"
		):
			return false
	return true


static func _faded(models: Array[Node3D]) -> bool:
	for model: Node3D in models:
		if (
			not model.get_node("Visual").visible
			or model.get_meta("receiver_render_state", "") != "faded"
		):
			return false
		for member: GeometryInstance3D in model.get_node("Visual").find_children(
			"*", "GeometryInstance3D", true, false
		):
			if (
				member.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				or not is_equal_approx(
					member.material_override.albedo_color.a, StadiumReceiverVisibility.FADED_ALPHA
				)
			):
				return false
	return true


static func _shadows(models: Array[Node3D], hidden: bool) -> bool:
	for model: Node3D in models:
		for member: GeometryInstance3D in model.get_node("Visual").find_children(
			"*", "GeometryInstance3D", true, false
		):
			if (
				member.cast_shadow
				!= (
					GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					if hidden
					else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				)
			):
				return false
	return true


static func _scope(
	adapter: StadiumReceiverOwnedVisibility, models: Array[Node3D], expected: bool
) -> bool:
	var foreign: Node3D = Node3D.new()
	foreign.set_meta("stadium_item", "ST-072")
	var valid: bool = not adapter.excludes(foreign)
	foreign.free()
	var tracking: BallTrackingVisibility = adapter._tracking.get_ref() as BallTrackingVisibility
	valid = (
		tracking != null
		and tracking.owns_receiver_scope(models, adapter.excludes)
		and not tracking._owned_receiver_bounds.is_empty()
		and valid
	)
	var observed: Array = []
	if tracking != null:
		for row: Dictionary in tracking._owned_receiver_bounds:
			var owner: Node3D = row.owner.get_ref() as Node3D
			valid = models.has(owner) and not tracking._obstacles.has(row.bounds) and valid
			if not observed.has(owner):
				observed.append(owner)
	for model: Node3D in models:
		valid = observed.has(model) and (adapter.excludes(model) == expected) and valid
	return valid


static func _physical(models: Array[Node3D]) -> Array:
	var result: Array = []
	for model: Node3D in models:
		result.append([model, model.transform])
		for body: StaticBody3D in model.get_node("Collision").find_children(
			"*", "StaticBody3D", true, false
		):
			result.append(
				[
					body,
					body.transform,
					body.collision_layer,
					body.collision_mask,
					body.physics_material_override,
					body.get_meta("surface_id", ""),
					body.get_meta("surface_role", "")
				]
			)
			for collider: CollisionShape3D in body.get_children():
				result.append(
					[
						collider,
						collider.transform,
						collider.shape,
						collider.shape.get_debug_mesh().get_aabb(),
						collider.shape.margin,
						collider.disabled
					]
				)
	return result


static func _adversarial(root: Node3D, check: Callable, mutation: String) -> void:
	var holder: Node3D = Node3D.new()
	root.add_child(holder)
	var lab: PitchBatLab = PitchBatLab.new()
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	holder.add_child(property)
	var row: Dictionary = {
		"copy": "VISIBILITY:ST-072",
		"site": "VISIBILITY",
		"position": Vector3(0, 0, -2.65),
		"yaw": 0.0
	}
	var model: Node3D = StadiumReceiverOwnedModels.create("ST-072", row)
	property.add_child(model)
	model.position = row.position
	property.objects[row.copy] = model
	var wires: MultiMeshInstance3D = MultiMeshInstance3D.new()
	wires.name = "VisibilityMultiMeshProbe"
	wires.multimesh = MultiMesh.new()
	wires.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var wire_mesh: BoxMesh = BoxMesh.new()
	wire_mesh.size = Vector3(0.003, 2.5, 0.003)
	wires.multimesh.mesh = wire_mesh
	wires.multimesh.instance_count = 1
	wires.multimesh.set_instance_transform(0, Transform3D(Basis.IDENTITY, Vector3(0, 1.4, 0)))
	wires.material_override = StandardMaterial3D.new()
	for key: String in ["owned_copy", "paid_copy", "site", "stadium_item", "receiver_owned"]:
		wires.set_meta(key, model.get_meta(key))
	model.get_node("Visual").add_child(wires)
	var camera: Camera3D = Camera3D.new()
	holder.add_child(camera)
	lab._camera = camera
	lab._camera_director = MatchCameraDirector.new()
	lab.set_meta("stadium_property", property)
	lab._camera_director.snap(camera)
	var authority: Callable = func() -> bool:
		return (
			is_instance_valid(lab)
			and lab.has_meta("stadium_property")
			and lab.get_meta("stadium_property") == property
		)
	var adapter: StadiumReceiverOwnedVisibility = StadiumReceiverOwnedVisibility.new()
	var models: Array[Node3D] = [model]
	var installed: bool = adapter.install(lab, property, models, authority)
	check.call(
		(
			installed
			and not model.get_node("Visual").visible
			and wires.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		),
		"isolated exact scope captures MultiMesh wires before first render: " + mutation
	)
	var member: MeshInstance3D = model.get_node("Visual/ST072_REAR_MESH")
	var old_visual: Node3D = model.get_node("Visual")
	var foreign: Node3D
	var replacement_camera: Camera3D
	match mutation:
		"material":
			member.material_override = StandardMaterial3D.new()
		"material_value":
			member.material_override.roughness = 0.137
		"shadow":
			wires.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		"visual":
			model.remove_child(old_visual)
			foreign = Node3D.new()
			foreign.name = "Visual"
			model.add_child(foreign)
		"model":
			foreign = Node3D.new()
			property.add_child(foreign)
			property.objects[row.copy] = foreign
		"multimesh":
			wires.multimesh = wires.multimesh.duplicate(true)
		"camera":
			replacement_camera = Camera3D.new()
			holder.add_child(replacement_camera)
			lab._camera = replacement_camera
	var before: Array = [
		member.material_override,
		member.material_override.roughness,
		wires.cast_shadow,
		wires.multimesh,
		old_visual.visible,
		foreign.visible if foreign != null else false,
		lab._camera
	]
	var rejected: bool = not adapter.refresh(true)
	adapter.retire()
	adapter.refresh()
	var after: Array = [
		member.material_override,
		member.material_override.roughness,
		wires.cast_shadow,
		wires.multimesh,
		old_visual.visible,
		foreign.visible if foreign != null else false,
		lab._camera
	]
	check.call(
		rejected and before == after and not adapter.excludes(model),
		(
			"foreign change retires without stale resource, shadow, replacement or camera writes: "
			+ mutation
		)
	)
	if old_visual.get_parent() == null:
		old_visual.free()
	lab.free()
	holder.free()
