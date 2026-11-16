class_name StadiumSurfaceNightPreview
extends RefCounted
## Ephemeral, private-world presentation only. Never a season, fixture or night certificate.

enum ApplyPhase { IDLE, SHADOW_CREATED, SHADOW_VALIDATION, PALETTE }

const OWNER_META: StringName = &"owned_surface_night_preview"
const SHADOW_OWNER: String = "OwnedSurfaceNightShadowOwner"
const ENVIRONMENT_FIELDS: Array[String] = [
	"background_mode",
	"background_color",
	"ambient_light_source",
	"ambient_light_color",
	"ambient_light_energy",
	"reflected_light_source"
]

var _lab: PitchBatLab
var _state: MatchState
var _property: StadiumPropertyGeometry
var _field: FieldDefinition
var _ledger: ClubAssetLedger
var _prefix: ClubAssetLedger
var _ledger_data: String
var _prefix_data: String
var _ledger_generation: int
var _prefix_generation: int
var _candidate: Dictionary = {}
var _candidate_data: String
var _viewport: SubViewport
var _world: World3D
var _camera: Camera3D
var _environment_owner: WorldEnvironment
var _environment: Environment
var _environment_before: Dictionary = {}
var _environment_metadata: Dictionary = {}
var _working_environment: Environment
var _expected_environment: Environment
var _expected_environment_values: Dictionary = {}
var _sun: DirectionalLight3D
var _sun_before: Dictionary = {}
var _sun_expected: Dictionary = {}
var _surface: MeshInstance3D
var _material: ShaderMaterial
var _material_pigment: float
var _material_metadata: Dictionary = {}
var _working_material: ShaderMaterial
var _expected_material: ShaderMaterial
var _expected_pigment: float
var _lamps: Array[Dictionary] = []
var _shadow_before: Dictionary = {}
var _shadow_expected: Dictionary = {}
var _shadow_owner: Node
var _shadow_callback: Callable
var _shadow_started: bool = false
var _apply_phase: ApplyPhase = ApplyPhase.IDLE
var _bound: bool = false
var _active: bool = false
var _restored: bool = false
var _abandoned: bool = false


func bind(lab: PitchBatLab, candidate: Variant, ledger: ClubAssetLedger) -> bool:
	if _bound:
		return (
			ledger == _ledger
			and candidate is Dictionary
			and _data(candidate) == _candidate_data
			and installed(lab)
		)
	if not _admissible(lab, candidate, ledger):
		return false
	var prefix: ClubAssetLedger = ledger.prefix(int(candidate.entry.revision))
	if (
		(prefix == null or not StadiumSurfaceNightLayout.valid(candidate, prefix))
		or (not _capture(lab, candidate, ledger, prefix))
	):
		return false
	_bound = true
	_lab.set_meta(OWNER_META, self)
	if not _apply_night():
		restore(lab)
		return false
	_active = true
	if not installed(lab):
		restore(lab)
		return false
	return true


func installed(lab: PitchBatLab) -> bool:
	return _active and not _restored and not _abandoned and _context(lab) and _operands()


func restore(lab: PitchBatLab) -> bool:
	if not _bound or _abandoned:
		return false
	if not _context(lab) or not _operands():
		_abandoned = true
		_apply_phase = ApplyPhase.IDLE
		_disconnect_shadow_callback()
		return false
	if _restored:
		return true
	_disconnect_shadow_callback()
	# Only private duplicates were modified. Restore exact original resource identities,
	# including their pre-existing metadata; do not manufacture assumed daytime defaults.
	_surface.material_override = _material
	_expected_material = _material
	_expected_pigment = _material.get_shader_parameter("vertex_pigment_scale")
	for row: Dictionary in _lamps:
		row.lens.material_override = row.material
		row.expected_material = row.material
		row.beam.visible = row.visible
		row.expected_visible = row.visible
		row.expected_emission = row.material.emission_enabled
		row.expected_energy = row.material.emission_energy_multiplier
	_environment_owner.environment = _environment
	_expected_environment = _environment
	_expected_environment_values = _environment_values(_environment)
	_sun.light_color = _sun_before.color
	_sun.light_energy = _sun_before.energy
	_sun_expected = _sun_before.duplicate(true)
	StadiumYardNightPrototype._restore_shadows(_viewport, _shadow_before)
	_shadow_expected = _shadow_before.duplicate(true)
	if is_instance_valid(_shadow_owner):
		_shadow_owner.free()
	_shadow_owner = null
	_lab.remove_meta(OWNER_META)
	_active = false
	_restored = true
	_apply_phase = ApplyPhase.IDLE
	return _context(lab) and _operands()


