class_name StadiumNpcRetainedBallReadability
extends RefCounted
## Retained presentation only. Preserve the authored visual and its physical body's exact state.

const MIN_DIAMETER_PX: float = 3.0
const DEFAULT_RADIUS_M: float = 0.075
# Two native screen-coordinate float32 rounding units; not a relaxed floor.
const FLOAT32_EPSILON: float = 0.00000011920928955078125
const MAX_SCALE_ATTEMPTS: int = 2

var _ball: WeakRef
var _camera: WeakRef
var _visual: WeakRef
var _source_mesh: WeakRef
var _original: Transform3D = Transform3D.IDENTITY
var _radius: float = DEFAULT_RADIUS_M
var _details: Dictionary = {"reason": "inactive", "scale": 1.0}


func update(ball: BattedBallBody, camera: Camera3D, live: bool) -> void:
	if not live or not is_instance_valid(ball) or not is_instance_valid(camera) \
		or not ball.is_inside_tree() or not camera.is_inside_tree():
		restore_all()
		return
	# Select the current genuine direct-child ball visual, even when the ball object is unchanged.
	var visual: MeshInstance3D = _sphere_visual(ball)
	if not is_instance_valid(visual):
		restore_all()
		_details.reason = "no-original-sphere"
		return
	if _object(_ball) != ball or _object(_camera) != camera \
		or _object(_visual) != visual or _object(_source_mesh) != visual.mesh:
		# Restore a surviving displaced visual before taking a baseline of its replacement.
		restore_all()
		_ball = weakref(ball)
		_camera = weakref(camera)
		_visual = weakref(visual)
		_source_mesh = weakref(visual.mesh)
		_original = visual.transform
	# Always derive the next frame from the untouched baseline, never compound scale.
	visual.transform = _original
	var sphere: SphereMesh = visual.mesh as SphereMesh
	var world: Transform3D = visual.global_transform
	var axes: Vector3 = Vector3(world.basis.x.length(), world.basis.y.length(),
		world.basis.z.length())
	var base_radius: float
	var inner_radius: float
	if visual is WiffleBallVisual:
		var shell_radii: Vector2 = _shell_radii(visual)
		base_radius = shell_radii.x * maxf(axes.x, maxf(axes.y, axes.z))
		inner_radius = shell_radii.y * minf(axes.x, minf(axes.y, axes.z))
	else:
		base_radius = maxf(sphere.radius, sphere.height * 0.5) * (
			maxf(axes.x, maxf(axes.y, axes.z)))
		inner_radius = minf(sphere.radius, sphere.height * 0.5) * (
			minf(axes.x, minf(axes.y, axes.z)))
	_radius = base_radius
	var center: Vector3 = world.origin
	var depth: float = -camera.to_local(center).z
	var viewport: Viewport = camera.get_viewport()
	var logical: Vector2 = viewport.get_visible_rect().size
	var native: Vector2 = _native_extent(viewport, logical)
	_details = {"reason": "base", "scale": 1.0, "base_radius": base_radius,
		"effective_radius": base_radius, "base_diameter_px": 0.0,
		"effective_diameter_px": 0.0, "logical_size": logical, "native_size": native,
		"texture_metadata_size": viewport.get_texture().get_size(),
		"native_extent_source": "subviewport-raw" if viewport is SubViewport else (
			"window-canvas-items-stretch" if native != Vector2.ZERO else "unsupported-window-mode"),
		"stretch_transform": viewport.get_stretch_transform(),
		"fov": camera.fov, "near": camera.near, "far": camera.far,
		"projection": camera.projection, "keep_aspect": camera.keep_aspect,
		"camera_size": camera.size, "depth": depth}
	if not center.is_finite() or not is_finite(base_radius) or not is_finite(inner_radius) \
		or inner_radius <= 0.0 or not is_finite(depth) \
		or camera.is_position_behind(center) or depth - base_radius <= camera.near \
		or depth + base_radius >= camera.far:
		_details.reason = "outside-safe-depth"
		return
	if not logical.is_finite() or not native.is_finite() \
		or minf(logical.x, logical.y) <= 0.0 or minf(native.x, native.y) <= 0.0:
		_details.reason = "invalid-viewport"
		return
	var pixels_per_unit: Vector2 = native / logical
	var diameter: float = _projected_diameter(camera, center, inner_radius, pixels_per_unit)
	if not is_finite(diameter) or diameter <= 0.0:
		_details.reason = "invalid-projection"
		return
	_details.base_diameter_px = diameter
	_details.effective_diameter_px = diameter
	_details.target_reserve_px = 2.0 * FLOAT32_EPSILON * maxf(native.x, native.y)
	_details.target_diameter_px = MIN_DIAMETER_PX + _details.target_reserve_px
	_details.attempt_count = 0
	_details.last_attempt_diameter_px = diameter
	_details.last_attempt_radius = base_radius
	if diameter >= MIN_DIAMETER_PX:
		return
	_apply_floor(visual, camera, sphere, pixels_per_unit, depth)


