class_name StadiumSurfaceNightRuntime
extends RefCounted
## One family-specific transaction, including a shared-viewport exclusive atlas owner.
## Configuration grants no public exposure and never changes historical light binding.

enum Phase { CONFIGURED, GEOMETRY, PRESENTATION, ACTIVE, RETIRED, ABANDONED }
const OWNER: StringName = &"owned_surface_night_runtime"
const BOUND: StringName = &"owned_surface_night_bound"
const ATLAS: StringName = &"owned_surface_night_atlas_owner"
const BALL: StringName = &"owned_surface_night_ball_owner"
const REMOVED: Array[String] = [
	"Ground",
	"BackWall",
	"LiveObjectPole",
	"Plate",
	"MoundMarker",
	"SafeBoundary",
	"DeepAirBoundary",
	"RightFoulLine",
	"LeftFoulLine"
]
const META: Array[StringName] = [
	&"stadium_property", &"stadium_snapshot", &"boundary_signature", &"stadium_environment"
]
const VISIBILITY: Array[StringName] = [
	&"field_wall_z", &"_obstacles", &"_uprights", &"_recipe", &"_wall_bounds", &"_wall_prisms"
]

const TIME_SKY_SHADER: Shader = preload(
	"res://src/presentation/stadium/stadium_game_stars.gdshader"
)
const SKY_PARAMETERS: Array[StringName] = [
	&"top_color", &"horizon_color", &"ground_color", &"star_strength"
]
const ORIGINAL_SKY_FIELDS: Array[StringName] = [
	&"sky_top_color",
	&"sky_horizon_color",
	&"sky_curve",
	&"sky_energy_multiplier",
	&"ground_bottom_color",
	&"ground_horizon_color",
	&"ground_curve",
	&"ground_energy_multiplier",
	&"sun_angle_max",
	&"sun_curve"
]

const RuntimeEntry: GDScript = preload(
	"res://src/presentation/stadium/stadium_surface_night_runtime_entry.gd"
)
const RuntimeInputs: GDScript = preload(
	"res://src/presentation/stadium/stadium_surface_night_runtime_inputs.gd"
)
const RuntimeInstallation: GDScript = preload(
	"res://src/presentation/stadium/stadium_surface_night_runtime_installation.gd"
)
const RuntimeBoundary: GDScript = preload(
	"res://src/presentation/stadium/stadium_surface_night_runtime_boundary.gd"
)
const RuntimeLighting: GDScript = preload(
	"res://src/presentation/stadium/stadium_surface_night_runtime_lighting.gd"
)
const RuntimeOperands: GDScript = preload(
	"res://src/presentation/stadium/stadium_surface_night_runtime_operands.gd"
)
const RuntimeRestoration: GDScript = preload(
	"res://src/presentation/stadium/stadium_surface_night_runtime_restoration.gd"
)
const RuntimeTime: GDScript = preload(
	"res://src/presentation/stadium/stadium_surface_night_runtime_time.gd"
)
const RuntimeAuthority: GDScript = preload(
	"res://src/presentation/stadium/stadium_surface_night_runtime_authority.gd"
)