func _admissible(lab: PitchBatLab, candidate: Variant, ledger: ClubAssetLedger) -> bool:
	if (
		not is_instance_valid(lab)
		or lab.get_script() != PitchBatLab
		or not lab.is_inside_tree()
		or not lab.get_meta("stadium_lab_only", false)
		or lab._managed_match
		or lab._automation != null
		or lab._field_id != PitchBatLab.FIELD_ID
		or not is_instance_valid(lab._pitch_actor)
		or lab.is_processing()
		or lab.is_physics_processing()
		or not StadiumPropertyRuntime.authoring_delivery_idle(lab)
		or lab.has_meta(OWNER_META)
		or lab.has_node(SHADOW_OWNER)
		or not StadiumSurfaceNightLayout.valid(candidate, ledger)
	):
		return false
	var viewport: SubViewport = lab.get_viewport() as SubViewport
	if (
		viewport == null
		or lab.get_parent() != viewport
		or not viewport.own_world_3d
		or viewport.get_child_count() != 1
		or viewport.get_child(0) != lab
		or viewport.find_world_3d() == lab.get_tree().root.find_world_3d()
	):
		return false
	if (
		lab._match_state == null
		or lab._stadium_ledger != ledger
		or not ClubCareer.same(lab._match_state.stadium, candidate.entry)
		or not ClubCareer.same(lab.get_meta("stadium_snapshot", {}), candidate.entry)
	):
		return false
	var value: Variant = lab.get_meta("stadium_property", null)
	if not is_instance_valid(value) or not value is StadiumPropertyGeometry:
		return false
	var property: StadiumPropertyGeometry = value
	return (
		property.get_script() == StadiumPropertyGeometry
		and lab.get_node_or_null("StarterFieldGeometry/HomeProperty") == property
		and property.tier == candidate.entry.tier
		and property.get_meta("property_signature", "") == candidate.entry.geometry
	)


func _capture(
	lab: PitchBatLab, candidate: Dictionary, ledger: ClubAssetLedger, prefix: ClubAssetLedger
) -> bool:
	_lab = lab
	_state = lab._match_state
	_property = lab.get_meta("stadium_property")
	_field = _property.field
	_ledger = ledger
	_prefix = prefix
	_ledger_data = _data(ledger.to_data())
	_prefix_data = _data(prefix.to_data())
	_ledger_generation = ledger.mutation_generation()
	_prefix_generation = prefix.mutation_generation()
	_candidate = candidate.duplicate(true)
	_candidate_data = _data(_candidate)
	_viewport = lab.get_viewport() as SubViewport
	_world = _viewport.find_world_3d()
	_camera = lab._camera
	_environment_owner = lab._world_environment
	_sun = lab.get_node_or_null("StarterFieldGeometry/Sun") as DirectionalLight3D
	_surface = (
		_property.get_node_or_null("OwnedSurfaceFinish/GroundTreatment/SurfaceVisual")
		as MeshInstance3D
	)
	if (
		not is_instance_valid(_camera)
		or _camera.get_viewport() != _viewport
		or not is_instance_valid(_environment_owner)
		or _environment_owner.get_parent() != lab
		or _environment_owner.environment == null
		or not is_instance_valid(_sun)
		or not is_instance_valid(_surface)
		or not _surface.material_override is ShaderMaterial
		or (
			_property.get_node("OwnedSurfaceFinish/GroundTreatment").get_meta("ground_style", "")
			!= "ST-063i"
		)
	):
		return false
	_environment = _environment_owner.environment
	_material = _surface.material_override as ShaderMaterial
	var pigment: Variant = _material.get_shader_parameter("vertex_pigment_scale")
	if (
		not (pigment is float or pigment is int)
		or not is_finite(float(pigment))
		or float(pigment) <= 0
	):
		return false
	if _material.has_meta("surface_day_pigment"):
		var retained: Variant = _material.get_meta("surface_day_pigment")
		if (
			not (retained is float or retained is int)
			or not is_finite(float(retained))
			or float(retained) != float(pigment)
		):
			return false
	_environment_before = _environment_values(_environment)
	_environment_metadata = _metadata(_environment)
	_material_pigment = float(pigment)
	_material_metadata = _metadata(_material)
	_working_environment = _environment.duplicate(true) as Environment
	_working_material = _material.duplicate(true) as ShaderMaterial
	if _working_environment == null or _working_material == null:
		return false
	_expected_environment = _environment
	_expected_environment_values = _environment_values(_environment)
	_expected_material = _material
	_expected_pigment = float(pigment)
	_sun_before = {"color": _sun.light_color, "energy": _sun.light_energy}
	_sun_expected = _sun_before.duplicate(true)
	_shadow_before = _shadows(_viewport)
	_shadow_expected = _shadow_before.duplicate(true)
	return _capture_lamps()


