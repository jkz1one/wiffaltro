extends RefCounted
## Stateless entry operations for the existing surface-night runtime owner.


static func _public_configure(lab: PitchBatLab, season: SeasonState, paid: ClubAssetLedger) -> bool:
	if (
		not is_instance_valid(lab)
		or lab.get_script() != PitchBatLab
		or lab.is_inside_tree()
		or lab.has_meta(StadiumSurfaceNightRuntime.OWNER)
		or lab.has_meta(StadiumSurfaceNightRuntime.BOUND)
		or lab._configured_match == null
		or lab._stadium_ledger != paid
		or lab._npc_season != season
		or season == null
		or paid == null
		or paid.mutation_generation() <= 0
	):
		return false
	var snapshot: Dictionary = lab._configured_match.stadium
	var wrapped: bool = StadiumSurfaceNightSnapshot.is_wrapped(snapshot)
	var wrapped_admission: Dictionary = {}
	var issued_state: MatchState = lab._configured_match
	var issued_generation: int = paid.mutation_generation()
	var issued_policy: Dictionary = season.owned_surface_night
	var issued_home: Dictionary = season.home_property
	if wrapped:
		# Fresh synchronous cold proof. Only detached canonical data escapes this
		# local call, never a reusable successful-authority token.
		if (
			not snapshot.get("binding") is Dictionary
			or not SeasonOwnership._whole(snapshot.binding.get("fixture"), 0, 32)
		):
			return false
		wrapped_admission = StadiumSurfaceNightSnapshot._wrapped_runtime_admission(
			snapshot,
			season,
			SeasonVenues.fixture_for_id(season, int(snapshot.binding.get("fixture", -1))),
			paid
		)
		if (
			wrapped_admission.is_empty()
			or not is_instance_valid(lab)
			or lab.has_meta(StadiumSurfaceNightRuntime.OWNER)
			or lab.has_meta(StadiumSurfaceNightRuntime.BOUND)
			or lab._configured_match != issued_state
			or not is_same(issued_state.stadium, snapshot)
			or lab._npc_season != season
			or lab._stadium_ledger != paid
			or paid.mutation_generation() != issued_generation
			or not is_same(season.owned_surface_night, issued_policy)
			or not is_same(season.home_property, issued_home)
		):
			return false
	elif (
		not StadiumSurfaceNightSnapshot.valid(snapshot)
		or not StadiumSurfaceNightSnapshot.matches_fixture(
			snapshot,
			season,
			SeasonVenues.fixture_for_id(season, int(snapshot.binding.fixture)),
			paid
		)
	):
		return false
	var request: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.new()
	request._lab = weakref(lab)
	request._season = season
	request._state = lab._configured_match
	request._paid = paid
	request._paid_generation = paid.mutation_generation()
	request._paid_data = StadiumSurfaceNightRuntime._data(paid.to_data())
	request._snapshot = snapshot.duplicate(true)
	request._guard_timing_enabled = (
		lab.has_meta("owned_floodlight_timing") and lab.get_meta("owned_floodlight_timing") == true
	)
	request._diagnostics_enabled = (
		lab.has_meta("owned_floodlight_diagnostics")
		and lab.get_meta("owned_floodlight_diagnostics") == true
	)
	request._kit_mode = StadiumLightingKitNightCandidate.is_candidate_layout(snapshot.layout)
	request._kit_profile = (
		(
			wrapped_admission.profile.duplicate(true)
			if wrapped
			else StadiumLightingKitNightCandidate.admission_profile(
				StadiumSurfaceNightSnapshot.entry(snapshot)
			)
		)
		if request._kit_mode
		else {}
	)
	request._kit_profile_data = StadiumSurfaceNightRuntime._data(request._kit_profile)
	if (
		request._kit_mode
		and (
			request._kit_profile.is_empty()
			or StadiumSurfaceNightSnapshot.is_time(snapshot)
			or request._kit_profile.renderer != str(RenderingServer.get_current_rendering_method())
		)
	):
		return false
	if request._kit_mode:
		request._kit_physical_layout = (
			wrapped_admission.physical_layout.duplicate(true)
			if wrapped
			else snapshot.layout.duplicate(true)
		)
		if request._kit_physical_layout.is_empty():
			return false
		request._kit_physical_geometry = (
			wrapped_admission.physical_geometry if wrapped else snapshot.geometry
		)
		var physical_boundary: StadiumRecipeBoundary = StadiumLightingKitItems.graph_for(
			(
				request._kit_physical_layout
				if wrapped
				else StadiumLightingKitNightCandidate.physical_layout(snapshot.layout)
			)
		)
		if physical_boundary == null or physical_boundary.signature() != snapshot.boundary:
			return false
	request._floodlight_mode = StadiumFloodlightOwnedItems.is_family(snapshot.layout)
	request._floodlight_profile = (
		snapshot.layout.floodlight_profile if request._floodlight_mode else ""
	)
	request._time_mode = StadiumSurfaceNightSnapshot.is_time(snapshot)
	request._time_profile = snapshot.environment.mode if request._time_mode else ""
	request._policy_data = StadiumSurfaceNightRuntime._data(season.owned_surface_night)
	request._proof = (
		wrapped_admission.proof.duplicate(true)
		if wrapped
		else StadiumSurfaceNightSnapshot.proof(snapshot, season.owned_surface_night, paid)
	)
	if request._proof.is_empty():
		return false
	request._career = season.career
	request._replay_paid = season._pool_replay_ledger
	if request._owned_boundary_mode():
		request._owned_backing_inputs = request._owned_backing_state()
	request._paid_state = StadiumSurfaceNightRuntime._ledger_state(paid)
	request._season_inputs = request._season_state()
	request._snapshot_data = StadiumSurfaceNightRuntime._data(request._snapshot)
	request._proof_data = StadiumSurfaceNightRuntime._data(request._proof)
	request._fixture_id = int(snapshot.binding.fixture)
	request._match_seed = int(snapshot.binding.match_seed)
	request._tier = snapshot.tier
	request._geometry_signature = snapshot.geometry
	request._season_seed = season.season_seed
	request._season_phase = season.phase
	request._season_round = season.round_index
	request._career_run = season.career.current if season.career != null else -1
	request._replay_run = season._npc_replay_run
	if request._paid_state.is_empty() or request._season_inputs.is_empty():
		return false
	request._paid_resources = StadiumSurfaceNightRuntime._ledger_resources(paid)
	if request._replay_paid != null:
		request._replay_generation = request._replay_paid.mutation_generation()
		request._replay_state = StadiumSurfaceNightRuntime._ledger_state(request._replay_paid)
		if request._replay_generation <= 0 or request._replay_state.is_empty():
			return false
		request._replay_resources = StadiumSurfaceNightRuntime._ledger_resources(
			request._replay_paid
		)
	if request._kit_mode and not request._capture_kit_inputs():
		return false
	if (
		wrapped
		and (
			not is_instance_valid(lab)
			or lab.has_meta(StadiumSurfaceNightRuntime.OWNER)
			or lab.has_meta(StadiumSurfaceNightRuntime.BOUND)
			or lab._configured_match != issued_state
			or not is_same(issued_state.stadium, snapshot)
			or lab._npc_season != season
			or lab._stadium_ledger != paid
			or paid.mutation_generation() != issued_generation
			or not is_same(season.owned_surface_night, issued_policy)
			or not is_same(season.home_property, issued_home)
		)
	):
		return false
	lab.set_meta(StadiumSurfaceNightRuntime.OWNER, request)
	# Sticky: failed or retired requests never fall back to day.
	lab.set_meta(StadiumSurfaceNightRuntime.BOUND, true)
	return true


