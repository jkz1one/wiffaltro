extends RefCounted
## Stateless operations for the original SeasonApp owner.


# gdlint: disable=max-returns
static func _source_private_ac02_passive_16_private_open_match(_source_owner: SeasonApp,
	state: MatchState,
	player_home: bool,
	season_game: bool,
	field_id: StringName = PitchBatLab.FIELD_ID
) -> void:
	if state == null:
		_source_owner.notice = "The saved match could not be prepared. Your season is unchanged."
		_source_owner.show_season()
		return
	if season_game and _source_owner.season != null \
		and SeasonPitchProof.enabled(_source_owner.season.build) \
		and not state.sure_shot.enable_current_evidence():
		_source_owner.notice = "Current pitching evidence must start before the first pitch."
		_source_owner.show_season()
		return
	var terrain: bool = StadiumLayoutSnapshot.is_terrain(state.stadium)
	var night: bool = StadiumSurfaceNightSnapshot.is_family(state.stadium)
	if (
		season_game
		and _source_owner.season != null
		and StadiumSurfaceNightSnapshot.expected(_source_owner.season, \
			_source_owner.season.pending_fixture())
		and not night
	):
		_source_owner.notice = "The immutable night fixture is missing. Your season is unchanged."
		_source_owner.show_season()
		return
	if (
		night
		and (
			not season_game
			or _source_owner.season == null
			or not player_home
			or _source_owner._fixture_id != _source_owner.season.pending_fixture().get("id", -1)
			or not StadiumSurfaceNightSnapshot.matches_fixture(
				state.stadium,
				_source_owner.season,
				_source_owner.season.pending_fixture(),
				StadiumSurfaceNightSnapshot.ledger(_source_owner.season)
			)
		)
	):
		_source_owner.notice = "The night fixture does not match its saved policy and paid field."
		_source_owner.show_season()
		return
	if (
		night
		and StadiumLightingKitNightCandidate.is_candidate_layout(state.stadium.get("layout"))
		and not StadiumLightingKitNightCandidate.renderer_supported(
			StadiumSurfaceNightSnapshot.entry(state.stadium)
		)
	):
		_source_owner.notice = StadiumLightingKitNightCandidate.renderer_reason(
			StadiumSurfaceNightSnapshot.entry(state.stadium)
		)
		_source_owner.show_season()
		return
	var npc_away: bool = StadiumNpcSnapshot.is_public(state.stadium)
	if field_id == &"field.npc_venue" and not npc_away:
		_source_owner.notice = "This away field is missing its saved fixture."
		_source_owner.show_season()
		return
	var neutral_final: bool = (
		npc_away
		and (
			state.stadium.get("version") == StadiumNpcSnapshot.FINAL_FIXTURE_VERSION
			or state.stadium.get("version") == StadiumNpcSnapshot.GRAND_FINAL_FIXTURE_VERSION
			or state.stadium.get("version") == StadiumNpcSnapshot.GRAND_II_FINAL_FIXTURE_VERSION
			or state.stadium.get("version") == StadiumNpcSnapshot.GRAND_III_FINAL_FIXTURE_VERSION
			or state.stadium.get("version") == StadiumNpcSnapshot.POOL_PARTY_FINAL_FIXTURE_VERSION
			or state.stadium.get("version") == StadiumNpcSnapshot.HILLSIDE_FINAL_FIXTURE_VERSION
		)
	)
	if (
		npc_away
		and (
			not season_game
			or _source_owner.season == null
			or (player_home and not neutral_final)
			or player_home != (_source_owner.season.pending_fixture().get("home", -1) == 0)
			or (
				neutral_final
				and _source_owner.season.pending_fixture().get("home", -1) != 0
				and _source_owner.season.pending_fixture().get("away", -1) != 0
			)
			or field_id != &"field.npc_venue"
			or not StadiumNpcSnapshot.matches_fixture(
				state.stadium, _source_owner.season, _source_owner.season.pending_fixture()
			)
		)
	):
		_source_owner.notice = \
			"This away field does not match its saved fixture. Your season is unchanged."
		_source_owner.show_season()
		return
	if (
		not state.stadium.is_empty()
		and not npc_away
		and (not StadiumLayoutSnapshot.valid(state.stadium) or field_id != PitchBatLab.FIELD_ID)
	):
		_source_owner.notice = "This home layout could not be validated. Your saved season is unchanged."
		_source_owner.menu.show_home()
		return
	var ledger: ClubAssetLedger = null
	if (
		night
		or StadiumWaterfallAnimationSnapshot.is_family(state.stadium)
		or StadiumLowWallSnapshot.is_family(state.stadium)
		or StadiumLightingKitItems.is_family(state.stadium.get("layout", {}))
		or StadiumWaterfallLiveItems.is_family(state.stadium.get("layout", {}))
		or (
			state.stadium.get("layout") is Dictionary
			and SeasonOwnership._whole(state.stadium.layout.get("version"), 15, 45)
		)
	):
		ledger = _source_owner._mounted_match_ledger(state, player_home, season_game)
		if ledger == null:
			_source_owner.notice = \
				"This home fixture does not match its paid field. Your season is unchanged."
			_source_owner.show_season()
			return
	# Legacy careers and exhibitions retain their exact old performance schema.
	state.performance.track_fielding = season_game and ClubPlayerLegend.enabled(_source_owner.season)
	_source_owner.sales.reset()
	state.inventory_boundary.connect(_source_owner.sales.apply_pending.bind(_source_owner))
	_source_owner._season_game = season_game
	_source_owner._busy = false
	_source_owner._result_recorded = false
	_source_owner._result_saved = false
	_source_owner._ac02_settlement_ticket.clear()
	_source_owner._continue.text = "CONTINUE"
	_source_owner._continue.tooltip_text = ""
	_source_owner.loadout.close()
	_source_owner.loadout.match_snapshot = SeasonLoadoutData.capture(_source_owner.season if \
		season_game else null)
	_source_owner.menu.hide()
	_source_owner.lab = PitchBatLab.new()
	_source_owner.lab.name = "ActiveMatch"
	_source_owner.lab._configured_match = state
	_source_owner.lab._npc_season = (
		_source_owner.season
		if (
			npc_away
			or night
			or StadiumLowWallSnapshot.is_family(state.stadium)
			or StadiumWaterfallAnimationSnapshot.is_family(state.stadium)
		)
		else null
	)
	_source_owner.lab._stadium_ledger = ledger
	_source_owner.lab._field_id = field_id
	_source_owner.lab._player_home = player_home
	_source_owner.lab._managed_match = true
	if night and not StadiumSurfaceNightRuntime.configure(_source_owner.lab, _source_owner.season, \
		ledger):
		_source_owner.lab.free()
		_source_owner.lab = null
		_source_owner.notice = "The night field could not bind its owner. Your season is unchanged."
		_source_owner.show_season()
		return
	if terrain and not StadiumSurfaceTerrainRuntime.configure(_source_owner.lab, ledger):
		_source_owner.lab.free()
		_source_owner.lab = null
		_source_owner.notice = "The terrain field could not bind its owner. Your season is unchanged."
		_source_owner.show_season()
		return
	_source_owner.lab.match_return_requested.connect(_source_owner.finish_game)
	_source_owner.lab.menu_exit_requested.connect(_source_owner.ask_leave_game)
	var hillside: bool = (
		state.stadium.get("version") == StadiumNpcSnapshot.HILLSIDE_FINAL_FIXTURE_VERSION
	)
	if hillside:
		_source_owner.lab.hillside_public_install_finished.connect(
			_source_owner._hillside_public_install_finished.bind(
				_source_owner.lab, state, _source_owner.season, \
					_source_owner.season.pending_fixture().duplicate(true)
			),
			SeasonApp.CONNECT_ONE_SHOT
		)
	var night_lab: PitchBatLab = _source_owner.lab if night else null
	var night_owner: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.current(night_lab)
	var night_season: SeasonState = _source_owner.season
	var night_fixture: int = _source_owner._fixture_id
	var terrain_lab: PitchBatLab = _source_owner.lab if terrain else null
	var terrain_owner: StadiumSurfaceTerrainRuntime = StadiumSurfaceTerrainRuntime.current(
		terrain_lab
	)
	var terrain_season: SeasonState = _source_owner.season
	var terrain_fixture: Dictionary = _source_owner.season.pending_fixture().duplicate(true) if \
		terrain else {}
	var terrain_snapshot: Dictionary = state.stadium.duplicate(true) if terrain else {}
	var startup: RefCounted = SeasonApp.AC02_STARTUP.new()
	if not startup.enroll(_source_owner, _source_owner.lab):
		startup = null
	_source_owner.add_child(_source_owner.lab)
	if startup != null:
		if not startup.validate_and_publish():
			var still_owned: bool = _source_owner.lab == startup.lab and _source_owner.season == \
				startup.season
			startup.dispose()
			if still_owned:
				_source_owner.notice = "The away field could not start. The pregame checkpoint remains saved."
				_source_owner.show_season()
		return
	if (
		terrain
		and (
			not is_instance_valid(terrain_lab)
			or _source_owner.lab != terrain_lab
			or terrain_lab.get_parent() != _source_owner
			or _source_owner.season != terrain_season
			or _source_owner._fixture_id != night_fixture
			or _source_owner._season_game != season_game
			or terrain_lab._match_state != state
			or not ClubCareer.same(terrain_fixture, terrain_season.pending_fixture())
			or not ClubCareer.same(terrain_snapshot, state.stadium)
			or StadiumSurfaceTerrainRuntime.current(terrain_lab) != terrain_owner
			or not StadiumSurfaceTerrainRuntime.installed_bound(terrain_lab, terrain_snapshot)
		)
	):
		StadiumSurfaceTerrainRuntime.retire_captured(terrain_lab, terrain_owner)
		return
	if (
		night
		and (
			not is_instance_valid(night_lab)
			or _source_owner.lab != night_lab
			or _source_owner.season != night_season
			or _source_owner._fixture_id != night_fixture
			or _source_owner._season_game != season_game
			or night_lab._match_state != state
			or StadiumSurfaceNightRuntime.current(night_lab) != night_owner
		)
	):
		StadiumSurfaceNightRuntime.retire_captured(night_lab, night_owner)
		return
	if hillside and StadiumNpcPublicRuntime.pending_hillside(_source_owner.lab):
		return
	_source_owner._verify_match_install(state, npc_away)
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_hillside_public_install_finished(_source_owner: SeasonApp,
	success: bool,
	captured: PitchBatLab,
	state: MatchState,
	owner_season: SeasonState,
	fixture: Dictionary
) -> void:
	# A retired/replaced scene cannot finish another match's pending installation.
	if not is_instance_valid(captured) or _source_owner.lab != captured:
		return
	if (
		not success
		or not captured.is_inside_tree()
		or captured._match_state != state
		or _source_owner.season != owner_season
		or owner_season == null
		or not _source_owner._season_game
		or _source_owner._fixture_id != fixture.get("id")
		or not ClubCareer.same(owner_season.pending_fixture(), fixture)
		or not StadiumNpcSnapshot.matches_fixture(state.stadium, owner_season, fixture)
	):
		if not _source_owner._close_match():
			return
		_source_owner.notice = "The neutral field could not start. Your saved season is unchanged."
		_source_owner.show_season()
		return
	_source_owner._verify_match_install(state, true)
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_verify_match_install(_source_owner: SeasonApp, state: MatchState, \
	npc_away: bool) -> void:
	var ac02_token: int = SeasonApp.AC02_PASSIVE_16.enter("season_app._verify_match_install")
	_source_owner._ac02_passive_16_private_verify_match_install(state, npc_away)
	SeasonApp.AC02_PASSIVE_16.leave(ac02_token)
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_ac02_passive_16_private_verify_match_install(_source_owner: \
	SeasonApp, state: MatchState, npc_away: bool) -> void:
	if StadiumLayoutSnapshot.is_terrain(state.stadium):
		if not is_instance_valid(_source_owner.lab) or _source_owner.lab._match_state != state or \
			_source_owner.lab.get_parent() != _source_owner:
			return
		var terrain_lab: PitchBatLab = _source_owner.lab
		var terrain_owner: StadiumSurfaceTerrainRuntime = StadiumSurfaceTerrainRuntime.current(
			terrain_lab
		)
		if not StadiumSurfaceTerrainRuntime.installed_bound(terrain_lab, state.stadium):
			StadiumSurfaceTerrainRuntime.retire_captured(terrain_lab, terrain_owner)
			return
	if (
		StadiumSurfaceNightSnapshot.is_family(state.stadium)
		and (not is_instance_valid(_source_owner.lab) or _source_owner.lab._match_state != state or \
			_source_owner.lab.get_parent() != _source_owner)
	):
		return
	if (
		StadiumSurfaceNightSnapshot.is_family(state.stadium)
		and not StadiumSurfaceNightRuntime.installed_bound(_source_owner.lab, state.stadium)
	):
		if not _source_owner._close_match():
			return
		_source_owner.notice = "The night field could not start. Your saved season is unchanged."
		_source_owner.show_season()
		return
	if npc_away and not StadiumPropertyRuntime.npc_installed_bound(_source_owner.lab, state.stadium):
		if not _source_owner._close_match():
			return
		_source_owner.notice = "The away field could not start. Your saved season is unchanged."
		_source_owner.show_season()
		return
	if (
		not state.stadium.is_empty()
		and (
			not _source_owner.lab.has_meta("stadium_snapshot")
			or (
				state.stadium.has("boundary")
				and not (
					StadiumSurfaceNightRuntime.installed_bound(_source_owner.lab, state.stadium)
					if StadiumSurfaceNightSnapshot.is_wrapped(state.stadium)
					else StadiumBoundaryRuntime.installed(_source_owner.lab, state.stadium)
				)
			)
		)
	):
		if not _source_owner._close_match():
			return
		_source_owner.notice = "The home field could not start. Your saved season is unchanged."
		_source_owner.show_season()
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_mounted_match_ledger(_source_owner: SeasonApp,
	state: MatchState, player_home: bool, season_game: bool
) -> ClubAssetLedger:
	if _source_owner.season == null or not season_game or not player_home:
		return null
	var fixture: Dictionary = _source_owner.season.pending_fixture()
	if fixture.is_empty() or fixture.home != 0 or fixture.id != _source_owner._fixture_id:
		return null
	var expected: Dictionary = StadiumLayoutSnapshot.for_fixture(_source_owner.season, fixture)
	if (
		expected.is_empty()
		or StadiumLayoutSnapshot.key(expected) != StadiumLayoutSnapshot.key(state.stadium)
	):
		return null
	var ledger: ClubAssetLedger = (
		load("res://src/gameplay/season/dynasty_shared_time_runtime.gd").paid_ledger(_source_owner.season)
		if _source_owner.season._league_home_context.get("format") in [95, 96] else
		load("res://src/gameplay/season/dynasty_league_home_runtime.gd").paid_ledger(_source_owner.season)
		if _source_owner.season._league_home_context.get("format") in [91, 92] else
		load("res://src/gameplay/season/dynasty_standard_runtime.gd").paid_ledger(_source_owner.season)
		if not _source_owner.season._standard_live_context.is_empty()
		else ClubPlayers.assets(_source_owner.season.career)
	)
	return ledger if StadiumLayoutSnapshot.matches(expected, ledger) else null
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_public_finish_game(_source_owner: SeasonApp) -> void:
	if _source_owner._busy or _source_owner.lab == null or _source_owner.lab._match_state.phase != \
		MatchState.Phase.GAME_END:
		return
	if _source_owner.lab._match_presentation_director.mode != \
		MatchPresentationDirector.Mode.OUTRO_HOLD:
		return
	_source_owner._busy = true
	var state: MatchState = _source_owner.lab._match_state
	if not _source_owner._commit_result():
		if _source_owner.round_ui == null or not _source_owner.round_ui._async_human_saving:
			_source_owner._busy = false
		return
	var score: String = state.score_label()
	if not _source_owner._close_match():
		_source_owner._busy = false
		return
	_source_owner.menu.show_postgame(score, _source_owner._season_game)
