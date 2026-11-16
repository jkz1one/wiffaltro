extends "res://src/tests/club_career_test.gd"
## Current/legacy entry, matching previews and immutable active-season saves.


func _ready() -> void:
	SeasonSave.path = "user://stadium-boundary-save-%d.json" % OS.get_process_id()
	var path: String = SeasonSave.path
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.begin_season(141, true, true, true, false)
	var old: SeasonState = app.season
	_check(old.home_property.version == 1 and not old.home_property.has("boundary"),
		"explicit historical field keeps its original snapshot contract")
	var layout: Dictionary = StadiumStarterLayout.empty()
	layout.receiver = "starter-v1:ST-079"
	layout.obstacles = [{"copy": "starter-v1:ST-001", "site": "O-L1", "yaw": 0}]
	_check(ClubConstruction.save_draft(old, layout, 0).ok
		and ClubConstruction.apply_draft(old, layout, 1).ok, "old pre-draft layout can still remodel")
	_check(old.home_property.version == 1 and not old.home_property.has("boundary"),
		"remodel does not silently upgrade an existing old field")
	var old_data: Dictionary = SeasonSave.snapshot(old)
	var old_key: String = StadiumLayoutSnapshot.key(old.home_property)
	StadiumEditorUI.show(app.menu)
	_check(not _preview_has_boundary(app), "old season preview matches its actual old geometry")
	var bytes: String = FileAccess.get_file_as_string(path)
	SeasonSave.path = path + "/missing/profile.json"
	app.begin_season(142, true)
	_check(app.season == old and StadiumLayoutSnapshot.key(old.home_property) == old_key
		and FileAccess.get_file_as_string(path) == bytes, "failed upgrade preserves old field and save")
	SeasonSave.path = path
	app.begin_season(142, true)
	var current: SeasonState = app.season
	_check(current != old and current.home_property.version == 3
		and current.home_property.boundary == StadiumBoundaryGraph.signature(),
		"new owned Working season selects the known complete template")
	_check(ClubCareer.same(current.home_property.layout, layout)
		and ClubPlayers.assets(current.career).construction().copies.size() == 3
		and current.career.balance() == 0, "new template preserves exact objects and grants no purchases")
	_check(StadiumLayoutSnapshot.key(SeasonSave._decode(old_data).home_property) == old_key,
		"new implementation still restores the original old field byte identity")
	StadiumEditorUI.show(app.menu)
	_check(_preview_has_boundary(app), "new season preview and live field use the same complete graph")
	var saved: Dictionary = SeasonSave.snapshot(current)
	for field: String in ["boundary", "inventory", "geometry"]:
		for wrong: Variant in [false, "unknown", null]:
			var bad: Dictionary = saved.duplicate(true)
			bad.home_property[field] = wrong
			_check(SeasonSave._decode(bad) == null, "malformed current field rejects: " + field)
	var bad: Dictionary = saved.duplicate(true)
	bad.home_property.erase("boundary")
	_check(SeasonSave._decode(bad) == null, "current snapshot cannot omit its full boundary binding")
	bad = saved.duplicate(true)
	bad.home_property.version = 2
	_check(SeasonSave._decode(bad) == null, "legacy snapshot cannot smuggle a new boundary")
	var key: String = StadiumLayoutSnapshot.key(current.home_property)
	app.choose_player(current.offers()[0])
	_check(not ClubConstruction.apply_draft(current, StadiumStarterLayout.empty(), 2).ok
		and StadiumLayoutSnapshot.key(current.home_property) == key, "first pick locks the full graph")
	current = SeasonSave.restore()
	_check(current != null and StadiumLayoutSnapshot.key(current.home_property) == key,
		"save/restart keeps the complete field, ownership and entry revision")
	app.queue_free()
	await _frames()
	_cleanup()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro boundary save checks passed: legacy preservation and exact current entry.")
	get_tree().quit(0 if _failures == 0 else 1)


func _preview_has_boundary(app: SeasonApp) -> bool:
	for child: Node in app.menu._body.get_children():
		if child is StadiumDraftPreview:
			var viewport: SubViewport = child.get_child(0)
			for geometry: Node in viewport.get_child(0).get_children():
				if geometry is StadiumPropertyGeometry:
					return geometry.has_node("BoundaryGraph")
	return false