static func _public_current(lab: PitchBatLab) -> StadiumSurfaceNightRuntime:
	if not is_instance_valid(lab) or not lab.has_meta(StadiumSurfaceNightRuntime.OWNER):
		return null
	var value: Variant = lab.get_meta(StadiumSurfaceNightRuntime.OWNER)
	return (
		value
		if (
			is_instance_valid(value)
			and value is StadiumSurfaceNightRuntime
			and value.get_script() == StadiumSurfaceNightRuntime
		)
		else null
	)


static func _public_install_bound(lab: PitchBatLab) -> bool:
	var owner: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.current(lab)
	return owner != null and owner._install(lab)


static func _public_installed_bound(lab: PitchBatLab, snapshot: Dictionary) -> bool:
	var owner: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.current(lab)
	return (
		owner != null
		and owner._phase == StadiumSurfaceNightRuntime.Phase.ACTIVE
		and ClubCareer.same(snapshot, owner._snapshot)
		and owner._configured(lab)
		and owner._context(lab)
		and owner._operands()
	)


static func _public_action_allowed(lab: PitchBatLab) -> bool:
	if not is_instance_valid(lab):
		return false
	var required: bool = (
		lab.has_meta(StadiumSurfaceNightRuntime.BOUND)
		or (
			lab._match_state != null
			and StadiumSurfaceNightSnapshot.is_family(lab._match_state.stadium)
		)
	)
	if not required:
		return true
	var owner: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.current(lab)
	var started_us: int = (
		Time.get_ticks_usec() if owner != null and owner._action_sample_enabled else 0
	)
	var accepted: bool = (
		owner != null
		and owner._phase == StadiumSurfaceNightRuntime.Phase.ACTIVE
		and (
			owner._kit_action_intact(lab)
			if owner._kit_mode
			else (owner._context(lab) and owner._operands())
		)
	)
	if owner != null and owner._action_sample_enabled:
		owner._record_action_sample("action_allowed", started_us, accepted)
	if accepted:
		return true
	StadiumSurfaceNightRuntime.retire(lab, "OWNERSHIP_CHANGED")
	return false


