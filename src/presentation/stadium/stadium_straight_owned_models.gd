class_name StadiumStraightOwnedModels
extends RefCounted
## Additive, exact-size art for owned straight hosts and their named display sockets.
## Host factories are preserved; this file never resizes or substitutes their geometry.

const VERSION: int = 1
const ITEMS: Array[String] = ["ST-029", "ST-030", "ST-031", "ST-035", "ST-039", "ST-042", "ST-044"]
const CREST_BOUNDS: AABB = AABB(Vector3(-0.34, -0.38, -0.045), Vector3(0.68, 0.74, 0.17))
const PENNANT_BOUNDS: AABB = AABB(Vector3(-0.77, -1.72, -0.04), Vector3(1.54, 1.80, 0.20))


static func create(item: String, identity: Dictionary = {}, earned: Dictionary = {}) -> Node3D:
	var root: Node3D
	match item:
		"ST-029":
			root = StadiumBaselineStandModels.lower(true)
		"ST-030":
			root = StadiumStraightStackModels._upper(true)
		"ST-031":
			root = StadiumStraightStackModels._concourse()
		"ST-035":
			root = _gate()
		"ST-039":
			root = StadiumClubModels.create("ST-039")
		"ST-042":
			root = _crest(identity)
		"ST-044":
			root = _pennant(earned if not earned.is_empty() else identity)
		_:
			return null
	return root


static func envelope(item: String) -> AABB:
	match item:
		"ST-029":
			return StadiumBaselineSites.LOWER_BOUNDS
		"ST-030":
			return AABB(Vector3(-2.95, 6.15, 2.0), Vector3(5.90, 6.05, 7.50))
		"ST-031":
			return AABB(Vector3(-2.95, 0, 6.90), Vector3(5.90, 6.95, 3.0))
		"ST-035":
			return AABB(Vector3(-5, 0, -1.5), Vector3(10, 6, 3))
		"ST-039":
			return AABB(Vector3(-2.38, 0, -0.85), Vector3(4.76, 4.0, 1.7))
		"ST-042":
			return CREST_BOUNDS
		"ST-044":
			return PENNANT_BOUNDS
	return AABB()


static func socket(host_item: String, kind: String) -> Dictionary:
	# All points are in the original host's local frame. ST029 + ST031 share that frame.
	# The crest faces +Z before yaw. No socket is inferred from a similar flat surface.
	var point: Vector3
	var yaw: float = 0.0
	var surface: String = ""
	var bounds: AABB = CREST_BOUNDS
	if kind in ["crest", "CREST-CENTER", "ST-042"]:
		match host_item:
			"ST-029":
				point = Vector3(-3.025, 2.40, 3.85)
				yaw = -PI / 2.0
				surface = "Visual/SolidRow5"
			"ST-030":
				point = Vector3(-2.975, 10.45, 5.125)
				yaw = -PI / 2.0
				surface = "Visual/FinishedEnd2_-1"
			"ST-035":
				point = Vector3(0, 5.0, 0.755)
				surface = "Visual/GateLintel"
			"ST-039":
				# Existing Header tops out at y=4.0. The crest's lower fixing tabs touch it.
				point = Vector3(0, 4.34, 0.14)
				surface = "Visual/Header"
			_:
				return {}
	elif kind in ["pennant", "PENNANT-RAIL", "ST-044"] and host_item in ["ST-029", "ST-031"]:
		point = Vector3(-1.25, 6.78, 9.90)
		surface = "Visual/RearParapet"
		bounds = PENNANT_BOUNDS
	else:
		return {}
	var pose: Transform3D = Transform3D(Basis(Vector3.UP, yaw), point)
	return {
		"position": point,
		"yaw": yaw,
		"transform": pose,
		"surface": surface,
		"host_item": host_item,
		"kind": "pennant" if bounds == PENNANT_BOUNDS else "crest",
		"requires": ["ST-029", "ST-031"] if bounds == PENNANT_BOUNDS else [host_item],
		"envelope": pose * bounds
	}