class KitBoundaryNodeSeal:
	extends RefCounted
	# Candidate3 critical hot schema. Full serialized state remains at transitions.
	var node: Node3D
	var parent: Node
	var node_name: StringName
	var children: Array[Node]
	var metadata: Dictionary
	var visual: MeshInstance3D
	var body: StaticBody3D
	var collision: CollisionShape3D
	var surface_materials: Array[Material] = []
	var n_transform: Transform3D
	var n_top_level: bool
	var n_visible: bool
	var n_process_mode: int
	var n_visibility_parent: NodePath
	var n_physics_interpolation_mode: int
	var v_mesh: Mesh
	var v_material_override: Material
	var v_material_overlay: Material
	var v_transparency: float
	var v_cast_shadow: int
	var v_layers: int
	var v_extra_cull_margin: float
	var v_custom_aabb: AABB
	var v_lod_bias: float
	var v_ignore_occlusion_culling: bool
	var v_visibility_range_begin: float
	var v_visibility_range_begin_margin: float
	var v_visibility_range_end: float
	var v_visibility_range_end_margin: float
	var v_visibility_range_fade_mode: int
	var v_sorting_offset: float
	var v_sorting_use_aabb_center: bool
	var v_gi_mode: int
	var v_gi_lightmap_texel_scale: int
	var v_skin: Skin
	var v_skeleton: NodePath
	var b_collision_layer: int
	var b_collision_mask: int
	var b_collision_priority: float
	var b_disable_mode: int
	var b_physics_material_override: PhysicsMaterial
	var b_constant_linear_velocity: Vector3
	var b_constant_angular_velocity: Vector3
	var c_shape: Shape3D
	var c_disabled: bool

	func _init(source: Node3D) -> void:
		node = source
		parent = node.get_parent()
		node_name = node.name
		children.assign(node.get_children(true))
		metadata = StadiumSurfaceNightRuntime._metadata(node)
		n_transform = node.transform
		n_top_level = node.top_level
		n_visible = node.visible
		n_process_mode = node.process_mode
		n_visibility_parent = node.visibility_parent
		n_physics_interpolation_mode = node.physics_interpolation_mode
		if node is MeshInstance3D:
			visual = node as MeshInstance3D
			v_mesh = visual.mesh
			v_material_override = visual.material_override
			v_material_overlay = visual.material_overlay
			v_transparency = visual.transparency
			v_cast_shadow = visual.cast_shadow
			v_layers = visual.layers
			v_extra_cull_margin = visual.extra_cull_margin
			v_custom_aabb = visual.custom_aabb
			v_lod_bias = visual.lod_bias
			v_ignore_occlusion_culling = visual.ignore_occlusion_culling
			v_visibility_range_begin = visual.visibility_range_begin
			v_visibility_range_begin_margin = visual.visibility_range_begin_margin
			v_visibility_range_end = visual.visibility_range_end
			v_visibility_range_end_margin = visual.visibility_range_end_margin
			v_visibility_range_fade_mode = visual.visibility_range_fade_mode
			v_sorting_offset = visual.sorting_offset
			v_sorting_use_aabb_center = visual.sorting_use_aabb_center
			v_gi_mode = visual.gi_mode
			v_gi_lightmap_texel_scale = visual.gi_lightmap_texel_scale
			v_skin = visual.skin
			v_skeleton = visual.skeleton
			for index in range(visual.mesh.get_surface_count()):
				surface_materials.append(visual.get_surface_override_material(index))
		if node is StaticBody3D:
			body = node as StaticBody3D
			b_collision_layer = body.collision_layer
			b_collision_mask = body.collision_mask
			b_collision_priority = body.collision_priority
			b_disable_mode = body.disable_mode
			b_physics_material_override = body.physics_material_override
			b_constant_linear_velocity = body.constant_linear_velocity
			b_constant_angular_velocity = body.constant_angular_velocity
		if node is CollisionShape3D:
			collision = node as CollisionShape3D
			c_shape = collision.shape
			c_disabled = collision.disabled

	func intact() -> bool:
		if (
			not is_instance_valid(node)
			or node.is_queued_for_deletion()
			or node.get_script() != null
			or not is_same(node.get_parent(), parent)
			or node.name != node_name
			or node.get_children(true) != children
			or StadiumSurfaceNightRuntime._metadata(node) != metadata
		):
			return false
		if (
			node.transform != n_transform
			or node.top_level != n_top_level
			or node.visible != n_visible
			or node.process_mode != n_process_mode
			or node.visibility_parent != n_visibility_parent
			or node.physics_interpolation_mode != n_physics_interpolation_mode
		):
			return false
		if visual != null:
			if (
				not is_same(visual.mesh, v_mesh)
				or not is_same(visual.material_override, v_material_override)
				or not is_same(visual.material_overlay, v_material_overlay)
				or visual.transparency != v_transparency
				or visual.cast_shadow != v_cast_shadow
				or visual.layers != v_layers
				or visual.extra_cull_margin != v_extra_cull_margin
				or visual.custom_aabb != v_custom_aabb
				or visual.lod_bias != v_lod_bias
				or visual.ignore_occlusion_culling != v_ignore_occlusion_culling
				or visual.visibility_range_begin != v_visibility_range_begin
				or visual.visibility_range_begin_margin != v_visibility_range_begin_margin
				or visual.visibility_range_end != v_visibility_range_end
				or visual.visibility_range_end_margin != v_visibility_range_end_margin
				or visual.visibility_range_fade_mode != v_visibility_range_fade_mode
				or visual.sorting_offset != v_sorting_offset
				or visual.sorting_use_aabb_center != v_sorting_use_aabb_center
				or visual.gi_mode != v_gi_mode
				or visual.gi_lightmap_texel_scale != v_gi_lightmap_texel_scale
				or not is_same(visual.skin, v_skin)
				or visual.skeleton != v_skeleton
			):
				return false
			if visual.mesh.get_surface_count() != surface_materials.size():
				return false
			for index in range(surface_materials.size()):
				if not is_same(
					visual.get_surface_override_material(index), surface_materials[index]
				):
					return false
		return _body_and_collision_intact()

	func _body_and_collision_intact() -> bool:
		if body != null:
			if (
				body.collision_layer != b_collision_layer
				or body.collision_mask != b_collision_mask
				or body.collision_priority != b_collision_priority
				or body.disable_mode != b_disable_mode
				or not is_same(body.physics_material_override, b_physics_material_override)
				or body.constant_linear_velocity != b_constant_linear_velocity
				or body.constant_angular_velocity != b_constant_angular_velocity
			):
				return false
		if collision != null:
			if not is_same(collision.shape, c_shape) or collision.disabled != c_disabled:
				return false
		return true


