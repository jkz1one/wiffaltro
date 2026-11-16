class_name StadiumMountedDisplayModels
extends RefCounted
## Complete straight ribbon, simulation-driven analog clock and silent PA assemblies.
## Named sockets are a source-model whitelist, never permission to mount on arbitrary art.
## The wider scoreboard factories are measured here; ownership may expose fewer hosts.

const VERSION: int = 1
const ITEMS: Array[String] = ["ST-068", "ST-069", "ST-070"]
const ROLE: String = "DECORATIVE_AFTER_TERMINAL"
const P = preload("res://src/presentation/stadium/stadium_landmark_models.gd")
const ENVELOPES: Dictionary = {
	"ST-068": AABB(Vector3(-2.90, -0.06, 0), Vector3(5.80, 0.72, 0.085)),
	"ST-069": AABB(Vector3(-0.52, -0.08, 0), Vector3(1.04, 1.12, 0.44)),
	"ST-070": AABB(Vector3(-0.34, -0.48, 0), Vector3(0.68, 0.96, 0.74))
}
const VISIBLE: Dictionary = {
	"ST-068": AABB(Vector3(-2.85, -0.06, 0), Vector3(5.70, 0.68, 0.0775)),
	"ST-069": AABB(Vector3(-0.48, 0.05, 0), Vector3(0.96, 0.99, 0.40)),
	"ST-070": AABB(Vector3(-0.33, -0.45, 0), Vector3(0.66, 0.90, 0.68))
}
const MESH_COUNTS: Dictionary = {"ST-068": 121, "ST-069": 36, "ST-070": 33}
const SOCKETS: Array[Dictionary] = [
	{
		"host_item": "ST-035",
		"host_model": "",
		"item": "ST-069",
		"id": "CLOCK-GATE-CENTER",
		"position": Vector3(0, 4.98, 0.73),
		"yaw": 0.0,
		"surface": "Visual/GateLintel",
		"body": "Collision/GateLintel"
	},
	{
		"host_item": "ST-039",
		"host_model": "",
		"item": "ST-069",
		"id": "CLOCK-MANUAL-HEADER",
		"position": Vector3(0, 3.92, 0.12),
		"yaw": 0.0,
		"surface": "Visual/Header",
		"body": "Collision/Header"
	},
	{
		"host_item": "ST-030",
		"host_model": "",
		"item": "ST-068",
		"id": "RIBBON-STRAIGHT-UPPER",
		"position": Vector3(0, 8.42, 2.0),
		"yaw": PI,
		"surface": "Visual/FrontFascia",
		"body": "Collision/FrontFascia"
	},
	{
		"host_item": "ST-031",
		"host_model": "",
		"item": "ST-068",
		"id": "RIBBON-STRAIGHT-CONCOURSE",
		"position": Vector3(0, 6.075, 7.0),
		"yaw": PI,
		"surface": "Visual/ConcourseDeck",
		"body": "Collision/ConcourseDeck"
	},
	{
		"host_item": "ST-035",
		"host_model": "",
		"item": "ST-070",
		"id": "PA-GATE-RIGHT",
		"position": Vector3(3.55, 4.98, 0.73),
		"yaw": 0.0,
		"surface": "Visual/GateLintel",
		"body": "Collision/GateLintel"
	},
	{
		"host_item": "ST-039",
		"host_model": "",
		"item": "ST-070",
		"id": "PA-MANUAL-RIGHT",
		"position": Vector3(2.30, 3.60, 0.12),
		"yaw": 0.0,
		"surface": "Visual/SideFrame1",
		"body": "Collision/SideFrame1"
	},
	{
		"host_item": "ST-039",
		"host_model": "manual-v2",
		"item": "ST-070",
		"id": "PA-MANUAL-V2-RIGHT",
		"position": Vector3(3.04, 4.65, 0.08),
		"yaw": 0.0,
		"surface": "Visual/TimberFrame",
		"body": ""
	},
	{
		"host_item": "ST-040",
		"host_model": "video-v2",
		"item": "ST-070",
		"id": "PA-VIDEO-RIGHT",
		"position": Vector3(7.25, 10.65, 0.15),
		"yaw": 0.0,
		"surface": "Visual/EndPylon1",
		"body": ""
	}
]