# gdlint: enable=max-returns


static func _source_private_ac02_save_settlement(_source_owner: SeasonApp) -> bool:
	var issue: Variant = _source_owner._ac02_settlement_ticket.get("issue")
	if (
		not issue is StadiumNpcAc02IssuedStateV1
		or issue.get_script() != StadiumNpcAc02IssuedStateV1
	):
		SeasonSave.last_error = \
			("The completed AC-02 game lost its settlement owner. The save was not " + "attempted.")
		return false
	return issue.save_settlement(_source_owner)


static func _source_private_ac02_settlement_owner_intact(_source_owner: SeasonApp) -> bool:
	var ticket: Dictionary = _source_owner._ac02_settlement_ticket
	var property: StadiumNpcPublicProperty = ticket.get("property") as StadiumNpcPublicProperty
	return (
		not ticket.is_empty()
		and _source_owner._result_recorded
		and is_instance_valid(_source_owner.lab)
		and _source_owner.lab == ticket.get("lab")
		and _source_owner.season != null
		and _source_owner.season == ticket.get("season")
		and _source_owner.lab._match_state == ticket.get("state")
		and _source_owner.lab._match_state.phase == MatchState.Phase.GAME_END
		and _source_owner._fixture_id == ticket.get("fixture_id")
		and is_instance_valid(property)
		and StadiumNpcPublicRuntime._property(_source_owner.lab) == property
		and property.has_ac02_issue()
		and property._ac02_issue != null
		and property._ac02_issue == ticket.get("issue")
		and property._ac02_issue_pin == ticket.get("issue")
		and _source_owner.lab._ac02_issued_owner == ticket.get("issue")
		and property._ac02_issue.state == StadiumNpcAc02IssuedStateV1.Lifetime.REVOKED
		and property.ac02_owns_cleanup()
		and _source_owner.season.physical == ticket.get("physical")
	)


