class_name StadiumNpcAe02PublicActors
extends RefCounted
## Bounded public ownership adapter for the authored two cone Visual cutaways.
## Ordinary avatar cutaway stays on the existing public property helper unchanged.


class ConeVisualCutaway extends StadiumNpcRetainedActorCutaway:
	var property_ref: WeakRef
	var visuals: Array[Node3D] = []

	func _allowed(visual: Node3D) -> bool:
		var property: StadiumNpcPublicProperty = property_ref.get_ref() \
			as StadiumNpcPublicProperty if property_ref != null else null
		return property != null and not property.suspended and visuals.has(visual) \
			and is_instance_valid(visual) and visual.is_inside_tree() \
			and visual.is_visible_in_tree() \
			and property.objects.values().has(visual.get_parent())

	func _sync(mesh: MeshInstance3D) -> void:
		var property: StadiumNpcPublicProperty = property_ref.get_ref() \
			as StadiumNpcPublicProperty if property_ref != null else null
		if property == null or not StadiumNpcAe02PublicActors.owns_mesh(property, mesh):
			return
		super._sync(mesh)
		if entries.has(mesh.get_instance_id()):
			var material: StandardMaterial3D = entries[mesh.get_instance_id()].fade_material
			# A supported fade material mutation also retires the same issued installation.
			if not material.changed.is_connected(property._installation_changed):
				material.changed.connect(property._installation_changed)


var cone_study: ConeVisualCutaway = ConeVisualCutaway.new()
var _property: WeakRef
var _originals: Dictionary = {}


func bind(property: StadiumNpcPublicProperty) -> bool:
	if _property != null or property == null or property.venue_id != "AE-02" \
		or property.get_parent() != null:
		return false
	for site: String in StadiumNpcAe02PublicConstruction.CONE_SITES:
		var model: Node3D = property.objects.get("npc:AE-02:r1:" + site)
		if model == null or model.get_parent() != property.construction \
			or not StadiumNpcAe02PublicConstruction.exact_meta(model, "stadium_item", "ST-001"):
			return false
		var visual: Node3D = model.get_node_or_null("Visual") as Node3D
		if visual == null or visual.get_child_count() != 3:
			return false
		cone_study.visuals.append(visual)
		for part: String in ["CONE_BASE", "CONE_BODY", "ConeStripe"]:
			var mesh: MeshInstance3D = visual.get_node_or_null(NodePath(part)) as MeshInstance3D
			if mesh == null or not mesh.material_override is StandardMaterial3D:
				return false
			_originals[mesh] = {"material": mesh.material_override, "overlay": mesh.material_overlay,
				"mesh": mesh.mesh, "shadow": mesh.cast_shadow, "transparency": mesh.transparency}
	_property = weakref(property)
	cone_study.property_ref = _property
	return _originals.size() == 6