static func _root(item: String) -> Node3D:
	var root: Node3D = StadiumPennantMotion.new() if item == "ST-044" else Node3D.new()
	root.name = item.replace("-", "") + "Owned"
	root.set_meta("stadium_item", item)
	root.set_meta("geometry_version", VERSION)
	for id: String in ["Visual", "Collision"]:
		var child: Node3D = Node3D.new()
		child.name = id
		root.add_child(child)
	return root


static func _gate() -> Node3D:
	# BO1: the entire full-size gate is inside the 10 x 3 x 6m ENTRY-GATE reservation.
	var root: Node3D = _root("ST-035")
	var brick: Color = Color("986449")
	var stone: Color = Color("c4b697")
	var iron: Color = Color("344b43")
	for side: int in [-1, 1]:
		var x: float = side * 4.0
		_box(root, "PierFoot%d" % side, Vector3(x, 0.15, 0), Vector3(1.90, 0.30, 1.90), stone)
		_box(root, "BrickPier%d" % side, Vector3(x, 2.48, 0), Vector3(1.45, 4.36, 1.40), brick)
		_box(root, "PierBaseCap%d" % side, Vector3(x, 0.51, 0), Vector3(1.60, 0.16, 1.54), stone)
		_box(root, "PierCapital%d" % side, Vector3(x, 4.61, 0), Vector3(1.70, 0.24, 1.64), stone)
		# Mortar courses and staggered perpends are visible on all four pier faces.
		for course in range(17):
			var y: float = 0.64 + course * 0.23
			for face: int in [-1, 1]:
				_art_box(
					root,
					"PierCourse%d_%d_%d" % [side, course, face],
					Vector3(x, y, face * 0.706),
					Vector3(1.45, 0.018, 0.012),
					stone.darkened(0.12)
				)
				_art_box(
					root,
					"PierSideCourse%d_%d_%d" % [side, course, face],
					Vector3(x + face * 0.731, y, 0),
					Vector3(0.012, 0.018, 1.40),
					stone.darkened(0.12)
				)
				for joint in range(3):
					var offset: float = -0.53 + joint * 0.47 + (0.22 if course % 2 == 0 else 0.0)
					if offset < 0.71:
						_art_box(
							root,
							"PierJoint%d_%d_%d_%d" % [side, course, face, joint],
							Vector3(x + offset, y + 0.115, face * 0.706),
							Vector3(0.018, 0.21, 0.012),
							stone.darkened(0.12)
						)
	_box(root, "GateLintel", Vector3(0, 4.96, 0), Vector3(9.55, 0.72, 1.46), brick)
	_box(root, "LintelLowerCourse", Vector3(0, 4.61, 0), Vector3(9.70, 0.14, 1.58), stone)
	_box(root, "GateCornice", Vector3(0, 5.40, 0), Vector3(9.90, 0.18, 1.70), stone)
	_box(root, "GateCoping", Vector3(0, 5.54, 0), Vector3(9.66, 0.10, 1.58), stone.lightened(0.09))
	for side: int in [-1, 1]:
		var center: float = side * 1.59
		for rail in range(3):
			var y: float = [0.48, 1.60, 3.52][rail]
			_box(
				root,
				"LeafRail%d_%d" % [side, rail],
				Vector3(center, y, 0),
				Vector3(3.10, 0.09, 0.13),
				iron
			)
		for bar in range(11):
			var x: float = center - 1.45 + bar * 0.29
			_box(
				root,
				"LeafBar%d_%d" % [side, bar],
				Vector3(x, 1.94, 0),
				Vector3(0.055, 3.37, 0.055),
				iron
			)
			_art_box(
				root,
				"LeafFinial%d_%d" % [side, bar],
				Vector3(x, 3.69, 0),
				Vector3(0.085, 0.10, 0.085),
				Color("a89661")
			)
		_box(
			root,
			"GateLatch%d" % side,
			Vector3(side * 0.12, 1.48, 0.10),
			Vector3(0.08, 0.32, 0.08),
			iron
		)
	_text(root, "GateWordLeft", "CLUB", Vector3(-2.0, 4.97, 0.751), 52, 0.007, stone)
	_text(root, "GateWordRight", "GROUNDS", Vector3(2.0, 4.97, 0.751), 44, 0.007, stone)
	return root


