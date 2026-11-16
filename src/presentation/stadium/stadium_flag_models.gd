class_name StadiumFlagModels
extends Node3D
## ST-043 only. Working cloth art; fixed outside-play pole, no scoring or wind physics.

const VERSION: int = 1
const ENVELOPE: AABB = AABB(Vector3(-0.30, 0, -0.30), Vector3(1.50, 3.60, 0.60))
const PERIOD_SECONDS: float = 6.0
const WAVE_M: float = 0.06
const CLOTH_SHADER: String = """shader_type spatial;
render_mode cull_disabled;
uniform float wave_phase = 0.0;
void vertex() {
    float along = clamp(VERTEX.x + 0.5, 0.0, 1.0);
    VERTEX.z += sin(wave_phase + along * 6.283185307179586) * 0.06 * along;
}
void fragment() {
    ALBEDO = vec3(0.1329, 0.2831, 0.1946);
    ROUGHNESS = 1.0;
    SPECULAR = 0.05;
}
"""

var _match: MatchState
var _lab: WeakRef
var _parent: WeakRef
var _property_host: WeakRef
var _property_world: Transform3D
var _phase: float = 0.0
var _pose_captured: bool = false
var _issued_pose: Transform3D
var _visual: Node3D
var _cloth: MeshInstance3D
var _cloth_mesh: QuadMesh
var _cloth_material: ShaderMaterial
var _cloth_shader: Shader


static func create() -> StadiumFlagModels:
	var root: StadiumFlagModels = StadiumFlagModels.new()
	root.name = "ST043"
	root.set_meta("stadium_item", "ST-043")
	root.set_process(false)
	for id: String in ["Visual", "Collision"]:
		var child: Node3D = Node3D.new()
		child.name = id
		root.add_child(child)
	root._visual = root.get_node("Visual")
	StadiumSeatingModels._box(root, "Foot", Vector3(0, 0.08, 0),
		Vector3(0.50, 0.16, 0.50), Color("645e51"))
	var pole: CylinderMesh = CylinderMesh.new()
	pole.top_radius = 0.04
	pole.bottom_radius = 0.04
	pole.height = 3.5
	pole.radial_segments = 16
	StadiumSeatingModels._mesh(root.get_node("Visual"), "Pole", pole,
		Vector3(0, 1.75, 0), Color("a6aaa5"))
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Pole"
	body.position = Vector3(0, 1.75, 0)
	body.collision_layer = 1
	body.collision_mask = 2
	body.set_meta("stadium_item", "ST-043")
	body.set_meta("surface_role", "DECORATIVE_AFTER_TERMINAL")
	body.set_meta("surface_id", "Pole")
	body.set_meta("ball_surface", &"stadium_scenery")
	var collider: CollisionShape3D = CollisionShape3D.new()
	var cylinder: CylinderShape3D = CylinderShape3D.new()
	cylinder.radius = 0.04
	cylinder.height = 3.5
	cylinder.margin = 0.0
	collider.shape = cylinder
	body.add_child(collider)
	root.get_node("Collision").add_child(body)
	var cap: SphereMesh = SphereMesh.new()
	cap.radius = 0.06
	cap.height = 0.12
	StadiumSeatingModels._mesh(root.get_node("Visual"), "Cap", cap,
		Vector3(0, 3.5, 0), Color("b5b7ac"))
	root._cloth_mesh = QuadMesh.new()
	root._cloth_mesh.size = Vector2(1.0, 0.65)
	root._cloth_mesh.subdivide_width = 16
	root._cloth_mesh.subdivide_depth = 2
	root._cloth_shader = Shader.new()
	root._cloth_shader.code = CLOTH_SHADER
	root._cloth_material = ShaderMaterial.new()
	root._cloth_material.shader = root._cloth_shader
	root._cloth_material.set_shader_parameter("wave_phase", 0.0)
	root._cloth = MeshInstance3D.new()
	root._cloth.name = "Cloth"
	root._cloth.mesh = root._cloth_mesh
	root._cloth.material_override = root._cloth_material
	root._cloth.position = Vector3(0.58, 2.925, 0)
	root._cloth.custom_aabb = AABB(Vector3(-0.5, -0.325, -WAVE_M), Vector3(1, 0.65, WAVE_M * 2))
	root.get_node("Visual").add_child(root._cloth)
	var label: Label3D = Label3D.new()
	label.name = "ClubBrand"
	label.text = "YARD CLUB\nWIFFALTRO"
	label.position = Vector3(0.58, 2.925, 0.08)
	label.font_size = 24
	label.pixel_size = 0.004
	label.modulate = Color("e1dcc8")
	label.outline_size = 0
	root.get_node("Visual").add_child(label)
	return root


func bind_match(state: MatchState, lab: PitchBatLab = null) -> bool:
	if not _intact():
		return false
	if not _pose_captured:
		_issued_pose = transform
		_pose_captured = true
	_match = state
	_lab = weakref(lab) if is_instance_valid(lab) else null
	_parent = weakref(get_parent()) if get_parent() != null else null
	if lab != null and get_parent() is StadiumPropertyGeometry:
		_property_host = weakref(get_parent().get_parent()) if get_parent().get_parent() != null else null
		_property_world = get_parent().global_transform
	set_process(state != null)
	return true


func _intact() -> bool:
	return (not _pose_captured or transform == _issued_pose) \
		and is_instance_valid(_visual) and get_node_or_null("Visual") == _visual \
		and _visual.transform == Transform3D.IDENTITY \
		and is_instance_valid(_cloth) and get_node_or_null("Visual/Cloth") == _cloth \
		and _cloth.get_parent() == _visual \
		and _cloth.transform == Transform3D(Basis.IDENTITY, Vector3(0.58, 2.925, 0)) \
		and _cloth.custom_aabb == AABB(Vector3(-0.5, -0.325, -WAVE_M), Vector3(1, 0.65, WAVE_M * 2)) \
		and _cloth_mesh.size == Vector2(1.0, 0.65) and _cloth_mesh.subdivide_width == 16 \
		and _cloth_mesh.subdivide_depth == 2 and _cloth_mesh.orientation == PlaneMesh.FACE_Z \
		and _cloth_mesh.center_offset == Vector3.ZERO \
		and _cloth.mesh == _cloth_mesh and _cloth.material_override == _cloth_material \
		and _cloth_material.shader == _cloth_shader and _cloth_shader.code == CLOTH_SHADER \
		and _cloth_material.get_shader_parameter("wave_phase") == _phase


func _process(delta: float) -> void:
	if _match == null or not is_finite(delta) or delta < 0 or not _intact():
		return
	if _parent != null and get_parent() != _parent.get_ref():
		return
	if _lab != null:
		var lab: PitchBatLab = _lab.get_ref()
		if not is_instance_valid(lab) or lab._match_state != _match \
			or not lab.has_meta("stadium_property") or lab.get_meta("stadium_property") != get_parent() \
			or not get_parent() is StadiumPropertyGeometry \
			or get_parent().get_parent() != (_property_host.get_ref() if _property_host != null else null) \
			or get_parent().global_transform != _property_world \
			or get_parent().objects.get(get_meta("owned_copy", "")) != self:
			return
		if lab._pitch_actor == null or lab._pitch_actor.running \
			or (lab._release_controller != null and lab._release_controller.active):
			return
	if _match.phase in [MatchState.Phase.PITCH_IN_FLIGHT, MatchState.Phase.BALL_IN_PLAY]:
		return
	_phase = fposmod(_phase + minf(delta, 0.1) * TAU / PERIOD_SECONDS, TAU)
	_cloth_material.set_shader_parameter("wave_phase", _phase)
