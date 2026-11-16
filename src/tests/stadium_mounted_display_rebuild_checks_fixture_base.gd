extends "res://src/tests/equipment_visual_rebuild_checks.gd"
## One bounded native qualification. Synthetic funding/progression; zero completed games.
## All ownership journals and views are isolated from the user's career.

const MD_SEED: int = 162
const MD_ROUTES: Array[Dictionary] = [
	{
		"case": "upper-ribbon",
		"item": "ST-068",
		"index": 0,
		"host_item": "ST-030",
		"socket": "RIBBON-STRAIGHT-UPPER",
		"host_index": 0,
		"spare_index": 1,
		"host_site": "BASE-L1",
		"support_index": 0
	},
	{
		"case": "concourse-ribbon",
		"item": "ST-068",
		"index": 1,
		"host_item": "ST-031",
		"socket": "RIBBON-STRAIGHT-CONCOURSE",
		"host_index": 1,
		"spare_index": 2,
		"host_site": "BASE-R1",
		"support_index": 1
	},
	{
		"case": "gate-pa",
		"item": "ST-070",
		"index": 0,
		"host_item": "ST-035",
		"socket": "PA-GATE-RIGHT",
		"host_index": 0,
		"spare_index": 1,
		"host_site": "ENTRY-GATE",
		"support_index": 0
	},
	{
		"case": "manual-pa",
		"item": "ST-070",
		"index": 1,
		"host_item": "ST-039",
		"socket": "PA-MANUAL-RIGHT",
		"host_index": 0,
		"spare_index": 1,
		"host_site": "SCORE-SMALL",
		"support_index": 0
	},
	{
		"case": "gate-clock",
		"item": "ST-069",
		"index": 0,
		"host_item": "ST-035",
		"socket": "CLOCK-GATE-CENTER",
		"host_index": 0,
		"spare_index": 1,
		"host_site": "ENTRY-GATE",
		"support_index": 0
	},
	{
		"case": "manual-clock",
		"item": "ST-069",
		"index": 1,
		"host_item": "ST-039",
		"socket": "CLOCK-MANUAL-HEADER",
		"host_index": 0,
		"spare_index": 1,
		"host_site": "SCORE-SMALL",
		"support_index": 0
	},
]
const MD_EXPECTED_HITS: Dictionary = {
	"bare_host_refusal": 6,
	"below_gate": 6,
	"camera_clearance": 4,
	"capture_containment": 2,
	"catalog_terms": 3,
	"clock_advance": 1,
	"clock_duplicate": 1,
	"clock_hand_angle": 10,
	"clock_hand_lease": 4,
	"clock_hold": 4,
	"clock_invalid": 10,
	"clock_invalid_hand": 3,
	"clock_mapping": 5,
	"clock_owner": 1,
	"clock_restore": 1,
	"clock_retirement": 1,
	"clock_twelve_hour_wrap": 1,
	"combined_apply": 1,
	"directory": 1,
	"draft_apply_retry": 1,
	"evidence_cap": 1,
	"evidence_open": 1,
	"exact_count": 1,
	"final_inventory": 1,
	"geometry_count": 1,
	"host_assembly": 7,
	"host_row_preserved": 6,
	"hosts_apply": 1,
	"images": 1,
	"immutable_refusal": 27,
	"inherited_apply": 1,
	"installed_final": 1,
	"installed_intact": 1,
	"installed_parents": 6,
	"installed_support": 6,
	"land": 3,
	"lifecycle_free": 6,
	"malformed_row": 9,
	"mount_apply": 6,
	"native_entry": 1,
	"no_live_budget": 1,
	"old_price": 3,
	"ordinary_install": 1,
	"ordinary_lighting": 2,
	"paid_inventory": 1,
	"purchase_charge": 9,
	"purchase_identity": 9,
	"purchase_replay": 9,
	"remount": 6,
	"restore_host": 6,
	"runtime_identity": 6,
	"runtime_roles": 6,
	"runtime_seal": 6,
	"runtime_tracking": 6,
	"same_select": 6,
	"silent_static": 6,
	"snapshot": 1,
	"starter_inventory": 1,
	"store_apply": 6,
	"store_first_remove": 6,
	"strict_cold": 1,
	"synthetic_metrics": 1,
	"threshold_quote": 3,
	"tier_gate": 24,
	"unsupported_family": 2,
	"upgrade": 1,
	"warm_checkpoint": 14,
	"whole_reservation": 6,
	"workshop_build": 6,
	"workshop_focus": 6,
	"wrong_copy": 3,
	"zero_game": 1
}  # Source-derived exact success-path assertion multiplicities.
# Named assertions plus four native image checks and158 geometry assertions.
const MD_EXPECTED_CHECKS: int = 480
var _md_operands: Dictionary = {}
var _md_hits: Dictionary = {}
var _md_ledger: ClubAssetLedger
var _md_credits: Array = []
var _md_progress: Array = []
var _md_copies: Dictionary = {}
var _md_empty: Dictionary = {}
var _md_hosts: Dictionary = {}
var _md_layout: Dictionary = {}
var _md_snapshot: Dictionary = {}
var _md_prefix: Dictionary = {}
var _md_receipts: Array[Dictionary] = []
var _md_lifecycle: Array[Dictionary] = []
var _md_refusals: Array[Dictionary] = []
var _md_fit: Array[Dictionary] = []
var _md_runtime: Array[Dictionary] = []
var _md_support: Array[Dictionary] = []
var _md_cameras: Array[Dictionary] = []
var _md_focus: Array[Dictionary] = []
var _md_views: Array[Dictionary] = []
var _md_geometry: Dictionary = {}
var _md_clock: Dictionary = {}
var _md_model_checks: int = 0
var _md_phase_counts: Dictionary = {}
var _md_last_draft: Dictionary = {}
var _md_last_apply: Dictionary = {}


