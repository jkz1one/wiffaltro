extends RefCounted
## Stateless time operations for the existing surface-night runtime owner.


static func _capture_time(owner: StadiumSurfaceNightRuntime) -> bool:
	# Automated jobs intentionally have no sky/radiance textures. Preserve that path.
	owner._original_sky = owner._environment.sky
	if (
		owner._original_sky != null
		and not owner._original_sky.sky_material is ProceduralSkyMaterial
	):
		return false
	owner._time_before = {"sky_values": {}, "radiance_size": -1, "process_mode": -1}
	owner._time_expected = {
		"sky": owner._original_sky, "parameters": {}, "radiance_size": -1, "process_mode": -1
	}
	if owner._original_sky != null:
		owner._original_sky_material = owner._original_sky.sky_material as ProceduralSkyMaterial
		owner._time_before.sky_values = owner._original_sky_values()
		owner._time_before.radiance_size = owner._original_sky.radiance_size
		owner._time_before.process_mode = owner._original_sky.process_mode
		owner._time_before["shader_code"] = StadiumSurfaceNightRuntime.TIME_SKY_SHADER.code
		owner._owned_sky_material = ShaderMaterial.new()
		owner._owned_sky_material.shader = StadiumSurfaceNightRuntime.TIME_SKY_SHADER
		owner._owned_sky = Sky.new()
		owner._owned_sky.process_mode = Sky.PROCESS_MODE_REALTIME
		owner._owned_sky.sky_material = owner._owned_sky_material
		owner._time_expected.radiance_size = owner._owned_sky.radiance_size
		owner._time_expected.process_mode = owner._owned_sky.process_mode
		for parameter: StringName in StadiumSurfaceNightRuntime.SKY_PARAMETERS:
			owner._time_expected.parameters[parameter] = (
				owner._owned_sky_material.get_shader_parameter(parameter)
			)
	return true


static func _original_sky_values(owner: StadiumSurfaceNightRuntime) -> Dictionary:
	var result: Dictionary = {}
	for field: StringName in StadiumSurfaceNightRuntime.ORIGINAL_SKY_FIELDS:
		result[field] = owner._original_sky_material.get(field)
	return result


static func _time_operands(owner: StadiumSurfaceNightRuntime) -> bool:
	if (
		owner._environment.sky != owner._original_sky
		or owner._expected.environment_resource.sky != owner._time_expected.sky
	):
		return false
	if owner._original_sky != null:
		if (
			owner._original_sky.sky_material != owner._original_sky_material
			or owner._original_sky_values() != owner._time_before.sky_values
			or owner._original_sky.radiance_size != owner._time_before.radiance_size
			or owner._original_sky.process_mode != owner._time_before.process_mode
			or owner._owned_sky == null
			or owner._owned_sky.sky_material != owner._owned_sky_material
			or owner._owned_sky_material.shader != StadiumSurfaceNightRuntime.TIME_SKY_SHADER
			or StadiumSurfaceNightRuntime.TIME_SKY_SHADER.code != owner._time_before.shader_code
			or owner._owned_sky.radiance_size != owner._time_expected.radiance_size
			or owner._owned_sky.process_mode != owner._time_expected.process_mode
		):
			return false
		for parameter: StringName in StadiumSurfaceNightRuntime.SKY_PARAMETERS:
			if (
				owner._owned_sky_material.get_shader_parameter(parameter)
				!= owner._time_expected.parameters[parameter]
			):
				return false
	elif owner._owned_sky != null or owner._owned_sky_material != null:
		return false
	for row: Dictionary in owner._emitters:
		if row.beam.light_energy != row.expected_beam_energy:
			return false
	return true


