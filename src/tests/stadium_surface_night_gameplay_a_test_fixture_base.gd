extends Node
## A only: SYNTHETIC closed funding, real paid journal, actual admission/callbacks.
## No earned-history, completed-game, optical or public activation claim.
## Delivery-boundary contract: six bulk edits defer refusal; identity/resources/field stay hot.

const JSON_NAME: String = "owned-surface-night-gameplay-a.json"
const MAX_BYTES: int = 131072
const CASE_NAMES: Array[String] = [
	"tracking_identity",
	"freed_pitch",
	"freed_camera",
	"freed_fielder",
	"freed_environment",
	"reused_match",
	"replaced_owner",
	"own_atlas_reopen",
	"foreign_atlas",
	"remove_replacement",
	"attach_replacement",
	"restore_replacement",
	"remove_retirement",
	"lamp_retirement",
	"pitch_inventory",
	"pitch_trace",
	"ball_attachment",
	"ball_launch",
	"cleanup_visibility",
	"outcome_inventory",
	"pitch_call_inventory",
	"release_continuation",
	"cadence_continuation",
	"swing_stop",
	"defense_observer",
	"visibility_root",
	"visibility_shadow",
	"runner_attachment",
	"managed_attachment",
	"managed_close"
]

const TAMPER_NAMES: Array[String] = [
	"journal",
	"derived_stock",
	"policy",
	"career_receipt",
	"replay_ledger",
	"schedule",
	"live_field_catalog",
	"supported_generation",
	"generation_exhaustion",
	"sticky_night_classification"
]

const PUBLIC_CHECKS: int = 28
const TIME_GAME_CHECKS: int = 32
const TIME_CHECKS: int = 63
var _public_proofs: Dictionary = {}
var _public_profiles: Array[Dictionary] = []
var _public_confirmed: int = 0

var _game_runner: PhysicalMatchRunner
var _game_lab: PitchBatLab
var _game_fixture: Dictionary = {}
var _game_report: Dictionary = {}
var _game_codec: Dictionary = {}
var _game_tactics: Dictionary = {}
var _game_terminal: Dictionary = {}
var _game_proofs: Dictionary = {}
var _game_trace: Dictionary = {
	"samples": 0,
	"active_samples": 0,
	"max_plays": 0,
	"max_halves": 0,
	"max_progress": 0.0,
	"bounded": true,
	"advances": 0,
	"clock_progress_valid": true,
	"last_clock": {},
	"last_target": 0.0
}
var _game_completed: int = 0
var _game_error: String = ""
var _game_status: String = "incomplete"
var _game_report_written: bool = false
var _game_codec_written: bool = false
var _game_capture_matches: bool = false
var _game_human_capture_empty: bool = false

var _time_rows: Array[Dictionary] = []

var _checks: int = 0
var _failures: int = 0
var _capture_dir: String = ""
var _group: String = "full"
var _case_ids: Array[int] = []
var _tamper_ids: Array[int] = []
var _planned_checks: int = 132
var _app: SeasonApp
var _season: SeasonState
var _paid: ClubAssetLedger
var _rows: Array[Dictionary] = []
var _tamper_rows: Array[Dictionary] = []
var _timing: Dictionary = {}
var _contracts: Dictionary = {}
var _shared_before: Dictionary = {}
var _save_path: String = ""
var _cursor_before: Dictionary = {}
var _started_usec: int = 0
var _progress_usec: int = 0


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		print("FAIL: " + message)


# Focused changed-profile selection only. Existing default/group paths stay above.
# Synthetic funding and in-memory progress tuples do not qualify actual gameplay.
func _restore_shared_atlas() -> void:
	var viewport: Viewport = get_viewport()
	viewport.positional_shadow_atlas_size = int(_shared_before.size)
	viewport.positional_shadow_atlas_16_bits = bool(_shared_before.precision)
	for index in range(4):
		viewport.set_positional_shadow_atlas_quadrant_subdiv(
			index, int(_shared_before.quadrants[index])
		)


