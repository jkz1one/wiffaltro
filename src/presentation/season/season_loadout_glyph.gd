extends Control
## Interim category silhouettes, not individual item/sponsor artwork.
## Item codes and readable tile captions provide identity independently of color.

var category: String = "misc"
var inactive: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(48, 40)
	resized.connect(queue_redraw)


func _draw() -> void:
	var ink: Color = ClubhouseTheme.MUTED if inactive else ClubhouseTheme.PAPER
	var center: Vector2 = size / 2.0
	match category:
		"bat":
			draw_line(center + Vector2(-13, 13), center + Vector2(10, -10), ink, 9, true)
			draw_line(center + Vector2(-18, 18), center + Vector2(-10, 10), ink, 4, true)
		"ball":
			draw_arc(center, 16, 0, TAU, 32, ink, 2, true)
			draw_arc(center + Vector2(-17, 0), 15, -0.9, 0.9, 16, ink, 2, true)
			draw_arc(center + Vector2(17, 0), 15, PI - 0.9, PI + 0.9, 16, ink, 2, true)
		"sponsors":
			draw_line(center + Vector2(-17, 19), center + Vector2(-17, -18), ink, 3, true)
			draw_colored_polygon(
				PackedVector2Array(
					[center + Vector2(-14, -17), center + Vector2(20, -7), center + Vector2(-14, 4)]
				),
				ink
			)
		"supplies":
			draw_rect(Rect2(center + Vector2(-13, -12), Vector2(26, 29)), ink, false, 2)
			draw_rect(Rect2(center + Vector2(-8, -18), Vector2(16, 6)), ink, false, 2)
			draw_line(center + Vector2(-7, 2), center + Vector2(7, 2), ink, 3)
			draw_line(center + Vector2(0, -5), center + Vector2(0, 9), ink, 3)
		"abilities":
			var points: PackedVector2Array = PackedVector2Array()
			for index in range(11):
				var angle: float = -PI / 2.0 + index * PI / 5.0
				points.append(
					center + Vector2(cos(angle), sin(angle)) * (18.0 if index % 2 == 0 else 8.0)
				)
			draw_polyline(points, ink, 2, true)
		_:
			draw_rect(Rect2(center + Vector2(-16, -11), Vector2(32, 26)), ink, false, 2)
			draw_arc(center + Vector2(0, -11), 8, PI, TAU, 12, ink, 2, true)
			draw_line(center + Vector2(-16, 0), center + Vector2(16, 0), ink, 2)
	if inactive:
		draw_line(center + Vector2(-22, 19), center + Vector2(22, 19), ink, 2)
