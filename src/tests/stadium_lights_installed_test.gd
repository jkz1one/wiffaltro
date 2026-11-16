extends "res://src/tests/stadium_yard_tracking_test.gd"
## Dense supported installed geometry through the same day/night tracking diagnostics.


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	get_window().size = Vector2i(1280, 720)
	for left: bool in [false, true]:
		await _track(left)
		await _pitch_views(left)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro installed light checks passed: dense geometry, real pitch flight and tracking.")
	get_tree().quit(0 if _failures == 0 else 1)


func _install_tracking(lab: PitchBatLab) -> Array[Node3D]:
	var stock: StadiumStock = StadiumStock.new_club()
	var layout: Dictionary = StadiumLightItems.upgrade(StadiumStarterLayout.empty())
	layout.obstacles = [{"copy": "starter-v1:ST-001", "site": "O-L1", "yaw": 0},
		{"copy": "starter-v1:ST-003", "site": "O-R1", "yaw": 90}]
	layout.obstacles.insert(1, {"copy": _copy(stock, "ST-003", "live-left"),
		"site": "O-L2", "yaw": 0})
	layout.obstacles.append({"copy": _copy(stock, "ST-003", "live-right"),
		"site": "O-R2", "yaw": 270})
	layout.target = _copy(stock, "ST-026", "target")
	layout.net = _copy(stock, "ST-025", "net")
	layout.bleachers = [{"copy": _copy(stock, "ST-028", "bleacher"), "site": "SIDE-SEAT-L"}]
	layout.seating = []
	for index in range(1, 4):
		layout.seating.append({"copy": _copy(stock, "ST-080", "chair%d" % index),
			"site": "SC-R%d" % index})
	for site: String in StadiumClubSites.SITES:
		layout.displays.append({"copy": _copy(stock, StadiumClubSites.SITES[site].item, site),
			"site": site})
	layout.displays.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.site < b.site)
	for site: String in StadiumYardLightModels.SITES:
		layout.lights.append({"copy": _copy(stock, "ST-037", site), "site": site})
	layout.lights.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.site < b.site)
	stock.styles.assign(["ST-062b", "ST-063c", "ST-063f"])
	layout.styles = {"line": "ST-062b", "grass": "ST-063c"}
	layout.ground = "ST-063f"
	layout = _author_surface(layout, stock)
	var snapshot: Dictionary = _fixture_snapshot(layout, stock)
	_check(StadiumLayoutSnapshot.valid(snapshot), "dense structural fixture validates")
	_check(StadiumHomeLayout.validate(layout, stock, "expanded").get("night_qualified", false)
		== _night_expected(),
		"dense supported preset remains eligible")
	lab._match_state.stadium = snapshot
	_check(StadiumPropertyRuntime.install_bound(lab), "full dense property installed")
	var property: StadiumPropertyGeometry = lab.get_meta("stadium_property")
	var lamps: Array[Node3D] = []
	for model: Node3D in property.objects.values():
		if model.get_meta("stadium_item") == "ST-037":
			lamps.append(model)
	return lamps


func _copy(stock: StadiumStock, item: String, suffix: String) -> String:
	if not stock.blueprints.has(item):
		stock.blueprints.append(item)
		stock.blueprints.sort()
	var id: String = "purchase:installed-fixture:" + suffix
	stock.copies[id] = {"item": item, "paid": StadiumCatalog.item(item).copy_price,
		"source": "purchase-v1"}
	return id


