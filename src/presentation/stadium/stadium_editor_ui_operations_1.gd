extends RefCounted
## Stateless operations for the original StadiumEditorUI script.


static func _confirmation(
	ledger: ClubAssetLedger, draft: Dictionary, movement: Dictionary
) -> String:
	var active: Dictionary = ledger.view().stadium_active
	if StadiumPoolWorkshopUI.pool_intent(active) or StadiumPoolWorkshopUI.pool_intent(draft):
		if ClubCareer.same(active, draft):
			return ""
		var pool_message: String = (
			"Apply this Pool layout? "
			if (StadiumPoolWorkshopUI.pool_intent(draft))
			else "Apply this layout and store the Pool? "
		)
		pool_message += "Moving and storage cost no Club Bucks."
		if not movement.displaced.is_empty():
			pool_message += (
				" Stored: "
				+ StadiumEditorUI.stored_summary(
					movement.displaced,
					ledger.construction(),
					ledger.wall_pieces(),
					ledger.scoreboards()
				)
				+ "."
			)
		return pool_message + " Current frozen games keep their original field."
	if (
		not SeasonOwnership._whole(active.get("version"), 13, 15)
		and not SeasonOwnership._whole(draft.get("version"), 13, 15)
	):
		return StadiumWallItemsUI.confirmation(
			active, draft, ledger.construction(), ledger.view().land
		)
	if ClubCareer.same(active, draft):
		return ""
	var next: Dictionary = movement.placement
	var message: String = (
		("Apply this complete stadium layout? " + "%d panels and %d scoreboards installed. ")
		% [next.wall_panels.size() + next.advanced_panels.size(), next.board_placements.size()]
	)
	message += (
		"%d displaced copies go to storage. No Club Bucks charge." % movement.displaced.size()
	)
	if not movement.displaced.is_empty():
		message += (
			" Stored: "
			+ StadiumEditorUI.stored_summary(
				movement.displaced,
				ledger.construction(),
				ledger.wall_pieces(),
				ledger.scoreboards()
			)
			+ "."
		)
	if (
		StadiumEditorUI._checked(ledger, active).get("night_qualified", false)
		and not next.get("night_qualified", false)
	):
		message += " Future home games become daylight-only."
	return message + " Current frozen games keep their original field."