func _check(ok: bool, message: String) -> void:
	if not ok:
		print(
			(
				"MOUNTED_DISPLAY_FAILURE "
				+ JSON.stringify(
					{"phase": _phase, "message": message, "operands": _md_operands}, "", true, true
				)
			)
		)
	super._check(ok, message)


func _md_assert(id: String, ok: bool, message: String) -> void:
	_md_hits[id] = int(_md_hits.get(id, 0)) + 1
	_check(ok, message)


func _md_clock_math() -> void:
	_phase = "simulation-clock-exact-mapping-types-range-wrap-and-hands"
	var table: Array[Dictionary] = []
	for input: Array in [
		["day", 0, 0, 0, 47400],
		["day", 1, 0, 15, 47415],
		["day", 1, 1, 135, 47535],
		["day", 100000, 10000, 21600, 69000],
		["night", 100000, 10000, 21600, 4200]
	]:
		var value: Dictionary = StadiumMountedClockRuntime.time_values(input[0], input[1], input[2])
		var expected_hour: float = -TAU * float(input[4] % 43200) / 43200.0
		var expected_minute: float = -TAU * float(input[4] % 3600) / 3600.0
		_md_assert(
			"clock_mapping",
			(
				value.get("rule", "") == "completed-play-half-v1"
				and value.get("mode", "") == input[0]
				and value.get("completed_plays", -1) == input[1]
				and value.get("completed_halves", -1) == input[2]
				and value.get("elapsed_seconds", -1) == input[3]
				and value.get("seconds_of_day", -1) == input[4]
				and value.get("hour_radians", INF) == expected_hour
				and value.get("minute_radians", INF) == expected_minute
			),
			"existing clock mapping obeys exact play/half offsets cap and midnight wrap"
		)
		table.append(value)
		for hand: String in ["hour", "minute"]:
			var pose: Transform3D = StadiumMountedDisplayModels.hand_pose(hand, input[4])
			var expected: Transform3D = Transform3D(
				Basis(Vector3.BACK, expected_hour if hand == "hour" else expected_minute),
				Vector3(0, 0.52, 0.362 if hand == "hour" else 0.374)
			)
			_md_assert(
				"clock_hand_angle",
				pose == expected and pose.basis.determinant() > 0.9999,
				"independent exact continuous hour/minute hand angle and original rigid pivot"
			)
	var invalid: Array[Dictionary] = []
	for input: Array in [
		["unknown", 0, 0],
		[true, 0, 0],
		["day", true, 0],
		["day", -1, 0],
		["day", 100001, 0],
		["day", 0.5, 0],
		["day", 0, true],
		["day", 0, -1],
		["day", 0, 10001],
		["day", 0, 0.5]
	]:
		var rejected: bool = (
			StadiumMountedClockRuntime.time_values(input[0], input[1], input[2]).is_empty()
		)
		_md_assert(
			"clock_invalid",
			rejected,
			"malformed clock mode or non-whole out-of-range count refuses"
		)
		invalid.append(
			{"mode": input[0], "plays": input[1], "halves": input[2], "rejected": rejected}
		)
	for input: Array in [["second", 0], ["hour", -1], ["minute", 86400]]:
		_md_assert(
			"clock_invalid_hand",
			StadiumMountedDisplayModels.hand_pose(input[0], input[1]) == Transform3D.IDENTITY,
			"unknown hand or out-of-day pose request is not applied"
		)
	_md_assert(
		"clock_twelve_hour_wrap",
		(
			(
				StadiumMountedDisplayModels.hand_pose("hour", 0)
				== StadiumMountedDisplayModels.hand_pose("hour", 43200)
			)
			and (
				StadiumMountedDisplayModels.hand_pose("minute", 0)
				== StadiumMountedDisplayModels.hand_pose("minute", 3600)
			)
		),
		"twelve-hour and sixty-minute wraps preserve exact hand positions"
	)
	_md_clock = {
		"mapping": table,
		"invalid_inputs": invalid,
		"native": {},
		"machine_clock_used": false,
		"native_clock_scope":
		"Day only; night mapping row is a pure wrap oracle and grants no Night admission."
	}