static func create(item: String, placement: Dictionary = {}) -> Node3D:
	if not ITEMS.has(item):
		return null
	var identity: Dictionary = {}
	if item == "ST-068":
		var supplied: Variant = placement.get("identity", StadiumClubIdentity.current())
		if not StadiumClubIdentity.valid(supplied):
			return null
		identity = supplied.duplicate(true)
	var root: Node3D = Node3D.new()
	root.name = {
		"ST-068": "ST068StraightRibbon", "ST-069": "ST069StadiumClock", "ST-070": "ST070SilentPA"
	}[item]
	root.set_meta("stadium_item", item)
	root.set_meta("geometry_version", VERSION)
	root.set_meta("model_version", VERSION)
	root.set_meta("authoring_status", "Working")
	root.set_meta("final_art_accepted", false)
	root.set_meta("envelope", envelope(item))
	root.set_meta("visible_bounds", visible_bounds(item))
	root.set_meta("static_geometry", item != "ST-069")
	root.set_meta("fixed_collision", true)
	root.set_meta("scenery_only", true)
	root.set_meta("surface_role", ROLE)
	root.set_meta("physics_profile", ROLE)
	root.set_meta("obstacle_units", 0)
	root.set_meta("animated_during_pitch", false)
	root.set_meta("gameplay_benefit", false)
	root.set_meta("night_benefit", false)
	root.set_meta("audio_implemented", false)
	root.set_meta("runtime_clock", item == "ST-069")
	root.set_meta("machine_time", false)
	root.set_meta("mount_interface", "named-rear-bearing-v1")
	for id: String in ["Visual", "Collision"]:
		var branch: Node3D = Node3D.new()
		branch.name = id
		root.add_child(branch)
	if item == "ST-068":
		root.set_meta("identity", identity.duplicate(true))
		root.set_meta("identity_mode", "current-static-colors")
		root.set_meta("curved_variant", false)
		_ribbon(root, identity)
	elif item == "ST-069":
		root.set_meta("time_source", "existing-match-simulation")
		root.set_meta("visual_hand_only", true)
		_clock(root)
	else:
		root.set_meta("silent_pa", true)
		root.set_meta("aiming", "fixed-host-positive-z")
		_pa(root)
	return root


static func envelope(item: String) -> AABB:
	return ENVELOPES.get(item, AABB())


static func visible_bounds(item: String) -> AABB:
	return VISIBLE.get(item, AABB())


static func bounds(item: String) -> AABB:
	return envelope(item)


static func mesh_count(item: String) -> int:
	return int(MESH_COUNTS.get(item, 0))


static func solid_count(item: String) -> int:
	return mesh_count(item) - (2 if item == "ST-069" else 0)


static func socket(host_item: String, item: String, host_model: String = "") -> Dictionary:
	for spec: Dictionary in SOCKETS:
		if spec.host_item == host_item and spec.host_model == host_model and spec.item == item:
			var result: Dictionary = spec.duplicate(true)
			var pose: Transform3D = Transform3D(Basis(Vector3.UP, spec.yaw), spec.position)
			result["transform"] = pose
			result["envelope"] = pose * envelope(item)
			result["support"] = support_points(item)
			return result
	return {}