static func _source_private_ac02_queue_authorized(_source_owner: SeasonApp, human: Array) -> bool:
	# A direct queue caller cannot skip active deep capture and revoke-before-write.
	return (
		_source_owner._ac02_settlement_owner_intact()
		and not _source_owner._ac02_settlement_ticket.has("pending")
		and _source_owner.season.physical != null
		and var_to_bytes(human) == var_to_bytes(_source_owner._ac02_settlement_ticket.get("human"))
		and ClubCareer.same(_source_owner.season.pending_fixture(), \
			_source_owner._ac02_settlement_ticket.get("fixture"))
	)


static func _source_private_ac02_resume_authorized(_source_owner: SeasonApp) -> bool:
	if not _source_owner._ac02_settlement_owner_intact() or _source_owner.season.physical == null:
		return false
	var pending: Dictionary = _source_owner.season.physical.pending
	return (
		is_same(pending, _source_owner._ac02_settlement_ticket.get("pending"))
		and pending.get("human") is Array
		and var_to_bytes(pending.human) == \
			var_to_bytes(_source_owner._ac02_settlement_ticket.get("human"))
		and ClubCareer.same(_source_owner.season.pending_fixture(), \
			_source_owner._ac02_settlement_ticket.get("fixture"))
	)


static func _source_private_retry_ac02_settlement(_source_owner: SeasonApp) -> bool:
	var ticket: Dictionary = _source_owner._ac02_settlement_ticket
	if not _source_owner._ac02_settlement_owner_intact():
		_source_owner.notice = "The completed AC-02 game no longer has its original settlement owner."
		return false
	if _source_owner.season.physical != null:
		if not _source_owner._ac02_resume_authorized():
			_source_owner.notice = "The captured AC-02 game evidence changed. The round was not resumed."
			return false
		_source_owner.round_ui.resume()
		return false
	if (
		_source_owner.season.player_results.is_empty()
		or not is_same(_source_owner.season.player_results.back(), ticket.get("result_source"))
		or var_to_bytes(_source_owner.season.player_results.back()) != var_to_bytes(ticket.get("result"))
	):
		_source_owner.notice = "The recorded AC-02 result changed. The previous save was preserved."
		return false
	# Persistence only. No report capture, result replay or additional reward.
	_source_owner._result_saved = _source_owner._checkpoint()
	_source_owner._continue.text = "CONTINUE" if _source_owner._result_saved else "RETRY SAVE"
	_source_owner._continue.tooltip_text = "" if _source_owner._result_saved else SeasonSave.last_error
	return _source_owner._result_saved