func _md_host(
	layout: Dictionary,
	item: String,
	copy: String,
	remove: bool = false,
	site: String = "BASE-L1",
	support_index: int = 0
) -> Dictionary:
	if item == "ST-039":
		var result: Dictionary = layout.duplicate(true)
		result.displays = result.displays.filter(
			func(row: Dictionary) -> bool:
				return row.copy != copy and (remove or row.site != "SCORE-SMALL")
		)
		if not remove:
			result.displays.append({"copy": copy, "site": "SCORE-SMALL"})
		result.displays.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool: return a.site < b.site
		)
		return result
	var row: Dictionary = {
		"copy": "", "site": "ENTRY-GATE" if item == "ST-035" else site, "lower": "", "concourse": ""
	}
	if item in ["ST-030", "ST-031"]:
		row.lower = _md_copies["ST-029"][support_index]
	if item == "ST-030":
		row.concourse = _md_copies["ST-031"][support_index]
	return StadiumStraightItemsUI.select(
		layout, _md_ledger.construction(), copy, {} if remove else row
	)


func _md_place(layout: Dictionary, route: Dictionary, host_index: int = -1) -> Dictionary:
	return StadiumMountedDisplayItems.place(
		layout,
		_md_ledger.construction(),
		_md_copies[route.item][route.index],
		_md_copies[route.host_item][route.host_index if host_index < 0 else host_index],
		route.socket,
		_md_ledger.surface_owned()
	)


func _md_validate(layout: Dictionary, tier: String = "mogul") -> Dictionary:
	var result: Dictionary = StadiumHomeLayout.validate(layout, _md_ledger.construction(), tier)
	_md_operands = {
		"tier": tier,
		"version": layout.get("version", -1),
		"error": result.get("error", ""),
		"mounts": layout.get("mounted_displays", [])
	}
	return result