static func support_points(item: String) -> PackedVector3Array:
	if item == "ST-068":
		return PackedVector3Array(
			[
				Vector3(-2.0, 0, 0),
				Vector3(-2.0 / 3.0, 0, 0),
				Vector3(2.0 / 3.0, 0, 0),
				Vector3(2.0, 0, 0)
			]
		)
	if item == "ST-069":
		return PackedVector3Array(
			[
				Vector3(0.24, 0.055, 0),
				Vector3(0.32, 0.055, 0),
				Vector3(0.24, 0.075, 0),
				Vector3(0.32, 0.075, 0)
			]
		)
	if item == "ST-070":
		return PackedVector3Array(
			[
				Vector3(-0.04, -0.20, 0),
				Vector3(0.04, -0.20, 0),
				Vector3(-0.04, 0.20, 0),
				Vector3(0.04, 0.20, 0)
			]
		)
	return PackedVector3Array()


static func signature() -> String:
	return (
		var_to_bytes(
			[
				VERSION,
				ITEMS,
				ENVELOPES,
				VISIBLE,
				MESH_COUNTS,
				SOCKETS,
				"complete-static-colors-and-silent-pa-after-terminal-v1"
			]
		)
		. hex_encode()
		. sha256_text()
	)


static func _ribbon(root: Node3D, identity: Dictionary) -> void:
	var primary: Color = Color(identity.palette[0])
	var accent: Color = Color(identity.palette[1])
	var metal: Color = Color("46545c")
	var dark: Color = Color("16272b")
	_ribbon_box(root, "RibbonHousing", Vector3(0, 0.35, 0.125), Vector3(5.70, 0.54, 0.10), metal)
	for index in range(4):
		var x: float = -2.0 + (4.0 / 3.0) * index
		_ribbon_box(
			root,
			"RibbonBearing%d" % index,
			Vector3(x, 0, 0.0125),
			Vector3(0.12, 0.12, 0.025),
			metal
		)
		_ribbon_box(
			root,
			"RibbonRiser%d" % index,
			Vector3(x, 0.145, 0.065),
			Vector3(0.08, 0.29, 0.10),
			metal
		)
	for index in range(4):
		var x: float = -2.04 + 1.36 * index
		_ribbon_box(
			root, "RibbonModule%d" % index, Vector3(x, 0.34, 0.215), Vector3(1.32, 0.40, 0.08), dark
		)
		for row in range(3):
			for column in range(8):
				# A frozen geometric club-color weave, with no text-clock, shader clock or emission.
				var color: Color = accent if posmod(column + row + index, 4) == 0 else primary
				_ribbon_box(
					root,
					"RibbonPixel%d_%d_%d" % [index, row, column],
					Vector3(x - 0.555 + column * 0.1585, 0.22 + row * 0.12, 0.2775),
					Vector3(0.115, 0.075, 0.045),
					color
				)
	for side: int in [-1, 1]:
		_ribbon_box(
			root,
			"RibbonHorizontalTrim%d" % side,
			Vector3(0, 0.35 + side * 0.25, 0.215),
			Vector3(5.70, 0.04, 0.16),
			accent
		)
		_ribbon_box(
			root,
			"RibbonEndCap%d" % side,
			Vector3(side * 2.825, 0.34, 0.215),
			Vector3(0.05, 0.48, 0.16),
			metal
		)
		for index in range(4):
			_ribbon_box(
				root,
				"RibbonFastener%d_%d" % [side, index],
				Vector3(-2.70 + index * 1.80, 0.10 if side == -1 else 0.59, 0.29),
				Vector3(0.04, 0.035, 0.04),
				Color("b9c0b8")
			)