func _pitch_views(left: bool) -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._status_label.visible = false
	var lamps: Array[Node3D] = _install_tracking(lab)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_coverage(lamps)
	lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
	lab._match_state.batter().definition.bats = PlayerDefinition.Handedness.LEFT if left \
		else PlayerDefinition.Handedness.RIGHT
	PitchBatLabPresentation.sync_players(lab)
	lab._camera_director.set_batter_handedness(left)
	var actor: PitchFlightActor = PitchFlightActor.new()
	lab.add_child(actor)
	actor.set_physics_process(false)
	var ball: BallSetupDefinition = ContentDB.get_ball_setup(&"ball_setup.fresh")
	var player: PlayerDefinition = ContentDB.get_player(&"player.debug_pitcher")
	var contrasts: Dictionary = {}
	var flights: Dictionary = {}
	var samples: int = 0
	for dark: bool in [false, true]:
		if dark:
			_night_scene(lab)
			StadiumNightBallStyle.apply(actor)
		for lamp: Node3D in lamps:
			StadiumYardLightModels.night(lamp, dark)
		for defense: bool in [false, true]:
			lab._camera_director.set_shot(MatchCameraDirector.Shot.PITCHING if defense \
				else MatchCameraDirector.Shot.BATTING)
			lab._camera_director.snap(lab._camera)
			StadiumPropertyRuntime.refresh_receiver_visibility(lab)
			for pitch: PitchDefinition in ContentDB.pitch_by_id.values():
				var rated: PitchDefinition = MatchLabSupport.rated_pitch(pitch, player, 1.0)
				var launch: PitchLaunchParameters = PitchAimSolver.solve(rated, ball,
					PitchBatLab.MOUND_ORIGIN, Vector3(0, 1.05, 0), left, 41)
				_check(launch != null, "pitch visibility fixture solves " + String(pitch.id))
				if launch == null:
					continue
				actor.start_pitch(launch)
				var points: Array[Vector3] = []
				var depths: Array[float] = [8.0, 4.0, 1.0]
				while actor.running:
					actor._physics_process(1.0 / 240)
					if not actor.running:
						break
					samples += 1
					points.append(actor.global_position)
					_check(not lab._camera.is_position_behind(actor.global_position)
						and lab._camera.get_viewport().get_visible_rect().has_point(
							lab._camera.unproject_position(actor.global_position)),
						"actual pitch flight remains framed")
					if not depths.is_empty() and actor.global_position.z <= depths[0]:
						var depth: float = depths.pop_front()
						if DisplayServer.get_name() != "headless":
							var value: float = await _contrast(lab._camera, actor)
							var key: String = str(defense) + str(pitch.id) + str(depth)
							if dark:
								print("PITCH_CONTRAST ", left, " ", key, " day=", contrasts[key],
									" night=", value)
								if value < maxf(0.03, contrasts[key] * 0.65):
									await _shot("pitch-contrast-" + str(left) + key)
								_check(value >= maxf(0.03, contrasts[key] * 0.65),
									"sampled real night pitch remains distinguishable")
							else:
								contrasts[key] = value
				var flight_id: String = str(defense) + str(pitch.id)
				if dark:
					_check(points == flights[flight_id], "night visuals preserve every pitch sample")
				else:
					flights[flight_id] = points
				actor.reset_pitch()
	print("INSTALLED_PITCH_SAMPLES hand=", left, " samples=", samples)
	_check(samples > 1000, "all authored pitch identities exercised through actual flight actor")
	lab.queue_free()
	await get_tree().process_frame


func _coverage(lamps: Array[Node3D]) -> void:
	var samples: int = 0
	var unlit: int = 0
	for x in range(-23, 24, 2):
		for z in range(-5, 24, 2):
			if not Geometry2D.is_point_in_polygon(Vector2(x, z),
				PackedVector2Array(StadiumBoundaryGraph.VERTICES)):
				continue
			for height: float in [0.2, 1.05, 3.0, 6.0, 10.0]:
				unlit += int(StadiumYardNightPrototype.coverage(Vector3(x, height, z), lamps) == 0)
				samples += 1
	print("INSTALLED_COVERAGE samples=", samples, " unlit=", unlit)
	_check(samples > 1000 and unlit == 0, "dense installed field has sampled open light beams")


func _author_surface(layout: Dictionary, _stock: StadiumStock) -> Dictionary:
	return layout


func _night_expected() -> bool:
	return true


func _fixture_snapshot(layout: Dictionary, stock: StadiumStock) -> Dictionary:
	return {"version": 4, "tier": "expanded", "revision": 0,
		"layout": layout, "inventory": stock.to_data(),
		"geometry": StadiumHomeLayout.geometry("expanded", layout),
		"boundary": StadiumBoundaryGraph.signature()}
