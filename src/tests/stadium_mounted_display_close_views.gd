extends "res://src/tests/stadium_mounted_display_rebuild_checks.gd"
## Bounded visual follow-up to the accepted480 technical gate, without replaying it.
const CV_CHECKS: int = 63
const CV_INPUT_SHA: String = "564822ffb857714ac8c7d221c75093e6b9ebb30a9f356a3f3baf1d1578c74d8b"
const CV_TECHNICAL_RESULT: String = \
	"cdc2e09c8a4a4cbf7bee38ff2e3c72cfc789df1e05922d27d148bbcaf2dc014e"
const CV_IMAGES: Array[String] = [
	"mounted-display-ribbon-close.png", "mounted-display-clock-pa-close.png"
]
var _cv_views: Array[Dictionary] = []
var _cv_source: Dictionary = {}
var _cv_clock_model: Dictionary = {}
var _cv_stock: StadiumStock


func run(directory: String) -> Dictionary:
	_capture_dir = directory
	_phase = "accepted-technical-input"
	_check(
		DisplayServer.get_name() != "headless" and not directory.is_empty(),
		"close views require the rendered existing viewport"
	)
	_check(DirAccess.make_dir_recursive_absolute(directory) == OK, "close-view directory opens")
	var input_path: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--mounted-display-input="):
			input_path = argument.trim_prefix("--mounted-display-input=")
	var input: FileAccess = FileAccess.open(input_path, FileAccess.READ)
	var valid_input: bool = (
		input != null
		and input.get_length() <= 131072
		and FileAccess.get_sha256(input_path) == CV_INPUT_SHA
	)
	_check(valid_input, "exact accepted480 evidence bytes are pinned")
	if valid_input:
		var decoded: Variant = JSON.parse_string(input.get_as_text())
		if decoded is Dictionary:
			_cv_source = decoded
	if input != null:
		input.close()
	_check(
		(
			_cv_source.get("checks") == 480
			and _cv_source.get("failures") == 0
			and _cv_source.get("games") == 0
			and _cv_source.get("model_checks") == 158
			and (
				_cv_source.get("images", [])
				== ["mounted-display-overview.png", "mounted-display-details.png"]
			)
		),
		"input is the scoped accepted technical480 result and zero-game source"
	)
	_cv_stock = StadiumStock.from_data(_cv_source.get("paid_inventory"))
	_check(
		(
			_cv_stock != null
			and ClubCareer.same(_cv_stock.to_data(), _cv_source.get("paid_inventory", {}))
		),
		"normal stock decoding preserves every exact paid copy"
	)
	var layout: Dictionary = _cv_source.get("layout", {})
	var checked: Dictionary = (
		StadiumHomeLayout.validate(layout, _cv_stock, "mogul")
		if _cv_stock != null
		else {"ok": false}
	)
	_check(
		checked.get("ok", false) and checked.get("mounted_display_placements", []).size() == 6,
		"normal owned-layout validation retains six actual mounts and existing hosts"
	)
	if _failures == 0:
		await _cv_clock_geometry()
		await _cv_capture(
			layout,
			checked,
			["purchase:mounted-buy:0:0"],
			CV_IMAGES[0],
			"STRAIGHT RIBBON | exact paid upper-fascia mount"
		)
		await _cv_capture(
			layout,
			checked,
			["purchase:mounted-buy:1:1", "purchase:mounted-buy:2:1"],
			CV_IMAGES[1],
			"SIMULATION CLOCK + SILENT PA | exact paid manual-board mounts"
		)
	_phase = "close-view-completion"
	_check(_images == CV_IMAGES, "exactly two native close originals")
	var payload: Dictionary = {
		"checks": _checks,
		"expected_checks": CV_CHECKS,
		"failures": _failures,
		"images": _images,
		"games": 0,
		"synthetic_funding": true,
		"synthetic_progression": true,
		"technical_checks_carried": 480,
		"technical_checks_reexecuted": 41,
		"technical_result_sha256": CV_TECHNICAL_RESULT,
		"input_sha256": CV_INPUT_SHA,
		"production_changed": true,
		"audio_implementation_claim": false,
		"night_qualification_claim": false,
		"gameplay_bonus_claim": false,
		"whole_game_acceptance_claim": false,
		"final_art_acceptance_claim": false,
		"paid_inventory_sha256":
		JSON.stringify(_cv_source.get("paid_inventory", {}), "", true, true).sha256_text(),
		"layout_sha256": JSON.stringify(layout, "", true, true).sha256_text(),
		"views": _cv_views,
		"affected_clock_checks": 43,
		"clock_model": _cv_clock_model
	}
	_check(
		JSON.stringify(payload, "", true, true).to_utf8_buffer().size() <= 131072,
		"close-view evidence stays within128KiB"
	)
	var file: FileAccess = FileAccess.open(
		directory.path_join("mounted-display-close-views.json"), FileAccess.WRITE
	)
	_check(file != null, "close-view evidence opens")
	_check(
		_checks + 1 == CV_CHECKS, "the fixed63 affected-clock and close-view checks are all reached"
	)
	if file != null:
		payload.checks = _checks
		payload.failures = _failures
		file.store_string(JSON.stringify(payload, "", true, true))
		file.flush()
		if file.get_error() != OK:
			_check(false, "close-view evidence fully writes")
		file.close()
	print(
		(
			(
				"MOUNTED_DISPLAY_CLOSE_VIEWS checks=%d failures=%d images=%d "
				+ "technical_checks_carried=480 technical_checks_reexecuted=41 games=0"
			)
			% [_checks, _failures, _images.size()]
		)
	)
	return {"checks": _checks, "failures": _failures}


