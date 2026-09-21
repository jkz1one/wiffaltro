class_name PitchFeedback
extends Label

const HOLD_SECONDS: float = 3.0
var remaining: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(300.0, 28.0)
	size = custom_minimum_size
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 14)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.055, 0.085, 0.94)
	add_theme_stylebox_override("normal", style)
	clear()


func show_note(message: String) -> void:
	text = message
	remaining = HOLD_SECONDS


func clear() -> void:
	remaining = 0.0
	text = ""
	visible = false


func advance(lab: PitchBatLab, delta: float) -> void:
	if not lab._debug_paused:
		remaining = maxf(0.0, remaining - delta)
	position = lab._scorebug.position + Vector2(0.0,
		-32.0 if lab._hud_anchor_index == 0 else 150.0)
	visible = (remaining > 0.0 and lab._match_mode and not lab._debug_paused
		and not lab._field_setup_active and not lab._pitching_staff_active
		and not lab._debug_overlay_visible
		and not lab._match_presentation_director.blocks_gameplay())
	modulate.a = minf(1.0, remaining / 0.25)


static func plate_message(lab: PitchBatLab, point: Vector3) -> String:
	var location: String = ""
	if point.y < lab.ZONE_MIN_Y:
		location = "LOW"
	elif point.y > lab.ZONE_MAX_Y:
		location = "HIGH"
	elif point.x < lab.ZONE_MIN_X or point.x > lab.ZONE_MAX_X:
		var left_handed: bool = lab._match_state.batter().bats_left()
		var inside: bool = point.x < 0.0 if left_handed else point.x > 0.0
		location = "INSIDE" if inside else "OUTSIDE"
	if not lab._swing_consumed:
		return "TOOK " + ("STRIKE" if location.is_empty() else location)
	var miss: String = (lab._pending_swing_miss.miss_reason_name()
		if lab._pending_swing_miss != null else "MISS")
	return miss if location.is_empty() else "CHASED %s • %s" % [location, miss]
