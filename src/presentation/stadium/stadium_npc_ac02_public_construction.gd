class_name StadiumNpcAc02PublicConstruction
extends Node3D

const AC02_PASSIVE_5 = preload("res://src/diagnostics/ac02_passive_attribution.gd")
## Detached AC-02/r1 composition of exact A art and the current common public surface.
## Only identity labels/mounted parentage change. No stock, catalog, private installer or lights.
# gdlint: disable=max-returns

const INSTANCE_PREFIX: String = "npc:AC-02:r1:"
const BOARD_SITE: String = "SCORE-SMALL"
const FIELD: Resource = preload("res://src/content/fields/starter_field.tres")
const COUNTS: Dictionary = {
	"ST-065": 19,
	"ST-065-L": 7,
	"ST-022": 16,
	"ST-023": 16,
	"ST-074": 2,
	"ST-021": 2,
	"ST-026": 1,
	"ST-073": 1,
	"ST-029": 4,
	"ST-053": 2,
	"ST-039": 1,
	"ST-038": 4
}
var objects: Dictionary = {}
var field: FieldDefinition
var tier: String = "club"


static func build() -> StadiumNpcAc02PublicConstruction:
	var ac02_token: int = AC02_PASSIVE_5.enter("stadium_npc_ac02_public_construction.build")
	var ac02_result: StadiumNpcAc02PublicConstruction = _ac02_passive_05_build()
	AC02_PASSIVE_5.leave(ac02_token)
	return ac02_result


static func _ac02_passive_05_build() -> StadiumNpcAc02PublicConstruction:
	var result: StadiumNpcAc02PublicConstruction = StadiumNpcAc02PublicConstruction.new()
	result.name = "AC02PublicRevision1"
	if not result._build():
		result.free()
		return null
	return result


func _build() -> bool:
	var ac02_token: int = AC02_PASSIVE_5.enter("stadium_npc_ac02_public_construction._build")
	var ac02_result: bool = _ac02_passive_05_private_build()
	AC02_PASSIVE_5.leave(ac02_token)
	return ac02_result


func _ac02_passive_05_private_build() -> bool:
	if not StadiumNpcAc02IssuedWritersV1.preissue_only(self, "construction-rebuild"):
		return false
	field = FIELD.duplicate(true) as FieldDefinition
	# Reuse the existing common Club surface with the exact starter field values.
	var template: StadiumNpcClubV1 = StadiumNpcClubV1.new()
	template.field = field
	template._surface()
	for child: Node in template.get_children():
		template.remove_child(child)
		add_child(child)
	template.free()
	var boundary: StadiumNpcAc02PublicBoundarySource = StadiumNpcAc02PublicBoundarySource.new()
	boundary.name = "ClubBoundary"
	add_child(boundary)
	if not boundary.build():
		return false
	for socket: Dictionary in StadiumFoulPoleSites.rows(boundary.graph):
		var side: int = -1 if socket.site == "FOUL-POLE-L" else 1
		var line: Node3D = get_node("FoulLine" + str(side))
		var end: Vector3 = socket.position
		line.position = end / 2 + Vector3(0, 0.02, 0)
		line.rotation.y = atan2(end.x, end.z)
		var mesh: MeshInstance3D = line.get_child(0)
		(mesh.mesh as BoxMesh).size = Vector3(0.055, 0.025, end.length())
	for model: Node3D in boundary.items:
		if not model.has_meta("candidate_site") or not model.get_meta("candidate_site") is String:
			return false
		_register(model, model.get_meta("candidate_site"))
	for site: String in StadiumBaselineSites.SITES:
		var stand: Node3D = StadiumBaselineStandModels.lower()
		add_child(stand)
		stand.transform = StadiumBaselineSites.pose(site)
		_register(stand, site)
		if site.ends_with("2"):
			var roof: Node3D = StadiumBaselineStandModels.lower_canopy()
			# Exact authored world pose, admitted mounted host with local identity.
			stand.add_child(roof)
			roof.transform = Transform3D.IDENTITY
			_register(roof, site + ".ROOF-LOWER", INSTANCE_PREFIX + site)
	var board: Node3D = StadiumNpcClubBoardV1.create("ST-039")
	add_child(board)
	board.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(-20, 0, 30))
	_register(board, BOARD_SITE)
	for site: String in StadiumNpcAc02PublicLightSites.SITES:
		var tower: Node3D = StadiumNpcAc02PublicLightSites.create(site)
		if tower == null:
			return false
		add_child(tower)
		_register(tower, site)
	return objects.size() == 75