func _cv_capture(
	layout: Dictionary, checked: Dictionary, copies: Array[String], filename: String, title: String
) -> void:
	_phase = "close-view:" + filename
	var preview: StadiumDraftPreview = StadiumDraftPreview.new()
	add_child(preview)
	preview.size = Vector2(1280, 720)
	preview.build(layout, _cv_stock, true, "mogul")
	await get_tree().process_frame
	await get_tree().process_frame
	var property: StadiumPropertyGeometry = preview.preview_property
	_check(
		(
			property != null
			and property.props_intact()
			and not preview.night_eligible
			and property.objects.size() == 14
		),
		"ordinary Workshop builds all current paid mounts and hosts in daylight"
	)
	var exact: bool = property != null
	var box: AABB
	var first: bool = true
	var normal: Vector3 = Vector3.ZERO
	var selected: Array[Dictionary] = []
	for copy: String in copies:
		var row: Dictionary = {}
		for candidate: Dictionary in checked.mounted_display_placements:
			if candidate.copy == copy:
				row = candidate
		var model: Node3D = property.objects.get(copy) if property != null else null
		var host: Node3D = property.objects.get(row.get("host", "")) if property != null else null
		exact = (
			exact
			and not row.is_empty()
			and model != null
			and host != null
			and preview.board_bounds.has(copy)
		)
		if row.is_empty() or model == null or host == null:
			continue
		var actual: AABB = StadiumMountedDisplayItems.bounds(row)
		exact = (
			exact
			and preview.board_bounds[copy] == actual
			and model.get_meta("stadium_item") == row.item
		)
		if row.item == "ST-069":
			exact = (
				exact
				and (
					model.get_node("HourHandPivot").transform
					== StadiumMountedDisplayModels.hand_pose("hour", 47400)
				)
				and (
					model.get_node("MinuteHandPivot").transform
					== StadiumMountedDisplayModels.hand_pose("minute", 47400)
				)
			)
		box = actual if first else box.merge(actual)
		if first:
			normal = model.global_basis * Vector3.BACK
		first = false
		selected.append(
			{
				"copy": copy,
				"item": row.item,
				"host": row.host,
				"socket": row.socket,
				"bounds":
				[
					actual.position.x,
					actual.position.y,
					actual.position.z,
					actual.size.x,
					actual.size.y,
					actual.size.z
				]
			}
		)
	_check(
		exact and selected.size() == copies.size(),
		"selected mounts retain exact paid host identities and complete registered bounds"
	)
	preview.focus_copy(copies[0])
	var center: Vector3 = box.get_center()
	var radius: float = box.size.length() * 0.5
	var distance: float = radius / sin(deg_to_rad(preview.camera.fov * 0.5)) * 1.18
	preview.camera.position = center + normal.normalized() * distance
	preview.camera.look_at(center)
	preview.camera.reset_physics_interpolation()
	preview.camera.force_update_transform()
	var heading: CanvasLayer = CanvasLayer.new()
	preview.camera.get_viewport().add_child(heading)
	var backing: ColorRect = ColorRect.new()
	backing.position = Vector2(10, 10)
	backing.size = Vector2(1260, 72)
	backing.color = Color(0.035, 0.075, 0.09, 0.94)
	heading.add_child(backing)
	var label: Label = Label.new()
	label.position = Vector2(22, 18)
	label.add_theme_font_size_override("font_size", 22)
	label.text = (
		title + "\nActual Workshop property | synthetic paid fixture | no gameplay or audio benefit"
	)
	heading.add_child(label)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var viewport: Viewport = preview.camera.get_viewport()
	var rect: Rect2 = Rect2(12, 90, 1256, 618)
	var corners: Array[Dictionary] = []
	var glyph: Dictionary = {}
	for copy: String in copies:
		var mounted: Node3D = property.objects.get(copy)
		if mounted != null and mounted.get_meta("stadium_item", "") == "ST-069":
			for row: Dictionary in checked.mounted_display_placements:
				if row.copy == copy:
					glyph = _cv_glyph_report(
						property.objects.get(row.host), mounted, preview.camera, row.socket
					)
	var contained: bool = (
		(glyph.is_empty() or glyph.clear) and viewport.get_visible_rect().size == Vector2(1280, 720)
	)
	for index: int in range(8):
		var point: Vector3 = box.get_endpoint(index)
		var projected: Vector2 = preview.camera.unproject_position(point)
		var behind: bool = preview.camera.is_position_behind(point)
		corners.append(
			{"world": _md_v3(point), "pixel": [projected.x, projected.y], "behind": behind}
		)
		contained = contained and not behind and rect.has_point(projected)
	_md_operands = {
		"file": filename,
		"rect": [12, 90, 1256, 618],
		"corners": corners,
		"glyph_clearance": _cv_glyph_summary(glyph)
	}
	_check(
		contained,
		"all eight complete mounted reservation corners are visibly framed below the heading"
	)
	var lights: int = preview.find_children("*", "DirectionalLight3D", true, false).size()
	var environments: int = preview.find_children("*", "WorldEnvironment", true, false).size()
	_check(
		(
			property != null
			and property.props_intact()
			and ClubCareer.same(_cv_stock.to_data(), _cv_source.paid_inventory)
			and lights == 1
			and environments == 1
		),
		"capture preserves the whole property exact paid source and single ordinary preview lighting"
	)
	var original: Image = viewport.get_texture().get_image()
	var saved: bool = (
		original != null
		and original.get_size() == Vector2i(1280, 720)
		and original.save_png(_capture_dir.path_join(filename)) == OK
	)
	_check(saved, "native SubViewport close original saves at1280x720")
	if saved:
		_images.append(filename)
	_cv_views.append(
		{
			"file": filename,
			"selected": selected,
			"camera_position": _md_v3(preview.camera.position),
			"camera_target": _md_v3(center),
			"camera_fov": preview.camera.fov,
			"front_normal": _md_v3(normal),
			"readable_rect": [12, 90, 1256, 618],
			"all_corners_in_frame": contained,
			"corners": corners,
			"night_eligible": preview.night_eligible,
			"property_intact": property.props_intact(),
			"viewport_size": [1280, 720],
			"directional_lights": lights,
			"world_environments": environments,
			"studio_light_added": false,
			"clock_seconds_of_day": 47400,
			"glyph_clearance": glyph
		}
	)
	await RenderingServer.frame_post_draw
	preview.queue_free()
	await get_tree().process_frame


