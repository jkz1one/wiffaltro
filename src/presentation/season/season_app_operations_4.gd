extends RefCounted
## Stateless operations for the original SeasonApp owner.


static func _source_private_fit_confirmation(_source_owner: SeasonApp, open: bool = false) -> void:
	if not is_instance_valid(_source_owner._dialog) or (not open and not \
		_source_owner._dialog.visible):
		return
	var available: Vector2i = \
		Vector2i(_source_owner._dialog.get_parent().get_viewport().get_visible_rect().size)
	var target: Vector2i = Vector2i(mini(680, available.x - 40), mini(520, available.y - 60))
	_source_owner._confirmation_scroll.custom_minimum_size.y = mini(170, maxi(60, target.y - 140))
	_source_owner._dialog.min_size = target
	_source_owner._dialog.popup_centered(target)


static func _source_public_close_inventory_for_hub(_source_owner: SeasonApp) -> bool:
	if (
		_source_owner.season == null
		or _source_owner.season.build == null
		or not SeasonInventoryResale.enabled(_source_owner.season.build._bank)
		or _source_owner.season.build._match_inventory.is_empty()
		or SeasonInventoryRules.closed(_source_owner.season.build)
	):
		return true
	if _source_owner.season.physical != null and not _source_owner.season.physical.pending.is_empty():
		return false
	var fixture: Dictionary = _source_owner.season.pending_fixture()
	if fixture.is_empty() or fixture.get("id") != \
		_source_owner.season.build._match_inventory.get("game"):
		return false
	return _source_owner._close_inventory_for_hub_remaining_checks(fixture)


static func _source_private_close_inventory_for_hub_remaining_checks(_source_owner: SeasonApp, \
	fixture: Dictionary) -> bool:
	if _source_owner.lab != null:
		var state: MatchState = _source_owner.lab._match_state
		if (
			not _source_owner._season_game
			or _source_owner._fixture_id != int(fixture.id)
			or state == null
			or (
				state.phase
				in [
					MatchState.Phase.GAME_END,
					MatchState.Phase.PITCH_IN_FLIGHT,
					MatchState.Phase.BALL_IN_PLAY
				]
			)
			or _source_owner.lab._release_controller == null
			or _source_owner.lab._release_controller.active
		):
			_source_owner.notice = "Finish the current play before leaving."
			return false
	var previous: SeasonBuild = _source_owner.season.build
	var command: Dictionary = {
		"id": "inventory-close:%d" % previous.revision(),
		"rev": previous.revision(),
		"op": SeasonInventoryRules.CLOSE_OP,
		"game": int(fixture.id),
		"attempt": SeasonInventoryRules.anchor(previous, int(fixture.id))
	}
	var candidate: SeasonBuild = previous.candidate(command)
	if candidate == null:
		_source_owner.notice = previous.last_error
		return false
	_source_owner.season.build = candidate
	if not _source_owner._checkpoint():
		_source_owner.season.build = previous
		return false
	return true