func _dispose(context: Dictionary) -> void:
	var lab: Variant = context.get("lab")
	var owner: StadiumSurfaceNightRuntime = context.get("owner")
	if is_instance_valid(lab):
		StadiumSurfaceNightRuntime.retire_captured(lab, owner)
		if (
			lab.has_meta(StadiumSurfaceNightRuntime.OWNER)
			and lab.get_meta(StadiumSurfaceNightRuntime.OWNER) != owner
		):
			# Intentionally injected foreign marker belongs to this fixture only.
			lab.remove_meta(StadiumSurfaceNightRuntime.OWNER)
		if _app.lab == lab:
			_app.lab = null
		lab.queue_free()
	await get_tree().process_frame
	# Fixture-owned abandoned values are reset only after evidence is captured and
	# every old lab leaves the tree. This is not claimed as runtime restoration.
	get_viewport().remove_meta(StadiumSurfaceNightRuntime.ATLAS)
	_restore_shared_atlas()


func _launch() -> BattedBallLaunch:
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(0, 1, 1)
	launch.velocity = Vector3(0, 2, 15)
	return launch


func _pause(lab: PitchBatLab) -> void:
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.set_process_input(false)
	lab.set_process_unhandled_input(false)
	lab._sounds.set_muted(true)
	lab._at_bat_cadence.stop()
	lab._field_setup_active = false
	lab._pitching_staff_active = false


func _open() -> Dictionary:
	_app._fixture_id = int(_season.pending_fixture().id)
	_app._open_match(_season.make_match(), true, true, PitchBatLab.FIELD_ID)
	var lab: PitchBatLab = _app.lab
	if (
		not is_instance_valid(lab)
		or not StadiumSurfaceNightRuntime.installed_bound(lab, lab._match_state.stadium)
	):
		_check(false, "fresh real managed night admission succeeds")
		return {}
	_pause(lab)
	return {"lab": lab, "owner": StadiumSurfaceNightRuntime.current(lab), "state": lab._match_state}


func _replacement(context: Dictionary) -> Dictionary:
	var lab: PitchBatLab = context.lab
	var replacement: MatchState = _season.make_match()
	lab._match_state = replacement
	lab.process_mode = Node.PROCESS_MODE_ALWAYS
	lab.set_process(true)
	lab.set_physics_process(true)
	return {
		"state": replacement,
		"phase": replacement.phase,
		"mode": lab.process_mode,
		"process": lab.is_processing(),
		"physics": lab.is_physics_processing(),
		"live": lab._live_label.text,
		"status": lab._status_label.text,
		"cooldown": lab._fielding_cooldown_seconds,
		"throw": lab._throw_number
	}


func _untouched(lab: PitchBatLab, replacement: Dictionary) -> bool:
	return (
		lab._match_state == replacement.state
		and replacement.state.phase == replacement.phase
		and lab.process_mode == replacement.mode
		and lab.is_processing() == replacement.process
		and lab.is_physics_processing() == replacement.physics
		and lab._live_label.text == replacement.live
		and lab._status_label.text == replacement.status
		and lab._fielding_cooldown_seconds == replacement.cooldown
		and lab._throw_number == replacement.throw
	)


func _ball_case(id: int, context: Dictionary, probe: Dictionary) -> void:
	var variants: Array[String] = []
	variants.assign(["attachment"] if id == 17 else ["held", "reparented", "foreign"])
	var aggregate_reached: bool = true
	var aggregate_preserved: bool = true
	var active: Dictionary = context
	for index in range(variants.size()):
		if index > 0:
			active = _open()
			if active.is_empty():
				aggregate_preserved = false
				break
		var lab: PitchBatLab = active.lab
		var local: Dictionary = {"reached": false}
		var variant: String = variants[index]
		var foreign_parent: Node3D = Node3D.new()
		add_child(foreign_parent)
		var foreign_token: RefCounted = RefCounted.new()
		lab.child_entered_tree.connect(
			func(child: Node) -> void:
				if not child is BattedBallBody or local.reached:
					return
				var body: BattedBallBody = child
				local["body"] = body
				var replace: Callable = func() -> void:
					local.reached = true
					local["replacement"] = _replacement(active)
					if variant == "held":
						lab.remove_meta(StadiumSurfaceNightRuntime.OWNER)
					elif variant == "reparented":
						body.reparent(foreign_parent)
					elif variant == "foreign":
						body.set_meta(StadiumSurfaceNightRuntime.BALL, foreign_token)
					local["freeze"] = body.freeze
					local["velocity"] = body.linear_velocity
					local["parent"] = body.get_parent()
					var replacement_ball: BattedBallBody = BattedBallBody.new()
					replacement_ball.freeze = true
					lab._batted_ball = replacement_ball
					lab.add_child(replacement_ball)
					local["replacement_ball"] = replacement_ball
				if id == 17:
					replace.call()
				else:
					body.launch_started.connect(
						func(_position: Vector3) -> void: replace.call(), CONNECT_ONE_SHOT
					)
		)
		lab._start_ball_in_play(_launch())
		var body_preserved: bool = false
		if local.reached:
			var body: BattedBallBody = local.body
			body_preserved = (
				(body.freeze and body.is_queued_for_deletion())
				if variant in ["attachment", "held"]
				else (
					body.freeze == local.freeze
					and body.linear_velocity == local.velocity
					and body.get_parent() == local.parent
					and not body.is_queued_for_deletion()
				)
			)
			if variant == "foreign":
				body_preserved = (
					body_preserved
					and body.get_meta(StadiumSurfaceNightRuntime.BALL) == foreign_token
				)
		var untouched: bool = (
			local.reached
			and _untouched(lab, local.replacement)
			and lab._batted_ball == local.replacement_ball
			and not local.replacement_ball.is_queued_for_deletion()
		)
		aggregate_reached = aggregate_reached and local.reached
		aggregate_preserved = aggregate_preserved and body_preserved and untouched
		probe.detail[variant] = {
			"reached": local.reached,
			"body_preserved": body_preserved,
			"replacement_untouched": untouched
		}
		# Fixture owns disposal of intentionally foreign or reparented bodies.
		foreign_parent.queue_free()
		await _dispose(active)
	probe.reached = aggregate_reached
	probe.preserved = aggregate_preserved