func _capture_lamps() -> bool:
	_lamps.clear()
	for placement: Dictionary in _candidate.entry.layout.lights:
		var value: Variant = _property.objects.get(placement.copy)
		if not is_instance_valid(value) or not value is Node3D:
			return false
		var model: Node3D = value
		if (
			model.get_parent() != _property
			or model.get_meta("owned_copy", "") != placement.copy
			or model.get_meta("site", "") != placement.site
			or model.get_meta("stadium_item", "") != "ST-037"
		):
			return false
		var beam: SpotLight3D = model.get_node_or_null("FieldLight") as SpotLight3D
		var lens: MeshInstance3D = model.get_node_or_null("Visual/LampLens") as MeshInstance3D
		if beam == null or lens == null or not lens.material_override is StandardMaterial3D:
			return false
		var original: StandardMaterial3D = lens.material_override as StandardMaterial3D
		var working: StandardMaterial3D = original.duplicate(true) as StandardMaterial3D
		if working == null:
			return false
		_lamps.append(
			{
				"copy": placement.copy,
				"site": placement.site,
				"model": model,
				"beam": beam,
				"lens": lens,
				"material": original,
				"working": working,
				"visible": beam.visible,
				"emission": original.emission_enabled,
				"energy": original.emission_energy_multiplier,
				"metadata": _metadata(original),
				"expected_visible": beam.visible,
				"expected_material": original,
				"expected_emission": original.emission_enabled,
				"expected_energy": original.emission_energy_multiplier
			}
		)
	return _lamps.size() == 4


func _apply_night() -> bool:
	if not _context(_lab) or not _operands():
		return false
	_environment_owner.environment = _working_environment
	_expected_environment = _working_environment
	_surface.material_override = _working_material
	_expected_material = _working_material
	for row: Dictionary in _lamps:
		row.lens.material_override = row.working
		row.expected_material = row.working
	_shadow_owner = Node.new()
	_shadow_started = true
	_shadow_owner.name = SHADOW_OWNER
	_apply_phase = ApplyPhase.SHADOW_CREATED
	_lab.add_child(_shadow_owner)
	# add_child can synchronously invoke external tree listeners. Revalidate before
	# the helper may touch the captured private environment, sun or viewport.
	if not _context(_lab) or not _operands():
		return false
	# This helper owns its callback on a new node inside this exact private viewport.
	_apply_scene()
	_expected_environment_values = _environment_values(_working_environment)
	_sun_expected = {"color": _sun.light_color, "energy": _sun.light_energy}
	_shadow_expected = _shadows(_viewport)
	var connections: Array = _shadow_owner.tree_exited.get_connections()
	# The new owner is adapter-private: remove the helper writer before any refusal.
	for connection: Dictionary in connections:
		_shadow_owner.tree_exited.disconnect(connection["callable"])
	# A failed callback validation still owns a disconnected private shadow node.
	_apply_phase = ApplyPhase.SHADOW_VALIDATION
	if connections.size() != 1:
		return false
	var helper_callback: Callable = connections[0]["callable"]
	var arguments: Array = helper_callback.get_bound_arguments()
	if arguments.size() != 2 or arguments[0] != _viewport or arguments[1] != _shadow_before:
		return false
	return _apply_night_palette()


