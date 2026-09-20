class_name PitchClearanceRegressionTest
extends RefCounted


static func run(host: Node, check: Callable) -> void:
	var field: FieldDefinition = ContentDB.get_field(PitchBatLab.FIELD_ID)
	var ball: BallSetupDefinition = ContentDB.get_ball_setup(PitchBatLab.BALL_SETUP_ID)
	var player: PlayerDefinition = ContentDB.get_player(PitchBatLab.DEBUG_PLAYER_ID)
	var targets: Array[Vector3] = [
		Vector3(0.0, 1.05, 0.0),
		Vector3(-0.75, 0.30, 0.0), Vector3(0.75, 0.30, 0.0),
		Vector3(-0.75, 1.85, 0.0), Vector3(0.75, 1.85, 0.0),
	]
	var camera: Camera3D = Camera3D.new()
	host.add_child(camera)
	var director: MatchCameraDirector = MatchCameraDirector.new()
	var views: Array[Vector3] = []
	for left_handed in [false, true]:
		director.set_batter_handedness(left_handed)
		for shot in [MatchCameraDirector.Shot.BATTING, MatchCameraDirector.Shot.PITCHING]:
			director.set_shot(shot)
			director.snap(camera)
			views.append(camera.global_position)
	camera.queue_free()
	var samples: int = 0
	var retries: int = 0
	for pitch_id in PitchBatLab.PITCH_IDS:
		var pitch: PitchDefinition = ContentDB.get_pitch(pitch_id)
		for left_handed in [false, true]:
			for target in targets:
				for stressed in [false, true]:
					var rated: PitchDefinition = MatchLabSupport.rated_pitch(
						pitch, player, 1.12 if stressed else 0.82, 1.0 if stressed else 0.0
					)
					var base: PitchLaunchParameters = PitchAimSolver.solve(
						rated, ball, PitchBatLab.MOUND_ORIGIN, target, left_handed, 4001 + samples
					)
					if base == null:
						check.call(
							pitch_id == &"pitch.eephus" and not stressed,
							"only minimum-effort Eephus targets may require an effort retry"
						)
						retries += 1
						# Match the player's explicit retry, not an automatic speed boost.
						rated = MatchLabSupport.rated_pitch(pitch, player, 1.0)
						base = PitchAimSolver.solve(
							rated, ball, PitchBatLab.MOUND_ORIGIN, target, left_handed, 4001 + samples
						)
					check.call(base != null, "clearance sample must solve after retry: %s" % pitch_id)
					if base == null:
						continue
					var executed: PitchLaunchParameters = PitchExecutionModel.apply(
						base, 0.0 if stressed else 1.0, 1.0 if stressed else 0.0,
						pitch.control_difficulty, pitch.execution_difficulty,
						pitch.category, 7019 + samples
					)
					check.call(
						_flight_clears_anchors(executed, field, views),
						"Pitch/role-camera sightline clearance failed: %s sample %d" % [pitch_id, samples]
					)
					samples += 1
	check.call(samples == 180, "clearance matrix must retain all 180 launched flights")
	print(
		"Pitch clearance regression sampled %d flights (%d effort retries; not exhaustive)."
		% [samples, retries]
	)


static func _flight_clears_anchors(
	parameters: PitchLaunchParameters, field: FieldDefinition, views: Array[Vector3]
) -> bool:
	var state: PitchState = PitchState.new()
	state.position = parameters.position
	state.velocity = parameters.velocity
	state.orientation = parameters.orientation
	state.angular_velocity = parameters.angular_velocity
	state.pitch_id = parameters.pitch_id
	state.seed = parameters.seed
	while state.elapsed_time < 3.0 and state.position.z > 0.0 and state.position.y >= -1.0:
		var previous: Vector3 = state.position
		PitchFlightSolver.step(state, parameters)
		for index in range(9):
			if not field.is_fielder_anchor_available(index):
				continue
			var anchor: Vector3 = field.fielder_anchor(index)
			if DefenderSpacing.segment_distance_xz(anchor, previous, state.position) < (
				DefenderSpacing.PITCH_CLEARANCE_M
			):
				return false
			# Conservative vertical-cylinder occlusion check, including high arcs.
			for view in views:
				if DefenderSpacing.segment_distance_xz(anchor, view, state.position) < (
					DefenderSpacing.PITCH_CLEARANCE_M
				):
					return false
	return true