static func _pa(root: Node3D) -> void:
	var metal: Color = Color("48565b")
	var housing: Color = Color("a7aea0")
	var inner: Color = Color("293b40")
	P._box(root, "PABearing", Vector3(0, 0, 0.02), Vector3(0.12, 0.50, 0.04), metal)
	P._box(root, "PAStandOff", Vector3(0, 0, 0.13), Vector3(0.10, 0.14, 0.20), metal)
	P._box(root, "PAYokeCrossbar", Vector3(0, 0, 0.23), Vector3(0.60, 0.08, 0.08), metal)
	for side: int in [-1, 1]:
		P._box(
			root,
			"PAYokeSide%d" % side,
			Vector3(side * 0.29, 0, 0.27),
			Vector3(0.04, 0.90, 0.08),
			metal
		)
		for upper: int in [-1, 1]:
			P._box(
				root,
				"PAPivot%d_%d" % [side, upper],
				Vector3(side * 0.31, upper * 0.23, 0.27),
				Vector3(0.04, 0.08, 0.10),
				Color("c3c4ad")
			)
			P._box(
				root,
				"PABearingBolt%d_%d" % [side, upper],
				Vector3(side * 0.04, upper * 0.20, 0.045),
				Vector3(0.025, 0.035, 0.025),
				Color("c3c4ad")
			)
	for upper: int in [-1, 1]:
		var y: float = upper * 0.23
		P._box(root, "PADriver%d" % upper, Vector3(0, y, 0.265), Vector3(0.20, 0.14, 0.09), metal)
		P._box(root, "PAThroat%d" % upper, Vector3(0, y, 0.3075), Vector3(0.14, 0.08, 0.015), inner)
		_horn(root, upper, y, housing)
		for side: int in [-1, 1]:
			P._box(
				root,
				"PAHornHorizontalLip%d_%d" % [upper, side],
				Vector3(0, y + side * 0.19, 0.655),
				Vector3(0.60, 0.02, 0.05),
				housing
			)
			P._box(
				root,
				"PAHornVerticalLip%d_%d" % [upper, side],
				Vector3(side * 0.29, y, 0.655),
				Vector3(0.02, 0.36, 0.05),
				housing
			)


static func _horn(root: Node3D, upper: int, y: float, color: Color) -> void:
	# Four real tapered shell solids surround each air aperture. No mouth-spanning collider.
	for side: int in [-1, 1]:
		var vertical: PackedVector3Array = []
		var horizontal: PackedVector3Array = []
		for z: float in [0.30, 0.65]:
			var wide: float = 0.10 if z == 0.30 else 0.28
			var high: float = 0.06 if z == 0.30 else 0.18
			for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				vertical.append(
					Vector3(side * (wide - 0.0125) + corner.x * 0.0125, y + corner.y * high, z)
				)
				horizontal.append(
					Vector3(
						corner.x * (wide - 0.025), y + side * (high - 0.0125) + corner.y * 0.0125, z
					)
				)
		P._solid(root, "PAHornSide%d_%d" % [upper, side], vertical, P.PRISM_FACES, color)
		P._solid(root, "PAHornTopBottom%d_%d" % [upper, side], horizontal, P.PRISM_FACES, color)


static func hand_pose(hand: String, seconds_of_day: int) -> Transform3D:
	if hand not in ["hour", "minute"] or seconds_of_day < 0 or seconds_of_day >= 86400:
		return Transform3D.IDENTITY
	var period: int = 43200 if hand == "hour" else 3600
	var angle: float = -TAU * float(seconds_of_day % period) / float(period)
	return Transform3D(
		Basis(Vector3.BACK, angle), Vector3(0, 0.56, 0.362 if hand == "hour" else 0.374)
	)


static func set_clock_time(model: Node3D, seconds_of_day: int) -> bool:
	if (
		not is_instance_valid(model)
		or model.get_meta("stadium_item", "") != "ST-069"
		or seconds_of_day < 0
		or seconds_of_day >= 86400
		or not model.has_node("HourHandPivot")
		or not model.has_node("MinuteHandPivot")
	):
		return false
	model.get_node("HourHandPivot").transform = hand_pose("hour", seconds_of_day)
	model.get_node("MinuteHandPivot").transform = hand_pose("minute", seconds_of_day)
	return true