var _diagnostics_enabled: bool = false
var _guard_timing_enabled: bool = false
var _guard_timings: Dictionary = {}
var _action_sample_enabled: bool = false
var _action_samples: Dictionary = {}
var _diagnostics_reported: bool = false
var _install_step: String = "configure"
var _floodlight_mode: bool = false
var _kit_mode: bool = false
var _kit_physical_layout: Dictionary = {}
var _kit_physical_geometry: String = ""
var _kit_profile: Dictionary = {}
var _kit_profile_data: String = ""
var _kit_lease: StadiumLightingKitPreviewRuntime
var _kit_texture_seal: StadiumKitSurfaceTextureSeal
var _kit_children: Array[Node] = []
# Candidate3 issued-state contract. Never persisted or reissued on the same owner.
var _kit_issue_ever: bool = false
var _kit_authority: StadiumLightingKitIssuedAuthority
var _kit_issued_receipt: Dictionary = {}
var _kit_issue_refs: Dictionary = {}
var _kit_absence_manifest: Dictionary = {}
var _kit_export_manifest: Dictionary = {}
var _kit_boundary_graph: StadiumRecipeBoundary
var _kit_issue_live: bool = false
var _kit_issue_invalid: bool = false
var _kit_issue_watch: Array[Dictionary] = []
var _kit_collision_nodes: Array[KitBoundaryNodeSeal] = []
var _kit_collision_resources: Array[Dictionary] = []
var _kit_light_rows: Array[Dictionary] = []
var _kit_root_rows: Array[Dictionary] = []

