class_name WiffleBallVisual
extends MeshInstance3D
## Cosmetic hollow shell. The actor/body still owns every physical and spin operand.

const RADIUS: float = 0.075
const INNER_RADIUS: float = 0.0725
const SLOT_COUNT: int = 8
const SLOT_BEGIN: float = 0.56
const SLOT_END: float = 1.12
const SLOT_CAP: float = 0.09
const SLOT_HALF_WIDTH: float = 0.12
const WHITE: Color = Color(0.97, 0.97, 0.95)
const HALF_COLUMNS: int = 4

var _shell: ArrayMesh


static func create(roughness_value: float = 0.85) -> WiffleBallVisual:
	var visual: WiffleBallVisual = WiffleBallVisual.new()
	visual._shell = _build_shell()
	visual.mesh = visual._shell
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = WHITE
	material.roughness = roughness_value
	visual.material_override = material
	return visual


func authored_mesh() -> bool:
	return _shell != null and mesh == _shell and _shell.get_surface_count() == 1


static func _build_shell() -> ArrayMesh:
	var angles: Array[float] = [0.0]
	_append_angles(angles, 0.0, SLOT_BEGIN, 10)
	_append_angles(angles, SLOT_BEGIN, SLOT_BEGIN + SLOT_CAP, 8)
	_append_angles(angles, SLOT_BEGIN + SLOT_CAP, SLOT_END - SLOT_CAP, 8)
	_append_angles(angles, SLOT_END - SLOT_CAP, SLOT_END, 8)
	_append_angles(angles, SLOT_END, PI / 2.0, 8)
	_append_angles(angles, PI / 2.0, PI, 24)
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_sector: float = PI / SLOT_COUNT
	for slot in range(SLOT_COUNT):
		var center: float = TAU * slot / SLOT_COUNT
		for row in range(angles.size() - 1):
			var first: float = angles[row]
			var second: float = angles[row + 1]
			var width_first: float = _slot_width(first)
			var width_second: float = _slot_width(second)
			for side: int in [-1, 1]:
				var start_first: float = -half_sector if side < 0 else width_first
				var end_first: float = -width_first if side < 0 else half_sector
				var start_second: float = -half_sector if side < 0 else width_second
				var end_second: float = -width_second if side < 0 else half_sector
				for column in range(HALF_COLUMNS):
					var u: float = float(column) / HALF_COLUMNS
					var v: float = float(column + 1) / HALF_COLUMNS
					var a: Vector3 = _direction(first, center + lerpf(start_first, end_first, u))
					var b: Vector3 = _direction(first, center + lerpf(start_first, end_first, v))
					var c: Vector3 = _direction(second, center + lerpf(start_second, end_second, v))
					var d: Vector3 = _direction(second, center + lerpf(start_second, end_second, u))
					_shell_quad(surface, a, b, c, d, RADIUS, false)
					_shell_quad(surface, a, b, c, d, INNER_RADIUS, true)
				if first >= SLOT_BEGIN and second <= SLOT_END:
					_slot_wall(surface, _direction(first, center + side * width_first),
						_direction(second, center + side * width_second), side)
	surface.index()
	return surface.commit()


static func _append_angles(angles: Array[float], begin: float, end: float, steps: int) -> void:
	for index in range(1, steps + 1):
		angles.append(end if index == steps else lerpf(begin, end, float(index) / steps))


static func _slot_width(theta: float) -> float:
	if theta <= SLOT_BEGIN or theta >= SLOT_END:
		return 0.0
	var cap: float = 0.0
	if theta < SLOT_BEGIN + SLOT_CAP:
		cap = (theta - SLOT_BEGIN - SLOT_CAP) / SLOT_CAP
	elif theta > SLOT_END - SLOT_CAP:
		cap = (theta - SLOT_END + SLOT_CAP) / SLOT_CAP
	return SLOT_HALF_WIDTH * sqrt(maxf(0.0, 1.0 - cap * cap))


static func _direction(theta: float, phi: float) -> Vector3:
	if theta == 0.0:
		return Vector3.RIGHT
	if theta == PI:
		return Vector3.LEFT
	return Vector3(cos(theta), sin(theta) * cos(phi), sin(theta) * sin(phi))


static func _shell_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
	d: Vector3, radius: float, inner: bool) -> void:
	if inner:
		_triangle(surface, a * radius, c * radius, b * radius, -a, -c, -b)
		_triangle(surface, a * radius, d * radius, c * radius, -a, -d, -c)
	else:
		_triangle(surface, a * radius, b * radius, c * radius, a, b, c)
		_triangle(surface, a * radius, c * radius, d * radius, a, c, d)


static func _slot_wall(surface: SurfaceTool, first: Vector3, second: Vector3, side: int) -> void:
	var a: Vector3 = first * RADIUS
	var b: Vector3 = second * RADIUS
	var c: Vector3 = second * INNER_RADIUS
	var d: Vector3 = first * INNER_RADIUS
	if side < 0:
		var swap: Vector3 = b
		b = d
		d = swap
	var normal: Vector3 = -(b - a).cross(c - a).normalized()
	_triangle(surface, a, b, c, normal, normal, normal)
	_triangle(surface, a, c, d, normal, normal, normal)


static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
	na: Vector3, nb: Vector3, nc: Vector3) -> void:
	if (b - a).cross(c - a).length_squared() <= 1e-20:
		return
	surface.set_normal(na)
	surface.add_vertex(a)
	surface.set_normal(nb)
	surface.add_vertex(b)
	surface.set_normal(nc)
	surface.add_vertex(c)