static func _source_private_played_field_matches(_source_owner: SeasonApp) -> bool:
	if (
		is_instance_valid(_source_owner.lab)
		and _source_owner.lab.has_meta(StadiumSurfaceTerrainRuntime.BOUND)
		and not StadiumSurfaceTerrainRuntime.boundary_allowed(_source_owner.lab)
	):
		_source_owner.notice = "The original terrain field lost its exact installed authority."
		return false
	# Original night authority cannot be reclassified by editing the live policy/property.
	if (
		is_instance_valid(_source_owner.lab)
		and _source_owner.lab.has_meta(StadiumSurfaceNightRuntime.BOUND)
		and not StadiumSurfaceNightRuntime.boundary_allowed(_source_owner.lab)
	):
		_source_owner.notice = "The original night field lost its paid authority or presentation."
		return false
	if _source_owner.season.home_property.is_empty() and _source_owner.season.npc_venues.is_empty():
		return true
	var expected: Dictionary = StadiumLayoutSnapshot.for_fixture(_source_owner.season, \
		_source_owner.season.pending_fixture())
	var key: String = StadiumLayoutSnapshot.key(expected)
	if (
		StadiumLayoutSnapshot.is_terrain(expected)
		and not StadiumSurfaceTerrainRuntime.installed_bound(_source_owner.lab, expected)
	):
		_source_owner.notice = "The played terrain does not match its frozen home field."
		return false
	return _source_owner._played_field_matches_remaining_checks(expected, key)