func _close_case(context: Dictionary, probe: Dictionary) -> void:
	var lab: PitchBatLab = context.lab
	var owner: StadiumSurfaceNightRuntime = context.owner
	var host: Node = lab.get_node("StarterFieldGeometry")
	host.child_entered_tree.connect(
		func(child: Node) -> void:
			if probe.reached or child == owner._property:
				return
			probe.reached = true
			probe["replacement"] = _replacement(context)
	)
	_app._close_match()
	probe.preserved = (
		probe.reached
		and _app.lab == lab
		and lab.get_parent() == _app
		and not lab.is_queued_for_deletion()
		and _untouched(lab, probe.replacement)
	)


func _gameplay_case(id: int, context: Dictionary, probe: Dictionary) -> void:
	var lab: PitchBatLab = context.lab
	var state: MatchState = context.state
	var replace: Callable = func() -> void:
		probe.reached = true
		probe["replacement"] = _replacement(context)
		probe["pitcher_pose"] = lab._pitcher_marker.transform
		probe["exit_speed"] = lab._last_exit_speed_mph
	if id == 19 or id == 23:
		var original_ball: BattedBallBody = BattedBallBody.new()
		original_ball.freeze = true
		lab.add_child(original_ball)
		lab._batted_ball = original_ball
		lab._ball_visibility.visible = true
		lab._ball_visibility.visibility_changed.connect(
			func() -> void:
				replace.call()
				var newer: BattedBallBody = BattedBallBody.new()
				newer.freeze = true
				lab.add_child(newer)
				lab._batted_ball = newer
				probe["ball"] = newer,
			CONNECT_ONE_SHOT
		)
		if id == 19:
			lab._cleanup_batted_ball()
		else:
			state.phase = MatchState.Phase.PLAY_DEAD
			lab._at_bat_cadence.hold_dead_ball(37)
			PitchBatLabFeelSupport.update(lab, 3.0)
		probe.preserved = (
			probe.reached
			and _untouched(lab, probe.replacement)
			and lab._batted_ball == probe.ball
			and not probe.ball.is_queued_for_deletion()
			and not original_ball.is_queued_for_deletion()
		)
	elif id == 20 or id == 21:
		state.inventory_boundary.connect(replace, CONNECT_ONE_SHOT)
		if id == 20:
			lab._ball_play_resolver.start_play(lab._field_definition)
			state.phase = MatchState.Phase.BALL_IN_PLAY
			var outcome: BallPlayOutcome = BallPlayOutcome.new()
			outcome.result = BallPlayOutcome.Result.OUT
			lab._on_ball_play_resolved(outcome)
		else:
			state.phase = MatchState.Phase.PITCH_IN_FLIGHT
			state.strikes = 2
			PitchBatLabPitchCall.resolve(lab, Vector3(0, 1, 0), 20.0, 0.4)
		probe.preserved = probe.reached and _untouched(lab, probe.replacement)
	elif id == 22:
		state.inventory_boundary.connect(replace, CONNECT_ONE_SHOT)
		state.between_batters = true
		lab._release_controller.begin()
		PitchBatLabFeelSupport.update(lab, 0.6)
		probe.preserved = (
			probe.reached
			and _untouched(lab, probe.replacement)
			and lab._pitcher_marker.transform == probe.pitcher_pose
			and not lab._pitch_actor.running
		)
	elif id == 24:
		var profiles: Array = ContentDB.swing_by_id.values()
		if profiles.is_empty():
			return
		lab._swing_tracker.begin(SwingIntent.new(), profiles[0], 5, 5)
		lab._pitch_actor.state = PitchState.new()
		lab._pitch_actor.state.velocity = Vector3(0, 0, -20)
		lab._pitch_actor.running = true
		lab._pitch_actor.flight_stopped.connect(
			func(_reason: StringName) -> void: replace.call(), CONNECT_ONE_SHOT
		)
		var contact: ContactResult = ContactResult.new()
		contact.outcome = ContactResult.Outcome.FOUL
		contact.exit_velocity = Vector3(0, 1, 10)
		PitchBatLabSwingSupport._resolve_contact(lab, contact)
		probe.preserved = (
			probe.reached
			and _untouched(lab, probe.replacement)
			and lab._last_exit_speed_mph == probe.exit_speed
			and lab._batted_ball == null
		)
	elif id == 25:
		lab._start_ball_in_play(_launch())
		var resolver: BallPlayResolver = lab._ball_play_resolver
		var boundary: Variant = context.owner._property.get_node_or_null("BoundaryGraph")
		if (
			not is_instance_valid(boundary)
			or not boundary is StadiumBoundaryPrototype
			or boundary.get_script() != StadiumBoundaryPrototype
			or boundary != context.owner._boundary
		):
			return
		var rear: Dictionary = StadiumBoundaryGraph.segments()[0]
		var center: Vector2 = (rear.a + rear.b) / 2.0
		var normal: Vector2 = StadiumBoundaryGraph.inward(rear)
		var inside: Vector2 = center + normal * 0.4
		var outside: Vector2 = center - normal * 0.4
		lab._pitcher_marker.global_position = Vector3(outside.x, 0, outside.y)
		resolver.play_resolved.connect(
			func(_outcome: BallPlayOutcome) -> void: replace.call(), CONNECT_ONE_SHOT
		)
		PitchBatLabDefenseSupport.try_pitcher(
			lab, Vector3(inside.x, 1, inside.y), Vector3(outside.x, 1, outside.y)
		)
		probe.preserved = (
			probe.reached and _untouched(lab, probe.replacement) and not lab._pitcher_attempted
		)
	elif id == 26 or id == 27:
		var ball: BattedBallBody = BattedBallBody.new()
		ball.freeze = true
		lab.add_child(ball)
		ball.global_position = Vector3(0, 1, 1)
		lab._batted_ball = ball
		var visibility: BallVisibility = lab._ball_visibility
		visibility.visible = id == 27
		visibility._shadow.visible = false
		var target: Node3D = visibility if id == 26 else visibility._shadow
		target.visibility_changed.connect(
			func() -> void:
				replace.call()
				probe["shadow_pose"] = visibility._shadow.transform
				probe["history"] = visibility._history.duplicate()
				probe["mesh_surfaces"] = visibility._mesh.get_surface_count(),
			CONNECT_ONE_SHOT
		)
		visibility.update_ball(ball, lab._camera, 0.01, 100)
		probe.preserved = (
			probe.reached
			and _untouched(lab, probe.replacement)
			and visibility._shadow.transform == probe.shadow_pose
			and visibility._history == probe.history
			and visibility._mesh.get_surface_count() == probe.mesh_surfaces
		)


