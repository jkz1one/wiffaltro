class_name SeasonApp
extends Node

var season: SeasonState
var menu: SeasonMenu
var lab: PitchBatLab
var notice: String = ""
var difficulty_choice: int = 1
var _season_game: bool = false
var _fixture_id: int = -1
var _dialog: ConfirmationDialog
var _confirmed_action: Callable
var _continue: Button
var _busy: bool = false
var _result_recorded: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	season = SeasonSave.restore()
	notice = SeasonSave.last_error
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 40
	add_child(canvas)
	menu = SeasonMenu.new()
	canvas.add_child(menu)
	menu.build(self)
	_dialog = ConfirmationDialog.new()
	_dialog.title = "Wiffaltro"
	_dialog.confirmed.connect(func() -> void: _confirmed_action.call())
	canvas.add_child(_dialog)
	_continue = Button.new()
	_continue.text = "CONTINUE"
	_continue.position = Vector2(500, 535)
	_continue.size = Vector2(280, 48)
	_continue.pressed.connect(finish_game)
	_continue.hide()
	canvas.add_child(_continue)
	menu.show_home()


func _process(_delta: float) -> void:
	if lab != null and lab._match_state.phase == MatchState.Phase.GAME_END:
		_commit_result()
	_continue.visible = (
		lab != null
		and not lab._debug_paused
		and (lab._match_presentation_director.mode == MatchPresentationDirector.Mode.OUTRO_HOLD)
	)


func ask_new_season() -> void:
	if season != null or FileAccess.file_exists(SeasonSave.path):
		_confirm("Start a new season? This replaces the saved season.", menu.show_preseason)
	else:
		menu.show_preseason()


func begin_season(seed_value: int = -1) -> void:
	var selected_seed: int = int(Time.get_unix_time_from_system()) & 0x7fffffff
	season = SeasonState.create(selected_seed if seed_value < 0 else seed_value)
	season.difficulty = difficulty_choice
	menu.draft_selection = ""
	_checkpoint()
	menu.show_draft()


func choose_player(id: String) -> void:
	if season.choose_player(id):
		menu.draft_selection = ""
		_checkpoint()
		show_season()


func show_season() -> void:
	if season == null:
		menu.show_home()
	elif season.phase == SeasonState.Phase.DRAFT:
		menu.show_draft()
	else:
		menu.show_hub()


func play_season_game() -> void:
	if lab != null or season == null or season.pending_fixture().is_empty():
		return
	# Commit lineup before starting; interruption restarts this fixture, not the season.
	if not _checkpoint():
		menu.show_hub()
		return
	var fixture: Dictionary = season.pending_fixture()
	_fixture_id = fixture["id"]
	_open_match(season.make_match(), fixture["home"] == 0, true)


func play_exhibition() -> void:
	if lab != null:
		return
	_open_match(
		MatchLabSupport.create_match(
			PitchBatLab.DEBUG_PLAYER_ID, PitchBatLab.PLAYER_TEAM_NAME, PitchBatLab.RIVAL_TEAM_NAME
		),
		false,
		false
	)


func _open_match(state: MatchState, player_home: bool, season_game: bool) -> void:
	_season_game = season_game
	_busy = false
	_result_recorded = false
	menu.hide()
	lab = PitchBatLab.new()
	lab.name = "ActiveMatch"
	lab._configured_match = state
	lab._player_home = player_home
	lab._managed_match = true
	lab.match_return_requested.connect(finish_game)
	lab.menu_exit_requested.connect(ask_leave_game)
	add_child(lab)


func finish_game() -> void:
	if _busy or lab == null or lab._match_state.phase != MatchState.Phase.GAME_END:
		return
	if lab._match_presentation_director.mode != MatchPresentationDirector.Mode.OUTRO_HOLD:
		return
	_busy = true
	var state: MatchState = lab._match_state
	if not _commit_result():
		_busy = false
		return
	var score: String = state.score_label()
	_close_match()
	menu.show_postgame(score, _season_game)


func _commit_result() -> bool:
	if not _season_game or _result_recorded:
		return true
	var state: MatchState = lab._match_state
	if not season.record_player_result(
		_fixture_id, state.away_team.runs, state.home_team.runs, state.performance.snapshot(state)
	):
		return false
	_result_recorded = true
	# Persist as soon as the score is final, even if the player exits during the outro.
	_checkpoint()
	return true


func ask_leave_game() -> void:
	if lab == null:
		return
	if lab._match_state.phase == MatchState.Phase.GAME_END:
		# Completed results must go through the result hold and single commit path.
		return
	_confirm(
		"Leave this game? The unfinished game will restart. Saved season progress stays.",
		leave_game
	)


func leave_game() -> void:
	_close_match()
	if _season_game:
		show_season()
	else:
		menu.show_home()


func _close_match() -> void:
	_continue.hide()
	if lab != null:
		PitchBatLabFeelSupport.reset_debug_pause(lab)
		remove_child(lab)
		lab.queue_free()
		lab = null
	get_tree().paused = false
	menu.show()


func swap_lineup(first: int, second: int) -> void:
	if lab != null or season == null or season.pending_fixture().is_empty():
		return
	season.swap_batters(first, second)
	_checkpoint()
	menu.refresh_lineup()


func select_starter(index: int) -> void:
	if lab != null or season == null or season.pending_fixture().is_empty():
		return
	season.select_starter(index)
	_checkpoint()
	menu.refresh_lineup()


func select_fielder(index: int) -> void:
	if lab != null or season == null or season.pending_fixture().is_empty():
		return
	if index != season.starter_index and index >= 0 and index < 4:
		season.fielder_index = index
		_checkpoint()
		menu.refresh_lineup()


func _checkpoint() -> bool:
	var saved: bool = SeasonSave.save(season)
	notice = SeasonSave.last_error
	return saved


func _confirm(message: String, action: Callable) -> void:
	_confirmed_action = action
	_dialog.dialog_text = message
	_dialog.popup_centered(Vector2i(480, 180))