static func _apply_time_presentation(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> bool:
	owner._install_step = "time:admission"
	owner._phase = StadiumSurfaceNightRuntime.Phase.PRESENTATION
	if not owner._context(lab) or not owner._operands():
		return false
	owner._install_step = "time:environment"
	owner._environment_owner.environment = owner._working_environment
	owner._expected.environment_resource = owner._working_environment
	if not owner._context(lab) or not owner._operands():
		return false
	owner._install_step = "time:surface-material"
	owner._surface.material_override = owner._working_material
	owner._expected.material_resource = owner._working_material
	if not owner._context(lab) or not owner._operands():
		return false
	if owner._owned_sky != null:
		owner._install_step = "time:sky"
		owner._working_environment.sky = owner._owned_sky
		owner._time_expected.sky = owner._owned_sky
	return _apply_time_shadows(owner, lab)


static func _apply_time_shadows(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> bool:
	# Allocate the unchanged four-shadow profile once, including a Day start.
	for index in range(4):
		owner._install_step = "time:atlas-quadrant:" + str(index)
		if not owner._context(lab) or not owner._operands():
			return false
		owner._viewport.set_positional_shadow_atlas_quadrant_subdiv(
			index, Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_1
		)
		owner._expected.shadows.quadrants[index] = (
			owner._viewport.get_positional_shadow_atlas_quadrant_subdiv(index)
		)
	if not owner._context(lab) or not owner._operands():
		return false
	owner._install_step = "time:atlas-size"
	owner._viewport.positional_shadow_atlas_size = 2048
	owner._expected.shadows.size = 2048
	if not owner._context(lab) or not owner._operands():
		return false
	owner._install_step = "time:atlas-precision"
	owner._viewport.positional_shadow_atlas_16_bits = false
	owner._expected.shadows.precision = false
	for row: Dictionary in owner._lamps:
		owner._install_step = "time:glow-material:" + String(row.site) + ":" + String(row.lens.name)
		if not owner._context(lab) or not owner._operands():
			return false
		row.lens.material_override = row.working
		row.expected_material = row.working
	return owner._write_time_values(lab, 0.0)


static func _advance_time(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> bool:
	if not owner._time_mode:
		return true
	if owner._time_updating:
		return false
	# Full input validation has already succeeded. Never change a live delivery.
	if (
		owner._state.phase != MatchState.Phase.PRE_PITCH
		or owner._pitch.running
		or is_instance_valid(lab._batted_ball)
	):
		return true
	return _advance_time_clock(owner, lab)


static func _advance_time_clock(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> bool:
	var plays: int = lab._play_records.size()
	var halves: int = (owner._state.inning - 1) * 2 + (0 if owner._state.top_half else 1)
	if plays < owner._clock_plays or halves < owner._clock_halves:
		return false
	if plays == owner._clock_plays and halves == owner._clock_halves:
		return true
	var progress: Dictionary = StadiumSurfaceNightSnapshot.clock(owner._time_profile, plays, halves)
	if progress.is_empty():
		return false
	# One tiny step per new completed-play/half tuple. Repeated calls cannot advance it.
	var target: float = StadiumSurfaceNightSnapshot.drift(owner._time_profile, progress)
	var next: float = minf(target, owner._profile_progress + 0.002)
	if not owner._write_time_values(lab, next):
		return false
	owner._clock_plays = plays
	owner._clock_halves = halves
	owner._profile_progress = next
	return owner._context(lab) and owner._operands()


static func _time_values(owner: StadiumSurfaceNightRuntime, progress: float) -> Dictionary:
	return StadiumSurfaceNightRuntime.time_values(
		owner._time_profile, progress, owner._before, owner._time_before.sky_values
	)


static func _public_time_values(
	profile: String, progress: float, before: Dictionary, sky_values: Dictionary
) -> Dictionary:
	var top: Color = sky_values.get("sky_top_color", Color(0.17, 0.43, 0.68))
	var horizon: Color = sky_values.get("sky_horizon_color", Color(0.63, 0.79, 0.88))
	var ambient: Color = horizon
	var ambient_energy: float = before.environment.ambient_light_energy
	var sun: Color = before.sun.color
	var sun_energy: float = before.sun.energy
	var lamps: float = 0.0
	var stars: float = 0.0
	var pigment: float = before.pigment
	if profile == "sunset":
		top = Color(0.08, 0.12, 0.23).lerp(Color("080f22"), progress)
		horizon = Color(0.66, 0.40, 0.30).lerp(Color("182842"), progress)
		ambient = Color("b5acb4").lerp(Color("92acc9"), progress)
		ambient_energy = lerpf(0.65, 0.52, progress)
		sun = Color(1.0, 0.72, 0.49).lerp(Color("93accb"), progress)
		sun_energy = lerpf(0.28, 0.18, progress)
		lamps = minf(1.0, progress * 3.0)
		stars = progress * 0.035 * (1.0 - lamps * 0.75)
		pigment = (
			before.pigment * lerpf(0.85, StadiumSurfaceNightPalette.PLATE_SAND_FACTOR, progress)
		)
	elif profile == "night":
		top = Color("080f22").lerp(Color("060c1d"), progress)
		horizon = Color("14263d").lerp(Color("102038"), progress)
		ambient = Color("92acc9")
		ambient_energy = 0.52 - progress * 0.02
		sun = Color("93accb")
		sun_energy = 0.28 - progress * 0.02
		lamps = 1.0
		stars = 0.012
		pigment = before.pigment * StadiumSurfaceNightPalette.PLATE_SAND_FACTOR
	else:
		top = top.darkened(progress * 0.10)
		horizon = horizon.darkened(progress * 0.10)
		sun_energy *= 1.0 - progress * 0.10
	return {
		"top_color": top,
		"horizon_color": horizon,
		"ground_color": horizon.darkened(0.30),
		"star_strength": stars,
		"ambient": ambient,
		"ambient_energy": ambient_energy,
		"sun": sun,
		"sun_energy": sun_energy,
		"lamps": lamps,
		"pigment": pigment
	}


static func _write_time_values(
	owner: StadiumSurfaceNightRuntime, lab: PitchBatLab, progress: float
) -> bool:
	if owner._time_updating or not owner._context(lab) or not owner._operands():
		return false
	owner._time_updating = true
	owner._time_update_phase = owner._phase
	owner._time_update_plays = lab._play_records.size()
	owner._time_update_halves = (owner._state.inning - 1) * 2 + (0 if owner._state.top_half else 1)
	var applied: bool = owner._write_time_values_owned(lab, progress)
	owner._time_updating = false
	return applied


static func _time_write_guard(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> bool:
	return (
		owner._time_updating
		and owner._phase == owner._time_update_phase
		and owner._context(lab)
		and owner._operands()
		and owner._state.phase == MatchState.Phase.PRE_PITCH
		and not owner._pitch.running
		and not is_instance_valid(lab._batted_ball)
		and lab._play_records.size() == owner._time_update_plays
		and (
			(owner._state.inning - 1) * 2 + (0 if owner._state.top_half else 1)
			== owner._time_update_halves
		)
	)


static func _write_time_values_owned(
	owner: StadiumSurfaceNightRuntime, lab: PitchBatLab, progress: float
) -> bool:
	var values: Dictionary = owner._time_values(progress)
	var environment: Dictionary = {
		"background_mode": Environment.BG_SKY if owner._owned_sky != null else Environment.BG_COLOR,
		"background_color": values.horizon_color,
		"ambient_light_source": Environment.AMBIENT_SOURCE_COLOR,
		"ambient_light_color": values.ambient,
		"ambient_light_energy": values.ambient_energy,
		"reflected_light_source": Environment.REFLECTION_SOURCE_DISABLED
	}
	for field: String in environment:
		owner._install_step = "time:environment:" + field
		if not owner._time_write_guard(lab):
			return false
		owner._working_environment.set(field, environment[field])
		owner._expected.environment[field] = owner._working_environment.get(field)
	for parameter: StringName in (
		StadiumSurfaceNightRuntime.SKY_PARAMETERS if owner._owned_sky_material != null else []
	):
		owner._install_step = "time:sky-parameter:" + String(parameter)
		if not owner._time_write_guard(lab):
			return false
		owner._owned_sky_material.set_shader_parameter(parameter, values[parameter])
		owner._time_expected.parameters[parameter] = owner._owned_sky_material.get_shader_parameter(
			parameter
		)
	if not owner._time_write_guard(lab):
		return false
	owner._install_step = "time:sun-color"
	owner._sun.light_color = values.sun
	owner._expected.sun.color = owner._sun.light_color
	if not owner._time_write_guard(lab):
		return false
	owner._install_step = "time:sun-energy"
	owner._sun.light_energy = values.sun_energy
	owner._expected.sun.energy = owner._sun.light_energy
	if not owner._time_write_guard(lab):
		return false
	owner._install_step = "time:pigment"
	owner._working_material.set_shader_parameter("vertex_pigment_scale", values.pigment)
	owner._expected.pigment = owner._working_material.get_shader_parameter("vertex_pigment_scale")
	return _write_time_emitters(owner, lab, values)


static func _write_time_emitters(
	owner: StadiumSurfaceNightRuntime, lab: PitchBatLab, values: Dictionary
) -> bool:
	for row: Dictionary in owner._emitters:
		owner._install_step = "time:emitter:" + String(row.site)
		if not owner._time_write_guard(lab):
			return false
		row.beam.light_energy = row.beam_energy * values.lamps
		row.expected_beam_energy = row.beam.light_energy
		if not owner._time_write_guard(lab):
			return false
		var visible: bool = values.lamps > 0.0
		if row.expected_visible != visible:
			row.expected_visible = visible
			row.beam.visible = visible
			if (
				not (
					owner._owned_transaction_configured(lab)
					if owner._owned_boundary_mode()
					else owner._configured(lab)
				)
				or not owner._time_write_guard(lab)
			):
				return false
	return _write_time_lamps(owner, lab, values)


static func _write_time_lamps(
	owner: StadiumSurfaceNightRuntime, lab: PitchBatLab, values: Dictionary
) -> bool:
	for row: Dictionary in owner._lamps:
		owner._install_step = "time:glow:" + String(row.site) + ":" + String(row.lens.name)
		if not owner._time_write_guard(lab):
			return false
		if owner._floodlight_mode:
			var visible: bool = values.lamps > 0.0
			if row.expected_lens_visible != visible:
				row.expected_lens_visible = visible
				row.lens.visible = visible
				if (
					not (
						owner._owned_transaction_configured(lab)
						if owner._owned_boundary_mode()
						else owner._configured(lab)
					)
					or not owner._time_write_guard(lab)
				):
					return false
		row.working.emission_enabled = values.lamps > 0.0
		row.expected_emission = row.working.emission_enabled
		if not owner._time_write_guard(lab):
			return false
		row.working.emission_energy_multiplier = values.lamps
		row.expected_energy = row.working.emission_energy_multiplier
	return owner._time_write_guard(lab)
