class_name StadiumBaseMarkerVisibility
extends RefCounted
## Raised cosmetic bags fade around a rolling ball instead of hiding it or changing collision.

const VERSION: int = 1
const FADED_ALPHA: float = 0.20


static func update(property: StadiumPropertyGeometry, camera: Camera3D, ball: Node3D) -> void:
	var markers: Node3D = property.get_node_or_null("BaseMarkerSet")
	if markers == null:
		return
	for mesh: MeshInstance3D in markers.get_children():
		var alpha: float = 1.0
		if is_instance_valid(ball) and is_instance_valid(camera):
			var bounds: AABB = mesh.global_transform * mesh.get_aabb()
			if bounds.grow(0.08).has_point(ball.global_position) \
				or bounds.intersects_segment(camera.global_position, ball.global_position) != null:
				alpha = FADED_ALPHA
		var material: StandardMaterial3D = mesh.material_override
		var color: Color = material.albedo_color
		color.a = alpha
		material.albedo_color = color
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if alpha < 1 \
			else BaseMaterial3D.TRANSPARENCY_DISABLED
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if alpha < 1 \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mesh.set_meta("base_render_state", "faded" if alpha < 1 else "visible")
