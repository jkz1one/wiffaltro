extends RefCounted
## Stateless inputs operations for the existing surface-night runtime owner.


static func _capture_kit_inputs(owner: StadiumSurfaceNightRuntime) -> bool:
	# Candidate3 captures only finite raw authority fields, not rebuilt catalogs or
	# mutable source aliases. Full historical replay validation remains at boundaries.
	var specs: Array = []
	for paid: ClubAssetLedger in [owner._paid, owner._replay_paid]:
		if paid == null:
			continue
		specs.append(
			[
				paid,
				[
					&"_mutation_generation",
					&"_seed",
					&"_credits",
					&"_championships",
					&"_progress",
					&"_land",
					&"_valid",
					&"_loading",
					&"_events",
					&"_requests",
					&"_pack_owned",
					&"_pending",
					&"_spent",
					&"_opened",
					&"_through",
					&"_surface_origin",
					&"_surface_owned",
					&"_salvage_origin",
					&"_salvage_cleared",
					&"_stadium_draft",
					&"_stadium_active"
				]
			]
		)
		specs.append([paid._stock, [&"starter", &"blueprints", &"styles", &"copies"]])
		specs.append([paid._scoreboards, [&"blueprints", &"copies"]])
		specs.append([paid._wall_pieces, [&"blueprints"]])
		specs.append([paid._wall_pieces.stock, [&"copies"]])
	specs.append(
		[
			owner._season,
			[
				&"season_seed",
				&"_npc_replay_run",
				&"home_property",
				&"phase",
				&"round_index",
				&"schedule",
				&"semifinals",
				&"final_fixture",
				&"owned_surface_night"
			]
		]
	)
	if owner._career != null:
		specs.append([owner._career, [&"current", &"runs", &"_assets", &"_pennants", &"_plaques"]])
	specs.append([owner._state, [&"stadium"]])
	specs.append(
		[
			owner,
			[
				&"_snapshot",
				&"_proof",
				&"_kit_profile",
				&"_kit_physical_layout",
				&"_kit_physical_geometry",
				&"_geometry_signature"
			]
		]
	)
	for spec: Array in specs:
		var object: Object = spec[0]
		if not is_instance_valid(object):
			return false
		var values: Array = []
		for field: StringName in spec[1]:
			values.append(StadiumSurfaceNightRuntime._kit_frozen_copy(object.get(field)))
		values.make_read_only()
		var fields: Array = spec[1].duplicate()
		fields.make_read_only()
		var row: Dictionary = {
			"object": weakref(object),
			"script": object.get_script(),
			"fields": fields,
			"values": values
		}
		row.make_read_only()
		owner._kit_input_rows.append(row)
	owner._kit_input_rows.make_read_only()
	return not owner._kit_input_rows.is_empty() and owner._kit_inputs_intact()


static func _kit_frozen_copy(value: Variant) -> Variant:
	if value is Array:
		var result: Array = value.duplicate(true)
		for index in range(result.size()):
			result[index] = StadiumSurfaceNightRuntime._kit_frozen_copy(result[index])
		result.make_read_only()
		return result
	if value is Dictionary:
		var result: Dictionary = value.duplicate(true)
		for key: Variant in result:
			result[key] = StadiumSurfaceNightRuntime._kit_frozen_copy(result[key])
		result.make_read_only()
		return result
	return value


static func _kit_inputs_intact(owner: StadiumSurfaceNightRuntime) -> bool:
	# Native container equality compares the current data against recursively frozen
	# detached copies each call. This is not a generation-only or per-frame cache.
	if owner._kit_input_rows.is_empty():
		return false
	for row: Dictionary in owner._kit_input_rows:
		var object: Object = row.object.get_ref()
		if not is_instance_valid(object) or not is_same(object.get_script(), row.script):
			return false
		for index in range(row.fields.size()):
			if not StadiumSurfaceNightRuntime._kit_value_equal(
				object.get(row.fields[index]), row.values[index]
			):
				return false
	return true


static func _owned_backing_state(owner: StadiumSurfaceNightRuntime) -> String:
	# Extra dependencies read by full matches_fixture, beyond the existing raw seals.
	# Candidate2 only; identity/script checks precede every transaction comparison.
	return StadiumSurfaceNightRuntime._data(
		[
			owner._paid._championships,
			null if owner._replay_paid == null else owner._replay_paid._championships,
			null if owner._career == null else owner._career._pennants,
			null if owner._career == null else owner._career._plaques
		]
	)


