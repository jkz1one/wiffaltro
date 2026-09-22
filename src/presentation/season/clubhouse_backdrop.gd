class_name ClubhouseBackdrop
extends Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	# Quiet field geometry gives the menus an identity without production art.
	var origin: Vector2 = Vector2(size.x * 0.84, size.y * 0.91)
	var color: Color = Color("233b32")
	for radius in [110.0, 220.0, 330.0, 440.0]:
		draw_arc(origin, radius, PI * 1.12, PI * 1.88, 64, color, 1.0, true)
	for angle in [PI * 1.12, PI * 1.88]:
		draw_line(origin, origin + Vector2.from_angle(angle) * 500, color, 1, true)
	var diamond: PackedVector2Array = PackedVector2Array([
		origin, origin + Vector2(-74, -74), origin + Vector2(0, -148),
		origin + Vector2(74, -74), origin])
	draw_polyline(diamond, color, 1.0, true)
