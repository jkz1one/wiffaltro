class_name SeasonApp
extends Node

const SOURCE_OPERATIONS_1: GDScript = preload(
	"res://src/presentation/season/season_app_operations_1.gd"
)

const SOURCE_OPERATIONS_2: GDScript = preload(
	"res://src/presentation/season/season_app_operations_2.gd"
)

const SOURCE_OPERATIONS_3: GDScript = preload(
	"res://src/presentation/season/season_app_operations_3.gd"
)

const SOURCE_OPERATIONS_4: GDScript = preload(
	"res://src/presentation/season/season_app_operations_4.gd"
)

const LOADING_FEEDBACK = preload("res://src/presentation/season/season_loading_feedback.gd")

const PHYSICAL_ENTRY = preload("res://src/gameplay/simulation/physical_job_entry.gd")

const AC02_PASSIVE_16 = preload("res://src/diagnostics/ac02_passive_attribution.gd")

const DYNASTY_OWNER_CONTROLLER = preload(
	"res://src/presentation/season/dynasty_owner_controller.gd"
)
const AC02_STARTUP = preload(
	"res://src/presentation/stadium/stadium_npc_ac02_startup_preparing_v1.gd"
)

const MAIN_CAREER = preload("res://src/presentation/season/main_career_controller.gd")
var _main_career: RefCounted

var dynasty_owner: RefCounted

var season: SeasonState
var menu: SeasonMenu
var sales: SeasonMatchSales = SeasonMatchSales.new()
var loadout: SeasonLoadoutUI
var lab: PitchBatLab
var notice: String = ""
var film_game: int = -1
var film_recipe: String = ""
var copy_game: int = -1
var copy_receipt: String = "?"
var insurance_game: int = -1
var insurance_receipt: String = ""
var round_ui: SeasonRoundUI
var _season_game: bool = false
var _fixture_id: int = -1
var _confirmation_body: VBoxContainer
var _confirmation_scroll: ScrollContainer
var _confirmation_text: Label
var _dialog: ConfirmationDialog
var _confirmed_action: Callable
var _continue: Button
var _busy: bool = false
var _loading_boot: bool = false
var _loading_play: bool = false
var _loading_generation: int = 0
var _result_recorded: bool = false
var _result_saved: bool = false
# Process-local failed draft checkpoint; never serialized as save authority.
var _unsaved_draft: SeasonState
var _draft_quit_tree: SceneTree
var _draft_auto_accept_quit: bool = true
# Process-local retry evidence only. Never written to a fixture, report or save.
var _ac02_settlement_ticket: Dictionary = {}


func _make_dynasty_owner_controller() -> RefCounted:
	if _main_career != null:
		return _main_career.make_owner_controller()
	return SOURCE_OPERATIONS_1._source_private_make_dynasty_owner_controller(self)


func _ready() -> void:
	# Keep exact SeasonApp ownership. Candidate subclasses retain their separate adapters.
	if get_script() == SeasonApp and PHYSICAL_ENTRY.route(OS.get_cmdline_user_args()) == PHYSICAL_ENTRY.NORMAL:
		_main_career = MAIN_CAREER.new(self)
		if not _main_career.prepare():
			return
	SOURCE_OPERATIONS_1._source_private_ready(self)


func _exit_tree() -> void:
	SOURCE_OPERATIONS_1._source_private_exit_tree(self)
	if _main_career != null:
		_main_career.release()


func _ready_with_loading_feedback() -> void:
	if _loading_boot:
		return
	_loading_boot = true
	set_process(false)
	var generation: int = _loading_generation
	var original_tree: SceneTree = get_tree()
	var original_parent: Node = get_parent()
	var overlay: CanvasLayer = LOADING_FEEDBACK.show(self, "Opening your clubhouse… Please wait")
	await RenderingServer.frame_post_draw
	var current: bool = (
		_loading_generation == generation
		and is_inside_tree()
		and not is_queued_for_deletion()
		and get_tree() == original_tree
		and get_parent() == original_parent
		and is_instance_valid(overlay)
		and overlay.get_parent() == self
	)
	if is_instance_valid(overlay):
		LOADING_FEEDBACK.remove(overlay)
	if not current:
		_loading_boot = false
		return
	var token: int = AC02_PASSIVE_16.enter("season_app._ready")
	_ac02_passive_16_private_ready()
	AC02_PASSIVE_16.leave(token)
	if not is_instance_valid(self) or is_queued_for_deletion():
		return
	_loading_boot = false
	set_process(true)


