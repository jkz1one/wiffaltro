class_name Ac02ReceiptLegacySeasonSave
extends "res://src/tests/ac02_receipt_legacy_season_save_scenario_base.gd"
static func save(season: SeasonState) -> bool:
	var data: Dictionary = snapshot(season)
	if data.is_empty():
		return false
	var decoded: SeasonState = _decode(data)
	if decoded == null:
		last_error = "Season data failed validation. The previous save was preserved."
		return false
	# A validated night save may preserve an exactly equivalent captured career.
	# Compare raw backing state: to_data() reconstructs assets and is not this proof.
	var original: ClubCareer = season.career
	var original_values: String = ""
	var retain_original: bool = (
		(
			data.version in [72, 73]
			or (data.version == 74 and data.get("terrain_save_version") in [72, 73])
		)
		and not decoded.owned_surface_night.is_empty()
		and original != null
		and original.get_script() == ClubCareer
		and decoded.career != null
		and decoded.career.get_script() == ClubCareer
	)
	if retain_original:
		original_values = JSON.stringify(
			[
				original.current,
				original.runs,
				original._assets,
				original._pennants,
				original._plaques
			],
			"",
			true,
			true
		)
		retain_original = ClubCareer.same(
			[
				original.current,
				original.runs,
				original._assets,
				original._pennants,
				original._plaques
			],
			[
				decoded.career.current,
				decoded.career.runs,
				decoded.career._assets,
				decoded.career._pennants,
				decoded.career._plaques
			]
		)
	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = "Could not save season. Your current session is still available."
		return false
	file.store_string(JSON.stringify(data, "", true, true))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	# Keep the last valid checkpoint; never replace it with a corrupt primary file.
	if error == OK and FileAccess.file_exists(path) and _read(path) != null:
		if DirAccess.copy_absolute(path, path + ".bak") != OK:
			last_error = "Could not back up the previous season save. Retry before closing."
			return false
	if error != OK or DirAccess.rename_absolute(path + ".tmp", path) != OK:
		last_error = "Could not replace the season save. Retry before closing."
		return false
	# Retention is only a final assignment choice after the durable rename.
	# Unequal sync progress and every day save retain their existing replacement path.
	if (
		data.has("career")
		and not (
			retain_original
			and season.career == original
			and (
				JSON.stringify(
					[
						original.current,
						original.runs,
						original._assets,
						original._pennants,
						original._plaques
					],
					"",
					true,
					true
				)
				== original_values
			)
		)
	):
		# Reuse only this save's fully decoded, unchanged modern career. Older
		# recovery/normalization paths retain their original reconstruction below.
		var checked_career: ClubCareer = _same_save_career(data.career, decoded.career)
		season.career = (
			checked_career if checked_career != null else ClubCareer.from_data(data.career)
		)
	last_error = ""
	return true


static func restore() -> SeasonState:
	last_error = ""
	var season: SeasonState = _read(path)
	if season == null:
		season = _read(path + ".bak")
		if season != null:
			last_error = "Recovered the previous checkpoint. The unreadable save was left untouched."
		elif FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak"):
			last_error = "Season save is invalid or incompatible. It has been left untouched."
	return season