static func _public_boundary_allowed(lab: PitchBatLab) -> bool:
	# Same-generation bulk edits are detected here, never adopted as a new seal.
	if not StadiumSurfaceNightRuntime.action_allowed(lab):
		return false
	var owner: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.current(lab)
	return StadiumSurfaceNightRuntime.continue_boundary(lab, owner, lab._match_state)


static func _public_continue_boundary(
	lab: PitchBatLab, owner: StadiumSurfaceNightRuntime, state: MatchState
) -> bool:
	if not StadiumSurfaceNightRuntime.continue_action(lab, owner, state):
		return false
	if owner == null:
		return true
	if (
		(
			owner._active_kit_transaction_configured(lab)
			if owner._kit_mode
			else owner._configured(lab)
		)
		and owner._advance_time(lab)
	):
		return true
	owner._retire_target(lab)
	return false


static func _public_capture_proof(lab: PitchBatLab) -> Dictionary:
	if (
		not is_instance_valid(lab)
		or lab._match_state == null
		or lab._match_state.phase != MatchState.Phase.GAME_END
		or not StadiumSurfaceNightRuntime.installed_bound(lab, lab._match_state.stadium)
	):
		return {}
	return StadiumSurfaceNightRuntime.current(lab)._proof.duplicate(true)


static func _public_retire(lab: PitchBatLab, _reason: String) -> void:
	var owner: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.current(lab)
	if owner != null:
		owner._retire_target(lab)


static func _public_continue_action(
	lab: PitchBatLab, owner: StadiumSurfaceNightRuntime, state: MatchState
) -> bool:
	# Keep the owner captured before a callback; never authorize its replacement.
	if owner == null:
		return (
			is_instance_valid(lab)
			and StadiumSurfaceNightRuntime.current(lab) == null
			and not lab.has_meta(StadiumSurfaceNightRuntime.BOUND)
			and (
				lab._match_state == null
				or not StadiumSurfaceNightSnapshot.is_family(lab._match_state.stadium)
			)
		)
	var started_us: int = Time.get_ticks_usec() if owner._action_sample_enabled else 0
	var accepted: bool = (
		state == owner._state
		and owner._phase == StadiumSurfaceNightRuntime.Phase.ACTIVE
		and (
			owner._kit_action_intact(lab)
			if owner._kit_mode
			else (owner._context(lab) and owner._operands())
		)
	)
	if owner._action_sample_enabled:
		owner._record_action_sample("continue_action", started_us, accepted)
	if accepted:
		return true
	owner._retire_target(lab)
	return false


