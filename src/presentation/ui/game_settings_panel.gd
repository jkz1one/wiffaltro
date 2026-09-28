class_name GameSettingsPanel
extends VBoxContainer

var anchor_button: Button
var backdrop_button: Button
var mute_button: Button
var volume_slider: HSlider
var _volume_label: Label
var _status: Label
var _retry: Button
var _values: Dictionary
var _lab: PitchBatLab


func build(lab: PitchBatLab = null) -> void:
	_lab = lab
	_values = (
		PitchBatLabSettings.read_values() if lab == null else PitchBatLabSettings.from_lab(lab)
	)
	add_theme_constant_override("separation", 8)
	anchor_button = _button("", _cycle_anchor)
	backdrop_button = _button("", _toggle_backdrop)
	mute_button = _button("", _toggle_mute)
	_volume_label = Label.new()
	add_child(_volume_label)
	volume_slider = HSlider.new()
	volume_slider.max_value = 100
	volume_slider.step = 5
	volume_slider.custom_minimum_size = Vector2(280, 32)
	volume_slider.value = _values.volume * 100.0
	volume_slider.tooltip_text = "Sound volume. Muting keeps this level for later."
	volume_slider.value_changed.connect(_change_volume)
	add_child(volume_slider)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 14)
	add_child(_status)
	_retry = _button("RETRY SAVING SETTINGS", _save)
	refresh()


func refresh() -> void:
	if _lab != null:
		_values = PitchBatLabSettings.from_lab(_lab)
	anchor_button.text = "Score box: " + ["Bottom right", "Top left", "Top right"][_values.anchor]
	backdrop_button.text = "Backdrop: " + ("Blue sky" if _values.sky else "Green")
	mute_button.text = "Mute sounds: " + ("On" if _values.muted else "Off")
	_volume_label.text = "Sound volume: %d%%" % roundi(_values.volume * 100.0)
	volume_slider.set_value_no_signal(_values.volume * 100.0)
	_status.text = PitchBatLabSettings.last_error
	_status.visible = not _status.text.is_empty()
	_retry.visible = _status.visible


func _cycle_anchor() -> void:
	_values.anchor = (_values.anchor + 1) % 3
	_save()


func _toggle_backdrop() -> void:
	_values.sky = not _values.sky
	_save()


func _toggle_mute() -> void:
	_values.muted = not _values.muted
	_save()


func _change_volume(value: float) -> void:
	_values.volume = value / 100.0
	_save()


func _save() -> void:
	if _lab != null:
		PitchBatLabSettings.apply(_lab, _values)
		PitchBatLabPresentation.apply_hud_anchor(_lab)
		PitchBatLabPresentation.apply_sky_backdrop(_lab)
	PitchBatLabSettings.write_values(_values)
	if _lab != null:
		_lab._refresh_config()
	refresh()


func _button(text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(300, 42)
	button.pressed.connect(action)
	add_child(button)
	return button