static func _record_action_sample(
	owner: StadiumSurfaceNightRuntime, key: String, started_us: int, accepted: bool
) -> void:
	# Opt-in diagnostic counters only. No guard is invoked by this measurement.
	if not owner._action_sample_enabled or not owner._floodlight_mode:
		return
	var elapsed_us: int = Time.get_ticks_usec() - started_us
	if not owner._action_samples.has(key):
		owner._action_samples[key] = {"calls": 0, "elapsed_us": 0, "refused": 0}
	owner._action_samples[key].calls += 1
	owner._action_samples[key].elapsed_us += elapsed_us
	if not accepted:
		owner._action_samples[key].refused += 1


static func _record_guard_timing(
	owner: StadiumSurfaceNightRuntime, key: String, started_us: int
) -> void:
	if not owner._guard_timing_enabled:
		return
	var elapsed_us: int = Time.get_ticks_usec() - started_us
	if not owner._guard_timings.has(key):
		owner._guard_timings[key] = {"calls": 0, "elapsed_us": 0}
	owner._guard_timings[key].calls += 1
	owner._guard_timings[key].elapsed_us += elapsed_us


static func _ledger_resources(ledger: ClubAssetLedger) -> Array:
	var result: Array = [
		ledger._stock, ledger._wall_pieces, ledger._wall_pieces.stock, ledger._scoreboards
	]
	result.make_read_only()
	return result


static func _ledger_identity(ledger: ClubAssetLedger, resources: Array) -> bool:
	return (
		is_instance_valid(ledger)
		and ledger.get_script() == ClubAssetLedger
		and resources.size() == 4
		and is_instance_valid(ledger._stock)
		and ledger._stock == resources[0]
		and ledger._stock.get_script() == StadiumStock
		and is_instance_valid(ledger._wall_pieces)
		and ledger._wall_pieces == resources[1]
		and ledger._wall_pieces.get_script() == StadiumWallPieceOwnership
		and is_instance_valid(ledger._wall_pieces.stock)
		and ledger._wall_pieces.stock == resources[2]
		and ledger._wall_pieces.stock.get_script() == StadiumWallPieceStock
		and is_instance_valid(ledger._scoreboards)
		and ledger._scoreboards == resources[3]
		and ledger._scoreboards.get_script() == StadiumScoreboardOwnership
	)


static func _field_unchanged(owner: StadiumSurfaceNightRuntime) -> bool:
	return (
		is_instance_valid(owner._field)
		and owner._field.get_script() == FieldDefinition
		and ContentDB.get_field(PitchBatLab.FIELD_ID) == owner._field
		and owner._field.fair_half_angle_degrees == owner._field_fair
		and owner._field.safe_hit_z_m == owner._field_safe
		and owner._field.deep_air_z_m == owner._field_deep
		and owner._field.back_wall_z_m == owner._field_wall
		and owner._field.home_run_height_m == owner._field_home_run
		and owner._field.dead_ball_z_m == owner._field_dead
		and (
			not owner._owned_boundary_mode()
			or (
				owner._field.shallow_anchor_z_m == owner._field_shallow_anchor
				and owner._field.middle_anchor_z_m == owner._field_middle_anchor
				and owner._field.middle_center_anchor_z_m == owner._field_middle_center_anchor
				and owner._field.deep_anchor_z_m == owner._field_deep_anchor
				and owner._field.side_anchor_x_m == owner._field_side_anchor
			)
		)
		and is_instance_valid(owner._resolver)
		and (
			owner._resolver.field == owner._field
			or (owner._resolver.field == null and owner._resolver.state == null)
		)
	)


static func _season_state(owner: StadiumSurfaceNightRuntime) -> String:
	# Raw authority inputs only: ClubCareer.to_data() would reconstruct the ledger.
	if (
		owner._season == null
		or owner._season.get_script() != SeasonState
		or owner._season.career != owner._career
		or owner._season._pool_replay_ledger != owner._replay_paid
		or (owner._career != null and owner._career.get_script() != ClubCareer)
	):
		return ""
	var career: Array = (
		[]
		if owner._career == null
		else [
			owner._career.get_instance_id(),
			owner._career.get_script().get_instance_id(),
			owner._career.current,
			owner._career.runs,
			owner._career._assets
		]
	)
	var inputs: Array = [
			owner._season.get_instance_id(),
			owner._season.get_script().get_instance_id(),
			owner._season.season_seed,
			owner._season._npc_replay_run,
			career,
			owner._season.home_property,
			owner._season.phase,
			owner._season.round_index,
			owner._season.schedule,
			owner._season.semifinals,
			owner._season.final_fixture
	]
	if owner._season._league_home_context.get("format") == 94:
		inputs.append_array([owner._season._league_home_context, owner._season.league_rules,
			owner._season.league_career, owner._season.inventory_rules, owner._season.player_access])
	if owner._season._league_home_context.get("format") in [95, 96]:
		inputs.append_array([owner._season._league_home_context, owner._season.league_rules,
			owner._season._dynasty_career_session, owner._season._dynasty_owner_binding,
			owner._season._dynasty_start, owner._season._closed_access,
			owner._season.inventory_rules, owner._season.player_access])
	return StadiumSurfaceNightRuntime._data(inputs)