func _managed_attach_case() -> Dictionary:
	var probe: Dictionary = {"reached": false}
	var attached: Callable = func(child: Node) -> void:
		if not child is PitchBatLab:
			return
		var lab: PitchBatLab = child
		# The real successful ready/install completes inside add_child. Replace at
		# ready completion so the outer caller's post-attachment guard is exercised.
		lab.ready.connect(
			func() -> void:
				probe.reached = true
				probe["lab"] = lab
				probe["owner"] = StadiumSurfaceNightRuntime.current(lab)
				probe["replacement"] = _replacement({"lab": lab}),
			CONNECT_ONE_SHOT
		)
	_app.child_entered_tree.connect(attached)
	_app._fixture_id = int(_season.pending_fixture().id)
	_app._open_match(_season.make_match(), true, true, PitchBatLab.FIELD_ID)
	_app.child_entered_tree.disconnect(attached)
	var preserved: bool = (
		probe.reached
		and _app.lab == probe.lab
		and _untouched(probe.lab, probe.replacement)
		and not probe.lab.is_queued_for_deletion()
	)
	if probe.reached:
		await _dispose({"lab": probe.lab, "owner": probe.owner})
	return {
		"id": 29,
		"name": CASE_NAMES[28],
		"reached": probe.reached,
		"preserved": preserved,
		"detail": {}
	}