static func _public_continue_pitch(
	lab: PitchBatLab,
	owner: StadiumSurfaceNightRuntime,
	state: MatchState,
	actor: Variant,
	parameters: PitchLaunchParameters
) -> bool:
	var valid_owner: bool = StadiumSurfaceNightRuntime.continue_boundary(lab, owner, state)
	if owner == null:
		return valid_owner
	var same_launch: bool = (
		is_instance_valid(lab)
		and owner._lab != null
		and owner._lab.get_ref() == lab
		and is_instance_valid(actor)
		and actor is PitchFlightActor
		and actor.get_script() == PitchFlightActor
		and actor == owner._pitch
		and actor.get_parent() == lab
		and actor.parameters == parameters
	)
	if valid_owner and same_launch:
		return true
	# start_pitch's final trace signal can replace the caller. Stop only the
	# exact old launch, without emitting stop_pitch/reset_pitch callbacks.
	if same_launch:
		actor.running = false
	return false


static func _public_continue_startup(
	lab: PitchBatLab, owner: StadiumSurfaceNightRuntime, state: MatchState
) -> bool:
	if (
		owner != null
		and owner._phase == StadiumSurfaceNightRuntime.Phase.CONFIGURED
		and state == owner._state
		and owner._same_target(lab)
	):
		return true
	return StadiumSurfaceNightRuntime.continue_boundary(lab, owner, state)


static func _public_claim_ball(
	lab: PitchBatLab,
	owner: StadiumSurfaceNightRuntime,
	state: MatchState,
	ball: Variant,
	play: BallPlayState
) -> bool:
	if (
		owner == null
		or owner._lab == null
		or not is_instance_valid(lab)
		or owner._lab.get_ref() != lab
		or not is_instance_valid(ball)
		or not ball is BattedBallBody
		or ball.get_script() != BattedBallBody
		or ball.get_parent() != null
		or ball.is_queued_for_deletion()
		or ball.has_meta(StadiumSurfaceNightRuntime.BALL)
		or lab._batted_ball != ball
	):
		return false
	# A marker belongs to this freshly created, still-detached candidate only.
	ball.set_meta(StadiumSurfaceNightRuntime.BALL, owner)
	owner._candidate = weakref(ball)
	owner._candidate_play = play
	if (
		StadiumSurfaceNightRuntime.continue_action(lab, owner, state)
		and owner._resolver.state == play
	):
		return true
	owner._reject_candidate(lab, ball, play)
	return false


static func _public_continue_ball(
	lab: PitchBatLab,
	owner: StadiumSurfaceNightRuntime,
	state: MatchState,
	ball: Variant,
	play: BallPlayState
) -> bool:
	var valid_owner: bool = StadiumSurfaceNightRuntime.continue_boundary(lab, owner, state)
	if owner == null:
		return valid_owner
	if (
		valid_owner
		and owner._candidate_owned(lab, ball, play)
		and ball.get_parent() == lab
		and ball.is_inside_tree()
		and not ball.is_queued_for_deletion()
		and lab._batted_ball == ball
		and owner._resolver.state == play
	):
		return true
	# An old launched body cannot remain physically active beside a replacement.
	owner._reject_candidate(lab, ball, play)
	owner._retire_target(lab)
	return false


static func _candidate_owned(
	owner: StadiumSurfaceNightRuntime, lab: PitchBatLab, ball: Variant, play: BallPlayState
) -> bool:
	return (
		is_instance_valid(lab)
		and owner._lab != null
		and owner._lab.get_ref() == lab
		and owner._candidate != null
		and is_instance_valid(ball)
		and ball is BattedBallBody
		and ball.get_script() == BattedBallBody
		and owner._candidate.get_ref() == ball
		and owner._candidate_play == play
		and ball.has_meta(StadiumSurfaceNightRuntime.BALL)
		and is_same(ball.get_meta(StadiumSurfaceNightRuntime.BALL), owner)
		and (ball.get_parent() == lab or ball.get_parent() == null)
	)


static func _reject_candidate(
	owner: StadiumSurfaceNightRuntime, lab: PitchBatLab, ball: Variant, play: BallPlayState
) -> void:
	if not owner._candidate_owned(lab, ball, play):
		return
	ball.freeze = true
	if not owner._candidate_owned(lab, ball, play):
		return
	if ball.surface_contact.is_connected(lab._on_batted_surface_contact):
		ball.surface_contact.disconnect(lab._on_batted_surface_contact)
	if owner._same_target(lab) and lab._batted_ball == ball:
		lab._batted_ball = null
	if owner._candidate_owned(lab, ball, play):
		ball.queue_free()