static func _crest(identity: Dictionary) -> Node3D:
	var brand: Dictionary = identity.duplicate(true)
	if brand.is_empty():
		brand = StadiumClubIdentity.current()
	if not StadiumClubIdentity.valid(brand):
		return null
	var root: Node3D = _root("ST-042")
	root.set_meta("identity", brand.duplicate(true))
	root.set_meta("identity_mode", "current")
	# Two lower fixing tabs let this exact crest fasten either to a facade or above Header.
	for side: int in [-1, 1]:
		_art_box(
			root,
			"CrestFixing%d" % side,
			Vector3(side * 0.17, -0.28, -0.015),
			Vector3(0.07, 0.19, 0.05),
			Color("7e8981")
		)
		_metal_finish(root, "CrestFixing%d" % side)
	_crest_mark(root, "ClubCrest", brand, Vector3.ZERO, 1.0, true)
	return root


static func _pennant(achievement: Dictionary) -> Node3D:
	# No era fallback: missing earned data never manufactures a historical club identity.
	if not StadiumPennantRewards.valid_record(achievement):
		return null
	var era: Dictionary = achievement.era.duplicate(true)
	var root: Node3D = _root("ST-044")
	root.set_meta("earned", achievement.duplicate(true))
	root.set_meta("identity_mode", "frozen_era")
	root.set_meta("cloth_motion", "bounded-bound-only-v1")
	root.set_meta("animation_envelope", PENNANT_BOUNDS)
	var primary: Color = _color(era, "primary", 0, Color("42685c"))
	var accent: Color = _color(era, "accent", 1, Color("e1dcc8"))
	var rod: Color = Color("9b967b")
	_art_box(root, "PennantHangingRail", Vector3(0, 0, 0), Vector3(1.48, 0.055, 0.055), rod)
	for side: int in [-1, 1]:
		_art_box(
			root,
			"PennantBracket%d" % side,
			Vector3(side * 0.64, 0.015, -0.01),
			Vector3(0.08, 0.10, 0.06),
			rod
		)
	# Shallow folds and their historical print move together only under an explicit binding.
	var outline: PackedVector2Array = [
		Vector2(-0.62, -0.06),
		Vector2(0.62, -0.06),
		Vector2(0.62, -0.94),
		Vector2(0, -1.66),
		Vector2(-0.62, -0.94)
	]
	_sheet(root, "ChampionshipClothBorder", outline, 0.023, 0.013, accent)
	_folded_cloth(root, primary)
	for side: int in [-1, 1]:
		_art_box(
			root,
			"PennantHangingLoop%d" % side,
			Vector3(side * 0.45, -0.055, 0.029),
			Vector3(0.055, 0.16, 0.035),
			accent
		)
	_crest_mark(root, "EraCrest", era, Vector3(0, -0.55, 0.058), 0.56, false)
	_text(
		root,
		"EraClubName",
		_short_text(str(era.name), 19).to_upper(),
		Vector3(0, -0.23, 0.079),
		28,
		0.0027,
		accent
	)
	_text(root, "TitleMarker", "CHAMPIONS", Vector3(0, -0.88, 0.079), 26, 0.0032, accent)
	var league: String = str(achievement.league_id).replace("_", " ").to_upper()
	var tier: String = str(achievement.difficulty_id).get_slice(".", 1).to_upper()
	_text(
		root,
		"LeagueTierMarker",
		_short_text(league + " / " + tier, 22),
		Vector3(0, -1.04, 0.079),
		20,
		0.0028,
		accent
	)
	_text(
		root,
		"SeasonMarker",
		"S" + str(achievement.season_number),
		Vector3(0, -1.25, 0.079),
		28,
		0.0034,
		accent
	)
	if not (root as StadiumPennantMotion).configure_motion():
		root.free()
		return null
	return root


