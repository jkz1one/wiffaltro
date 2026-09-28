class_name PitchBatLabSettings
extends RefCounted

static var path: String = "user://display-settings.cfg"
static var last_error: String = ""


static func read_values() -> Dictionary:
	var values: Dictionary = {"anchor": 0, "sky": true, "muted": false, "volume": 1.0}
	var config: ConfigFile = ConfigFile.new()
	if config.load(path) != OK:
		return values
	var anchor: Variant = config.get_value("display", "scorebox_anchor", 0)
	var sky: Variant = config.get_value("display", "blue_sky", true)
	var mute: Variant = config.get_value("audio", "muted", false)
	var volume: Variant = config.get_value("audio", "volume", 1.0)
	if anchor is int:
		values.anchor = clampi(anchor, 0, 2)
	if sky is bool:
		values.sky = sky
	if mute is bool:
		values.muted = mute
	if (volume is int or volume is float) and is_finite(float(volume)):
		values.volume = clampf(float(volume), 0.0, 1.0)
	return values


static func from_lab(lab: PitchBatLab) -> Dictionary:
	return {
		"anchor": lab._hud_anchor_index,
		"sky": lab._sky_backdrop_enabled,
		"muted": lab._sounds_muted,
		"volume": lab._sound_volume
	}


static func apply(lab: PitchBatLab, values: Dictionary) -> void:
	lab._hud_anchor_index = values.anchor
	lab._sky_backdrop_enabled = values.sky
	lab._sounds_muted = values.muted
	lab._sound_volume = values.volume
	if lab._sounds != null:
		lab._sounds.set_muted(lab._sounds_muted)
		lab._sounds.set_volume(lab._sound_volume)


static func restore(lab: PitchBatLab) -> void:
	apply(lab, read_values())


static func save(lab: PitchBatLab) -> bool:
	return write_values(from_lab(lab))


static func write_values(values: Dictionary) -> bool:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("display", "scorebox_anchor", values.anchor)
	config.set_value("display", "blue_sky", values.sky)
	config.set_value("audio", "muted", values.muted)
	config.set_value("audio", "volume", values.volume)
	if config.save(path + ".tmp") != OK or DirAccess.rename_absolute(path + ".tmp", path) != OK:
		last_error = "Settings could not be saved. Retry before closing."
		return false
	last_error = ""
	return true