static func _source_private_played_field_matches_remaining_checks(_source_owner: SeasonApp, \
	expected: Dictionary, key: String) -> bool:
	if (
		StadiumSurfaceNightSnapshot.is_family(expected)
		and not StadiumSurfaceNightRuntime.installed_bound(_source_owner.lab, expected)
	):
		_source_owner.notice = "The played night field lost its exact owner or presentation."
		return false
	if StadiumNpcSnapshot.is_public(expected):
		if not StadiumPropertyRuntime.npc_installed_bound(_source_owner.lab, \
			_source_owner.lab._match_state.stadium):
			_source_owner.notice = "The played away field does not match its frozen fixture."
			return false
	# Fixture36 retains original46/47 ownership but installs separately bound physical43.
	# Its exact Night owner checks both receipts; the historical boundary hash path
	# intentionally does not reinterpret the new complete-owner wrappers.
	if (
		expected.has("boundary")
		and not (
			StadiumSurfaceNightRuntime.installed_bound(_source_owner.lab, expected)
			if StadiumSurfaceNightSnapshot.is_wrapped(expected)
			else StadiumBoundaryRuntime.installed(_source_owner.lab, expected)
		)
	):
		_source_owner.notice = "The played boundary is missing or does not match the frozen home field."
		return false
	if StadiumLayoutSnapshot.key(_source_owner.lab._match_state.stadium) == key:
		if (
			key.is_empty()
			or (
				_source_owner.lab.has_meta("stadium_snapshot")
				and StadiumLayoutSnapshot.key(_source_owner.lab.get_meta("stadium_snapshot")) == key
			)
		):
			return true
	_source_owner.notice = "The played field does not match this season's frozen home layout."
	return false