var _kit_boundary_visuals: Dictionary = {}
var _kit_boundary_pool: Dictionary = {}
var _kit_input_rows: Array[Dictionary] = []
var _floodlight_profile: String = ""
var _towers: Array[Dictionary] = []
var _companions: Array[Dictionary] = []
var _emitters: Array[Dictionary] = []
var _glow_resources: Array[Dictionary] = []
var _owned_property: Dictionary = {}
var _time_mode: bool = false
var _time_profile: String = ""
var _original_sky: Sky
var _original_sky_material: ProceduralSkyMaterial
var _owned_sky: Sky
var _owned_sky_material: ShaderMaterial
var _time_before: Dictionary = {}
var _time_expected: Dictionary = {}
var _clock_plays: int = 0
var _clock_halves: int = 0
var _profile_progress: float = 0.0
var _time_updating: bool = false
var _time_update_phase: Phase = Phase.CONFIGURED
var _time_update_plays: int = 0
var _time_update_halves: int = 0
var _lab: WeakRef
var _season: SeasonState
var _state: MatchState
var _paid: ClubAssetLedger
var _paid_generation: int
var _paid_data: String
var _snapshot: Dictionary
var _policy_data: String
var _proof: Dictionary
# Private value snapshots. No live Dictionary/Array is retained as sealed authority.
var _paid_state: String
var _career: ClubCareer
var _replay_paid: ClubAssetLedger
var _replay_generation: int = 0
var _replay_state: String
var _season_inputs: String
var _owned_backing_inputs: String
var _snapshot_data: String
var _proof_data: String
# Captured scalar bindings are the only authority data consumed between boundaries.
# Bulk mutable inputs remain checked against their original strings at full boundaries.
var _fixture_id: int
var _match_seed: int
var _tier: String
var _geometry_signature: String
var _season_seed: int
var _season_phase: int
var _season_round: int
var _career_run: int = -1
var _replay_run: int
var _paid_resources: Array = []
var _replay_resources: Array = []
var _field_fair: float
var _field_safe: float
var _field_deep: float
var _field_wall: float
var _field_home_run: float
var _field_dead: float
var _field_shallow_anchor: float
var _field_middle_anchor: float
var _field_middle_center_anchor: float
var _field_deep_anchor: float
var _field_side_anchor: float
var _phase: Phase = Phase.CONFIGURED
var _host: StarterFieldLabGeometry
var _parent: Node
var _viewport: Viewport
var _world: World3D
var _property: StadiumPropertyGeometry
var _boundary: Node3D
var _field: FieldDefinition
var _property_field: FieldDefinition
var _restoring: bool = false
var _tree_transition: bool = false
var _retire_requested: bool = false
var _camera: Camera3D
var _pitch: PitchFlightActor
var _resolver: BallPlayResolver
var _fielder: FielderController
var _director: MatchCameraDirector
var _tracking: BallTrackingVisibility
var _environment_owner: WorldEnvironment
var _environment: Environment
var _working_environment: Environment
var _sun: DirectionalLight3D
var _surface: MeshInstance3D
var _material: ShaderMaterial
var _working_material: ShaderMaterial
var _lamps: Array[Dictionary] = []
var _old_nodes: Array = []
var _old_order: Array = []
var _before: Dictionary = {}
var _expected: Dictionary = {}
var _exit_callback: Callable
var _palette_applying: bool = false
var _candidate: WeakRef
var _candidate_play: BallPlayState


static func configure(lab: PitchBatLab, season: SeasonState, paid: ClubAssetLedger) -> bool:
	return RuntimeEntry._public_configure(lab, season, paid)


static func current(lab: PitchBatLab) -> StadiumSurfaceNightRuntime:
	return RuntimeEntry._public_current(lab)


static func install_bound(lab: PitchBatLab) -> bool:
	return RuntimeEntry._public_install_bound(lab)


static func installed_bound(lab: PitchBatLab, snapshot: Dictionary) -> bool:
	return RuntimeEntry._public_installed_bound(lab, snapshot)


static func action_allowed(lab: PitchBatLab) -> bool:
	return RuntimeEntry._public_action_allowed(lab)


static func boundary_allowed(lab: PitchBatLab) -> bool:
	return RuntimeEntry._public_boundary_allowed(lab)


static func continue_boundary(
	lab: PitchBatLab, owner: StadiumSurfaceNightRuntime, state: MatchState
) -> bool:
	return RuntimeEntry._public_continue_boundary(lab, owner, state)


static func capture_proof(lab: PitchBatLab) -> Dictionary:
	return RuntimeEntry._public_capture_proof(lab)


static func retire(lab: PitchBatLab, _reason: String) -> void:
	RuntimeEntry._public_retire(lab, _reason)


static func continue_action(
	lab: PitchBatLab, owner: StadiumSurfaceNightRuntime, state: MatchState
) -> bool:
	return RuntimeEntry._public_continue_action(lab, owner, state)


static func continue_pitch(
	lab: PitchBatLab,
	owner: StadiumSurfaceNightRuntime,
	state: MatchState,
	actor: Variant,
	parameters: PitchLaunchParameters
) -> bool:
	return RuntimeEntry._public_continue_pitch(lab, owner, state, actor, parameters)