func _pitch_case(id: int, context: Dictionary, probe: Dictionary) -> void:
	var lab: PitchBatLab = context.lab
	var actor: PitchFlightActor = lab._pitch_actor
	context.state.between_batters = true
	if id == 15:
		context.state.inventory_boundary.connect(
			func() -> void:
				probe.reached = true
				probe["replacement"] = _replacement(context),
			CONNECT_ONE_SHOT
		)
	else:
		actor.trace_sampled.connect(
			func(_point: Vector3) -> void:
				probe.reached = true
				probe["launch"] = actor.parameters
				probe["replacement"] = _replacement(context),
			CONNECT_ONE_SHOT
		)
	lab._throw_pitch()
	probe.preserved = probe.reached and _untouched(lab, probe.replacement) and not actor.running
	if id == 16:
		probe.preserved = probe.preserved and actor.parameters == probe.launch
		probe.detail["original_launch_stopped"] = probe.preserved
		await _dispose(context)
		var token_context: Dictionary = _open()
		if token_context.is_empty():
			probe.preserved = false
			return
		var token_actor: PitchFlightActor = token_context.lab._pitch_actor
		var token_probe: Dictionary = {"reached": false}
		token_actor.trace_sampled.connect(
			func(_point: Vector3) -> void:
				if token_probe.reached:
					return
				token_probe.reached = true
				token_probe["original_parameters"] = token_actor.parameters
				var replacement_parameters: PitchLaunchParameters = PitchLaunchParameters.new()
				token_probe["parameters"] = replacement_parameters
				# Change the launch identity while keeping the exact owner and actor.
				# This callback is one-shot, so the nested ordinary start is finite.
				token_actor.start_pitch(replacement_parameters)
				token_probe["live"] = token_context.lab._live_label.text
				token_probe["status"] = token_context.lab._status_label.text,
			CONNECT_ONE_SHOT
		)
		token_context.lab._throw_pitch()
		var token_preserved: bool = (
			token_probe.reached
			and not StadiumSurfaceNightRuntime.continue_pitch(
				token_context.lab,
				token_context.owner,
				token_context.state,
				token_actor,
				token_probe.original_parameters
			)
			and token_actor.running
			and token_actor.parameters == token_probe.parameters
			and token_context.lab._live_label.text == token_probe.live
			and token_context.lab._status_label.text == token_probe.status
		)
		probe.reached = probe.reached and token_probe.reached
		probe.preserved = probe.preserved and token_preserved
		probe.detail["replacement_launch_untouched"] = token_preserved
		await _dispose(token_context)


func _prepared() -> Dictionary:
	# Controlled negative setup: ordinary lab _ready builds its actors once. The
	# detached, already-ready lab is then configured through the real runtime API.
	# Invalid install cases therefore exercise refusal without deliberate startup errors.
	var lab: PitchBatLab = PitchBatLab.new()
	var day_state: MatchState = _season.make_match()
	day_state.stadium = {}
	lab._configured_match = day_state
	lab._managed_match = true
	lab._player_home = true
	_app.lab = lab
	_app._season_game = true
	_app._fixture_id = int(_season.pending_fixture().id)
	_app.add_child(lab)
	_pause(lab)
	_app.remove_child(lab)
	var state: MatchState = _season.make_match()
	lab._match_state = null
	lab._configured_match = state
	lab._stadium_ledger = _paid
	lab._npc_season = _season
	if not StadiumSurfaceNightRuntime.configure(lab, _season, _paid):
		_check(false, "detached negative fixture configures through real owner API")
		lab.queue_free()
		return {}
	lab._match_state = state
	lab._configured_match = null
	lab._base_state = state.bases
	_app.add_child(lab)
	_pause(lab)
	return {"lab": lab, "owner": StadiumSurfaceNightRuntime.current(lab), "state": state}


