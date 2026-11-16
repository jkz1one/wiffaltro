extends Node3D

const Probe = preload("res://src/presentation/ball/home_run_visual_occlusion.gd")
var failures: int = 0
var checks: int = 0
var camera: Camera3D
var ball: Node3D
var wall: MeshInstance3D


func _ready() -> void:
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	ball = Node3D.new()
	add_child(ball)
	ball.position = Vector3(0, 0, -10)
	wall = MeshInstance3D.new()
	wall.mesh = BoxMesh.new()
	wall.position = Vector3(0, 0, -5)
	add_child(wall)
	await get_tree().process_frame
	_expect(true, "opaque noncolliding wall")
	wall.visible = false
	var collider: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	collider.add_child(shape)
	add_child(collider)
	collider.position = wall.position
	_expect(false, "invisible collider is irrelevant")
	wall.visible = true
	visible = false
	_expect(false, "hidden ancestor")
	visible = true
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	_expect(false, "shadows-only geometry")
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var opaque: StandardMaterial3D = StandardMaterial3D.new()
	var transparent: StandardMaterial3D = StandardMaterial3D.new()
	transparent.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wall.material_override = transparent
	_expect(false, "transparent material")
	transparent.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_expect(false, "alpha scissor is uncertain")
	wall.set_surface_override_material(0, opaque)
	_expect(false, "whole material override wins over surface")
	wall.material_override = null
	_expect(true, "surface override is opaque")
	wall.set_surface_override_material(0, transparent)
	_expect(false, "surface override is transparent")
	wall.set_surface_override_material(0, null)
	(wall.mesh as BoxMesh).material = transparent
	_expect(false, "mesh material is transparent")
	wall.material_override = opaque
	_expect(true, "whole override wins over mesh material")
	wall.layers = 2
	camera.cull_mask = 1
	_expect(false, "camera cull layers")
	wall.layers = 1
	wall.position.x = 5
	_expect(false, "live transform moving away")
	wall.position.x = 0
	wall.scale = Vector3(0.01, 2, 0.2)
	wall.rotation.z = 0.4
	_expect(true, "nonuniform rotated transform")
	wall.scale = Vector3(-1, 1, 1)
	_expect(false, "mirrored geometry is conservatively unsupported")
	wall.scale = Vector3.ONE
	wall.rotation = Vector3.ZERO
	wall.mesh = null
	_expect(false, "missing mesh")
	wall.mesh = BoxMesh.new()
	wall.reparent(ball)
	wall.global_position = Vector3(0, 0, -5)
	_expect(false, "exclude entire actual ball subtree")
	wall.reparent(self)
	wall.global_position = Vector3(0, 0, -5)
	camera.near = 6
	_expect(false, "wall before near clipping plane")
	camera.near = 0.05
	camera.far = 7
	_expect(false, "ball beyond far clipping plane")
	camera.far = 100
	wall.position.z = -15
	_expect(false, "geometry behind ball")
	wall.position.z = -5
	wall.material_override = ShaderMaterial.new()
	_expect(false, "unknown shader")
	wall.material_override = opaque
	wall.transparency = 0.5
	_expect(false, "instance transparency")
	wall.transparency = 0
	wall.skin = Skin.new()
	_expect(false, "skinning is not an opaque proof")
	wall.skin = null
	wall.mesh = _surfaces()
	wall.material_override = null
	_expect(false, "only transparent surface crosses ray")
	wall.set_surface_override_material(1, opaque)
	_expect(true, "per-surface opaque override")
	wall.set_surface_override_material(1, null)
	(wall.mesh.surface_get_material(1) as StandardMaterial3D).transparency = (
		BaseMaterial3D.TRANSPARENCY_DISABLED
	)
	_expect(true, "live in-place material mutation")
	var array_mesh: ArrayMesh = wall.mesh as ArrayMesh
	array_mesh.clear_surfaces()
	_expect(false, "live in-place mesh mutation")
	var lod_mesh := ArrayMesh.new()
	var lod_arrays: Array = _arrays(1.0, 0.0)
	lod_arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 1, 2])
	lod_mesh.add_surface_from_arrays(
		Mesh.PRIMITIVE_TRIANGLES, lod_arrays, [], {1.0: PackedInt32Array([0, 1, 2])}
	)
	wall.mesh = lod_mesh
	_expect(false, "automatic surface LOD is conservatively unsupported")
	lod_mesh.clear_surfaces()
	lod_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays(1.0, 0.0))
	_expect(true, "removing LOD restores live opaque surface proof")
	wall.mesh = QuadMesh.new()
	wall.material_override = opaque
	_expect(true, "primitive front winding")
	(wall.mesh as QuadMesh).flip_faces = true
	_expect(false, "primitive flip_faces winding")
	opaque.cull_mode = BaseMaterial3D.CULL_DISABLED
	_expect(true, "flipped primitive with disabled culling")
	wall.mesh = _triangle(0.00001)
	wall.material_override = opaque
	opaque.cull_mode = BaseMaterial3D.CULL_DISABLED
	_expect(true, "tiny local triangle normalized")
	opaque.cull_mode = BaseMaterial3D.CULL_BACK
	_expect(true, "clockwise front triangle")
	opaque.cull_mode = BaseMaterial3D.CULL_FRONT
	_expect(false, "front face culling")
	wall.rotation.y = PI
	_expect(true, "back face rendered with front culling")
	opaque.cull_mode = BaseMaterial3D.CULL_BACK
	_expect(false, "back face culled")
	wall.rotation.y = 0
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_expect(true, "orthographic camera")
	print(
		"HR_VISUAL_OCCLUSION_TEST: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks]
	)
	get_tree().quit(0 if failures == 0 else 1)


func _expect(expected: bool, label: String) -> void:
	checks += 1
	var actual: bool = Probe.blocked(self, camera, ball)
	if actual != expected:
		failures += 1
		push_error("%s: expected %s, got %s" % [label, expected, actual])


func _triangle(size: float, offset: float = 0.0) -> ArrayMesh:
	var result: ArrayMesh = ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays(size, offset))
	return result


func _arrays(size: float, offset: float) -> Array:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(
		[
			Vector3(offset - size, -size, 0),
			Vector3(offset, size, 0),
			Vector3(offset + size, -size, 0)
		]
	)
	return arrays


func _surfaces() -> ArrayMesh:
	var result: ArrayMesh = _triangle(1.0, 5.0)
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays(1.0, 0.0))
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	result.surface_set_material(1, material)
	return result
