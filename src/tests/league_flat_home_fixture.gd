extends RefCounted
## Pure paid-journal fixture builder. Funding and achievements are explicitly synthetic.
const ADAPTERS: Dictionary = {
	12: preload("res://src/gameplay/stadium/stadium_surface_layout.gd"),
	18: preload("res://src/gameplay/stadium/stadium_flag_items.gd"),
	19: preload("res://src/gameplay/stadium/stadium_ground_props_items.gd"),
	20: preload("res://src/gameplay/stadium/stadium_straight_items.gd"),
	21: preload("res://src/gameplay/stadium/stadium_roof_items.gd"),
	22: preload("res://src/gameplay/stadium/stadium_facility_items.gd"),
	23: preload("res://src/gameplay/stadium/stadium_boundary_items.gd"),
	24: preload("res://src/gameplay/stadium/stadium_receiver_owned_items.gd"),
	25: preload("res://src/gameplay/stadium/stadium_floodlight_owned_items.gd"),
	26: preload("res://src/gameplay/stadium/stadium_landscape_owned_items.gd"),
	27: preload("res://src/gameplay/stadium/stadium_live_furnishing_items.gd"),
	28: preload("res://src/gameplay/stadium/stadium_small_yard_scenery_items.gd"),
	29: preload("res://src/gameplay/stadium/stadium_molded_seat_items.gd"),
	30: preload("res://src/gameplay/stadium/stadium_ground_box_items.gd"),
	31: preload("res://src/gameplay/stadium/stadium_practice_facility_items.gd"),
	32: preload("res://src/gameplay/stadium/stadium_treehouse_items.gd"),
	33: preload("res://src/gameplay/stadium/stadium_landmark_items.gd"),
	34: preload("res://src/gameplay/stadium/stadium_outfield_bleacher_items.gd"),
	35: preload("res://src/gameplay/stadium/stadium_rising_apple_items.gd"),
	36: preload("res://src/gameplay/stadium/stadium_wall_top_terrace_items.gd"),
	37: preload("res://src/gameplay/stadium/stadium_player_tunnel_items.gd"),
	38: preload("res://src/gameplay/stadium/stadium_mounted_display_items.gd"),
	39: preload("res://src/gameplay/stadium/stadium_string_light_items.gd"),
	40: preload("res://src/gameplay/stadium/stadium_salvage_car_items.gd"),
	41: preload("res://src/gameplay/stadium/stadium_mastery_banner_items.gd"),
	42: preload("res://src/gameplay/stadium/stadium_waterfall_items.gd"),
	43: preload("res://src/gameplay/stadium/stadium_lighting_kit_items.gd"),
	44: preload("res://src/gameplay/stadium/stadium_outfield_plaza_items.gd"),
	45: preload("res://src/gameplay/stadium/stadium_waterfall_live_items.gd")
}

static func ledger(version: int) -> ClubAssetLedger:
	var credits: Array = [2500, 2500, 2500, 2500]
	var progress: Array = [{"seasons": 1, "wins": 5}, {"seasons": 1, "wins": 5}, {"seasons": 1, "wins": 5}, {"seasons": 1, "wins": 5}]
	var ledger: ClubAssetLedger = ClubAssetLedger.new_club(8401, credits, progress) if version >= 40 else ClubAssetLedger.new(8401, credits, progress)
	if version >= 40:
		if not ledger.commit({"id": "flat-clear", "rev": ledger.revision(), "op": "stadium_salvage_clear",
			"copy": StadiumStock.SALVAGE_COPY, "price_version": 1, "through": 4}).ok:
			return null
	if version >= 29 and version <= 38:
		if not ledger.commit({"id": "flat-land", "rev": ledger.revision(), "op": "stadium_land",
			"tier": "expanded", "price_version": StadiumLand.VERSION, "through": 4, "progress_through": 4}).ok:
			return null
	var purchase: Dictionary = ledger.commit({"id": "flat-obstacle", "rev": ledger.revision(),
		"op": "stadium_buy", "item": "ST-001", "quantity": 1,
		"price_version": StadiumPurchases.VERSION, "through": 4})
	if not purchase.ok:
		print("FLAT_FIXTURE_REFUSED ", version, " purchase ", purchase)
		return null
	var layout: Dictionary = ADAPTERS[version].upgrade(ledger.view().stadium_active, ledger.surface_owned())
	layout.obstacles = [{"copy": "purchase:flat-obstacle:0", "site": "O-R1", "yaw": 0}]
	var draft: Dictionary = ledger.commit({"id": "flat-draft", "rev": ledger.revision(), "op": "stadium_draft", "layout": layout})
	if not draft.ok:
		print("FLAT_FIXTURE_REFUSED ", version, " draft ", draft)
		return null
	var applied: Dictionary = ledger.commit({"id": "flat-apply", "rev": ledger.revision(), "op": "stadium_apply", "layout": layout,
		"geometry": StadiumOwnedLayout.geometry(ledger.view().land, layout)})
	if not applied.ok:
		print("FLAT_FIXTURE_REFUSED ", version, " apply ", applied)
		return null
	return ledger