func _runner_case() -> Dictionary:
	var runner: PhysicalMatchRunner = PhysicalMatchRunner.new()
	add_child(runner)
	var replacement: SubViewport = SubViewport.new()
	var probe: Dictionary = {"reached": false, "original": null}
	runner.child_entered_tree.connect(
		func(child: Node) -> void:
			if child is SubViewport and not probe.reached:
				probe.reached = true
				probe.original = child
				runner._viewport = replacement
				runner.set_process(true)
	)
	var state: MatchState = _season.make_match()
	var started: bool = runner.start(
		state, int(state.stadium.binding.match_seed), PitchBatLab.FIELD_ID, _paid, {}, _season
	)
	var preserved: bool = (
		probe.reached
		and not started
		and runner._viewport == replacement
		and runner._lab == null
		and runner.is_processing()
		and not replacement.is_queued_for_deletion()
		and replacement.get_parent() == null
	)
	# Test-owned cleanup only, after observing the refused caller's exact values.
	runner.set_process(false)
	runner._viewport = null
	replacement.queue_free()
	runner.queue_free()
	await get_tree().process_frame
	return {
		"id": 28,
		"name": CASE_NAMES[27],
		"reached": probe.reached,
		"preserved": preserved,
		"detail": {"start_refused": not started}
	}


func _geometry_node(node: Node, result: Dictionary) -> void:
	var row: Dictionary = {}
	if node is Node3D:
		row["transform"] = node.transform
	if node is CollisionShape3D:
		row["shape"] = node.shape
		row["disabled"] = node.disabled
		row["values"] = {}
		if node.shape != null:
			for property: Dictionary in node.shape.get_property_list():
				if int(property.usage) & PROPERTY_USAGE_STORAGE:
					var value: Variant = node.shape.get(property.name)
					row.values[property.name] = (
						value.duplicate(true) if value is Array or value is Dictionary else value
					)
	if not row.is_empty():
		result[node.get_instance_id()] = row
	for child: Node in node.get_children():
		_geometry_node(child, result)


func _geometry(roots: Array) -> Dictionary:
	var result: Dictionary = {}
	for root: Node in roots:
		_geometry_node(root, result)
	return result


func _original(owner: StadiumSurfaceNightRuntime) -> Dictionary:
	var lamps: Array[Dictionary] = []
	for row: Dictionary in owner._lamps:
		lamps.append(
			{
				"lens": row.lens,
				"beam": row.beam,
				"material": row.original,
				"metadata": row.metadata.duplicate(true),
				"visible": row.visible,
				"emission": row.emission,
				"energy": row.energy
			}
		)
	return {
		"environment": owner._environment,
		"environment_values": owner._before.environment.duplicate(true),
		"environment_meta": owner._before.environment_meta.duplicate(true),
		"sun": owner._before.sun.duplicate(true),
		"sun_node": owner._sun,
		"surface": owner._surface,
		"material": owner._material,
		"material_meta": owner._before.material_meta.duplicate(true),
		"pigment": owner._before.pigment,
		"lamps": lamps,
		"geometry": _geometry(owner._old_order),
		"shadows": owner._before.shadows.duplicate(true),
		"order": owner._old_order.duplicate(),
		"tracking": owner._tracking,
		"visibility": owner._before.visibility.duplicate(true),
		"observer": owner._before.observer,
		"clip": owner._before.clip,
		"obstacles": owner._before.obstacles.duplicate(true),
		"metadata": owner._before.metadata.duplicate(true)
	}


func _visibility(value: BallTrackingVisibility) -> Dictionary:
	var result: Dictionary = {}
	for key: StringName in StadiumSurfaceNightRuntime.VISIBILITY:
		var operand: Variant = value.get(key)
		result[key] = (
			operand.duplicate(true) if operand is Array or operand is Dictionary else operand
		)
	return result


