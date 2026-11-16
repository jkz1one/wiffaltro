extends "res://src/tests/stadium_owned_outfield_plaza_test.gd"
## Native exact-paid low-wall/plaza composition, never a camera substitute.


func _buy(item: String, id: String, quantity: int, price: int) -> bool:
	var result: bool = super._buy(item, id, quantity, price)
	if not result or id != "plaza-kits":
		return result
	if not super._buy("ST-024", "low-plaza-standard", 23, 8):
		return false
	var low: Dictionary = _paid.commit(
		{
			"id": "low-plaza-pieces",
			"rev": _paid.revision(),
			"op": "stadium_wall_piece",
			"item": "ST-024-L",
			"quantity": 23,
			"price_version": 1,
			"through": credits.size(),
			"progress_through": progress.size()
		}
	)
	check(low.ok, "real paid low panel purchase " + low.error)
	return low.ok


func _views(layout_value: Dictionary, recipe: String) -> void:
	var low_layout: Dictionary = StadiumLowWallLayout.upgrade(layout_value, _paid.surface_owned())
	var suggested: Dictionary = StadiumLowWallManifest.suggest(
		_profile(recipe), "ST-024", _paid.construction(), _paid.wall_pieces().stock
	)
	check(suggested.ok, "exact low-flank profile owned")
	if not suggested.ok:
		return
	low_layout.low_wall = suggested.manifest
	if not _low_apply(low_layout):
		return
	await _capture_low_views(low_layout, recipe)
	check(_low_apply(layout_value), "explicit restore base after immutable native capture")


func _low_apply(layout: Dictionary) -> bool:
	var draft: Dictionary = _paid.commit(
		{
			"id": "low-view-draft-%d" % _paid.revision(),
			"rev": _paid.revision(),
			"op": "stadium_draft",
			"layout": layout
		}
	)
	check(draft.ok, "low plaza exact draft " + draft.error)
	if not draft.ok:
		return false
	var applied: Dictionary = _paid.commit(
		{
			"id": "low-view-apply-%d" % _paid.revision(),
			"rev": _paid.revision(),
			"op": "stadium_apply",
			"layout": layout,
			"geometry": StadiumOwnedLayout.geometry(_paid.view().land, layout)
		}
	)
	check(applied.ok, "low plaza exact apply " + applied.error)
	return applied.ok


func _capture_low_views(layout_value: Dictionary, recipe: String) -> void:
	var directory: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			directory = argument.trim_prefix("--ui-capture-dir=")
	if DisplayServer.get_name() == "headless":
		return
	if directory.is_empty():
		directory = ProjectSettings.globalize_path(
			(
				"res://../evidence/native-low-plaza-all-low"
				if _profile(recipe) == "low_outfield"
				else "res://../evidence/native-low-plaza"
			)
		)
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	PitchBatLabPresentation.hide_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._pitch_actor.set_physics_process(false)
	lab._primary_fielder.set_physics_process(false)
	lab._match_state.stadium = StadiumLayoutSnapshot.capture(_paid, true)
	lab._stadium_ledger = _paid
	var installed: bool = StadiumPropertyRuntime.install_bound(lab)
	check(
		installed and ClubCareer.same(lab._match_state.stadium.layout, layout_value),
		recipe + " native exact current paid snapshot"
	)
	if not installed:
		lab.queue_free()
		await get_tree().process_frame
		return
	var capture = preload("res://src/tests/stadium_mounted_scoreboard_capture_support.gd").new()
	add_child(capture)
	await capture.initialize()
	check(await capture.resize(Vector2i(1280, 720)), recipe + " native1280 handshake")
	lab._status_label.hide()
	lab._camera.make_current()
	check(
		await capture.capture(directory, recipe + "-ordinary-batting"),
		recipe + " actual batting view"
	)
	var camera: Camera3D = Camera3D.new()
	add_child(camera)
	camera.fov = 50
	camera.position = Vector3(48, 36, -5)
	camera.look_at(Vector3(0, 0, 29))
	camera.make_current()
	check(
		await capture.capture(directory, recipe + "-complete-park"),
		recipe + " complete field and concourse"
	)
	camera.position = Vector3(-38, 15, 21)
	camera.look_at(Vector3(-5, 1, 41))
	check(
		await capture.capture(directory, recipe + "-concourse-detail"),
		recipe + " actual connecting paving and landmark pads"
	)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 104
	camera.position = Vector3(0, 80, 14)
	camera.look_at(Vector3(0, 0, 14), Vector3.FORWARD)
	check(
		await capture.capture(directory, recipe + "-overhead"),
		recipe + " native overhead full property"
	)
	check(
		(lab.get_meta("stadium_property") as StadiumPropertyGeometry).props_intact(),
		recipe + " captures preserve installed resource seal"
	)
	camera.free()
	capture.free()
	lab.queue_free()
	await get_tree().process_frame


func _profile(_recipe: String) -> String:
	return "low_flanks"