func refresh(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> void:
	if _property == null or _property.get_ref() != property or lab == null \
		or property.suspended or property.ae02_actors != self \
		or property.lab_ref == null or property.lab_ref.get_ref() != lab \
		or lab.get_node_or_null("StarterFieldGeometry/HomeProperty") != property \
		or not lab._camera_director is StadiumNpcAe02PublicCamera \
		or lab._camera_director != property.presentation_director \
		or lab.get_tree().paused \
		or lab._camera_director.shot != MatchCameraDirector.Shot.BALL_IN_PLAY \
		or not lab._ball_in_play_is_live() or not is_instance_valid(lab._batted_ball) \
		or lab._batted_ball.get_parent() != lab:
		restore_all()
		return
	cone_study.apply_actors(cone_study.visuals, lab._camera, lab._batted_ball, true)
	for hit: Dictionary in cone_study.last_hits:
		hit.role = "AE02_CONE_VISUAL"


func restore_all() -> void:
	cone_study.restore_all()


static func owns_mesh(property: StadiumNpcPublicProperty, mesh: Node) -> bool:
	if property == null or property.venue_id != "AE-02" or not mesh is MeshInstance3D \
		or property.ae02_actors == null or property.ae02_actors._property == null \
		or property.ae02_actors._property.get_ref() != property \
		or not property.ae02_actors._originals.has(mesh):
		return false
	var visual: Node = mesh.get_parent()
	if visual == null or visual.name != &"Visual":
		return false
	var model: Node3D = visual.get_parent() as Node3D
	if model == null or model.get_parent() != property.construction:
		return false
	for site: String in StadiumNpcAe02PublicConstruction.CONE_SITES:
		if property.objects.get("npc:AE-02:r1:" + site) == model:
			return model.get_node_or_null("Visual") == visual \
				and String(mesh.name) in ["CONE_BASE", "CONE_BODY", "ConeStripe"] \
				and visual.get_node_or_null(NodePath(mesh.name)) == mesh
	return false


static func mesh_intact(property: StadiumNpcPublicProperty, mesh: MeshInstance3D,
	original_material: Material, original_overlay: Material) -> bool:
	if not owns_mesh(property, mesh):
		return false
	var helper: StadiumNpcAe02PublicActors = property.ae02_actors
	var original: Dictionary = helper._originals[mesh]
	if original.material != original_material or original.overlay != original_overlay \
		or mesh.mesh != original.mesh or mesh.material_overlay != original_overlay \
		or mesh.transparency != original.transparency:
		return false
	var entry: Dictionary = helper.cone_study.entries.get(mesh.get_instance_id(), {})
	if entry.is_empty():
		return mesh.material_override == original_material and mesh.cast_shadow == original.shadow
	if entry.mesh.get_ref() != mesh or entry.source_mesh != original.mesh \
		or entry.original_material != original_material or entry.shadow != original.shadow \
		or entry.transparency != original.transparency:
		return false
	if not entry.faded:
		return mesh.material_override == original_material and mesh.cast_shadow == original.shadow
	var faded: StandardMaterial3D = entry.fade_material as StandardMaterial3D
	return faded != null and mesh.material_override == faded \
		and faded.albedo_color.a == Color(0, 0, 0, StadiumReceiverVisibility.FADED_ALPHA).a \
		and faded.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA \
		and faded.changed.is_connected(property._installation_changed) \
		and mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func normalize_geometry(property: StadiumNpcPublicProperty, mesh: MeshInstance3D,
	data: Dictionary) -> bool:
	if not owns_mesh(property, mesh):
		return false
	var original: Dictionary = property.ae02_actors._originals[mesh]
	if not mesh_intact(property, mesh, original.material, original.overlay):
		return false
	if mesh.material_override != original.material:
		# Cold audit compares every fade property against the authored duplicate policy.
		var faded: Dictionary = StadiumNpcRetainedGeometry._resource(mesh.material_override)
		var expected: Dictionary = StadiumNpcRetainedGeometry._resource(original.material)
		var color: Color = expected.properties.albedo_color
		color.a = minf(color.a, StadiumReceiverVisibility.FADED_ALPHA)
		expected.properties.albedo_color = color
		expected.properties.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if var_to_bytes(faded) != var_to_bytes(expected):
			return false
	data.material_override = StadiumNpcRetainedGeometry._resource(original.material)
	data.cast_shadow = original.shadow
	return true


func owners_intact() -> bool:
	var property: StadiumNpcPublicProperty = _property.get_ref() as StadiumNpcPublicProperty \
		if _property != null else null
	if property == null or property.ae02_actors != self or _originals.size() != 6 \
		or cone_study.property_ref == null or cone_study.property_ref.get_ref() != property \
		or cone_study.visuals.size() != 2:
		return false
	for index in range(2):
		var site: String = StadiumNpcAe02PublicConstruction.CONE_SITES[index]
		var model: Node3D = property.objects.get("npc:AE-02:r1:" + site)
		if not is_instance_valid(model) or model.get_parent() != property.construction \
			or cone_study.visuals[index] != model.get_node_or_null("Visual"):
			return false
		for part: String in ["CONE_BASE", "CONE_BODY", "ConeStripe"]:
			var mesh: MeshInstance3D = model.get_node_or_null("Visual/" + part) as MeshInstance3D
			if not owns_mesh(property, mesh):
				return false
	return true