func _apply_night_palette() -> bool:
	# Never retain the prototype's unconditional exit writer, even briefly after bind.
	_shadow_callback = _on_shadow_exiting
	_shadow_owner.tree_exiting.connect(_shadow_callback)
	_apply_phase = ApplyPhase.PALETTE
	for row: Dictionary in _lamps:
		StadiumYardLightModels.night(row.model, true)
		row.expected_visible = true
		row.expected_emission = true
		row.expected_energy = 1.0
	var applied: bool = _apply_palette()
	# A helper may fail after writing its owned material. Revalidate every owner and
	# resource before recording that post-state; never bless a replacement resource.
	if not _context(_lab) or not _operands(false):
		return false
	var pigment: Variant = _working_material.get_shader_parameter("vertex_pigment_scale")
	if not (pigment is float or pigment is int) or not is_finite(float(pigment)):
		return false
	_expected_pigment = float(pigment)
	_apply_phase = ApplyPhase.IDLE
	return applied and _context(_lab) and _operands()


func _apply_scene() -> void:
	StadiumYardNightPrototype.apply_scene(_shadow_owner, _working_environment, _sun)


func _apply_palette() -> bool:
	return StadiumSurfaceNightPalette.apply(_property)


func _context(lab: PitchBatLab) -> bool:
	if (
		lab != _lab
		or not is_instance_valid(_lab)
		or not _lab.is_inside_tree()
		or _lab.get_script() != PitchBatLab
		or not _lab.get_meta("stadium_lab_only", false)
		or _lab._managed_match
		or _lab._automation != null
		or not is_instance_valid(_lab._pitch_actor)
		or _lab.is_processing()
		or _lab.is_physics_processing()
		or not StadiumPropertyRuntime.authoring_delivery_idle(_lab)
		or _lab._match_state != _state
		or _lab._stadium_ledger != _ledger
		or _lab._camera != _camera
		or _lab._world_environment != _environment_owner
		or _lab.get_meta("stadium_property", null) != _property
		or _lab.get_node_or_null("StarterFieldGeometry/HomeProperty") != _property
		or _lab.get_node_or_null("StarterFieldGeometry/Sun") != _sun
		or _lab.get_parent() != _viewport
		or _lab.get_viewport() != _viewport
		or not is_instance_valid(_viewport)
		or not _viewport.own_world_3d
		or _viewport.get_child_count() != 1
		or _viewport.get_child(0) != _lab
		or _viewport.find_world_3d() != _world
		or _world == _lab.get_tree().root.find_world_3d()
		or not is_instance_valid(_property)
		or _property.field != _field
		or _property.tier != _candidate.entry.tier
		or _property.get_meta("property_signature", "") != _candidate.entry.geometry
		or _lab._field_id != PitchBatLab.FIELD_ID
		or not is_instance_valid(_camera)
		or _camera.get_viewport() != _viewport
		or not is_instance_valid(_environment_owner)
		or _environment_owner.get_parent() != _lab
	):
		return false
	if _lab.has_meta(OWNER_META) if _restored else _lab.get_meta(OWNER_META, null) != self:
		return false
	return (
		_ledger.mutation_generation() == _ledger_generation
		and _prefix.mutation_generation() == _prefix_generation
		and _data(_ledger.to_data()) == _ledger_data
		and _data(_prefix.to_data()) == _prefix_data
		and _data(_candidate) == _candidate_data
		and StadiumSurfaceNightLayout.valid(_candidate, _prefix)
		and ClubCareer.same(_state.stadium, _candidate.entry)
		and ClubCareer.same(_lab.get_meta("stadium_snapshot", {}), _candidate.entry)
	)


