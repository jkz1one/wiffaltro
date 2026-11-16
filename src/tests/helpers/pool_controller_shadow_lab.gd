extends PitchBatLab
## Every ordinary call runs once with unchanged arguments, even if observation rejects.

var pool_shadow: StadiumPoolControllerShadow


func _start_ball_in_play(launch_data: BattedBallLaunch) -> void:
	if pool_shadow != null:
		pool_shadow.launch_enter(self, launch_data)
	super._start_ball_in_play(launch_data)
	if pool_shadow != null:
		pool_shadow.launch_return(self, launch_data)


func _physics_process(delta: float) -> void:
	var call_id: int = _writer_enter("controller", [delta])
	if pool_shadow != null:
		pool_shadow.controller_enter(self, delta)
	super._physics_process(delta)
	if pool_shadow != null:
		pool_shadow.controller_return(self)
	_writer_return("controller", call_id)


func _try_pitcher_defense(previous: Vector3, current: Vector3) -> void:
	var call_id: int = _writer_enter("pitcher", [previous, current])
	if pool_shadow != null:
		pool_shadow.pitcher_enter(self, previous, current)
		pool_shadow.writer.pitcher_seal(self, previous, current)
	super._try_pitcher_defense(previous, current)
	if pool_shadow != null:
		pool_shadow.pitcher_return(self)
	_writer_return("pitcher", call_id)


func _on_batted_surface_contact(surface_id: StringName, contact_position: Vector3) -> void:
	var call_id: int = _writer_enter("surface", [String(surface_id), contact_position])
	super._on_batted_surface_contact(surface_id, contact_position)
	_writer_return("surface", call_id)


func _try_primary_fielder() -> void:
	var call_id: int = _writer_enter("primary", [])
	super._try_primary_fielder()
	_writer_return("primary", call_id)


func _apply_fielding_outcome(
	defender_id: StringName,
	defender_position: Vector3,
	outcome: FieldingResolver.Outcome,
	control_position: Vector3 = Vector3.INF
) -> void:
	var call_id: int = _writer_enter(
		"fielding", [String(defender_id), defender_position, int(outcome), control_position]
	)
	super._apply_fielding_outcome(defender_id, defender_position, outcome, control_position)
	_writer_return("fielding", call_id)


func _on_ball_play_resolved(outcome: BallPlayOutcome) -> void:
	var call_id: int = _writer_enter(
		"resolved",
		[
			outcome.get_instance_id(),
			int(outcome.result),
			String(outcome.reason),
			outcome.caught,
			outcome.resolution_position
		]
	)
	super._on_ball_play_resolved(outcome)
	if pool_shadow != null:
		pool_shadow.writer.end(
			self,
			"resolved",
			call_id,
			[
				outcome.get_instance_id(),
				int(outcome.result),
				String(outcome.reason),
				outcome.caught,
				outcome.resolution_position
			]
		)


func _writer_enter(kind: String, arguments: Array) -> int:
	return pool_shadow.writer.begin(self, kind, arguments) if pool_shadow != null else 0


func _writer_return(kind: String, call_id: int) -> void:
	if pool_shadow != null:
		pool_shadow.writer.end(self, kind, call_id)