static func _source_public_ask_leave_game(_source_owner: SeasonApp) -> void:
	if _source_owner.lab == null:
		return
	if _source_owner.lab._match_state.phase == MatchState.Phase.GAME_END:
		# Completed results must go through the result hold and single commit path.
		return
	_source_owner._confirm(
		"Leave this game? The unfinished game will restart. Saved season progress stays.",
		_source_owner.leave_game
	)


static func _source_public_leave_game(_source_owner: SeasonApp) -> void:
	if not _source_owner._close_match(_source_owner._season_game):
		return
	if _source_owner._season_game:
		_source_owner.show_season()
	else:
		_source_owner.menu.show_home()


static func _source_private_ac02_settled_manual_qc_close_allowed(_source_owner: SeasonApp) -> bool:
	# Failed diagnostics do not trap a legitimately settled game. Only the existing
	# original settlement/cleanup proof can allow discard after its required revoke.
	var issue: StadiumNpcAc02IssuedStateV1 = StadiumNpcAc02IssuedStateV1.current(_source_owner.lab)
	return (
		issue != null
		and issue.get_script() == StadiumNpcAc02IssuedStateV1
		and issue._manual_qc_started
		and issue.manual_qc_pending()
		and not issue._manual_qc_flushing
		and issue._manual_qc_terminal_attempted
		and issue._bindings_pin.get("lab") == _source_owner.lab
		and issue._bindings_pin.get("match") == _source_owner.lab._match_state
		and issue._bindings_pin.get("automation") == null
		and _source_owner.lab._automation == null
		and _source_owner.lab._record_export == issue._manual_qc_exporter
		and is_same(_source_owner.lab._play_records, issue._manual_qc_records)
		and _source_owner.lab._play_records.size() == issue._manual_qc_terminal_count
		and issue._manual_qc_dirty_revision == issue._manual_qc_terminal_revision
		and _source_owner._ac02_settlement_owner_intact()
	)


static func _source_private_close_match(_source_owner: SeasonApp, close_inventory: bool = false) \
	-> bool:
	if is_instance_valid(_source_owner.lab) and _source_owner.lab.ac02_startup_pending():
		if _source_owner.lab._ac02_startup_attempt != null:
			_source_owner.lab._ac02_startup_attempt.abort("SeasonApp close during startup")
		return false
	# Flush before ticket/ledger removal or retirement. Export callbacks cannot close a
	# replacement lab, and recursive close must not dispose the currently exporting one.
	var qc_lab: PitchBatLab = _source_owner.lab
	var qc_state: MatchState = qc_lab._match_state if is_instance_valid(qc_lab) else null
	if (
		(
			(
					not _source_owner._ac02_settled_manual_qc_close_allowed()
					and not PitchBatLabFeelSupport.flush_pending_manual_records(qc_lab)
				)
		)
		or (
			(
					_source_owner.lab != qc_lab
					or (qc_lab != null and (not is_instance_valid(qc_lab) or qc_lab._match_state != qc_state))
				)
		)
		or (
			close_inventory and not _source_owner.close_inventory_for_hub()
		)
	):
		return false
	PitchBatLabFeelSupport.warn_pending_manual_records(qc_lab)
	_source_owner._ac02_settlement_ticket.clear()
	var night_owner: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.current(_source_owner.lab)
	var night_lab: PitchBatLab = _source_owner.lab if night_owner != null else null
	var night_state: MatchState = night_lab._match_state if is_instance_valid(night_lab) else null
	StadiumSurfaceNightRuntime.retire_captured(night_lab, night_owner)
	if (
		night_owner != null
		and (
			not is_instance_valid(night_lab)
			or _source_owner.lab != night_lab
			or night_lab._match_state != night_state
			or StadiumSurfaceNightRuntime.current(night_lab) != night_owner
		)
	):
		return false
	StadiumPoolOwnedExtension.retire_installed_field(_source_owner.lab, "APP_CLOSE")
	_source_owner.loadout.close()
	_source_owner._continue.hide()
	if _source_owner.lab != null:
		PitchBatLabFeelSupport.reset_debug_pause(_source_owner.lab)
		_source_owner.lab._stadium_ledger = null
		_source_owner.remove_child(_source_owner.lab)
		if (
			night_owner != null
			and (
				not is_instance_valid(night_lab)
				or _source_owner.lab != night_lab
				or night_lab._match_state != night_state
				or StadiumSurfaceNightRuntime.current(night_lab) != night_owner
				or night_lab.get_parent() != null
			)
		):
			return false
		_source_owner.lab.queue_free()
		_source_owner.lab = null
	_source_owner.get_tree().paused = false
	_source_owner.menu.show()
	return true