func _request_play_with_loading_feedback() -> void:
	if round_ui != null and round_ui._async_human_saving:
		return 
	# Direct/headless APIs retain the original synchronous path.
	if _loading_play or _loading_boot:
		return
	if DisplayServer.get_name() == "headless":
		play_season_game()
		return
	if (
		not is_inside_tree()
		or is_queued_for_deletion()
		or season == null
		or not is_instance_valid(menu)
		or lab != null
	):
		return
	_loading_play = true
	var generation: int = _loading_generation
	var owner_season: SeasonState = season
	var owner_menu: SeasonMenu = menu
	var owner_menu_parent: Node = menu.get_parent()
	var owner_tree: SceneTree = get_tree()
	var owner_parent: Node = get_parent()
	var owner_build: SeasonBuild = season.build
	var revision: int = owner_build.revision() if owner_build != null else -1
	var fixture: Dictionary = season.pending_fixture().duplicate(true)
	var page: String = menu.page
	var was_visible: bool = menu.visible
	var overlay: CanvasLayer = LOADING_FEEDBACK.show(self, "Preparing your game… Please wait")
	menu.hide()
	await RenderingServer.frame_post_draw
	var current: bool = (
		_loading_generation == generation
		and is_inside_tree()
		and not is_queued_for_deletion()
		and get_tree() == owner_tree
		and get_parent() == owner_parent
		and is_instance_valid(owner_season)
		and season == owner_season
		and is_instance_valid(owner_menu)
		and menu == owner_menu
		and owner_menu.is_inside_tree()
		and not owner_menu.is_queued_for_deletion()
		and owner_menu.get_parent() == owner_menu_parent
		and owner_menu.page == page
		and lab == null
		and season.build == owner_build
		and (
			owner_build == null
			or (is_instance_valid(owner_build) and owner_build.revision() == revision)
		)
		and ClubCareer.same(fixture, season.pending_fixture())
		and is_instance_valid(overlay)
		and overlay.get_parent() == self
	)
	if is_instance_valid(overlay):
		LOADING_FEEDBACK.remove(overlay)
	if (
		was_visible
		and _loading_generation == generation
		and is_inside_tree()
		and not is_queued_for_deletion()
		and get_tree() == owner_tree
		and get_parent() == owner_parent
		and is_instance_valid(owner_menu)
		and menu == owner_menu
		and owner_menu.is_inside_tree()
		and not owner_menu.is_queued_for_deletion()
		and owner_menu.get_parent() == owner_menu_parent
		and owner_menu.page == page
		and is_instance_valid(owner_season)
		and season == owner_season
		and lab == null
	):
		owner_menu.show()
	if current:
		# No yield inside checkpoint, match creation, or installation authority.
		play_season_game()
	if is_instance_valid(self):
		_loading_play = false


func _ac02_passive_16_private_ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	dynasty_owner = _make_dynasty_owner_controller()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--closed-dynasty-owner="):
			SeasonSave.bind_dynasty_owner(argument.trim_prefix("--closed-dynasty-owner="))
	season = SeasonSave.restore()
	notice = SeasonSave.last_error
	_show_final_notice()
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 40
	add_child(canvas)
	menu = SeasonMenu.new()
	canvas.add_child(menu)
	menu.build(self)
	_dialog = ConfirmationDialog.new()
	_dialog.title = "Wiffaltro"
	_dialog.theme = ClubhouseTheme.create()
	_dialog.dialog_autowrap = true
	_dialog.confirmed.connect(func() -> void: _confirmed_action.call())
	canvas.add_child(_dialog)
	_continue = Button.new()
	_continue.text = "CONTINUE"
	_continue.theme = ClubhouseTheme.create()
	ClubhouseTheme.primary(_continue)
	_continue.position = Vector2(500, 535)
	_continue.size = Vector2(280, 48)
	_continue.pressed.connect(finish_game)
	_continue.hide()
	canvas.add_child(_continue)
	loadout = SeasonLoadoutUI.new()
	loadout.app = self
	add_child(loadout)
	round_ui = SeasonRoundUI.new()
	round_ui.app = self
	add_child(round_ui)
	if SeasonSave.dynasty_owner_bound() and season == null:
		dynasty_owner.recover()
	close_inventory_for_hub()
	menu.show_home()
	if season != null and season.physical != null and not season.physical.pending.is_empty():
		round_ui.restore_pending()


