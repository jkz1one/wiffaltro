extends RefCounted
## Stateless operations for the original SeasonApp owner.


static func _source_private_make_dynasty_owner_controller(_source_owner: SeasonApp) -> RefCounted:
	return SeasonApp.DYNASTY_OWNER_CONTROLLER.new(_source_owner)


static func _source_private_ready(_source_owner: SeasonApp) -> void:
	var job_route: int = SeasonApp.PHYSICAL_ENTRY.route(OS.get_cmdline_user_args())
	if job_route != SeasonApp.PHYSICAL_ENTRY.NORMAL:
		_source_owner.set_process(false)
		_source_owner.set_process_input(false)
		_source_owner.set_process_unhandled_input(false)
		if job_route == SeasonApp.PHYSICAL_ENTRY.INVALID or DisplayServer.get_name() != "headless":
			_source_owner.get_tree().quit(1)
			return
		_source_owner.add_child(SeasonApp.PHYSICAL_ENTRY.scene_for(job_route).instantiate())
		return
	if DisplayServer.get_name() != "headless":
		_source_owner._ready_with_loading_feedback()
		return
	var ac02_token: int = SeasonApp.AC02_PASSIVE_16.enter("season_app._ready")
	_source_owner._ac02_passive_16_private_ready()
	SeasonApp.AC02_PASSIVE_16.leave(ac02_token)


static func _source_private_exit_tree(_source_owner: SeasonApp) -> void:
	_source_owner._restore_draft_quit_policy()
	# A detached/reinserted app must not resume an earlier paint continuation.
	_source_owner._loading_generation += 1


static func _source_private_process(_source_owner: SeasonApp, _delta: float) -> void:
	_source_owner.sales.apply_pending(_source_owner)
	if _source_owner.lab != null and _source_owner.lab._match_state.phase == MatchState.Phase.GAME_END:
		if (
			not _source_owner._result_recorded
			and not _source_owner.lab._home_run.presentation_pending(_source_owner.lab)
			and not _source_owner._ac02_wait_for_manual_outro()
		):
			_source_owner._commit_result()
	_source_owner._continue.visible = (
		_source_owner.lab != null
		and not _source_owner.round_ui.shade.visible
		and not _source_owner.lab._debug_paused
		and (_source_owner.lab._match_presentation_director.mode == \
			MatchPresentationDirector.Mode.OUTRO_HOLD)
	)


static func _source_private_ac02_wait_for_manual_outro(_source_owner: SeasonApp) -> bool:
	# Scheduling only: the unchanged commit path still proves settlement authority.
	# A successful F3 must not bypass the real result hold. Custom opt-out stays sticky.
	var issue: StadiumNpcAc02IssuedStateV1 = StadiumNpcAc02IssuedStateV1.current(_source_owner.lab)
	if (
		issue == null
		or issue.get_script() != StadiumNpcAc02IssuedStateV1
		or not issue._manual_qc_started
		or issue._manual_qc_opted_out
		or _source_owner.lab._automation != null
		or issue._bindings_pin.get("automation") != null
	):
		return false
	var director: MatchPresentationDirector = _source_owner.lab._match_presentation_director
	var exporter: PlayRecordExport = _source_owner.lab._record_export
	if (
		director == null
		or director.get_script() != MatchPresentationDirector
		or exporter == null
		or exporter.get_script() != PlayRecordExport
		or exporter != issue._manual_qc_exporter
		or not is_same(_source_owner.lab._play_records, issue._manual_qc_records)
		or _source_owner.lab._play_records.size() != issue._manual_qc_count
	):
		return false
	# Paused is a reason to keep waiting, never a reason to reclassify into fallback.
	return (
		issue.manual_qc_owner(_source_owner.lab)
		and (_source_owner.lab._debug_paused or director.mode != \
			MatchPresentationDirector.Mode.OUTRO_HOLD)
	)


static func _source_public_ask_new_season(_source_owner: SeasonApp) -> void:
	if SeasonSave.dynasty_owner_bound() and _source_owner.dynasty_owner != null:
		_source_owner.dynasty_owner.ask_next()
		return
	if _source_owner.season != null or FileAccess.file_exists(SeasonSave.path):
		_source_owner._confirm(
			(
				"Start a new season? An unfinished season is abandoned without Club Bucks. "
				+ "Saved club history and earned rewards remain."
			),
			_source_owner.menu.show_preseason
		)
	else:
		_source_owner.menu.show_preseason()


# gdlint: disable=max-returns
static func _source_public_begin_season(_source_owner: SeasonApp,
	seed_value: int = -1,
	working_progression: bool = false,
	permanent_players: bool = true,
	home_stadium: bool = true,
	complete_boundary: bool = true,
	surface_progression: bool = false,
	selected_tier: int = 0
) -> void:
	_source_owner._begin_season(
		seed_value,
		working_progression,
		permanent_players,
		home_stadium,
		complete_boundary,
		surface_progression,
		selected_tier,
		false
	)
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_public_begin_surface_night_season(_source_owner: SeasonApp, seed_value: int = \
	-1, selected_tier: int = 0) -> void:
	_source_owner._begin_season(seed_value, true, true, true, true, true, selected_tier, true)
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_public_begin_surface_time_season(_source_owner: SeasonApp,
	profile: String = "day", seed_value: int = -1, selected_tier: int = 0
) -> void:
	if profile not in ["day", "sunset", "night"]:
		_source_owner.notice = "That starting profile is unavailable. Your season is unchanged."
		_source_owner.menu.show_home()
		return
	_source_owner._begin_season_profile(seed_value, true, true, true, true, true, selected_tier, \
		false, profile)
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_public_begin_gardens_time_season(_source_owner: SeasonApp, profile: String = \
	"day", seed_value: int = -1) -> void:
	if profile not in ["day", "sunset", "night"]:
		_source_owner.notice = "That Gardens starting profile is unavailable. Your season is unchanged."
		_source_owner.menu.show_home()
		return
	_source_owner._begin_season_final_profile(seed_value, true, true, true, true, true, 4, false, \
		"", profile)
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_begin_season(_source_owner: SeasonApp,
	seed_value: int = -1,
	working_progression: bool = false,
	permanent_players: bool = true,
	home_stadium: bool = true,
	complete_boundary: bool = true,
	surface_progression: bool = false,
	selected_tier: int = 0,
	night_opt_in: bool = false
) -> void:
	_source_owner._begin_season_profile(
		seed_value,
		working_progression,
		permanent_players,
		home_stadium,
		complete_boundary,
		surface_progression,
		selected_tier,
		night_opt_in,
		""
	)
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_begin_season_profile(_source_owner: SeasonApp,
	seed_value: int,
	working_progression: bool,
	permanent_players: bool,
	home_stadium: bool,
	complete_boundary: bool,
	surface_progression: bool,
	selected_tier: int,
	night_opt_in: bool,
	starting_profile: String
) -> void:
	_source_owner._begin_season_final_profile(
		seed_value,
		working_progression,
		permanent_players,
		home_stadium,
		complete_boundary,
		surface_progression,
		selected_tier,
		night_opt_in,
		starting_profile,
		(
			"night"
			if (
				selected_tier == 4
				and working_progression
				and permanent_players
				and home_stadium
				and complete_boundary
				and surface_progression
			)
			else ""
		)
	)
# gdlint: enable=max-returns
