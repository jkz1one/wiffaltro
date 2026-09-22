class_name ClubhouseMenuStack
extends VBoxContainer


func _ready() -> void:
	theme = ClubhouseTheme.create()
	theme.default_font_size = 14
	add_theme_constant_override("separation", 8)
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_style_box(ClubhouseTheme.surface(false, 0),
		Rect2(Vector2(-10, -10), size + Vector2(20, 20)))