func _md_fit_checks() -> void:
	_phase = "exact-host-property-and-whole-mount-reservations"
	for route: Dictionary in MD_ROUTES:
		var isolated: Dictionary = _md_empty.duplicate(true)
		for item: String in (
			["ST-029", "ST-031", "ST-030"]
			if route.host_item in ["ST-030", "ST-031"]
			else [route.host_item]
		):
			if route.host_item == "ST-031" and item == "ST-030":
				continue
			isolated = _md_host(
				isolated,
				item,
				_md_copies[item][
					route.support_index if item in ["ST-029", "ST-031"] else route.host_index
				],
				false,
				route.host_site,
				route.support_index
			)
		isolated = _md_place(isolated, route)
		for tier: String in ["backyard", "expanded", "club", "mogul"]:
			var checked: Dictionary = _md_validate(isolated, tier)
			var eligible: bool = (
				tier == "mogul"
				if route.host_item == "ST-035"
				else (
					tier in ["expanded", "club", "mogul"]
					if route.host_item == "ST-039"
					else tier in ["club", "mogul"]
				)
			)
			_md_assert(
				"tier_gate",
				checked.ok == eligible,
				(
					"whole mounted assembly obeys original host property gate "
					+ route.case
					+ ":"
					+ tier
				)
			)
			_md_fit.append(
				{
					"case": route.case,
					"tier": tier,
					"eligible": eligible,
					"accepted": checked.ok,
					"error": checked.get("error", "")
				}
			)
		var checked: Dictionary = _md_validate(isolated)
		if not checked.ok or checked.get("mounted_display_placements", []).size() != 1:
			_md_assert("fit_setup", false, "finite single mount fit setup is valid")
			return
		var row: Dictionary = checked.mounted_display_placements[0]
		var pose: Transform3D = Transform3D(
			Basis(Vector3.UP, deg_to_rad(float(row.yaw))), row.position
		)
		var bounds: AABB = pose * StadiumMountedDisplayModels.envelope(row.item)
		_md_assert(
			"whole_reservation",
			(
				pose.basis.determinant() > 0.9999
				and pose.basis.get_scale().is_equal_approx(Vector3.ONE)
				and StadiumProperty.contains("mogul", bounds)
				and StadiumClubSites._outside(bounds)
			),
			"whole mount remains rigid full-size and outside live play " + route.case
		)


func _md_project_rect(camera: Camera3D, box: AABB) -> Rect2:
	var result: Rect2 = Rect2()
	var started: bool = false
	for index: int in range(8):
		var point: Vector3 = box.get_endpoint(index)
		if camera.is_position_behind(point):
			continue
		var pixel: Vector2 = camera.unproject_position(point)
		result = result.expand(pixel) if started else Rect2(pixel, Vector2.ZERO)
		started = true
	return result


