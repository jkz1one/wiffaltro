extends RefCounted


## Pre-draft branch construction only. Reuse of physical evidence requires caller's exact request
## comparisons.
static func prepare(input: Dictionary, profile: String) -> Dictionary:
	if profile not in StadiumLowWallRecipes.PROFILES:
		return {"ok": false, "error": "Unknown low profile."}
	var previous: SeasonState = SeasonSave._decode(input)
	if previous == null or previous.phase != SeasonState.Phase.COMPLETE:
		return {"ok": false, "error": "Expected exact cold-valid completed funding career."}
	var paid: ClubAssetLedger = ClubPlayers.assets(previous.career)
	var stored: Dictionary = paid.view().stadium_active.duplicate(true)
	for row: Dictionary in stored.get("live_waterfalls", []).duplicate(true):
		stored = StadiumWaterfallLiveItems.store_copy(stored, row.copy)
	var draft: Dictionary = ClubConstruction.save_draft(previous, stored, paid.revision())
	if not draft.ok:
		return draft
	var applied: Dictionary = ClubConstruction.apply_draft(
		previous, stored, ClubPlayers.assets(previous.career).revision()
	)
	if not applied.ok:
		return applied
	var standard_count: int = 0
	var low_count: int = 0
	for row: Dictionary in StadiumLowWallRecipes.rows(profile, "ST-024"):
		if row.height == StadiumLowWallRecipes.STANDARD:
			standard_count += 1
		else:
			low_count += 1
	if standard_count > 0:
		var standard: Dictionary = ClubConstruction.buy_walls(
			previous, "ST-024", standard_count, ClubPlayers.assets(previous.career).revision()
		)
		if not standard.ok:
			return standard
	var low: Dictionary = ClubConstruction.buy_wall_pieces(
		previous, "ST-024-L", low_count, ClubPlayers.assets(previous.career).revision()
	)
	if not low.ok:
		return low
	paid = ClubPlayers.assets(previous.career)
	var layout: Dictionary = StadiumLowWallLayout.upgrade(
		paid.view().stadium_active, paid.surface_owned()
	)
	var suggestion: Dictionary = StadiumLowWallManifest.suggest(
		profile, "ST-024", paid.construction(), paid.wall_pieces().stock
	)
	if not suggestion.ok:
		return suggestion
	layout.low_wall = suggestion.manifest
	draft = ClubConstruction.save_draft(previous, layout, paid.revision())
	if not draft.ok:
		return draft
	applied = ClubConstruction.apply_draft(
		previous, layout, ClubPlayers.assets(previous.career).revision()
	)
	if not applied.ok:
		return applied
	return {
		"ok": true,
		"error": "",
		"completed_season": previous,
		"pre_draft_save": SeasonSave.snapshot(previous),
		"profile": profile
	}