static func continue_startup(
	lab: PitchBatLab, owner: StadiumSurfaceNightRuntime, state: MatchState
) -> bool:
	return RuntimeEntry._public_continue_startup(lab, owner, state)


static func claim_ball(
	lab: PitchBatLab,
	owner: StadiumSurfaceNightRuntime,
	state: MatchState,
	ball: Variant,
	play: BallPlayState
) -> bool:
	return RuntimeEntry._public_claim_ball(lab, owner, state, ball, play)


static func continue_ball(
	lab: PitchBatLab,
	owner: StadiumSurfaceNightRuntime,
	state: MatchState,
	ball: Variant,
	play: BallPlayState
) -> bool:
	return RuntimeEntry._public_continue_ball(lab, owner, state, ball, play)


func _candidate_owned(lab: PitchBatLab, ball: Variant, play: BallPlayState) -> bool:
	return RuntimeEntry._candidate_owned(self, lab, ball, play)


func _reject_candidate(lab: PitchBatLab, ball: Variant, play: BallPlayState) -> void:
	RuntimeEntry._reject_candidate(self, lab, ball, play)


static func retire_captured(lab: PitchBatLab, owner: StadiumSurfaceNightRuntime) -> void:
	RuntimeEntry._public_retire_captured(lab, owner)


func _same_target(lab: PitchBatLab) -> bool:
	return RuntimeEntry._same_target(self, lab)


func _retire_target(lab: PitchBatLab) -> void:
	RuntimeEntry._retire_target(self, lab)


func _configured(lab: PitchBatLab) -> bool:
	return RuntimeEntry._configured(self, lab)


func _active_kit_transaction_configured(lab: PitchBatLab) -> bool:
	return RuntimeEntry._active_kit_transaction_configured(self, lab)


func _owned_transaction_configured(lab: PitchBatLab) -> bool:
	return RuntimeEntry._owned_transaction_configured(self, lab)


func _identity_configured(lab: PitchBatLab) -> bool:
	return RuntimeEntry._identity_configured(self, lab)


func _live_configured(lab: PitchBatLab) -> bool:
	return RuntimeEntry._live_configured(self, lab)


func _wrapped_live_inputs_configured(lab: PitchBatLab) -> bool:
	return RuntimeEntry._wrapped_live_inputs_configured(self, lab)


func _owned_live_configured(lab: PitchBatLab) -> bool:
	return RuntimeEntry._owned_live_configured(self, lab)


func _capture_kit_inputs() -> bool:
	return RuntimeInputs._capture_kit_inputs(self)


static func _kit_frozen_copy(value: Variant) -> Variant:
	return RuntimeInputs._kit_frozen_copy(value)


func _kit_inputs_intact() -> bool:
	return RuntimeInputs._kit_inputs_intact(self)


func _owned_backing_state() -> String:
	return RuntimeInputs._owned_backing_state(self)


func _record_action_sample(key: String, started_us: int, accepted: bool) -> void:
	RuntimeInputs._record_action_sample(self, key, started_us, accepted)


func _record_guard_timing(key: String, started_us: int) -> void:
	RuntimeInputs._record_guard_timing(self, key, started_us)


static func _ledger_resources(ledger: ClubAssetLedger) -> Array:
	return RuntimeInputs._ledger_resources(ledger)


static func _ledger_identity(ledger: ClubAssetLedger, resources: Array) -> bool:
	return RuntimeInputs._ledger_identity(ledger, resources)


func _field_unchanged() -> bool:
	return RuntimeInputs._field_unchanged(self)


func _season_state() -> String:
	return RuntimeInputs._season_state(self)


static func _ledger_state(ledger: ClubAssetLedger) -> String:
	return RuntimeInputs._ledger_state(ledger)


func _admissible(lab: PitchBatLab) -> bool:
	return RuntimeInputs._admissible(self, lab)


func _node_operands_valid(lab: PitchBatLab) -> bool:
	return RuntimeInputs._node_operands_valid(self, lab)


func _caller(lab: PitchBatLab) -> bool:
	return RuntimeInputs._caller(self, lab)