func _restored(context: Dictionary, original: Dictionary) -> bool:
	var lab: PitchBatLab = context.lab
	var host: Node = lab.get_node("StarterFieldGeometry")
	var metadata_ok: bool = true
	for key: StringName in StadiumSurfaceNightRuntime.META:
		var before: Dictionary = original.metadata[key]
		metadata_ok = metadata_ok and lab.has_meta(key) == before.present
		if before.present:
			metadata_ok = metadata_ok and lab.get_meta(key) == before.value
	var materials_ok: bool = (
		original.surface.material_override == original.material
		and original.material.get_shader_parameter("vertex_pigment_scale") == original.pigment
		and StadiumSurfaceNightPreview._metadata(original.material) == original.material_meta
	)
	for row: Dictionary in original.lamps:
		materials_ok = (
			materials_ok
			and row.lens.material_override == row.material
			and StadiumSurfaceNightPreview._metadata(row.material) == row.metadata
			and row.beam.visible == row.visible
			and row.material.emission_enabled == row.emission
			and row.material.emission_energy_multiplier == row.energy
		)
	return (
		context.owner._phase == StadiumSurfaceNightRuntime.Phase.RETIRED
		and materials_ok
		and host.get_node("Sun") == original.sun_node
		and original.sun_node.light_color == original.sun.color
		and original.sun_node.light_energy == original.sun.energy
		and _geometry(original.order) == original.geometry
		and lab._world_environment.environment == original.environment
		and (
			StadiumSurfaceNightPreview._environment_values(original.environment)
			== original.environment_values
		)
		and StadiumSurfaceNightPreview._metadata(original.environment) == original.environment_meta
		and host.get_children() == original.order
		and metadata_ok
		and lab._camera_director.tracking_visibility == original.tracking
		and _visibility(original.tracking) == original.visibility
		and lab._ball_play_resolver.segment_observer == original.observer
		and lab._primary_fielder.stadium_boundary_clip == original.clip
		and lab._primary_fielder.stadium_obstacles == original.obstacles
		and StadiumSurfaceNightPreview._shadows(get_viewport()) == original.shadows
		and not get_viewport().has_meta(StadiumSurfaceNightRuntime.ATLAS)
	)


func _tree_case(id: int, context: Dictionary, probe: Dictionary) -> void:
	var lab: PitchBatLab = context.lab
	var owner: StadiumSurfaceNightRuntime = context.owner
	var host: Node = lab.get_node("StarterFieldGeometry")
	if id == 10 or id == 13:
		var first: Node = host.get_node(NodePath(StadiumSurfaceNightRuntime.REMOVED[0]))
		first.tree_exiting.connect(
			func() -> void:
				probe.reached = true
				if id == 13:
					probe["original"] = _original(owner)
					StadiumSurfaceNightRuntime.retire(lab, "A_REMOVE_CALLBACK")
				else:
					probe["replacement"] = _replacement(context),
			CONNECT_ONE_SHOT
		)
	elif id == 11 or id == 14:
		host.child_entered_tree.connect(
			func(child: Node) -> void:
				if child != owner._property:
					return
				if id == 11:
					probe.reached = true
					probe["replacement"] = _replacement(context)
				else:
					var beam: SpotLight3D = owner._lamps[0].beam
					beam.visibility_changed.connect(
						func() -> void:
							if (
								probe.reached
								or owner._phase != StadiumSurfaceNightRuntime.Phase.PRESENTATION
								or not owner._lamps[0].expected_visible
								or not beam.visible
							):
								return
							probe.reached = true
							probe["original"] = _original(owner)
							probe.detail = {
								"presentation_phase": true,
								"expected_visible": true,
								"actual_visible": true
							}
							StadiumSurfaceNightRuntime.retire(lab, "A_LAMP_CALLBACK")
					)
		)
	else:
		host.child_entered_tree.connect(
			func(child: Node) -> void:
				if probe.reached or child == owner._property:
					return
				probe.reached = true
				probe["replacement"] = _replacement(context)
		)
	if id == 12:
		StadiumSurfaceNightRuntime.retire(lab, "A_RESTORE_CALLBACK")
	else:
		probe["installed"] = StadiumSurfaceNightRuntime.install_bound(lab)
	if id == 13 or id == 14:
		probe.preserved = (
			probe.reached and not probe.installed and _restored(context, probe.original)
		)
	else:
		probe.preserved = (
			probe.reached
			and _untouched(lab, probe.replacement)
			and owner._phase == StadiumSurfaceNightRuntime.Phase.ABANDONED
			and not get_viewport().has_meta(StadiumSurfaceNightRuntime.ATLAS)
		)