func _cv_clock_geometry() -> void:
	_phase = "affected-clock-geometry"
	var probe: Node3D = Node3D.new()
	probe.position = Vector3(2700, 0, 0)
	add_child(probe)
	var clock: Node3D = StadiumMountedDisplayModels.create("ST-069")
	_check(clock != null, "affected complete clock creates")
	var row: Dictionary = {}
	var start: int = _checks - 1
	if clock != null:
		probe.add_child(clock)
		row = await StadiumMountedDisplayGeometryRebuildChecks._common(
			probe, clock, "ST-069", _check
		)
		await StadiumMountedDisplayGeometryRebuildChecks._anatomy(clock, "ST-069", _check)
		StadiumMountedDisplayGeometryRebuildChecks._clock_poses(clock, _check)
		clock.free()
	var sockets: Array[Dictionary] = []
	var glyphs: Array[Dictionary] = []
	for raw: Dictionary in StadiumMountedDisplayModels.SOCKETS:
		if raw.item != "ST-069":
			continue
		sockets.append(
			await StadiumMountedDisplayGeometryRebuildChecks._socket_check(probe, raw, _check)
		)
		var host: Node3D = StadiumStraightOwnedModels.create(raw.host_item)
		var mounted: Node3D = StadiumMountedDisplayModels.create("ST-069")
		probe.add_child(host)
		probe.add_child(mounted)
		mounted.transform = StadiumMountedDisplayModels.socket(raw.host_item, "ST-069").transform
		var camera: Camera3D = Camera3D.new()
		probe.add_child(camera)
		camera.fov = 50.0
		var target: Vector3 = host.to_global(Vector3(0, raw.position.y, 0))
		camera.global_position = target + host.global_basis * Vector3(0, 0, 6)
		camera.look_at(target)
		camera.force_update_transform()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var glyph: Dictionary = _cv_glyph_report(host, mounted, camera, raw.id)
		_md_operands = _cv_glyph_summary(glyph)
		_check(
			glyph.clear,
			(
				"actual rendered host glyph bounds clear every complete clock member in world and "
				+ "front projection"
			)
		)
		glyphs.append(glyph)
		camera.free()
		mounted.free()
		host.free()
	_cv_clock_model = {
		"checks": _checks - start,
		"expected_checks": 43,
		"item": row,
		"sockets": sockets,
		"glyphs": glyphs,
		"unchanged_reservation":
		StadiumMountedDisplayGeometryRebuildChecks._box_array(
			StadiumMountedDisplayModels.envelope("ST-069")
		),
		"hand_center_y": 0.56,
		"time_semantics_changed": false
	}
	probe.free()