static func _crest_mark(
	root: Node3D, prefix: String, identity: Dictionary, center: Vector3, factor: float, metal: bool
) -> void:
	var primary: Color = _color(identity, "primary", 0, Color("42685c"))
	var accent: Color = _color(identity, "accent", 1, Color("e1dcc8"))
	var outline: PackedVector2Array = [
		Vector2(-0.31, 0.30),
		Vector2(0.31, 0.30),
		Vector2(0.28, -0.10),
		Vector2(0, -0.32),
		Vector2(-0.28, -0.10)
	]
	var inset: PackedVector2Array = [
		Vector2(-0.255, 0.245),
		Vector2(0.255, 0.245),
		Vector2(0.23, -0.07),
		Vector2(0, -0.26),
		Vector2(-0.23, -0.07)
	]
	_sheet(
		root,
		prefix + "Rim",
		_scale_outline(outline, center, factor),
		center.z,
		0.045 * factor,
		Color("a8b0a4") if metal else accent
	)
	if metal:
		_metal_finish(root, prefix + "Rim")
	_sheet(
		root,
		prefix + "Enamel",
		_scale_outline(inset, center, factor),
		center.z + 0.034 * factor,
		0.014 * factor,
		primary
	)
	# Existing brand is the ball reference; the deterministic mark also retains its reference.
	var disk: CylinderMesh = CylinderMesh.new()
	disk.top_radius = 0.145 * factor
	disk.bottom_radius = disk.top_radius
	disk.height = 0.018 * factor
	disk.radial_segments = 32
	StadiumSeatingModels._mesh(
		root.get_node("Visual"),
		prefix + "Ball",
		disk,
		center + Vector3(0, 0.035, 0.063) * factor,
		accent
	)
	var ball: MeshInstance3D = root.get_node("Visual/" + prefix + "Ball")
	ball.rotation.x = PI / 2.0
	ball.set_meta("crest_reference", identity.crest)
	for index in range(5):
		var angle: float = TAU * index / 5.0 - PI / 2.0
		var hole: CylinderMesh = CylinderMesh.new()
		hole.top_radius = 0.020 * factor
		hole.bottom_radius = hole.top_radius
		hole.height = 0.006 * factor
		hole.radial_segments = 12
		StadiumSeatingModels._mesh(
			root.get_node("Visual"),
			prefix + "BallHole%d" % index,
			hole,
			center + Vector3(cos(angle) * 0.081, 0.035 + sin(angle) * 0.081, 0.077) * factor,
			primary
		)
		root.get_node("Visual/" + prefix + "BallHole%d" % index).rotation.x = PI / 2.0
	if metal:
		for side: int in [-1, 1]:
			_art_box(
				root,
				prefix + "Bolt%d" % side,
				center + Vector3(side * 0.27, 0.26, 0.035) * factor,
				Vector3(0.025, 0.025, 0.018) * factor,
				Color("d1d3bf")
			)