func _register(model: Node3D, site: String, host: String = "field") -> void:
	var identity: String = INSTANCE_PREFIX + site
	for key: String in ["candidate_site", "candidate_instance", "candidate_mount"]:
		if model.has_meta(key):
			model.remove_meta(key)
	model.set_meta("npc_instance", identity)
	model.set_meta("npc_site", site)
	model.set_meta("npc_host", host)
	model.set_meta("site", "RECEIVER-NET" if site == "RECEIVER-CATCH" else site)
	objects[identity] = model
	for body: StaticBody3D in model.find_children("*", "StaticBody3D", true, false):
		body.set_meta("npc_instance", identity)
		body.set_meta("owned_copy", identity)


func route_obstacles() -> Array[Dictionary]:
	# Exact retained cup-shaped chain: 0.3 m spacing, 0.8 m discs; no filled giant net disc.
	var result: Array[Dictionary] = []
	for ends: Array in StadiumNpcClubNetV1.PANELS.values():
		var pieces: int = ceili(ends[0].distance_to(ends[1]) / 0.3)
		for index in range(pieces + 1):
			var point: Vector2 = ends[0].lerp(ends[1], float(index) / pieces)
			result.append({"center": Vector3(point.x, 0, point.y), "radius": 0.8})
	var target: Node3D = objects[INSTANCE_PREFIX + "RECEIVER-PRIMARY"]
	StadiumNpcClubV1._bounds_obstacle(result, target.transform * StadiumNpcClubTargetV1.ENVELOPE)
	var net: Node3D = objects[INSTANCE_PREFIX + "RECEIVER-CATCH"]
	for body: StaticBody3D in net.get_node("Collision").get_children():
		if (
			body.has_meta("surface_id")
			and String(body.get_meta("surface_id")).begins_with("ST073_ANCHOR")
		):
			var shape: CollisionShape3D = body.get_child(0)
			var size: Vector3 = (shape.shape as BoxShape3D).size
			StadiumNpcClubV1._bounds_obstacle(
				result, net.transform * body.transform * shape.transform * AABB(-size / 2, size)
			)
	return result


static func exact_meta(node: Node, key: String, value: Variant) -> bool:
	return (
		is_instance_valid(node)
		and node.has_meta(key)
		and typeof(node.get_meta(key)) == typeof(value)
		and node.get_meta(key) == value
	)


static func components(pose: Transform3D) -> Array:
	return [
		pose.basis.x.x,
		pose.basis.x.y,
		pose.basis.x.z,
		pose.basis.y.x,
		pose.basis.y.y,
		pose.basis.y.z,
		pose.basis.z.x,
		pose.basis.z.y,
		pose.basis.z.z,
		pose.origin.x,
		pose.origin.y,
		pose.origin.z
	]


static func valid(property: StadiumNpcPublicProperty) -> bool:
	var ac02_token: int = AC02_PASSIVE_5.enter("stadium_npc_ac02_public_construction.valid")
	var ac02_result: bool = _ac02_passive_05_valid(property)
	AC02_PASSIVE_5.leave(ac02_token)
	return ac02_result


static func _ac02_passive_05_valid(property: StadiumNpcPublicProperty) -> bool:
	if (
		property == null
		or property.venue_id != "AC-02"
		or not is_instance_valid(property.construction)
		or property.construction.get_script() != StadiumNpcAc02PublicConstruction
		or property.field == null
		or property.field == FIELD
		or property.field.get_script() != FieldDefinition
		or property.construction.field != property.field
		or property.objects != property.construction.objects
		or property.objects.size() != 75
		or property.tier != "club"
		or not StadiumMountedScoreboardContract._clean_tree(property)
	):
		return false
	# Every stored exported field is checked; DefinitionBase.id remains an actual StringName.
	for description: Dictionary in FIELD.get_property_list():
		if (
			(int(description.usage) & PROPERTY_USAGE_STORAGE) == 0
			or (
				description.name
				in [
					"script",
					"resource_path",
					"resource_name",
					"resource_local_to_scene",
					"resource_scene_unique_id"
				]
			)
		):
			continue
		var key: String = description.name
		if (
			typeof(property.field.get(key)) != typeof(FIELD.get(key))
			or property.field.get(key) != FIELD.get(key)
		):
			return false
	var counts: Dictionary = {}
	for row: Dictionary in StadiumNpcClubTwoDefinitionV1.payload().instances:
		var model: Node3D = property.objects.get(row.instance)
		if (
			not is_instance_valid(model)
			or not property.construction.is_ancestor_of(model)
			or not exact_meta(model, "npc_instance", row.instance)
			or not exact_meta(model, "owned_copy", row.instance)
			or not exact_meta(model, "npc_host", row.host)
			or not exact_meta(model, "npc_site", row.site)
			or not exact_meta(model, "stadium_item", row.item)
			or components(model.transform) != Array(PackedFloat32Array(row.transform))
		):
			return false
		if row.host != "field" and model.get_parent() != property.objects.get(row.host):
			return false
		counts[row.item] = int(counts.get(row.item, 0)) + 1
		if row.item == "ST-038" and not _dormant_tower(model, row.site):
			return false
		if row.item == "ST-021":
			var cap: float = 3.25 if row.site == "FOUL-POLE-L" else 1.625
			if (
				not exact_meta(model, "wall_cap_height", cap)
				or not exact_meta(model.get_node("Collision/Pole"), "wall_cap_height", cap)
			):
				return false
		for body: StaticBody3D in model.find_children("*", "StaticBody3D", true, false):
			# Mounted roofs are separate copies under the stand, not stand-owned collision.
			if _model_owner(body, property) != model:
				continue
			if (
				not exact_meta(body, "npc_instance", row.instance)
				or not exact_meta(body, "owned_copy", row.instance)
			):
				return false
	for node: Node in property.find_children("*", "", true, false):
		if (
			node is Light3D
			or node.has_meta("candidate_instance")
			or node.has_meta("candidate_site")
		):
			return false
		for key: String in ["npc_instance", "owned_copy"]:
			if (
				node.has_meta(key)
				and (
					not node.get_meta(key) is String or not property.objects.has(node.get_meta(key))
				)
			):
				return false
	return counts == COUNTS