func _cv_projected_box(camera: Camera3D, box: AABB) -> Rect2:
	var result: Rect2 = Rect2(camera.unproject_position(box.get_endpoint(0)), Vector2.ZERO)
	for index: int in range(1, 8):
		result = result.expand(camera.unproject_position(box.get_endpoint(index)))
	return result


func _cv_glyph_report(
	host: Node3D, mounted: Node3D, camera: Camera3D, socket_id: String
) -> Dictionary:
	var labels: Array[Dictionary] = []
	var world_overlaps: Array[Dictionary] = []
	var projection_overlaps: Array[Dictionary] = []
	var members: Array[Node] = mounted.find_children("*", "MeshInstance3D", true, false)
	var complete: bool = (
		is_instance_valid(host) and is_instance_valid(mounted) and is_instance_valid(camera)
	)
	var pairs: int = 0
	for label: Label3D in host.find_children("*", "Label3D", true, false):
		var native: AABB = label.get_aabb()
		var world: AABB = label.global_transform * native
		var local: AABB = host.global_transform.affine_inverse() * world
		var plane: Rect2 = Rect2(
			Vector2(local.position.x, local.position.y), Vector2(local.size.x, local.size.y)
		)
		var projected: Rect2 = _cv_projected_box(camera, world)
		complete = (
			complete
			and native.size.x > 0
			and native.size.y > 0
			and projected.size.x > 0
			and projected.size.y > 0
		)
		labels.append(
			{
				"path": str(host.get_path_to(label)),
				"text": label.text,
				"host_bounds": StadiumMountedDisplayGeometryRebuildChecks._box_array(local),
				"world_bounds": StadiumMountedDisplayGeometryRebuildChecks._box_array(world),
				"pixel_rect":
				[projected.position.x, projected.position.y, projected.size.x, projected.size.y]
			}
		)
		for member: MeshInstance3D in members:
			pairs += 1
			var member_world: AABB = member.global_transform * member.mesh.get_aabb()
			var member_local: AABB = host.global_transform.affine_inverse() * member_world
			var member_plane: Rect2 = Rect2(
				Vector2(member_local.position.x, member_local.position.y),
				Vector2(member_local.size.x, member_local.size.y)
			)
			var member_projected: Rect2 = _cv_projected_box(camera, member_world)
			var operand: Dictionary = {
				"label": label.text,
				"member": str(mounted.get_path_to(member)),
				"member_host_bounds":
				StadiumMountedDisplayGeometryRebuildChecks._box_array(member_local)
			}
			if plane.intersects(member_plane):
				world_overlaps.append(operand)
			if projected.intersects(member_projected):
				projection_overlaps.append(operand)
	return {
		"host_item": str(host.get_meta("stadium_item")),
		"socket": socket_id,
		"label_count": labels.size(),
		"mounted_members": members.size(),
		"pairs": pairs,
		"world_overlaps": world_overlaps,
		"projection_overlaps": projection_overlaps,
		"labels": labels,
		"clear":
		(
			complete
			and not labels.is_empty()
			and members.size() == 36
			and world_overlaps.is_empty()
			and projection_overlaps.is_empty()
		)
	}


func _cv_glyph_summary(report: Dictionary) -> Dictionary:
	if report.is_empty():
		return {}
	var world: Array = report.get("world_overlaps", [])
	var projected: Array = report.get("projection_overlaps", [])
	return {
		"host_item": report.get("host_item", ""),
		"socket": report.get("socket", ""),
		"labels": report.get("label_count", 0),
		"members": report.get("mounted_members", 0),
		"world_overlap_count": world.size(),
		"projection_overlap_count": projected.size(),
		"first_world": world[0] if not world.is_empty() else {},
		"first_projection": projected[0] if not projected.is_empty() else {},
		"clear": report.get("clear", false)
	}