static func _folded_cloth(root: Node3D, color: Color) -> void:
	# Three shallow folds are authored into the cloth, never into the historical print.
	# No animation clock runs until an explicit preview or exact production binding exists.
	var rows: Array[Vector2] = [
		Vector2(-0.11, 0.57), Vector2(-0.50, 0.57), Vector2(-0.92, 0.57), Vector2(-1.58, 0.0)
	]
	var points: PackedVector3Array = []
	for side: float in [-1.0, 1.0]:
		for row: Vector2 in rows:
			for column in range(9):
				var across: float = column / 8.0
				var x: float = lerpf(-row.y, row.y, across)
				var fold: float = sin(across * TAU * 3.0) * 0.012 * clampf(-row.x, 0.0, 1.0)
				points.append(Vector3(x, row.x, 0.040 + fold + side * 0.004))
	var faces: Array = []
	var layer: int = rows.size() * 9
	for face in range(2):
		var offset: int = face * layer
		for row in range(rows.size() - 1):
			for column in range(8):
				var a: int = offset + row * 9 + column
				faces.append([a, a + 1, a + 10, a + 9])
	for column in range(8):
		faces.append([column, column + 1, column + 1 + layer, column + layer])
	for row in range(rows.size() - 1):
		for column: int in [0, 8]:
			var a: int = row * 9 + column
			faces.append([a, a + 9, a + 9 + layer, a + layer])
	StadiumSeatingModels._mesh(
		root.get_node("Visual"),
		"ChampionshipCloth",
		StadiumGroundPropsModels._poly_mesh(points, faces),
		Vector3.ZERO,
		color
	)
	var material: StandardMaterial3D = root.get_node("Visual/ChampionshipCloth").material_override
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED


static func _metal_finish(root: Node3D, id: String) -> void:
	var material: StandardMaterial3D = root.get_node("Visual/" + id).material_override
	material.metallic = 0.65
	material.roughness = 0.42


static func _scale_outline(
	outline: PackedVector2Array, center: Vector3, factor: float
) -> PackedVector2Array:
	var result: PackedVector2Array = []
	for point: Vector2 in outline:
		result.append(point * factor + Vector2(center.x, center.y))
	return result


static func _sheet(
	root: Node3D, id: String, outline: PackedVector2Array, z: float, thickness: float, color: Color
) -> void:
	var points: PackedVector3Array = []
	for face: float in [-0.5, 0.5]:
		for point: Vector2 in outline:
			points.append(Vector3(point.x, point.y, z + thickness * face))
	var faces: Array = []
	var front: Array = []
	var back: Array = []
	var count: int = outline.size()
	for index in range(count):
		front.append(index + count)
		back.append(count - 1 - index)
		faces.append([index, (index + 1) % count, (index + 1) % count + count, index + count])
	faces.append(front)
	faces.append(back)
	var mesh: ArrayMesh = StadiumGroundPropsModels._poly_mesh(points, faces)
	StadiumSeatingModels._mesh(root.get_node("Visual"), id, mesh, Vector3.ZERO, color)
	var material: StandardMaterial3D = root.get_node("Visual/" + id).material_override
	material.cull_mode = BaseMaterial3D.CULL_DISABLED


static func _color(identity: Dictionary, key: String, index: int, fallback: Color) -> Color:
	var palette: Variant = identity.get("palette", {})
	var value: Variant = (
		palette.get(key, fallback)
		if palette is Dictionary
		else (palette[index] if palette is Array and palette.size() > index else fallback)
	)
	return value if value is Color else Color.from_string(str(value), fallback)


static func _short_text(value: String, limit: int) -> String:
	return value if value.length() <= limit else value.substr(0, limit - 1) + "."


static func _box(root: Node3D, id: String, point: Vector3, size: Vector3, color: Color) -> void:
	StadiumSeatingModels._box(root, id, point, size, color)
	var shape: CollisionShape3D = root.get_node("Collision/" + id).get_child(0)
	shape.shape.margin = 0.0


static func _art_box(root: Node3D, id: String, point: Vector3, size: Vector3, color: Color) -> void:
	StadiumSeatingModels._box(root, id, point, size, color, false)


static func _text(
	root: Node3D,
	id: String,
	value: String,
	point: Vector3,
	font_size: int,
	pixels: float,
	color: Color
) -> void:
	var label: Label3D = Label3D.new()
	label.name = id
	label.text = value
	label.position = point
	label.font_size = font_size
	label.pixel_size = pixels
	label.modulate = color
	label.outline_size = 0
	root.get_node("Visual").add_child(label)