static func _clock(root: Node3D) -> void:
	var metal: Color = Color("455956")
	var pale: Color = Color("ece6cb")
	var dark: Color = Color("243d3a")
	P._box(root, "ClockBearing", Vector3(0.28, 0.065, 0.02), Vector3(0.12, 0.03, 0.04), metal)
	P._box(root, "ClockStandOff", Vector3(0.28, 0.07, 0.11), Vector3(0.10, 0.04, 0.18), metal)
	P._box(root, "ClockUpstand", Vector3(0.28, 0.305, 0.20), Vector3(0.10, 0.51, 0.04), metal)
	P._stem(
		root,
		"ClockClosedCase",
		Vector3(0, 0.56, 0.18),
		Vector3(0, 0.56, 0.32),
		0.48,
		0.48,
		metal,
		32
	)
	P._stem(
		root,
		"ClockOpaqueFace",
		Vector3(0, 0.56, 0.32),
		Vector3(0, 0.56, 0.34),
		0.435,
		0.435,
		pale,
		32
	)
	for index in range(16):
		var points: PackedVector3Array = []
		for z: float in [0.32, 0.38]:
			for polar: Vector2 in [
				Vector2(0.435, TAU * index / 16.0),
				Vector2(0.48, TAU * index / 16.0),
				Vector2(0.48, TAU * (index + 1) / 16.0),
				Vector2(0.435, TAU * (index + 1) / 16.0)
			]:
				points.append(Vector3(cos(polar.y) * polar.x, 0.56 + sin(polar.y) * polar.x, z))
		P._solid(root, "ClockBezel%02d" % index, points, P.PRISM_FACES, Color("b49b69"))
	for index in range(12):
		var angle: float = -TAU * index / 12.0
		var pose: Basis = Basis(Vector3.BACK, angle)
		var points: PackedVector3Array = []
		for z: float in [0.34, 0.35]:
			for corner: Vector2 in [
				Vector2(-0.012, 0.34),
				Vector2(0.012, 0.34),
				Vector2(0.012, 0.40),
				Vector2(-0.012, 0.40)
			]:
				points.append(Vector3(0, 0.56, z) + pose * Vector3(corner.x, corner.y, 0))
		P._solid(root, "ClockHourMark%02d" % index, points, P.PRISM_FACES, dark)
	P._stem(
		root,
		"ClockCenterPin",
		Vector3(0, 0.56, 0.34),
		Vector3(0, 0.56, 0.40),
		0.035,
		0.035,
		Color("b49b69"),
		16
	)
	for hand: String in ["hour", "minute"]:
		var pivot: Node3D = Node3D.new()
		pivot.name = "HourHandPivot" if hand == "hour" else "MinuteHandPivot"
		root.add_child(pivot)
		var width: float = 0.038 if hand == "hour" else 0.024
		var length: float = 0.245 if hand == "hour" else 0.36
		var points: PackedVector3Array = []
		for z: float in [-0.005, 0.005]:
			for corner: Vector2 in [
				Vector2(-width / 2, -0.045),
				Vector2(width / 2, -0.045),
				Vector2(width / 2, length),
				Vector2(-width / 2, length)
			]:
				points.append(Vector3(corner.x, corner.y, z))
		var id: String = "ClockHourHand" if hand == "hour" else "ClockMinuteHand"
		P._visual(root, id, points, P.PRISM_FACES, dark)
		var member: Node3D = root.get_node("Visual/" + id)
		root.get_node("Visual").remove_child(member)
		pivot.add_child(member)
	set_clock_time(root, 47400)


static func _ribbon_box(
	root: Node3D, id: String, center: Vector3, size: Vector3, color: Color
) -> void:
	# Slim authored enclosure clears the untouched rear seats below the concourse fascia.
	# Unit transforms stay exact; only this new object's vertex coordinates define its depth.
	P._box(
		root,
		id,
		Vector3(center.x, center.y, center.z * 0.25),
		Vector3(size.x, size.y, size.z * 0.25),
		color
	)