func _process(_delta: float) -> void:
	if _main_career != null and _main_career.blocked:
		return
	SOURCE_OPERATIONS_1._source_private_process(self, _delta)


func _ac02_wait_for_manual_outro() -> bool:
	return SOURCE_OPERATIONS_1._source_private_ac02_wait_for_manual_outro(self)


func ask_new_season() -> void:
	if _main_career != null and _main_career.new_season_handled():
		return
	SOURCE_OPERATIONS_1._source_public_ask_new_season(self)


# gdlint: disable=max-returns
func begin_season(
	seed_value: int = -1,
	working_progression: bool = false,
	permanent_players: bool = true,
	home_stadium: bool = true,
	complete_boundary: bool = true,
	surface_progression: bool = false,
	selected_tier: int = 0
) -> void:
	SOURCE_OPERATIONS_1._source_public_begin_season(self, seed_value, working_progression, \
		permanent_players, home_stadium, complete_boundary, surface_progression, selected_tier)


func begin_surface_night_season(seed_value: int = -1, selected_tier: int = 0) -> void:
	SOURCE_OPERATIONS_1._source_public_begin_surface_night_season(self, seed_value, selected_tier)


func begin_surface_time_season(
	profile: String = "day", seed_value: int = -1, selected_tier: int = 0
) -> void:
	SOURCE_OPERATIONS_1._source_public_begin_surface_time_season(self, profile, seed_value, \
		selected_tier)


# Explicit new-season final profile; owned home lighting keeps its ordinary branch.
func begin_gardens_time_season(profile: String = "day", seed_value: int = -1) -> void:
	SOURCE_OPERATIONS_1._source_public_begin_gardens_time_season(self, profile, seed_value)


func _begin_season(
	seed_value: int = -1,
	working_progression: bool = false,
	permanent_players: bool = true,
	home_stadium: bool = true,
	complete_boundary: bool = true,
	surface_progression: bool = false,
	selected_tier: int = 0,
	night_opt_in: bool = false
) -> void:
	SOURCE_OPERATIONS_1._source_private_begin_season(self, seed_value, working_progression, \
		permanent_players, home_stadium, complete_boundary, surface_progression, selected_tier, \
		night_opt_in)