static func _public_retire_captured(lab: PitchBatLab, owner: StadiumSurfaceNightRuntime) -> void:
	if owner != null:
		owner._retire_target(lab)


static func _same_target(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> bool:
	return (
		is_instance_valid(lab)
		and owner._lab != null
		and owner._lab.get_ref() == lab
		and lab.get_script() == PitchBatLab
		and lab.has_meta(StadiumSurfaceNightRuntime.OWNER)
		and is_same(lab.get_meta(StadiumSurfaceNightRuntime.OWNER), owner)
		and lab.has_meta(StadiumSurfaceNightRuntime.BOUND)
		and is_same(lab.get_meta(StadiumSurfaceNightRuntime.BOUND), true)
		and lab._stadium_ledger == owner._paid
		and lab._npc_season == owner._season
		and (
			(lab._match_state == owner._state and lab._configured_match == null)
			or (lab._match_state == null and lab._configured_match == owner._state)
		)
		and (
			owner._parent == null
			or (
				is_instance_valid(owner._parent)
				and lab.get_parent() == owner._parent
				and owner._caller(lab)
			)
		)
	)


static func _retire_target(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> void:
	owner._restore(lab)
	# Restore can run tree callbacks. A reused lab or replacement owner is untouched.
	if owner._same_target(lab):
		lab.process_mode = Node.PROCESS_MODE_DISABLED
	if owner._same_target(lab):
		lab.set_process(false)
	if owner._same_target(lab):
		lab.set_physics_process(false)


static func _configured(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> bool:
	# Full replay authority remains at admission, transaction boundaries and reports.
	var started_us: int = Time.get_ticks_usec() if owner._guard_timing_enabled else 0
	var wrapped: bool = StadiumSurfaceNightSnapshot.is_wrapped(owner._snapshot)
	var issued_snapshot: Dictionary = owner._snapshot
	var issued_state_receipt: Dictionary = owner._state.stadium if owner._state != null else {}
	var issued_policy: Dictionary = (
		owner._season.owned_surface_night if owner._season != null else {}
	)
	var issued_home: Dictionary = owner._season.home_property if owner._season != null else {}
	var accepted: bool = (
		(owner._wrapped_live_inputs_configured(lab) if wrapped else owner._live_configured(lab))
		and (
			owner._kit_mode
			== StadiumLightingKitNightCandidate.is_candidate_layout(owner._snapshot.layout)
		)
		and StadiumSurfaceNightRuntime._data(owner._kit_profile) == owner._kit_profile_data
		and owner._floodlight_mode == StadiumFloodlightOwnedItems.is_family(owner._snapshot.layout)
		and (
			owner._floodlight_profile
			== (owner._snapshot.layout.floodlight_profile if owner._floodlight_mode else "")
		)
		and owner._time_mode == StadiumSurfaceNightSnapshot.is_time(owner._snapshot)
		and owner._time_profile == (owner._snapshot.environment.mode if owner._time_mode else "")
		and StadiumSurfaceNightSnapshot.matches_fixture(
			owner._snapshot,
			owner._season,
			SeasonVenues.fixture_for_id(owner._season, owner._fixture_id),
			owner._paid
		)
		and (
			not lab._managed_match
			or owner._season.pending_fixture().get("id", -1) == owner._fixture_id
		)
	)

	if wrapped:
		# No callback/await occurs inside the admission. Pin current authority again
		# before any result is used; the next lifecycle call creates a new proof.
		accepted = (
			accepted
			and owner._identity_configured(lab)
			and is_same(owner._snapshot, issued_snapshot)
			and is_same(owner._state.stadium, issued_state_receipt)
			and is_same(owner._season.owned_surface_night, issued_policy)
			and is_same(owner._season.home_property, issued_home)
		)
	owner._record_guard_timing("full_configured", started_us)
	return (
		accepted
		and (
			not owner._kit_mode
			or owner._restoring
			or not owner._kit_issue_ever
			or (owner._kit_issue_live and not owner._kit_issue_invalid)
		)
		and (
			not owner._kit_mode
			or owner._kit_boundary_visuals.is_empty()
			or owner._kit_boundary_visuals_intact(true)
		)
	)


static func _active_kit_transaction_configured(
	owner: StadiumSurfaceNightRuntime, lab: PitchBatLab
) -> bool:
	# Candidate3 only. Full replay proved the separate immutable issued receipt.
	# Check current owner/generation/fixture anew after callbacks, never a frame cache.
	# Full replay remains in configure/install/installed_bound and final proofs.
	return (
		owner._kit_mode
		and not owner._floodlight_mode
		and not owner._time_mode
		and owner._phase == StadiumSurfaceNightRuntime.Phase.ACTIVE
		and not owner._restoring
		and owner._identity_configured(lab)
		and owner._kit_current_authority_intact()
		and owner._field_unchanged()
		and owner._fixture_id == int(owner._snapshot.binding.fixture)
		and owner._match_seed == int(owner._snapshot.binding.match_seed)
		and StadiumLightingKitNightCandidate.is_candidate_layout(owner._snapshot.layout)
		and owner._kit_profile.renderer == str(RenderingServer.get_current_rendering_method())
		and owner._kit_issue_live
		and not owner._kit_issue_invalid
		and (
			not lab._managed_match
			or owner._season.pending_fixture().get("id", -1) == owner._fixture_id
		)
	)


static func _owned_transaction_configured(
	owner: StadiumSurfaceNightRuntime, lab: PitchBatLab
) -> bool:
	# Same raw seals and cheap derived predicates after synchronous callbacks.
	# Full fixture replay remains at the existing entry/completion boundaries.
	return (
		owner._owned_live_configured(lab)
		and owner._fixture_id == int(owner._snapshot.binding.fixture)
		and (
			owner._kit_mode
			== StadiumLightingKitNightCandidate.is_candidate_layout(owner._snapshot.layout)
		)
		and StadiumSurfaceNightRuntime._data(owner._kit_profile) == owner._kit_profile_data
		and owner._floodlight_mode == StadiumFloodlightOwnedItems.is_family(owner._snapshot.layout)
		and (
			owner._floodlight_profile
			== (owner._snapshot.layout.floodlight_profile if owner._floodlight_mode else "")
		)
		and owner._time_mode == StadiumSurfaceNightSnapshot.is_time(owner._snapshot)
		and owner._time_profile == (owner._snapshot.environment.mode if owner._time_mode else "")
		and (
			not lab._managed_match
			or owner._season.pending_fixture().get("id", -1) == owner._fixture_id
		)
	)


static func _identity_configured(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> bool:
	return (
		is_instance_valid(lab)
		and owner._lab != null
		and owner._lab.get_ref() == lab
		and lab.get_script() == PitchBatLab
		and lab.has_meta(StadiumSurfaceNightRuntime.OWNER)
		and is_same(lab.get_meta(StadiumSurfaceNightRuntime.OWNER), owner)
		and lab.has_meta(StadiumSurfaceNightRuntime.BOUND)
		and is_same(lab.get_meta(StadiumSurfaceNightRuntime.BOUND), true)
		and lab._match_state == owner._state
		and lab._configured_match == null
		and lab._stadium_ledger == owner._paid
		and lab._npc_season == owner._season
		and StadiumSurfaceNightRuntime._ledger_identity(owner._paid, owner._paid_resources)
		and owner._paid.mutation_generation() > 0
		and owner._paid.mutation_generation() == owner._paid_generation
		and is_instance_valid(owner._season)
		and owner._season.get_script() == SeasonState
		and owner._season.career == owner._career
		and owner._season._pool_replay_ledger == owner._replay_paid
		and owner._season.season_seed == owner._season_seed
		and owner._season.phase == owner._season_phase
		and owner._season.round_index == owner._season_round
		and owner._season._npc_replay_run == owner._replay_run
		and (
			owner._career == null
			or (
				owner._career.get_script() == ClubCareer
				and owner._career.current == owner._career_run
			)
		)
		and (
			owner._replay_paid == null
			or (
				StadiumSurfaceNightRuntime._ledger_identity(
					owner._replay_paid, owner._replay_resources
				)
				and owner._replay_paid.mutation_generation() > 0
				and owner._replay_paid.mutation_generation() == owner._replay_generation
			)
		)
	)


static func _live_configured(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> bool:
	# Full original input equality. Never called by the ACTIVE recurring hot path.
	return (
		owner._identity_configured(lab)
		and (not owner._kit_mode or owner._kit_inputs_intact())
		and StadiumSurfaceNightRuntime._ledger_state(owner._paid) == owner._paid_state
		and not owner._paid_state.is_empty()
		and StadiumSurfaceNightRuntime._data(owner._paid.to_data()) == owner._paid_data
		and owner._season_state() == owner._season_inputs
		and not owner._season_inputs.is_empty()
		and (
			owner._replay_paid == null
			or (
				StadiumSurfaceNightRuntime._ledger_state(owner._replay_paid) == owner._replay_state
				and not owner._replay_state.is_empty()
			)
		)
		and (
			StadiumSurfaceNightRuntime._data(owner._season.owned_surface_night)
			== owner._policy_data
		)
		and StadiumSurfaceNightRuntime._data(owner._snapshot) == owner._snapshot_data
		and StadiumSurfaceNightRuntime._data(owner._proof) == owner._proof_data
		and ClubCareer.same(owner._state.stadium, owner._snapshot)
		and StadiumSurfaceNightSnapshot.valid(owner._snapshot)
		and StadiumSurfaceNightSnapshot.policy_shape(owner._season.owned_surface_night)
	)


static func _wrapped_live_inputs_configured(
	owner: StadiumSurfaceNightRuntime, lab: PitchBatLab
) -> bool:
	# Full original input equality. Never called by the ACTIVE recurring hot path.
	return (
		owner._identity_configured(lab)
		and (not owner._kit_mode or owner._kit_inputs_intact())
		and StadiumSurfaceNightRuntime._ledger_state(owner._paid) == owner._paid_state
		and not owner._paid_state.is_empty()
		and StadiumSurfaceNightRuntime._data(owner._paid.to_data()) == owner._paid_data
		and owner._season_state() == owner._season_inputs
		and not owner._season_inputs.is_empty()
		and (
			owner._replay_paid == null
			or (
				StadiumSurfaceNightRuntime._ledger_state(owner._replay_paid) == owner._replay_state
				and not owner._replay_state.is_empty()
			)
		)
		and (
			StadiumSurfaceNightRuntime._data(owner._season.owned_surface_night)
			== owner._policy_data
		)
		and StadiumSurfaceNightRuntime._data(owner._snapshot) == owner._snapshot_data
		and StadiumSurfaceNightRuntime._data(owner._proof) == owner._proof_data
		and ClubCareer.same(owner._state.stadium, owner._snapshot)
	)


static func _owned_live_configured(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> bool:
	# Candidate2 synchronous transaction inputs: derived catalogs have no mutable input
	# beyond these exact ledger seals and the captured FieldDefinition scalars.
	var started_us: int = Time.get_ticks_usec() if owner._guard_timing_enabled else 0
	var accepted: bool = (
		owner._owned_boundary_mode()
		and owner._field_unchanged()
		and owner._identity_configured(lab)
		and (not owner._kit_mode or owner._kit_inputs_intact())
		and owner._owned_backing_state() == owner._owned_backing_inputs
		and not owner._owned_backing_inputs.is_empty()
		and StadiumSurfaceNightRuntime._ledger_state(owner._paid) == owner._paid_state
		and not owner._paid_state.is_empty()
		and owner._season_state() == owner._season_inputs
		and not owner._season_inputs.is_empty()
		and (
			owner._replay_paid == null
			or (
				StadiumSurfaceNightRuntime._ledger_state(owner._replay_paid) == owner._replay_state
				and not owner._replay_state.is_empty()
			)
		)
		and (
			StadiumSurfaceNightRuntime._data(owner._season.owned_surface_night)
			== owner._policy_data
		)
		and StadiumSurfaceNightRuntime._data(owner._snapshot) == owner._snapshot_data
		and StadiumSurfaceNightRuntime._data(owner._proof) == owner._proof_data
		and ClubCareer.same(owner._state.stadium, owner._snapshot)
	)

	owner._record_guard_timing("owned_live", started_us)
	return accepted