func _md_v3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _md_camera_clearance(lab: PitchBatLab, property: StadiumPropertyGeometry, rows: Array) -> void:
	var director: MatchCameraDirector = lab._camera_director
	var old_side: float = director._batter_side
	var old_shot: MatchCameraDirector.Shot = director.shot
	var old_motion: MatchCameraDirector.PresentationMotion = director._presentation_motion
	var old_progress: float = director._presentation_progress
	var old_pose: Transform3D = lab._camera.transform
	for left: bool in [false, true]:
		for zoom: bool in [false, true]:
			director.set_batter_handedness(left)
			director.set_shot(MatchCameraDirector.Shot.BATTING)
			director.set_presentation_motion(
				(
					MatchCameraDirector.PresentationMotion.ZOOM_IN
					if zoom
					else MatchCameraDirector.PresentationMotion.STILL
				),
				1.0
			)
			var pose: Transform3D = director._desired_transform(PitchBatLab.MOUND_ORIGIN, 0.0)
			lab._camera.transform = pose
			director._apply_projection(lab._camera)
			lab._camera.reset_physics_interpolation()
			lab._camera.force_update_transform()
			await RenderingServer.frame_post_draw
			var protected: Rect2 = (
				_md_project_rect(
					lab._camera,
					AABB(PitchBatLab.MOUND_ORIGIN + Vector3(-1.6, 0, -0.8), Vector3(3.2, 3.6, 1.6))
				)
				. grow(16)
			)
			var clear: bool = true
			var blocked: bool = false
			var visible: int = 0
			var count: int = 0
			var target: Vector3 = PitchBatLab.MOUND_ORIGIN + Vector3.UP
			for row: Dictionary in rows:
				var model: Node3D = property.objects[row.copy]
				var reserve: AABB = (
					model.global_transform * StadiumMountedDisplayModels.envelope(row.item)
				)
				blocked = (
					blocked
					or reserve.has_point(pose.origin)
					or reserve.intersects_segment(pose.origin, target) != null
				)
				for node: Node in model.get_node("Visual").find_children(
					"*", "MeshInstance3D", true, false
				):
					var mesh: MeshInstance3D = node as MeshInstance3D
					count += 1
					var projected: Rect2 = _md_project_rect(
						lab._camera, mesh.global_transform * mesh.get_aabb()
					)
					if projected.has_area():
						visible += 1
						clear = clear and not projected.intersects(protected)
			_md_operands = {
				"left_handed": left,
				"zoom_in": zoom,
				"eye": _md_v3(pose.origin),
				"pitcher_target": _md_v3(target),
				"blocked": blocked,
				"backdrop_clear": clear,
				"visible_meshes": visible,
				"checked_meshes": count
			}
			_md_assert(
				"camera_clearance",
				not blocked and clear and protected.has_area(),
				"ordinary normal and zoom batting camera clears every complete mount and pitcher backdrop"
			)
			_md_cameras.append(_md_operands.duplicate(true))
	director._batter_side = old_side
	director.shot = old_shot
	director._presentation_motion = old_motion
	director._presentation_progress = old_progress
	lab._camera.transform = old_pose
	director._apply_projection(lab._camera)
	lab._camera.reset_physics_interpolation()
	lab._camera.force_update_transform()


func _md_in_frame(camera: Camera3D, box: AABB) -> bool:
	var readable: Rect2 = Rect2(12, 110, 1256, 565)
	for index: int in range(8):
		var point: Vector3 = box.get_endpoint(index)
		if (
			camera.is_position_behind(point)
			or not readable.has_point(camera.unproject_position(point))
		):
			return false
	return true


