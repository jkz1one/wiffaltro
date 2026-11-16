class_name StadiumCenterBoardCandidate
extends RefCounted
## Explicit visual-only study. Never a production site, saved layout, SKU or entitlement.

const ID: String = "CENTER-ELECTRONIC-STUDY-v1"
const POSITION: Vector3 = Vector3(0, 0, 30.75)
const LIFT: float = 2.4
const ENVELOPE: AABB = AABB(Vector3(-4.4, 0, -1.1), Vector3(8.8, 10.8, 2.2))
const SUPPORT_ENVELOPE: AABB = AABB(Vector3(-3.4, 0, -1.1), Vector3(6.8, 7.8, 2.2))
const CABINET_ENVELOPE: AABB = AABB(Vector3(-4.4, 7.6, -0.4), Vector3(8.8, 3.2, 0.8))
const SHAPES: Array[String] = [
	"straight", "deeper_center", "left_loft", "right_shelf", "offset_gables"]


static func pose() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, PI), POSITION)


static func graph_for(shape: String) -> StadiumRecipeBoundary:
	return StadiumRecipeBoundary.create(shape) if shape in StadiumWallRecipes.SHAPES else (
		StadiumAdvancedWallManifest.graph(shape))


static func inspect(graph: StadiumRecipeBoundary, land: String = "backyard",
	eye: Vector3 = Vector3(0, 1.5, -1)) -> Dictionary:
	if graph == null or not eye.is_finite():
		return {"ok": false, "error": "A known wall graph and finite eye are required."}
	var bounds: AABB = pose() * ENVELOPE
	if not StadiumProperty.contains(land, bounds) \
		or not StadiumScoreboardTierSites._outside(bounds, graph):
		return {"ok": false, "error": "The whole support needs outside-play property clearance."}
	# Include joined wall thickness/miter vertices, not just the live polygon.
	var outer_z: float = -INF
	for index in range(graph.polygon().size()):
		outer_z = maxf(outer_z, graph.outer_vertex(index).y)
	if bounds.position.z - outer_z < 0.5:
		return {"ok": false, "error": "The joined wall needs a 0.5 m support setback."}
	var regions: Dictionary = StadiumScoreboardTiers.readouts("electronic")
	regions.merge(StadiumScoreboardTiers.detail_slots("electronic"))
	for key: String in regions:
		var slot: Dictionary = regions[key]
		var bottom: Vector3 = slot.point + Vector3(0, LIFT - slot.height / 2, 0)
		if not StadiumScoreboardTierSites._region_clear(eye,
			pose() * (bottom - Vector3(slot.width / 2, 0, 0)),
			pose() * (bottom + Vector3(slot.width / 2, 0, 0)), graph):
			return {"ok": false, "error": "The wall obscures the " + key + " readout."}
	return {"ok": true, "error": "", "bounds": bounds,
		"outer_wall_setback": bounds.position.z - outer_z,
		"role": "DECORATIVE_AFTER_TERMINAL", "scope": "isolated-visual-study-only"}


static func create(explicit_opt_in: bool = false) -> Node3D:
	if not explicit_opt_in:
		return null
	var root: Node3D = Node3D.new()
	root.name = "CenterElectronicStudy"
	root.set_meta("center_board_study", ID)
	root.set_meta("surface_role", "DECORATIVE_AFTER_TERMINAL")
	root.set_meta("stadium_candidate_only", true)
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	root.add_child(visual)
	# Reuse the exact electronic-v2 factory, then replace only this fresh instance's
	# ground posts/feet. The cabinet, fonts, wells and held-score display stay intact.
	var board: Node3D = StadiumScoreboardModels.create("ST-090", "electronic-v2")
	if board == null:
		root.free()
		return null
	board.name = "ElectronicV2Cabinet"
	board.position.y = LIFT
	for part: String in ["Support-1", "Support1", "Foot-1", "Foot1"]:
		var old: Node = board.get_node_or_null("Visual/" + part)
		if old == null:
			board.free()
			root.free()
			return null
		old.free()
	visual.add_child(board)
	_support(root)
	return root


static func display(root: Node3D) -> StadiumScoreboardTierDisplay:
	return root.get_node("Visual/ElectronicV2Cabinet/Visual/ScoreDisplay")


static func _support(root: Node3D) -> void:
	var steel: Color = Color("526066")
	for side in [-1, 1]:
		var x: float = side * 2.8
		StadiumScoreboardTiers._box(root, "Foundation%d" % side,
			Vector3(x, 0.125, 0), Vector3(1.2, 0.25, 2.2), Color("777a71"))
		StadiumScoreboardTiers._box(root, "Mast%d" % side,
			Vector3(x, 4.0, -0.2), Vector3(0.42, 7.5, 0.5), steel)
		StadiumScoreboardTiers._box(root, "BasePlate%d" % side,
			Vector3(x, 0.28, -0.2), Vector3(0.70, 0.06, 0.75), steel)
		StadiumScoreboardTiers._beam(root, "RearRake%d" % side,
			Vector3(x, 0.3, -0.9), Vector3(x, 7.45, -0.2), 0.14, steel)
		StadiumScoreboardTiers._beam(root, "CrossBrace%d" % side,
			Vector3(x, 0.45, -0.47), Vector3(-x, 7.45, -0.47), 0.14, steel)
	StadiumScoreboardTiers._box(root, "CabinetBearing", Vector3(0, 7.55, -0.2),
		Vector3(6.25, 0.25, 0.65), steel)
	StadiumScoreboardTiers._box(root, "WaistTie", Vector3(0, 3.8, -0.43),
		Vector3(5.6, 0.16, 0.2), steel)
