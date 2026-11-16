class_name StadiumReceiverVisibility
extends RefCounted
## Receiver-only render policy; collision and named contact ownership never change.

const VERSION: int = 1
const FADED_ALPHA: float = 0.20


static func apply(model: Node3D, hidden: bool, camera: Camera3D, ball: Node3D = null) -> void:
	var alpha: float = 1.0
	if not hidden and is_instance_valid(camera) and is_instance_valid(ball):
		var bounds: AABB = _bounds(model)
		# Live contact may be viewed from behind the panel; preserve the ball through a fade.
		if bounds.intersects_segment(camera.global_position, ball.global_position) != null:
			alpha = FADED_ALPHA
	_style(model, hidden, alpha)


static func _style(model: Node3D, hidden: bool, alpha: float) -> void:
	var visual: Node3D = model.get_node("Visual")
	visual.visible = not hidden
	var state: String = "hidden" if hidden else "faded" if alpha < 1 else "visible"
	model.set_meta("receiver_render_state", state)
	for mesh: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
		var material: StandardMaterial3D = mesh.material_override
		var color: Color = material.albedo_color
		color.a = alpha
		material.albedo_color = color
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if alpha < 1.0 \
			else BaseMaterial3D.TRANSPARENCY_DISABLED
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if hidden or alpha < 1.0 \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_ON


static func _bounds(model: Node3D) -> AABB:
	var result: AABB
	var first: bool = true
	for mesh: MeshInstance3D in model.get_node("Visual").find_children(
		"*", "MeshInstance3D", true, false):
		var bounds: AABB = mesh.global_transform * mesh.get_aabb()
		result = bounds if first else result.merge(bounds)
		first = false
	return result