static func _ledger_state(ledger: ClubAssetLedger) -> String:
	# Finite family-local equivalent of the existing owned-ledger state seal.
	# Generation is not a substitute for checking mutable backing data and resources.
	if (
		ledger == null
		or ledger.get_script() != ClubAssetLedger
		or not is_instance_valid(ledger._stock)
		or not is_instance_valid(ledger._wall_pieces)
		or not is_instance_valid(ledger._scoreboards)
		or not is_instance_valid(ledger._wall_pieces.stock)
		or ledger._stock.get_script() != StadiumStock
		or ledger._wall_pieces.get_script() != StadiumWallPieceOwnership
		or ledger._wall_pieces.stock.get_script() != StadiumWallPieceStock
		or ledger._scoreboards.get_script() != StadiumScoreboardOwnership
	):
		return ""
	return StadiumSurfaceNightRuntime._data(
		[
			ledger.get_instance_id(),
			ledger.get_script().get_instance_id(),
			ledger._stock.get_instance_id(),
			ledger._stock.get_script().get_instance_id(),
			ledger._wall_pieces.get_instance_id(),
			ledger._wall_pieces.get_script().get_instance_id(),
			ledger._wall_pieces.stock.get_instance_id(),
			ledger._wall_pieces.stock.get_script().get_instance_id(),
			ledger._scoreboards.get_instance_id(),
			ledger._scoreboards.get_script().get_instance_id(),
			ledger._seed,
			ledger._credits,
			ledger._progress,
			ledger._land,
			ledger._valid,
			ledger._loading,
			ledger._events,
			ledger._requests,
			ledger._pack_owned,
			ledger._pending,
			ledger._spent,
			ledger._opened,
			ledger._through,
			ledger._surface_origin,
			ledger._surface_owned,
			ledger._scoreboards.to_data(),
			ledger._wall_pieces.to_data(),
			ledger._stock.to_data(),
			ledger._stadium_draft,
			ledger._stadium_active
		]
	)


static func _admissible(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> bool:
	if (
		not owner._configured(lab)
		or not lab.is_inside_tree()
		or lab._field_id != PitchBatLab.FIELD_ID
		or lab.global_transform != Transform3D.IDENTITY
		or lab.has_meta("stadium_property")
		or not owner._node_operands_valid(lab)
		or not StadiumPropertyRuntime.authoring_delivery_idle(lab)
		or is_instance_valid(lab._batted_ball)
		or owner._state.phase != MatchState.Phase.PRE_PITCH
	):
		return false
	var host: Variant = lab.get_node_or_null("StarterFieldGeometry")
	if (
		not is_instance_valid(host)
		or not host is StarterFieldLabGeometry
		or host.get_script() != StarterFieldLabGeometry
		or host.has_node("HomeProperty")
		or host.global_transform != Transform3D.IDENTITY
	):
		return false
	for id: String in StadiumSurfaceNightRuntime.REMOVED:
		var node: Node = host.get_node_or_null(NodePath(id))
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			return false
	return not lab.get_viewport().has_meta(StadiumSurfaceNightRuntime.ATLAS) and owner._caller(lab)


static func _node_operands_valid(_owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> bool:
	# Externally retained Node fields may be freed while still non-null.
	var camera: Variant = lab._camera
	var pitch: Variant = lab._pitch_actor
	var fielder: Variant = lab._primary_fielder
	var environment_owner: Variant = lab._world_environment
	return (
		is_instance_valid(camera)
		and camera is Camera3D
		and is_instance_valid(pitch)
		and pitch is PitchFlightActor
		and pitch.get_script() == PitchFlightActor
		and is_instance_valid(fielder)
		and fielder is FielderController
		and fielder.get_script() == FielderController
		and is_instance_valid(environment_owner)
		and environment_owner is WorldEnvironment
	)


static func _caller(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> bool:
	if lab._managed_match:
		var app: Variant = lab.get_parent()
		return (
			is_instance_valid(app)
			and app is SeasonApp
			and app.get_script() == SeasonApp
			and app.lab == lab
			and app.season == owner._season
			and app._season_game
			and app._fixture_id == owner._fixture_id
		)
	var viewport: SubViewport = lab.get_parent() as SubViewport
	if viewport == null or not viewport.own_world_3d or lab._automation == null:
		return false
	var runner: Variant = viewport.get_parent()
	return (
		is_instance_valid(runner)
		and runner is PhysicalMatchRunner
		and runner.get_script() == PhysicalMatchRunner
		and runner._lab == lab
		and runner._viewport == viewport
		and lab._automation.seed == owner._match_seed
	)