static func _source_public_swap_lineup(_source_owner: SeasonApp, first: int, second: int) -> void:
	if _source_owner.lab != null or _source_owner.season == null or \
		_source_owner.season.pending_fixture().is_empty():
		return
	_source_owner.season.swap_batters(first, second)
	_source_owner._checkpoint()
	_source_owner.menu.refresh_lineup()


static func _source_public_select_starter(_source_owner: SeasonApp, index: int) -> void:
	if _source_owner.lab != null or _source_owner.season == null or \
		_source_owner.season.pending_fixture().is_empty():
		return
	_source_owner.season.select_starter(index)
	_source_owner._checkpoint()
	_source_owner.menu.refresh_lineup()


static func _source_public_select_fielder(_source_owner: SeasonApp, index: int) -> void:
	if _source_owner.lab != null or _source_owner.season == null or \
		_source_owner.season.pending_fixture().is_empty():
		return
	if index != _source_owner.season.starter_index and index >= 0 and index < 4:
		_source_owner.season.fielder_index = index
		_source_owner._checkpoint()
		_source_owner.menu.refresh_lineup()


static func _source_private_checkpoint(_source_owner: SeasonApp) -> bool:
	# A live original-night session must pass its full seal before any checkpoint.
	# The attempted-result marker is not persistence authority.
	if (
		is_instance_valid(_source_owner.lab)
		and _source_owner.lab.has_meta(StadiumSurfaceNightRuntime.BOUND)
		and not StadiumSurfaceNightRuntime.boundary_allowed(_source_owner.lab)
	):
		_source_owner.notice = "The original night authority changed; the previous save was preserved."
		return false
	var saved: bool = SeasonSave.save(_source_owner.season)
	_source_owner.notice = SeasonSave.last_error
	_source_owner._show_final_notice()
	return saved


static func _source_private_progression_terms(_unused_source_owner: SeasonApp, selected_tier: \
	int) -> String:
	var terms: String = "Standard/Base (Working). Away quota: 2 Backyard, 2 Expanded, 1 Club. "
	if selected_tier == 1:
		terms = (
			"Standard d1 (Working). Away quota: 2 Backyard, 1 Expanded, 2 Club. "
			+ "Shared human/AI rerolls: +1 Cash when payable; free remains 0. "
			+ "Finish awards: floor(Base x 1.05), or 36/68/99/189 Club Bucks; "
			+ "regular-record bonus unchanged, +25 for the first d1 title. "
		)
	elif selected_tier == 2:
		terms = (
			"Standard d2 (Working). Away quota: 1 Backyard, 1 Expanded, 2 Club, 1 Mogul. "
			+ "Opponent drafts draw up to two eligible cards and prefer Pitching, Fielding, "
			+ "Power, then Contact by round; player ID breaks ties. "
			+ "Shared human/AI rerolls: +1 Cash when payable; free remains 0. "
			+ "Finish awards: floor(Base x 1.10), or 38/71/104/198 Club Bucks; "
			+ "regular-record bonus unchanged, +25 for the first d2 title. "
		)
	elif selected_tier == 3:
		terms = (
			"Standard d3 (Working). Away quota: 1 Backyard, 0 Expanded, 2 Club, 2 Mogul. "
			+ "Inherited d2 fitting drafts and shared human/AI +1 Cash paid rerolls; free remains 0. "
			+ "Marked sponsor offers return 0 Cash on cancellation or replacement; "
			+ "voluntary removal remains available. Unmarked copies keep ordinary resale. "
			+ "Finish awards: floor(Base x 1.15), or 40/74/109/207 Club Bucks; "
			+ "regular-record bonus unchanged, +25 for the first d3 title. "
		)
	elif selected_tier == 4:
		terms = (
			"Standard d4 (Working). Away quota: 1 Backyard, 0 Expanded, 2 Club, 2 Mogul. "
			+ "Inherited d2 fitting drafts, +1 Cash paid rerolls, and D3 nonrefundable copies. "
			+ "Marked short-term sponsors cover the next two completed games of their own club, "
			+ "including final-game settlement, then expire for 0 Cash. Early removal returns half paid. "
			+ "Remaining games are shown on owned copies; earned player growth stays. "
			+ "Finish awards: floor(Base x 1.20), or 42/78/114/216 Club Bucks; "
			+ "regular-record bonus unchanged, +25 for the first d4 title. "
		)
	return (
		terms
		+ (
			"Neutral final: Grandstand Gardens III, 19:10, Clear."
			if selected_tier == 4
			else (
				"Neutral final: Grandstand Gardens II, 19:10, Clear."
				if selected_tier >= 2
				else "Neutral final: Grandstand Gardens I, 19:10, Clear."
			)
		)
	)