static func _dormant_tower(model: Node3D, site: String) -> bool:
	return (
		StadiumNpcAc02PublicLightSites.SITES.has(site)
		and exact_meta(model, "geometry_version", 1)
		and exact_meta(model, "night_qualified", false)
		and exact_meta(model, "working_geometry_only", true)
		and exact_meta(model, "obstacle_units", 0)
		and exact_meta(model, "club_site_version", 1)
		and exact_meta(model, "candidate_preset", StadiumNpcAc02PublicLightSites.PRESET)
		and exact_meta(model, "aim_profile", StadiumNpcAc02PublicLightSites.PROFILE)
		and exact_meta(model, "reference_target", StadiumNpcAc02PublicLightSites.TARGETS[site])
	)


static func _metadata(node: Node, property: StadiumNpcPublicProperty) -> Dictionary:
	var result: Dictionary = {"meta": {}, "children": []}
	var keys: Array[StringName] = node.get_meta_list()
	keys.sort()
	for key: StringName in keys:
		if (
			key == &"receiver_render_state"
			and node in [property.receiver.chair, property.receiver.net]
		):
			continue
		result.meta[String(key)] = node.get_meta(key)
	for child: Node in node.get_children():
		result.children.append(_metadata(child, property))
	return result


static func same(
	actual: StadiumNpcPublicProperty, expected: StadiumNpcPublicProperty, admission: Variant = null
) -> bool:
	var ac02_token: int = AC02_PASSIVE_5.enter("stadium_npc_ac02_public_construction.same")
	var ac02_result: bool = _ac02_passive_05_same(actual, expected, admission)
	AC02_PASSIVE_5.leave(ac02_token)
	return ac02_result


static func _ac02_passive_05_same(
	actual: StadiumNpcPublicProperty, expected: StadiumNpcPublicProperty, admission: Variant = null
) -> bool:
	var receiver: StadiumNpcAc02PublicReceiver = actual.receiver as StadiumNpcAc02PublicReceiver
	var reference: StadiumNpcAc02PublicReceiver = expected.receiver as StadiumNpcAc02PublicReceiver
	if (
		receiver == null
		or reference == null
		or receiver._rest_meshes.keys() != reference._rest_meshes.keys()
	):
		return false
	for surface: String in reference._rest_meshes:
		if (
			not receiver._rest_meshes[surface] is Mesh
			or (
				var_to_bytes(
					StadiumNpcRetainedGeometry._mesh(
						receiver._rest_meshes[surface], null, admission
					)
				)
				!= var_to_bytes(
					StadiumNpcRetainedGeometry._mesh(
						reference._rest_meshes[surface], null, admission
					)
				)
			)
		):
			return false
	if not receiver.flex_surface.is_empty():
		if (
			not StadiumNpcClubNetV1.PANELS.has(receiver.flex_surface)
			or not is_finite(receiver.flex_elapsed)
			or receiver.flex_elapsed < 0
			or receiver.flex_elapsed > StadiumNpcClubNetV1.SETTLE
			or not receiver.flex_impact.is_finite()
			or not StadiumNpcClubNetV1.flex(
				reference.net, receiver.flex_surface, receiver.flex_elapsed, receiver.flex_impact
			)
		):
			return false
	return (
		valid(actual)
		and valid(expected)
		and (
			var_to_bytes(_metadata(actual.construction, actual))
			== var_to_bytes(_metadata(expected.construction, expected))
		)
		and StadiumNpcRetainedGeometry.same(actual, expected, admission)
	)


static func _model_owner(node: Node, property: StadiumNpcPublicProperty) -> Node3D:
	var current: Node = node
	while current != null and current != property:
		if current.has_meta("npc_instance"):
			var identity: Variant = current.get_meta("npc_instance")
			if identity is String and property.objects.get(identity) == current:
				return current as Node3D
		current = current.get_parent()
	return null