func _install(lab: PitchBatLab) -> bool:
	return RuntimeInstallation._install(self, lab)


func _capture(lab: PitchBatLab) -> bool:
	return RuntimeInstallation._capture(self, lab)


func _owned_boundary_mode() -> bool:
	return RuntimeInstallation._owned_boundary_mode(self)


func _capture_kit(lab: PitchBatLab) -> bool:
	return RuntimeInstallation._capture_kit(self, lab)


func _kit_texture_issuance_allowed(property: StadiumPropertyGeometry) -> bool:
	return RuntimeInstallation._kit_texture_issuance_allowed(self, property)


func _kit_lease_context(lease: StadiumLightingKitPreviewRuntime, require_claim: bool) -> bool:
	return RuntimeInstallation._kit_lease_context(self, lease, require_claim)


func _attached_kit_lease(lease: StadiumLightingKitPreviewRuntime) -> bool:
	return RuntimeInstallation._attached_kit_lease(self, lease)


func _kit_toggle_allowed(lease: StadiumLightingKitPreviewRuntime, enabled: bool) -> bool:
	return RuntimeInstallation._kit_toggle_allowed(self, lease, enabled)


func _kit_transaction_intact(lease: StadiumLightingKitPreviewRuntime) -> bool:
	return RuntimeInstallation._kit_transaction_intact(self, lease)


func _kit_operands() -> bool:
	return RuntimeInstallation._kit_operands(self)


static func _kit_value_equal(actual: Variant, expected: Variant) -> bool:
	return RuntimeBoundary._kit_value_equal(actual, expected)


static func _kit_no_internal_children(root: Node) -> bool:
	return RuntimeBoundary._kit_no_internal_children(root)


func _kit_boundary_visual_fingerprint() -> String:
	return RuntimeBoundary._kit_boundary_visual_fingerprint(self)


func _pool_kit_boundary_visuals() -> bool:
	return RuntimeBoundary._pool_kit_boundary_visuals(self)


func _capture_kit_boundary_visuals() -> bool:
	return RuntimeBoundary._capture_kit_boundary_visuals(self)


func _kit_boundary_visuals_intact(deep: bool = false) -> bool:
	return RuntimeBoundary._kit_boundary_visuals_intact(self, deep)


func _capture_floodlights() -> bool:
	return RuntimeLighting._capture_floodlights(self)


func _capture_glow_materials(original: StandardMaterial3D, working: StandardMaterial3D) -> bool:
	return RuntimeLighting._capture_glow_materials(self, original, working)


static func _placement_metadata(model: Node3D, placement: Dictionary) -> bool:
	return RuntimeLighting._placement_metadata(model, placement)


func _owned_property_intact() -> bool:
	return RuntimeLighting._owned_property_intact(self)


func _apply_presentation(lab: PitchBatLab) -> bool:
	return RuntimeLighting._apply_presentation(self, lab)


func _context(lab: PitchBatLab) -> bool:
	return RuntimeOperands._context(self, lab)


func _operands(check_pigment: bool = true) -> bool:
	return RuntimeOperands._operands(self, check_pigment)


func _member_model_intact(row: Dictionary) -> bool:
	return RuntimeOperands._member_model_intact(self, row)


func _after_tree_transition(lab: PitchBatLab) -> bool:
	return RuntimeOperands._after_tree_transition(self, lab)


func _restore(lab: PitchBatLab) -> void:
	RuntimeRestoration._restore(self, lab)


func _restore_guard(lab: PitchBatLab) -> bool:
	return RuntimeRestoration._restore_guard(self, lab)


func _abandon_restore() -> void:
	RuntimeRestoration._abandon_restore(self)


func _dispose_detached() -> void:
	RuntimeRestoration._dispose_detached(self)


func _on_exiting() -> void:
	RuntimeRestoration._on_exiting(self)


func _disconnect(lab: PitchBatLab) -> void:
	RuntimeRestoration._disconnect(self, lab)


func _visibility() -> Dictionary:
	return RuntimeRestoration._visibility(self)


func _shadows() -> Dictionary:
	return RuntimeRestoration._shadows(self)


static func _metadata(value: Object) -> Dictionary:
	return RuntimeRestoration._metadata(value)