static func _source_public_commit_inventory(_source_owner: SeasonApp, command: Dictionary) -> bool:
	if not WorkingPitchDynastySave.public_playable(_source_owner.season):
		_source_owner.notice = "Recover the exact saved Dynasty owner before playing or changing this roster."
		return false
	if (
		_source_owner.lab != null
		or _source_owner.season == null
		or _source_owner.season.build == null
		or command.get("op") != "inventory_sell"
		or not SeasonInventoryRules.menu_available(_source_owner.season.build)
	):
		return false
	var previous: SeasonBuild = _source_owner.season.build
	var next: SeasonBuild = previous.candidate(command)
	if next == null:
		_source_owner.notice = previous.last_error
		return false
	_source_owner.season.build = next
	if not _source_owner._checkpoint():
		_source_owner.season.build = previous
		return false
	return true


static func _source_public_commit_shop(_source_owner: SeasonApp, command: Dictionary) -> bool:
	if not WorkingPitchDynastySave.public_playable(_source_owner.season):
		_source_owner.notice = "Recover the exact saved Dynasty owner before playing or changing this roster."
		return false
	if _source_owner.lab != null or _source_owner.season == null or not \
		_source_owner.season.shop_available():
		return false
	if command.get("op") not in SeasonBuild.SHOP_OPS:
		return false
	var previous: SeasonBuild = _source_owner.season.build
	var previous_roster: Array = _source_owner.season.teams[0].roster.duplicate()
	var next: SeasonBuild = previous.candidate(command)
	if next == null:
		_source_owner.notice = previous.last_error
		return false
	_source_owner.season.adopt_build(next)
	if not _source_owner._checkpoint():
		_source_owner.season.build = previous
		_source_owner.season.teams[0].roster = previous_roster
		return false
	return true


static func _source_public_open_shop(_source_owner: SeasonApp) -> void:
	if not WorkingPitchDynastySave.public_playable(_source_owner.season):
		_source_owner.notice = "Recover the exact saved Dynasty owner before playing or changing this roster."
		return
	if SeasonSave.dynasty_owner_bound() and (_source_owner.dynasty_owner == null or not \
		_source_owner.dynasty_owner.playable()):
		_source_owner.notice = "This season has ended. Start the next season to continue."
		return
	if _source_owner.lab != null or _source_owner.season == null or not \
		_source_owner.season.shop_available():
		return
	if not _source_owner.season.build.view().shop.open:
		var rev: int = _source_owner.season.build.revision()
		if not _source_owner.commit_shop({"id": "shop:%d" % rev, "rev": rev, "op": "open"}):
			_source_owner.menu.show_hub()
			return
	for child in _source_owner.menu.get_children():
		if child is SeasonShopWindow:
			child.popup_centered()
			return
	var window: SeasonShopWindow = SeasonShopWindow.new()
	window.app = _source_owner
	_source_owner.menu.add_child(window)
	window.popup_centered()


static func _source_private_confirm(_source_owner: SeasonApp, message: String, action: Callable) \
	-> void:
	_source_owner._ensure_confirmation_content()
	for child: Node in _source_owner._confirmation_body.get_children():
		if child != _source_owner._confirmation_scroll:
			_source_owner._confirmation_body.remove_child(child)
			child.queue_free()
	_source_owner._confirmed_action = action
	_source_owner._dialog.dialog_text = message
	_source_owner._refresh_confirmation()


static func _source_private_ensure_confirmation_content(_source_owner: SeasonApp) -> void:
	if is_instance_valid(_source_owner._confirmation_body):
		return
	_source_owner._confirmation_body = VBoxContainer.new()
	_source_owner._dialog.add_child(_source_owner._confirmation_body)
	_source_owner._confirmation_scroll = ScrollContainer.new()
	_source_owner._confirmation_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_source_owner._confirmation_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_source_owner._confirmation_scroll.focus_mode = Control.FOCUS_ALL
	_source_owner._confirmation_body.add_child(_source_owner._confirmation_scroll)
	_source_owner._confirmation_text = Label.new()
	_source_owner._confirmation_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_source_owner._confirmation_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_source_owner._confirmation_scroll.add_child(_source_owner._confirmation_text)
	_source_owner._dialog.get_parent().get_viewport().size_changed.connect( \
		_source_owner._fit_confirmation)


static func _source_private_refresh_confirmation(_source_owner: SeasonApp) -> void:
	# Keep the original disclosure property intact for callers, but put its visible
	# copy in a bounded scroller. Long terms must never displace Cancel/OK offscreen.
	_source_owner._dialog.get_label().max_lines_visible = 1
	_source_owner._dialog.get_label().hide()
	_source_owner._confirmation_text.text = _source_owner._dialog.dialog_text
	_source_owner._confirmation_scroll.scroll_vertical = 0
	_source_owner._fit_confirmation(true)
