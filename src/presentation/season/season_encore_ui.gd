class_name SeasonEncoreUI
extends RefCounted


static func reviewing(lab: PitchBatLab) -> bool:
	return lab.has_meta("encore_review")


static func request(lab: PitchBatLab, index: int) -> void:
	if reviewing(lab) or not MatchLabSupport.can_edit_pitch_plan(lab):
		return
	var state: MatchState = lab._match_state
	var team: TeamMatchState = state.defensive_team()
	if not state.can_change_defense() or not SeasonEncore.available(team, index):
		return
	var previous: int = team.pitcher_index
	var player: PlayerMatchState = team.roster[index]
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.name = "EncoreReview"
	dialog.title = "Encore Energy • Return pitcher?"
	dialog.dialog_text = (
		(
			"Return %s with %.0f%% stamina?\nSpend your one return for this "
			+ "game.\nSpent workload, pitch count and used effects stay unchanged.\nThe "
			+ "current pitcher leaves normally. No free recovery."
		)
		% [player.definition.display_name, player.stamina_percent() * 100.0]
	)
	dialog.ok_button_text = "RETURN PITCHER"
	dialog.exclusive = true
	dialog.transient = true
	dialog.theme = ClubhouseTheme.create()
	dialog.get_ok_button().custom_minimum_size.y = 44
	dialog.get_cancel_button().custom_minimum_size.y = 44
	lab.add_child(dialog)
	lab.set_meta("encore_review", dialog)
	# Suspend the lab's process/input paths without opening its pause menu or pausing the tree.
	lab._debug_paused = true
	dialog.canceled.connect(_close.bind(lab, dialog))
	dialog.confirmed.connect(
		func() -> void:
			_close(lab, dialog)
			if lab._match_state != state or team.pitcher_index != previous:
				return
			if (
				MatchLabSupport.can_edit_pitch_plan(lab)
				and SeasonEncore.return_pitcher(state, index)
			):
				lab._selected_pitch_index = 0
				lab._apply_defensive_assignment()
				lab._status_label.text = (
					"%s returns • Encore used. Stamina retained." % player.definition.display_name
				)
				lab._refresh_config()
	)
	dialog.popup_centered(Vector2i(600, 250))
	dialog.get_cancel_button().grab_focus()


static func _close(lab: PitchBatLab, dialog: ConfirmationDialog) -> void:
	if lab.get_meta("encore_review", null) != dialog:
		return
	lab.remove_meta("encore_review")
	lab._debug_paused = false
	dialog.queue_free()