func _md_capture_view(root: Node3D, property: StadiumPropertyGeometry, details: bool) -> void:
	_phase = "original-native-details" if details else "original-native-overview"
	var lights: Array[Node] = root.find_children("*", "DirectionalLight3D", true, false)
	var environments: Array[Node] = root.find_children("*", "WorldEnvironment", true, false)
	var sun: DirectionalLight3D = lights[0] as DirectionalLight3D if lights.size() == 1 else null
	var world: WorldEnvironment = (
		environments[0] as WorldEnvironment if environments.size() == 1 else null
	)
	var selected: Array[String] = []
	for row: Dictionary in MD_ROUTES:
		if not details or row.case in ["upper-ribbon", "manual-pa", "manual-clock"]:
			selected.append(_md_copies[row.item][row.index])
	var complete: AABB = AABB()
	var started: bool = false
	for copy: String in selected:
		var model: Node3D = property.objects[copy]
		var box: AABB = (
			model.global_transform
			* StadiumMountedDisplayModels.envelope(model.get_meta("stadium_item"))
		)
		complete = complete.merge(box) if started else box
		started = true
	var camera: Camera3D = Camera3D.new()
	root.add_child(camera)
	var target: Vector3 = complete.get_center() + Vector3.UP * 2.5
	camera.position = target + (Vector3(-36, 24, -32) if details else Vector3(65, 56, -65))
	camera.look_at(target)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 30 if details else 82
	camera.make_current()
	camera.reset_physics_interpolation()
	camera.force_update_transform()
	for attempt: int in range(12):
		if _md_in_frame(camera, complete):
			break
		camera.size *= 1.10
	var heading: ColorRect = ColorRect.new()
	heading.position = Vector2(10, 10)
	heading.size = Vector2(1260, 94)
	heading.color = Color(0.06, 0.10, 0.13, 0.94)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(heading)
	var labels: Array[Node] = []
	for text_row: Array in [
		[
			"MOUNTED DISPLAYS | Separately paid straight ribbon, simulation clock and silent PA",
			18,
			23
		],
		[
			(
				"Exact named host sockets | complete brackets and supports | ordinary daylight | six "
				+ "installed copies"
			),
			50,
			16
		],
		[
			(
				"Synthetic funding/progression | 0 games | no audio, gameplay, Night or final-art "
				+ "acceptance claim"
			),
			77,
			16
		]
	]:
		var label: Label = Label.new()
		label.text = text_row[0]
		label.position = Vector2(22, text_row[1])
		label.add_theme_font_size_override("font_size", text_row[2])
		root.add_child(label)
		labels.append(label)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_md_assert(
		"ordinary_lighting",
		(
			lights.size() == 1
			and environments.size() == 1
			and sun != null
			and world != null
			and str(sun.name) == "Sun"
			and str(world.name) == "LabWorldEnvironment"
		),
		"original capture uses one ordinary Sun and environment without studio additions"
	)
	_md_assert(
		"capture_containment",
		_md_in_frame(camera, complete) and property.props_intact(),
		"original view contains complete selected unchanged owned mounts below backed heading"
	)
	var filename: String = (
		"mounted-display-details.png" if details else "mounted-display-overview.png"
	)
	await _capture(filename)
	_md_views.append(
		{
			"file": filename,
			"framed_copies": selected,
			"camera_position": _md_v3(camera.position),
			"camera_target": _md_v3(target),
			"camera_size": camera.size,
			"directional_lights": lights.size(),
			"world_environments": environments.size(),
			"sun_name": str(sun.name) if sun != null else "",
			"sun_energy": sun.light_energy if sun != null else -1.0,
			"environment_name": str(world.name) if world != null else "",
			"ambient_energy": world.environment.ambient_light_energy if world != null else -1.0,
			"tonemap_mode": world.environment.tonemap_mode if world != null else -1,
			"tonemap_exposure": world.environment.tonemap_exposure if world != null else -1.0,
			"studio_light_added": false,
			"heading_backing_rect": [10, 10, 1260, 94]
		}
	)
	for label: Node in labels:
		label.queue_free()
	heading.queue_free()
	camera.queue_free()
	await get_tree().process_frame