func _begin_season_profile(
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
	SOURCE_OPERATIONS_1._source_private_begin_season_profile(self, seed_value, working_progression, \
		permanent_players, home_stadium, complete_boundary, surface_progression, selected_tier, \
		night_opt_in, starting_profile)


func _begin_season_final_profile(
	seed_value: int,
	working_progression: bool,
	permanent_players: bool,
	home_stadium: bool,
	complete_boundary: bool,
	surface_progression: bool,
	selected_tier: int,
	night_opt_in: bool,
	starting_profile: String,
	gardens_profile: String
) -> void:
	SOURCE_OPERATIONS_2._source_private_begin_season_final_profile(self, seed_value, \
		working_progression, permanent_players, home_stadium, complete_boundary, surface_progression, \
		selected_tier, night_opt_in, starting_profile, gardens_profile)


func choose_player(id: String) -> void:
	if _main_career != null and _main_career.choose_player_handled(id):
		return
	SOURCE_OPERATIONS_2._source_public_choose_player(self, id)


func show_season() -> void:
	if _main_career != null and _main_career.show_season_handled():
		return
	SOURCE_OPERATIONS_2._source_public_show_season(self)


func _retry_draft_save() -> void:
	SOURCE_OPERATIONS_2._source_private_retry_draft_save(self)


func _prepare_draft_exit() -> bool:
	if round_ui != null and round_ui._async_human_saving:
		return false
	return SOURCE_OPERATIONS_2._source_private_prepare_draft_exit(self)


func _request_quit() -> void:
	if round_ui != null and round_ui._async_human_saving:
		return 
	SOURCE_OPERATIONS_2._source_private_request_quit(self)


func _notification(what: int) -> void:
	SOURCE_OPERATIONS_2._source_private_notification(self, what)


func _enter_tree() -> void:
	SOURCE_OPERATIONS_2._source_private_enter_tree(self)


func _guard_draft_quit() -> void:
	SOURCE_OPERATIONS_2._source_private_guard_draft_quit(self)


func _restore_draft_quit_policy() -> void:
	SOURCE_OPERATIONS_2._source_private_restore_draft_quit_policy(self)


func play_season_game() -> void:
	if load("res://src/gameplay/season/async_save/async_save_ui.gd").locked or load("res://src/gameplay/season/async_save/async_save_coordinator.gd").leased:
		return 
	SOURCE_OPERATIONS_2._source_public_play_season_game(self)


func _ac02_passive_16_play_season_game() -> void:
	SOURCE_OPERATIONS_2._source_private_ac02_passive_16_play_season_game(self)


func play_exhibition() -> void:
	if load("res://src/gameplay/season/async_save/async_save_ui.gd").locked or load("res://src/gameplay/season/async_save/async_save_coordinator.gd").leased:
		return 
	SOURCE_OPERATIONS_2._source_public_play_exhibition(self)




func _open_match(
	state: MatchState,
	player_home: bool,
	season_game: bool,
	field_id: StringName = PitchBatLab.FIELD_ID
) -> void:
	SOURCE_OPERATIONS_2._source_private_open_match(self, state, player_home, season_game, field_id)


func _ac02_passive_16_private_open_match(
	state: MatchState,
	player_home: bool,
	season_game: bool,
	field_id: StringName = PitchBatLab.FIELD_ID
) -> void:
	SOURCE_OPERATIONS_3._source_private_ac02_passive_16_private_open_match(self, state, player_home, \
		season_game, field_id)


func _hillside_public_install_finished(
	success: bool,
	captured: PitchBatLab,
	state: MatchState,
	owner_season: SeasonState,
	fixture: Dictionary
) -> void:
	SOURCE_OPERATIONS_3._source_private_hillside_public_install_finished(self, success, captured, \
		state, owner_season, fixture)


func _verify_match_install(state: MatchState, npc_away: bool) -> void:
	SOURCE_OPERATIONS_3._source_private_verify_match_install(self, state, npc_away)


func _ac02_passive_16_private_verify_match_install(state: MatchState, npc_away: bool) -> void:
	SOURCE_OPERATIONS_3._source_private_ac02_passive_16_private_verify_match_install(self, state, \
		npc_away)


func _mounted_match_ledger(
	state: MatchState, player_home: bool, season_game: bool
) -> ClubAssetLedger:
	return SOURCE_OPERATIONS_3._source_private_mounted_match_ledger(self, state, player_home, \
		season_game)


func finish_game() -> void:
	if round_ui != null and round_ui._async_human_saving:
		return 
	SOURCE_OPERATIONS_3._source_public_finish_game(self)


func _commit_result() -> bool:
	if round_ui != null and round_ui._async_human_saving:
		return false
	# Scheduling only: keep the captured HR body and owner alive through its
	# presentation. The existing result, validation and persistence paths follow.
	if (
		lab != null
		and lab._match_state != null
		and lab._match_state.phase == MatchState.Phase.GAME_END
		and lab._home_run.presentation_pending(lab)
	):
		return false
	if not _season_game or _result_saved:
		return true
	# An accepted completed game has already revoked its live issue. Retry only
	# its captured evidence/persistence, never use a revoked token for another capture.
	if not _ac02_settlement_ticket.is_empty():
		return _retry_ac02_settlement()
	if (
		lab == null
		or lab._match_state.phase != MatchState.Phase.GAME_END
		or not _played_field_matches()
	):
		return false
	var qc_lab: PitchBatLab = lab
	var qc_state: MatchState = lab._match_state
	var qc_season: SeasonState = season
	var qc_fixture: int = _fixture_id
	var qc_season_game: bool = _season_game
	if not PitchBatLabFeelSupport.flush_pending_manual_records(qc_lab):
		return false
	if (
		not is_instance_valid(qc_lab)
		or lab != qc_lab
		or qc_lab._match_state != qc_state
		or season != qc_season
		or _fixture_id != qc_fixture
		or _season_game != qc_season_game
		or qc_state.phase != MatchState.Phase.GAME_END
	):
		return false
	if season.physical != null and _result_recorded:
		round_ui.resume()
		return false
	if not _result_recorded:
		var state: MatchState = lab._match_state
		var human: Array = [
			_fixture_id,
			state.away_team.runs,
			state.home_team.runs,
			state.performance.snapshot(state),
			state.gear_usage.first_pitch,
			(state.home_team if lab._player_home else state.away_team).tactics.consumed,
			(
				state.cold.evidence(state.home_team if lab._player_home else state.away_team)
				if season.build != null and season.build._freezer_start != null
				else {}
			),
			(
				state.sides.evidence(state.home_team if lab._player_home else state.away_team)
				if season.build != null and season.build._sides_start != null
				else []
			),
			(
				state.clean_outs.evidence(state.home_team if lab._player_home else state.away_team)
				if season.build != null and season.build._jump_start != null
				else []
			),
			(
				state.sure_shot.evidence(state.home_team if lab._player_home else state.away_team)
				if (
					season.build != null
					and (
						season.build._sure_start != null
						or LeagueRules.doubleheader(season.league_rules)
					)
				)
				else {}
			),
			(state.home_team if lab._player_home else state.away_team).field_supply.evidence(),
			state.frozen_contacts.filter(
				func(row: Dictionary) -> bool: return season.teams[0].roster.has(row.player)
			)
		]
		if SeasonPitchProof.enabled(season.build):
			var proof: Dictionary = state.sure_shot.evidence_current(
				state.home_team if lab._player_home else state.away_team)
			if not SeasonPitchProof.install_human(season.build, human, proof):
				return false
		if season.opponents != null and season.opponents._format >= 9:
			human.append(
				SeasonOpponentTactics.evidence(
					state, state.away_team if lab._player_home else state.home_team
				)
			)
		if LeagueRules.doubleheader(season.league_rules):
			human.append(SeasonDoubleheader.capture(state))
		if (
			season.build != null
			and not SeasonInventoryRules.paused_sales(season.build, _fixture_id).is_empty()
		):
			human.append(
				SeasonInventoryRules.capture_final(
					season.build,
					_fixture_id,
					state,
					state.home_team if lab._player_home else state.away_team
				)
			)
		if not season.home_property.is_empty() or not season.npc_venues.is_empty():
			human.append([])  # Reserved historical replay-only tactical argument.
			human.append(StadiumLayoutSnapshot.key(state.stadium))
		if StadiumSurfaceNightHumanEvidence.expected(season, season.pending_fixture()):
			var evidence: Dictionary = StadiumSurfaceNightHumanEvidence.capture(lab, season)
			if evidence.is_empty():
				notice = "The completed night game could not be validated. Your season is unchanged."
				return false
			human.append(null)
			human.append(null)
			human.append(evidence)
		if StadiumPoolOwnedHumanEvidence.expected(season, season.pending_fixture()):
			var evidence: Dictionary = StadiumPoolOwnedHumanEvidence.capture(lab, season)
			if evidence.is_empty():
				notice = "The completed Pool game could not be validated. Your season is unchanged."
				return false
			human.append(evidence)
		if StadiumNpcYardTwoHumanEvidence.expected(season, season.pending_fixture()):
			var evidence: Dictionary = StadiumNpcYardTwoHumanEvidence.capture(lab, season)
			if evidence.is_empty():
				notice = "The completed AY-02 game could not be validated. Your season is unchanged."
				return false
			human.append(null)  # Preserve the existing owned-Pool argument position.
			human.append(evidence)
		var ac02_property: StadiumNpcPublicProperty = StadiumNpcPublicRuntime._property(lab)
		if lab._ac02_issued_owner != null:
			# All historical human evidence above is captured while the issue is active.
			# This final deep boundary revokes before the first season/reward write below.
			var captured_fixture: Dictionary = season.pending_fixture()
			if (
				not is_instance_valid(ac02_property)
				or not ac02_property.has_ac02_issue()
				or ac02_property._ac02_issue != lab._ac02_issued_owner
				or ac02_property._ac02_issue_pin != lab._ac02_issued_owner
				or not StadiumNpcAc02IssuedStateV1.before_settlement(lab)
			):
				notice = "The completed AC-02 game could not be validated. Your season is unchanged."
				return false
			_ac02_settlement_ticket = {
				"lab": lab,
				"season": season,
				"state": state,
				"property": ac02_property,
				"issue": ac02_property._ac02_issue,
				"fixture_id": _fixture_id,
				"fixture": captured_fixture.duplicate(true),
				"human": human.duplicate(true),
				"physical": season.physical
			}
		if season.physical != null:
			_result_recorded = true
			var saved: bool = round_ui.queue_human(human)
			_continue.text = "CONTINUE" if saved else "RETRY SAVE"
			_continue.tooltip_text = "" if saved else SeasonSave.last_error
			return false
		if not season.callv("record_player_result", human):
			return false
		_result_recorded = true
		if not _ac02_settlement_ticket.is_empty() and not season.player_results.is_empty():
			_ac02_settlement_ticket["result_source"] = season.player_results.back()
			_ac02_settlement_ticket["result"] = season.player_results.back().duplicate(true)
	# Retry persistence without replaying the result or paying twice.
	_result_saved = _checkpoint()
	_continue.text = "CONTINUE" if _result_saved else "RETRY SAVE"
	_continue.tooltip_text = "" if _result_saved else SeasonSave.last_error
	return _result_saved


# gdlint: enable=max-returns


func _ac02_save_settlement() -> bool:
	return SOURCE_OPERATIONS_3._source_private_ac02_save_settlement(self)


func _ac02_settlement_owner_intact() -> bool:
	return SOURCE_OPERATIONS_3._source_private_ac02_settlement_owner_intact(self)


func _ac02_queue_authorized(human: Array) -> bool:
	return SOURCE_OPERATIONS_3._source_private_ac02_queue_authorized(self, human)


func _ac02_resume_authorized() -> bool:
	return SOURCE_OPERATIONS_3._source_private_ac02_resume_authorized(self)


func _retry_ac02_settlement() -> bool:
	return SOURCE_OPERATIONS_3._source_private_retry_ac02_settlement(self)


func _played_field_matches() -> bool:
	return SOURCE_OPERATIONS_3._source_private_played_field_matches(self)


func _played_field_matches_remaining_checks(expected: Dictionary, key: String) -> bool:
	return SOURCE_OPERATIONS_3._source_private_played_field_matches_remaining_checks(self, expected, \
		key)


func ask_leave_game() -> void:
	if round_ui != null and round_ui._async_human_saving:
		return 
	SOURCE_OPERATIONS_3._source_public_ask_leave_game(self)


func leave_game() -> void:
	if round_ui != null and round_ui._async_human_saving:
		return 
	SOURCE_OPERATIONS_3._source_public_leave_game(self)


func _ac02_settled_manual_qc_close_allowed() -> bool:
	return SOURCE_OPERATIONS_3._source_private_ac02_settled_manual_qc_close_allowed(self)


func _close_match(close_inventory: bool = false) -> bool:
	if round_ui != null and round_ui._async_human_saving:
		return false
	return SOURCE_OPERATIONS_3._source_private_close_match(self, close_inventory)


func swap_lineup(first: int, second: int) -> void:
	if load("res://src/gameplay/season/async_save/async_save_ui.gd").locked or load("res://src/gameplay/season/async_save/async_save_coordinator.gd").leased:
		return 
	SOURCE_OPERATIONS_3._source_public_swap_lineup(self, first, second)


func select_starter(index: int) -> void:
	if load("res://src/gameplay/season/async_save/async_save_ui.gd").locked or load("res://src/gameplay/season/async_save/async_save_coordinator.gd").leased:
		return 
	SOURCE_OPERATIONS_3._source_public_select_starter(self, index)


func select_fielder(index: int) -> void:
	if load("res://src/gameplay/season/async_save/async_save_ui.gd").locked or load("res://src/gameplay/season/async_save/async_save_coordinator.gd").leased:
		return 
	SOURCE_OPERATIONS_3._source_public_select_fielder(self, index)


func _checkpoint() -> bool:
	return SOURCE_OPERATIONS_3._source_private_checkpoint(self)


func _show_final_notice() -> void:
	if not notice.is_empty() or season == null or season.phase != SeasonState.Phase.DRAFT:
		return
	var selection: String = str(season.final_venue.get("selection", ""))
	if (
		selection
		not in [
			SeasonFinalVenue.STANDARD_BASE_SELECTION,
			SeasonFinalVenue.STANDARD_D1_SELECTION,
			SeasonFinalVenue.STANDARD_D2_SELECTION,
			SeasonFinalVenue.STANDARD_D3_SELECTION,
			SeasonFinalVenue.STANDARD_D4_SELECTION
		]
	):
		return
	var tier: int = (
		4
		if selection == SeasonFinalVenue.STANDARD_D4_SELECTION
		else (
			3
			if selection == SeasonFinalVenue.STANDARD_D3_SELECTION
			else (
				2
				if selection == SeasonFinalVenue.STANDARD_D2_SELECTION
				else (1 if selection == SeasonFinalVenue.STANDARD_D1_SELECTION else 0)
			)
		)
	)
	var parks: Array[String] = []
	for owner: String in SeasonVenues.OWNERS:
		var assigned: Dictionary = season.npc_venues.get("assignments", {}).get(owner, {})
		parks.append(str(assigned.get("manifest", {}).get("id", "Unavailable")))
	notice = _progression_terms(tier) + " Frozen away parks: " + ", ".join(parks) + "."


func ask_progression_season(selected_tier: int = 0) -> void:
	if _main_career != null and _main_career.standard_handled():
		return
	if (
		selected_tier not in [0, 1, 2, 3, 4]
		or (selected_tier == 4 and not ClubCareer.D4_PUBLIC_ACTIVATION_ENABLED)
	):
		notice = "That Standard tier is unavailable. Your season and club history are unchanged."
		menu.show_home()
		return
	_confirm(
		(
			"Start a Working Standard season? An unfinished season is abandoned without payout. "
			+ "Club Bucks and history remain. "
			+ _progression_terms(selected_tier)
			+ " Other clubs play physical games and buy supported items with their own rewards."
		),
		begin_season.bind(-1, true, true, true, true, true, selected_tier)
	)
	if StadiumSurfaceNightSnapshot.PUBLIC_READY:
		var towers: bool = (
			season != null
			and StadiumFloodlightOwnedItems.is_family(season.home_property.get("layout", {}))
		)
		var kit: bool = (
			season != null
			and StadiumLightingKitNightCandidate.is_candidate_layout(
				season.home_property.get("layout", {})
			)
		)
		_dialog.dialog_text += (" This choice applies to supported owned home games. Day keeps " + \
			"ordinary daylight when the owned profile is unavailable; Sunset and " + \
			"Night require the qualified paid four-pole home layout. Away and " + \
			"final parks use their own venue profiles.")
		if towers:
			_dialog.dialog_text = _dialog.dialog_text.replace(
				"qualified paid four-pole home layout",
				"qualified complete owned floodlight preset and measured layout"
			)
		if kit:
			_dialog.dialog_text = (
				_dialog
				. dialog_text
				. replace(
					"Sunset and Night require the qualified paid four-pole home layout",
					(
						"Fixed Night requires this exact kit pattern and rough-dirt composition to have "
						+ "reviewed evidence; Sunset is unavailable"
					)
				)
			)
		var profile_choice: OptionButton = OptionButton.new()
		profile_choice.add_item("Day · 13:10")
		profile_choice.add_item(
			(
				"Sunset · 16:10 (qualified floodlight preset required)"
				if towers
				else "Sunset · 16:10 (paid four-pole field required)"
			)
		)
		profile_choice.add_item(
			(
				"Night · fixed (reviewed kit pattern required)"
				if kit
				else (
					"Night · 19:10 (qualified floodlight preset required)"
					if towers
					else "Night · 19:10 (paid four-pole field required)"
				)
			)
		)
		if kit:
			profile_choice.set_item_disabled(1, true)
		profile_choice.select(0)
		profile_choice.fit_to_longest_item = false
		profile_choice.clip_text = true
		_confirmation_body.add_child(profile_choice)
		_confirmed_action = func() -> void:
			var profiles: Array[String] = ["day", "sunset", "night"]
			if is_instance_valid(profile_choice) and profile_choice.selected in [0, 1, 2]:
				begin_surface_time_season(profiles[profile_choice.selected], -1, selected_tier)
		var profile_ref: WeakRef = weakref(profile_choice)
		_dialog.visibility_changed.connect(
			func() -> void:
				var previous: OptionButton = profile_ref.get_ref()
				if not _dialog.visible and is_instance_valid(previous):
					previous.queue_free(),
			CONNECT_ONE_SHOT
		)
		_refresh_confirmation()


func _progression_terms(selected_tier: int) -> String:
	return SOURCE_OPERATIONS_3._source_private_progression_terms(self, selected_tier)


func commit_inventory(command: Dictionary) -> bool:
	if load("res://src/gameplay/season/async_save/async_save_ui.gd").locked or load("res://src/gameplay/season/async_save/async_save_coordinator.gd").leased:
		return false
	return SOURCE_OPERATIONS_3._source_public_commit_inventory(self, command)


func commit_shop(command: Dictionary) -> bool:
	if load("res://src/gameplay/season/async_save/async_save_ui.gd").locked or load("res://src/gameplay/season/async_save/async_save_coordinator.gd").leased:
		return false
	return SOURCE_OPERATIONS_3._source_public_commit_shop(self, command)


func open_shop() -> void:
	if load("res://src/gameplay/season/async_save/async_save_ui.gd").locked or load("res://src/gameplay/season/async_save/async_save_coordinator.gd").leased:
		return 
	SOURCE_OPERATIONS_3._source_public_open_shop(self)


func _confirm(message: String, action: Callable) -> void:
	SOURCE_OPERATIONS_3._source_private_confirm(self, message, action)


func _ensure_confirmation_content() -> void:
	SOURCE_OPERATIONS_3._source_private_ensure_confirmation_content(self)


func _refresh_confirmation() -> void:
	SOURCE_OPERATIONS_3._source_private_refresh_confirmation(self)


func _fit_confirmation(open: bool = false) -> void:
	SOURCE_OPERATIONS_4._source_private_fit_confirmation(self, open)


func close_inventory_for_hub() -> bool:
	return SOURCE_OPERATIONS_4._source_public_close_inventory_for_hub(self)


func _close_inventory_for_hub_remaining_checks(fixture: Dictionary) -> bool:
	return SOURCE_OPERATIONS_4._source_private_close_inventory_for_hub_remaining_checks(self, fixture)


# Presentation hooks keep the normal owner composed, never subclass-authorized.
func _get(property: StringName) -> Variant:
	if _main_career == null:
		return null
	match property:
		&"league_career": return _main_career.league_career
		&"dynasty_enrollment": return _main_career.dynasty_enrollment
		&"_player_asset_pending": return _main_career.player_asset_pending
		&"_main_startup_blocked": return _main_career.blocked
	return null


func _set(property: StringName, value: Variant) -> bool:
	if property == &"_player_asset_pending" and _main_career != null and value is Dictionary:
		_main_career.player_asset_pending = value
		return true
	return false


func _uses_main_leagues() -> bool:
	return _main_career != null


func _league_career_home(parent: Node) -> void:
	if SeasonSave.path in [WorkingPitchSeasonUI.SAVE_PATH, ExpandedSeasonUI.SAVE_PATH]:
		return
	if _main_career != null:
		_main_career.home(parent)
	elif SeasonSave.dynasty_owner_bound() and dynasty_owner != null:
		dynasty_owner.add_controls(menu, parent)
	else:
		menu._button(parent, "NEW SEASON", ask_new_season)
		menu._button(parent, "NEW WORKING SEASON", ask_progression_season)


func _show_main_leagues() -> void:
	if _main_career != null:
		_main_career.show_leagues()


func _dynasty_enrollment_enabled() -> bool:
	return _main_career != null and MAIN_CAREER.MainDynasty.enrollment_enabled(season)


func _prepare_dynasty() -> void:
	if _main_career != null:
		_main_career.prepare_dynasty()


func _shared_career_badge(parent: Node) -> bool:
	return _main_career != null and _main_career.badge(parent)


func _shared_career_settlement() -> bool:
	return _main_career != null and _main_career.settlement()


func _dynasty_career_summary() -> bool:
	return _main_career != null and _main_career.summary()


func _show_league_career_record(page: int = 0) -> void:
	if _main_career != null:
		_main_career.record(page)
	else:
		ClubCareerUI.show_ordinary(menu, page)


func _candidate_players_enabled() -> bool:
	return _main_career.players_enabled() if _main_career != null else season != null and season.career != null


func _player_collection_view() -> Dictionary:
	if _main_career != null:
		return _main_career.player_view()
	return ClubPlayersUI.career_view(season.career) if season != null else {}


func _player_collection_transact(request: Dictionary) -> Dictionary:
	return _main_career.player_transact(request) if _main_career != null else ClubPlayers.transact(season, request)