static func _environment_values(value: Environment) -> Dictionary:
	return RuntimeRestoration._environment_values(value)


static func _data(value: Variant) -> String:
	return RuntimeRestoration._data(value)


func _capture_time() -> bool:
	return RuntimeTime._capture_time(self)


func _original_sky_values() -> Dictionary:
	return RuntimeTime._original_sky_values(self)


func _time_operands() -> bool:
	return RuntimeTime._time_operands(self)


func _apply_time_presentation(lab: PitchBatLab) -> bool:
	return RuntimeTime._apply_time_presentation(self, lab)


func _advance_time(lab: PitchBatLab) -> bool:
	return RuntimeTime._advance_time(self, lab)


func _time_values(progress: float) -> Dictionary:
	return RuntimeTime._time_values(self, progress)


static func time_values(
	profile: String, progress: float, before: Dictionary, sky_values: Dictionary
) -> Dictionary:
	return RuntimeTime._public_time_values(profile, progress, before, sky_values)


func _write_time_values(lab: PitchBatLab, progress: float) -> bool:
	return RuntimeTime._write_time_values(self, lab, progress)


func _time_write_guard(lab: PitchBatLab) -> bool:
	return RuntimeTime._time_write_guard(self, lab)


func _write_time_values_owned(lab: PitchBatLab, progress: float) -> bool:
	return RuntimeTime._write_time_values_owned(self, lab, progress)


func _report_install_failure(lab: PitchBatLab) -> void:
	RuntimeAuthority._report_install_failure(self, lab)


func _first_cached_difference() -> Dictionary:
	return RuntimeAuthority._first_cached_difference(self)


static func _resource_difference(row: Dictionary, kind: String) -> Dictionary:
	return RuntimeAuthority._resource_difference(row, kind)


static func _difference(
	kind: String, node: String, field: String, current: Variant, expected: Variant
) -> Dictionary:
	return RuntimeAuthority._difference(kind, node, field, current, expected)


static func _brief(value: Variant) -> Variant:
	return RuntimeAuthority._brief(value)


func _kit_hot_context(lab: PitchBatLab) -> bool:
	return RuntimeAuthority._kit_hot_context(self, lab)


func _kit_hot_operands() -> bool:
	return RuntimeAuthority._kit_hot_operands(self)


func _kit_action_intact(lab: PitchBatLab) -> bool:
	return RuntimeAuthority._kit_action_intact(self, lab)


func _kit_hot_property_intact() -> bool:
	return RuntimeAuthority._kit_hot_property_intact(self)


func _issue_kit_state() -> bool:
	return RuntimeAuthority._issue_kit_state(self)


func _watch_kit_signal(node: Node, signal_name: StringName) -> bool:
	return RuntimeAuthority._watch_kit_signal(self, node, signal_name)


func _invalidate_kit_issue() -> void:
	RuntimeAuthority._invalidate_kit_issue(self)


func _revoke_kit_state() -> void:
	RuntimeAuthority._revoke_kit_state(self)


func _kit_required_nodes_intact(lab: PitchBatLab) -> bool:
	return RuntimeAuthority._kit_required_nodes_intact(self, lab)


func _kit_current_authority_intact() -> bool:
	return RuntimeAuthority._kit_current_authority_intact(self)


func _capture_kit_absence() -> bool:
	return RuntimeAuthority._capture_kit_absence(self)


func _kit_feature_absent(property: StadiumPropertyGeometry, feature: StringName) -> bool:
	return RuntimeAuthority._kit_feature_absent(self, property, feature)


func _capture_kit_export() -> bool:
	return RuntimeAuthority._capture_kit_export(self)


static func issued_export_key(lab: PitchBatLab, snapshot: Dictionary) -> String:
	return RuntimeAuthority._public_issued_export_key(lab, snapshot)


func _kit_export_identity(lab: PitchBatLab, snapshot: Dictionary) -> bool:
	return RuntimeAuthority._kit_export_identity(self, lab, snapshot)


func _kit_export_key(lab: PitchBatLab, snapshot: Dictionary) -> String:
	return RuntimeAuthority._kit_export_key(self, lab, snapshot)