func _md_clock_native(lab: PitchBatLab, property: StadiumPropertyGeometry) -> void:
	_phase = "native-simulation-clock-pause-hold-and-sticky-retirement"
	var owner: StadiumMountedClockRuntime = StadiumMountedClockRuntime.current(lab)
	_md_assert(
		"clock_owner",
		owner != null and owner.intact() and owner.clock_value().seconds_of_day == 47400,
		"ordinary current paid clocks bind one intact day13:10 owner"
	)
	if owner == null or not owner.intact():
		return
	var before: Dictionary = owner.clock_value()
	var state: MatchState = lab._match_state
	var old_phase: MatchState.Phase = state.phase
	var old_inning: int = state.inning
	var old_half: bool = state.top_half
	var old_running: bool = lab._pitch_actor.running
	state.inning = 1
	# Synthetic presentation half-transition; no PlayRecord or game is invented.
	state.top_half = false
	state.phase = MatchState.Phase.PRE_PITCH
	var holds: Array[Dictionary] = []
	for kind: String in ["pause", "pitch-phase", "flight-phase", "running-pitch"]:
		state.phase = (
			MatchState.Phase.PITCH_IN_FLIGHT
			if kind == "pitch-phase"
			else (
				MatchState.Phase.BALL_IN_PLAY
				if kind == "flight-phase"
				else MatchState.Phase.PRE_PITCH
			)
		)
		lab._pitch_actor.running = kind == "running-pitch"
		get_tree().paused = kind == "pause"
		var accepted: bool = StadiumMountedClockRuntime.before_pitch(lab)
		var held: bool = ClubCareer.same(owner.clock_value(), before) and owner.intact()
		get_tree().paused = false
		_md_assert(
			"clock_hold",
			accepted and held,
			"clock remains exactly held during protected presentation state " + kind
		)
		holds.append({"case": kind, "accepted": accepted, "unchanged": held})
	state.phase = MatchState.Phase.PRE_PITCH
	lab._pitch_actor.running = false
	var advanced: bool = StadiumMountedClockRuntime.before_pitch(lab)
	var after: Dictionary = owner.clock_value()
	_md_assert(
		"clock_advance",
		(
			advanced
			and owner.intact()
			and after.completed_plays == 0
			and after.completed_halves == 1
			and after.seconds_of_day == 47520
			and property.props_intact()
		),
		"synthetic presentation half-transition advances exact120seconds only at safe pre-pitch"
	)
	_md_assert(
		"clock_duplicate",
		(
			StadiumMountedClockRuntime.before_pitch(lab)
			and ClubCareer.same(owner.clock_value(), after)
			and owner.intact()
		),
		"same presentation input cannot advance the clock twice"
	)
	var pivots: Array[Dictionary] = []
	for copy: String in _md_copies["ST-069"]:
		var model: Node3D = property.objects[copy]
		for hand: String in ["hour", "minute"]:
			var pivot: Node3D = model.get_node(
				"HourHandPivot" if hand == "hour" else "MinuteHandPivot"
			)
			var pose: Transform3D = pivot.transform
			pivot.position.x += 0.01
			var rejected: bool = not owner.intact() and not property.props_intact()
			pivot.transform = pose
			_md_assert(
				"clock_hand_lease",
				(
					pose == StadiumMountedDisplayModels.hand_pose(hand, 47520)
					and rejected
					and owner.intact()
				),
				(
					"exact native hand transform is leased; foreign displacement refuses and exact "
					+ "restoration restores integrity"
				)
			)
			pivots.append(
				{
					"copy": copy,
					"hand": hand,
					"expected_seconds": 47520,
					"foreign_pose_rejected": rejected
				}
			)
	state.top_half = true
	var foreign_rejected: bool = not StadiumMountedClockRuntime.before_pitch(lab) and owner.retired
	state.top_half = false
	var sticky: bool = (
		not StadiumMountedClockRuntime.before_pitch(lab)
		and owner.retired
		and ClubCareer.same(owner.clock_value(), after)
	)
	_md_assert(
		"clock_retirement",
		foreign_rejected and sticky,
		"backward completed-half input retires clock permanently without later resumption"
	)
	state.phase = old_phase
	state.inning = old_inning
	state.top_half = old_half
	lab._pitch_actor.running = old_running
	_md_assert(
		"clock_restore",
		(
			property.props_intact()
			and lab._play_records.is_empty()
			and _md_ledger.revision() == int(_md_snapshot.revision)
		),
		"synthetic clock probe leaves no gameplay record career mutation or geometry damage"
	)
	_md_clock.native = {
		"synthetic_half_transition": true,
		"completed_games": 0,
		"before": before,
		"after": after,
		"holds": holds,
		"pivots": pivots,
		"backward_half_rejected": foreign_rejected,
		"sticky_retirement": sticky,
		"restored_play_record_count": lab._play_records.size(),
		"paid_revision": _md_ledger.revision()
	}
