extends RefCounted
## Stateless operations for the original SeasonSave script.


static func _public_save(season: SeasonState, _ac02_career_write: Variant = null) -> bool:
	if not WorkingPitchDynastySave.owner_context_valid(season):
		SeasonSave.last_error = "Current Dynasty requires its exact durable selected owner."
		return false
	# Only the synchronous revoked-settlement owner creates this empty local output.
	# Ordinary callers retain every historical observation and assignment below.
	if (
		_ac02_career_write != null
		and (
			not _ac02_career_write is Array
			or _ac02_career_write.is_read_only()
			or not _ac02_career_write.is_empty()
		)
	):
		SeasonSave.last_error = "Invalid settlement save transaction. The previous save was preserved."
		return false
	if SeasonSave.dynasty_owner_bound():
		return SeasonSave._owner_checkpoint(season)
	var data: Dictionary = SeasonSave.snapshot(season)
	if data.is_empty():
		return false
	var decoded: SeasonState = SeasonSave._decode(data)
	if decoded == null:
		SeasonSave.last_error = "Season data failed validation. The previous save was preserved."
		return false
	# Owned87 keeps its validated Career27 inside81; publish that same decoded
	# career only after the unchanged durable rename, never mutate the envelope.
	var published: Dictionary = data.checkpoint if data.version in [93, 94] or WorkingPitchProgression.is_version(data.version, WorkingPitchCareerSave.VERSION) else data
	if published.version == 87:
		published = published.checkpoint
	# A validated night save may preserve an exactly equivalent captured career.
	# Compare raw backing state: to_data() reconstructs assets and is not this proof.
	var original: ClubCareer = season.career
	var original_values: String = ""
	var retain_original: bool = (
		(
			data.version in [72, 73, 94]
			or (WorkingPitchProgression.is_version(data.version, WorkingPitchLeagueSave.VERSION)
				and data.home_context.get("format") == 94)
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
	var file: FileAccess = FileAccess.open(SeasonSave.path + ".tmp", FileAccess.WRITE)
	if file == null:
		SeasonSave.last_error = "Could not save season. Your current session is still available."
		return false
	file.store_string(JSON.stringify(data, "", true, true))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	# Keep the last valid checkpoint; never replace it with a corrupt primary file.
	if (
		error == OK
		and FileAccess.file_exists(SeasonSave.path)
		and SeasonSave._read(SeasonSave.path) != null
	):
		if DirAccess.copy_absolute(SeasonSave.path, SeasonSave.path + ".bak") != OK:
			SeasonSave.last_error = "Could not back up the previous season save. Retry before closing."
			return false
	if error != OK or DirAccess.rename_absolute(SeasonSave.path + ".tmp", SeasonSave.path) != OK:
		SeasonSave.last_error = "Could not replace the season save. Retry before closing."
		return false
	# Retention is only a final assignment choice after the durable rename.
	# Unequal sync progress and every day save retain their existing replacement path.
	if (
		published.has("career")
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
		var checked_career: ClubCareer = SeasonSave._same_save_career(published.career, decoded.career)
		if _ac02_career_write == null:
			season.career = (
				checked_career if checked_career != null else ClubCareer.from_data(published.career)
			)
		else:
			# Capture the object this invocation actually publishes, not a later lookup.
			# Keep the replaced reference alive across the assignment and receipt return.
			var replacement: ClubCareer = (
				checked_career if checked_career != null else ClubCareer.from_data(published.career)
			)
			var replaced: ClubCareer = season.career
			season.career = replacement
			var budget: Array[int] = [
				StadiumNpcAc02IssuedStateV1.MAX_ENTRIES,
				StadiumNpcAc02IssuedStateV1.MAX_STRING_BYTES
			]
			var saved_values: Variant = StadiumNpcAc02IssuedStateV1._copy_canonical(
				[
					published.career.get("current"),
					published.career.get("runs"),
					published.career.get("assets"),
					published.career.get("pennants", {}),
					published.career.get("plaques", {})
				],
				budget
			)
			if data.version == 61 and budget[0] >= 0 and budget[1] >= 0 and saved_values is Array:
				_ac02_career_write.append([season, replaced, replacement, saved_values])
	SeasonSave.last_error = ""
	return true
