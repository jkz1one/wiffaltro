class_name PitchBatLabSettings
extends RefCounted

static var path: String = "user://display-settings.cfg"


static func restore(lab: PitchBatLab) -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(path) != OK:
		return
	var anchor: Variant = config.get_value("display", "scorebox_anchor", 0)
	var mute: Variant = config.get_value("audio", "muted", false)
	if mute is bool:
		lab._sounds_muted = mute
		if lab._sounds != null:
			lab._sounds.set_muted(mute)
	var sky: Variant = config.get_value("display", "blue_sky", true)
	if anchor is int:
		lab._hud_anchor_index = clampi(anchor, 0, 2)
	if sky is bool:
		lab._sky_backdrop_enabled = sky


static func save(lab: PitchBatLab) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("display", "scorebox_anchor", lab._hud_anchor_index)
	config.set_value("display", "blue_sky", lab._sky_backdrop_enabled)
	config.set_value("audio", "muted", lab._sounds_muted)
	if config.save(path) != OK:
		push_warning("Settings could not be saved; current choices still apply.")
