extends Node
## Presentation-only contract. No owner, save, field or gameplay access.
var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _ready() -> void:
	var root: VBoxContainer = VBoxContainer.new()
	root.theme = ClubhouseTheme.create()
	add_child(root)
	var primary: Button = SeasonMenu._button(root, "CONTINUE SEASON", func() -> void: pass)
	primary.grab_focus()
	check(primary.has_focus(), "Continue receives the same initial keyboard focus as Main")
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		check(primary.has_theme_color_override(state), "primary explicitly styles " + state)
		check(primary.get_theme_color(state) == ClubhouseTheme.INK, "dark foreground in " + state)
	for state: String in ["normal", "hover", "pressed"]:
		check(primary.has_theme_stylebox_override(state), "primary retains gold style for " + state)
	check(not primary.has_theme_color_override("font_disabled_color"), "disabled foreground keeps the shared theme")
	var secondary: Button = SeasonMenu._button(root, "CLUB RECORD", func() -> void: pass)
	check(not secondary.has_theme_color_override("font_focus_color"), "ordinary button foreground is unchanged")
	primary.disabled = true
	check(primary.get_theme_color("font_disabled_color") == root.theme.get_color("font_disabled_color", "Button"), "disabled primary retains muted readable foreground")
	root.free()
	print("CLUBHOUSE_PRIMARY_FOCUS checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