func _md_model_report(
	lab: PitchBatLab,
	property: StadiumPropertyGeometry,
	model: Node3D,
	host: Node3D,
	row: Dictionary
) -> Dictionary:
	var socket: Dictionary = StadiumMountedDisplayModels.socket(
		row.host_item, row.item, row.host_model
	)
	var expected: Transform3D = host.global_transform * socket.transform
	_md_assert(
		"runtime_identity",
		(
			model.get_meta("stadium_item", "") == row.item
			and model.get_meta("owned_copy", "") == row.copy
			and model.get_meta("host_copy", "") == row.host
			and model.global_transform.is_equal_approx(expected)
			and model.scale.is_equal_approx(Vector3.ONE)
			and model.transform.basis.determinant() > 0.9999
		),
		(
			"actual complete parent has exact paid identity socket pose and positive full-size rigid frame "
			+ row.copy
		)
	)
	var bodies: Array[Node] = model.find_children("*", "CollisionObject3D", true, false)
	var roles: bool = not bodies.is_empty()
	for body: Node in bodies:
		roles = (
			roles
			and body is StaticBody3D
			and body.get_meta("owned_copy", "") == row.copy
			and body.get_meta("surface_role", "") == "DECORATIVE_AFTER_TERMINAL"
		)
	_md_assert(
		"runtime_roles",
		roles and model.find_children("*", "Area3D", true, false).is_empty(),
		(
			"complete physical assembly has after-terminal scenery solids and no receiver Areas "
			+ row.copy
		)
	)
	var static_only: bool = (
		model.find_children("*", "AnimationPlayer", true, false).is_empty()
		and model.find_children("*", "RigidBody3D", true, false).is_empty()
	)
	var audio_nodes: int = (
		model.find_children("*", "AudioStreamPlayer", true, false).size()
		+ model.find_children("*", "AudioStreamPlayer3D", true, false).size()
		+ model.find_children("*", "AudioStreamPlayer2D", true, false).size()
	)
	for node: Node in [model] + model.find_children("*", "", true, false):
		static_only = static_only and not node.is_processing() and not node.is_physics_processing()
	_md_assert(
		"silent_static",
		(
			static_only
			and audio_nodes == 0
			and not model.get_meta("audio_implemented", true)
			and not model.get_meta("gameplay_benefit", true)
			and not model.get_meta("night_benefit", true)
		),
		(
			"complete model contains no sound player self-animation gameplay or Night benefit "
			+ row.copy
		)
	)
	var old_position: Vector3 = model.position
	model.position.x += 0.01
	var moved_rejected: bool = not property.props_intact()
	model.position = old_position
	_md_assert(
		"runtime_seal",
		moved_rejected and property.props_intact(),
		"current-copy seal rejects displaced mount and accepts exact restoration " + row.copy
	)
	var tracking: BallTrackingVisibility = lab._camera_director.tracking_visibility
	var tracked: bool = true
	var count: int = 0
	for node: Node in model.get_node("Visual").find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		if box.size.y > 0.025:
			count += 1
			tracked = tracked and tracking._obstacles.has(box)
	_md_assert(
		"runtime_tracking",
		count > 0 and tracked and tracking._owned_receiver_models.is_empty(),
		(
			"ordinary tracking collects every qualifying visible mount member without receiver authority "
			+ row.copy
		)
	)
	return {
		"copy": row.copy,
		"item": row.item,
		"host": row.host,
		"host_item": row.host_item,
		"socket": row.socket,
		"physical_scenery_bodies": bodies.size(),
		"static_only": static_only,
		"audio_nodes": audio_nodes,
		"moved_seal_rejected": moved_rejected,
		"tracking_mesh_bounds": count,
		"tracking_collected": tracked
	}