func _native_extent(viewport: Viewport, logical: Vector2) -> Vector2:
	if viewport is SubViewport:
		# SubViewport texture metadata is its raw render-target size, including 2D overrides.
		return Vector2(viewport.get_texture().get_size())
	if viewport is Window and not viewport.is_embedded() \
		and viewport.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS:
		# Window texture metadata applies stretch to an already native-sized target a second time.
		# Camera unprojection is logical; apply only the engine's content stretch, never canvas
		# transforms or window/letterbox dimensions. Round away float32 basis representation error.
		var stretch: Transform2D = viewport.get_stretch_transform()
		return Vector2(roundf(logical.x * stretch.x.length()),
			roundf(logical.y * stretch.y.length()))
	# Embedded Windows and other modes need their own raw-texture qualification before use.
	return Vector2.ZERO


func _apply_floor(visual: MeshInstance3D, camera: Camera3D, sphere: SphereMesh,
	pixels_per_unit: Vector2, depth: float) -> void:
	var target: float = _details.target_diameter_px
	var base_diameter: float = _details.base_diameter_px
	var factor: float = 1.0 if base_diameter >= MIN_DIAMETER_PX else target / base_diameter
	for attempt in range(MAX_SCALE_ATTEMPTS):
		_details.attempt_count = attempt + 1
		var predicted_radius: float = float(_details.base_radius) * factor
		if not is_finite(factor) or not is_finite(predicted_radius) \
			or depth - predicted_radius <= camera.near or depth + predicted_radius >= camera.far:
			_reset_floor(visual, "floor-outside-safe-depth")
			return
		# Every attempt starts at the original transform. Float32 basis rounding is measured below.
		visual.transform = _original if factor == 1.0 else Transform3D(
			_original.basis.scaled(Vector3.ONE * factor), _original.origin)
		var world: Transform3D = visual.global_transform
		var axes: Vector3 = Vector3(world.basis.x.length(), world.basis.y.length(),
			world.basis.z.length())
		var outer: float
		var inner: float
		if visual is WiffleBallVisual:
			var shell_radii: Vector2 = _shell_radii(visual)
			outer = shell_radii.x * maxf(axes.x, maxf(axes.y, axes.z))
			inner = shell_radii.y * minf(axes.x, minf(axes.y, axes.z))
		else:
			outer = maxf(sphere.radius, sphere.height * 0.5) * (
				maxf(axes.x, maxf(axes.y, axes.z)))
			inner = minf(sphere.radius, sphere.height * 0.5) * (
				minf(axes.x, minf(axes.y, axes.z)))
		var measured: float = _projected_diameter(camera, world.origin, inner, pixels_per_unit)
		_details.last_attempt_diameter_px = measured
		_details.last_attempt_radius = outer
		if not is_finite(outer) or not is_finite(inner) or inner <= 0.0 \
			or not is_finite(measured) or measured <= 0.0 \
			or depth - outer <= camera.near or depth + outer >= camera.far:
			_reset_floor(visual, "invalid-applied-floor")
			return
		if measured >= MIN_DIAMETER_PX:
			_radius = outer
			_details.reason = "floor" if factor > 1.0 else "base"
			_details.scale = factor
			_details.effective_radius = outer
			_details.effective_diameter_px = measured
			return
		factor *= target / measured
	# Never claim a floor that the actual transformed sphere failed to reach.
	_reset_floor(visual, "floor-not-reached")


func _reset_floor(visual: MeshInstance3D, reason: String) -> void:
	visual.transform = _original
	_radius = _details.base_radius
	_details.reason = reason
	_details.scale = 1.0
	_details.effective_radius = _radius
	_details.effective_diameter_px = _details.base_diameter_px


func _projected_diameter(camera: Camera3D, center: Vector3, radius: float,
	pixels_per_unit: Vector2) -> float:
	var right: Vector3 = camera.global_basis.x.normalized() * radius
	var up: Vector3 = camera.global_basis.y.normalized() * radius
	var horizontal: Vector2 = (camera.unproject_position(center + right) - (
		camera.unproject_position(center - right))) * pixels_per_unit
	var vertical: Vector2 = (camera.unproject_position(center + up) - (
		camera.unproject_position(center - up))) * pixels_per_unit
	if not horizontal.is_finite() or not vertical.is_finite():
		return -1.0
	return minf(horizontal.length(), vertical.length())


func restore_all() -> void:
	var visual: MeshInstance3D = _object(_visual) as MeshInstance3D
	if is_instance_valid(visual):
		visual.transform = _original
	_ball = null
	_camera = null
	_visual = null
	_source_mesh = null
	_original = Transform3D.IDENTITY
	_radius = DEFAULT_RADIUS_M
	_details = {"reason": "inactive", "scale": 1.0,
		"effective_radius": DEFAULT_RADIUS_M}


func effective_radius() -> float:
	return _radius


func diagnostics() -> Dictionary:
	return _details.duplicate(true)


func _sphere_visual(ball: BattedBallBody) -> MeshInstance3D:
	for child: Node in ball.get_children():
		if child is MeshInstance3D and (child.mesh is SphereMesh \
			or (child is WiffleBallVisual and child.authored_mesh())):
			return child as MeshInstance3D
	return null


func _shell_radii(visual: WiffleBallVisual) -> Vector2:
	var half_extents: Vector3 = visual.mesh.get_aabb().size * 0.5
	return Vector2(maxf(half_extents.x, maxf(half_extents.y, half_extents.z)),
		minf(half_extents.x, minf(half_extents.y, half_extents.z)))


func _object(reference: WeakRef) -> Object:
	return reference.get_ref() if reference != null else null