func _operands(check_pigment: bool = true) -> bool:
	# The sole relaxed value is the expected pigment during synchronous palette
	# application. All captured node/resource identities and other values stay strict.
	if (
		not check_pigment
		and (
			_apply_phase != ApplyPhase.PALETTE or _active or _expected_material != _working_material
		)
	):
		return false
	if (
		not is_instance_valid(_sun)
		or not is_instance_valid(_surface)
		or (
			_property.get_node_or_null("OwnedSurfaceFinish/GroundTreatment/SurfaceVisual")
			!= _surface
		)
		or _environment_values(_environment) != _environment_before
		or _metadata(_environment) != _environment_metadata
		or _material.get_shader_parameter("vertex_pigment_scale") != _material_pigment
		or _metadata(_material) != _material_metadata
		or _environment_owner.environment != _expected_environment
		or _environment_values(_expected_environment) != _expected_environment_values
		or _surface.material_override != _expected_material
		or (
			check_pigment
			and _expected_material.get_shader_parameter("vertex_pigment_scale") != _expected_pigment
		)
		or _sun.light_color != _sun_expected.color
		or _sun.light_energy != _sun_expected.energy
		or _shadows(_viewport) != _shadow_expected
	):
		return false
	if _shadow_started and not _restored and not is_instance_valid(_shadow_owner):
		return false
	if is_instance_valid(_shadow_owner):
		if not _shadow_operands():
			return false
	for row: Dictionary in _lamps:
		if (
			not is_instance_valid(row.model)
			or _property.objects.get(row.copy) != row.model
			or not is_instance_valid(row.beam)
			or not is_instance_valid(row.lens)
			or row.model.get_parent() != _property
			or row.model.get_meta("owned_copy", "") != row.copy
			or row.model.get_meta("site", "") != row.site
			or row.model.get_node_or_null("FieldLight") != row.beam
			or row.model.get_node_or_null("Visual/LampLens") != row.lens
			or row.material.emission_enabled != row.emission
			or row.material.emission_energy_multiplier != row.energy
			or _metadata(row.material) != row.metadata
			or row.lens.material_override != row.expected_material
			or row.beam.visible != row.expected_visible
			or row.expected_material.emission_enabled != row.expected_emission
			or row.expected_material.emission_energy_multiplier != row.expected_energy
		):
			return false
	return true


func _shadow_operands() -> bool:
	if (
		_shadow_owner.get_parent() != _lab
		or _lab.get_node_or_null(SHADOW_OWNER) != _shadow_owner
		or _shadow_owner.get_viewport() != _viewport
		or not _shadow_owner.tree_exited.get_connections().is_empty()
	):
		return false
	if _apply_phase == ApplyPhase.SHADOW_CREATED and not _active:
		if (
			_shadow_owner.has_meta("yard_shadow_profile")
			or _shadow_callback.is_valid()
			or not _shadow_owner.tree_exiting.get_connections().is_empty()
		):
			return false
	else:
		if not _shadow_owner.get_meta("yard_shadow_profile", false):
			return false
		if _apply_phase == ApplyPhase.SHADOW_VALIDATION and not _active:
			if (
				_shadow_callback.is_valid()
				or not _shadow_owner.tree_exiting.get_connections().is_empty()
			):
				return false
		elif (
			_shadow_owner.tree_exiting.get_connections().size() != 1
			or not _shadow_owner.tree_exiting.is_connected(_shadow_callback)
		):
			return false
	return true


func _on_shadow_exiting() -> void:
	# A removed/replaced owner is never an unconditional delayed atlas restore.
	# This callback can only write the captured private viewport while every owner,
	# resource, candidate and paid prefix is still exactly the one we installed.
	if (
		_active
		and _apply_phase == ApplyPhase.IDLE
		and not _restored
		and not _abandoned
		and _context(_lab)
		and _operands()
	):
		StadiumYardNightPrototype._restore_shadows(_viewport, _shadow_before)
	_active = false
	_abandoned = true
	_apply_phase = ApplyPhase.IDLE
	_disconnect_shadow_callback()


func _disconnect_shadow_callback() -> void:
	if (
		is_instance_valid(_shadow_owner)
		and _shadow_callback.is_valid()
		and _shadow_owner.tree_exiting.is_connected(_shadow_callback)
	):
		_shadow_owner.tree_exiting.disconnect(_shadow_callback)
	_shadow_callback = Callable()


static func _metadata(object: Object) -> Dictionary:
	var result: Dictionary = {}
	for key: StringName in object.get_meta_list():
		result[str(key)] = object.get_meta(key)
	return result.duplicate(true)


static func _environment_values(environment: Environment) -> Dictionary:
	var result: Dictionary = {}
	for field: String in ENVIRONMENT_FIELDS:
		result[field] = environment.get(field)
	return result


static func _shadows(viewport: Viewport) -> Dictionary:
	var result: Dictionary = {
		"precision": viewport.positional_shadow_atlas_16_bits,
		"size": viewport.positional_shadow_atlas_size,
		"quadrants": []
	}
	for index in range(4):
		result.quadrants.append(viewport.get_positional_shadow_atlas_quadrant_subdiv(index))
	return result


static func _data(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)
