class_name StadiumEditorUI
extends RefCounted
## Owned starter staging and atomic between-season application.

const MOUNTED_STAGED_NOTICE: String = (
	"Mounted scoreboard layout is staged, " + "not available in this workshop yet."
)

const Operations1: GDScript = preload(
	"res://src/presentation/stadium/stadium_editor_ui_operations_1.gd"
)


static func show(menu: SeasonMenu, draft: Dictionary = {}, base_revision: int = -1) -> void:
	var season: SeasonState = menu.app.season
	if season == null or season.career == null:
		return
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	if ledger == null:
		return
	var view: Dictionary = ledger.view()
	var stock: StadiumStock = ledger.construction()
	if draft.is_empty():
		draft = view.stadium_draft.duplicate(true)
		base_revision = ledger.revision()
	var changed: bool = not ClubCareer.same(draft, view.stadium_draft)
	var stale: bool = base_revision != ledger.revision()
	var editable: bool = ClubConstruction.editable(season)
	if (
		StadiumPoolWorkshopUI.staged(view, draft)
		and (not StadiumPoolWorkshopUI.WORKSHOP_ENABLED or StadiumPoolWorkshopUI.pool_intent(draft))
	):
		StadiumPoolWorkshopUI.show_staged(menu, ledger, draft, base_revision, changed)
		return
	# The complete mounted workshop remains gated with its production family.
	if _mounted_staged(view, draft):
		_staged_workshop(menu, draft, base_revision, changed)
		return
	if StadiumWaterfallAnimationLayout.is_family(draft):
		StadiumWaterfallAnimationUI.show(menu, ledger, draft, base_revision)
		return
	var checked: Dictionary = _checked(ledger, draft)
	var active_same: bool = ClubCareer.same(draft, view.stadium_active)
	var ready_now: bool = (
		not season.home_property.is_empty() and ClubCareer.same(season.home_property.layout, draft)
	)
	var applied: bool = active_same and (season.phase != SeasonState.Phase.DRAFT or ready_now)
	menu._screen(
		"stadium",
		"STADIUM WORKSHOP",
		(
			"WORKING %s • %d Club Bucks • Layouts lock when drafting begins"
			% [StadiumLand.NAMES[view.land].to_upper(), view.balance]
		)
	)
	if not editable:
		SeasonPages.wrapped(
			menu._body, "Editing opens between seasons, before choosing your draft roster."
		)
	if stale:
		SeasonPages.wrapped(
			menu._body, "Club data changed. Reload the saved draft before saving again."
		)
	if not checked.ok:
		SeasonPages.wrapped(menu._body, checked.error)
		# Invalid drafts must not reach builders that require a validated layout schema.
		# Keep the held save untouched and offer an explicit route back to saved data.
		menu._button(menu._footer, "RELOAD SAVED", show.bind(menu, {}, -1))
		menu._button(menu._footer, "CLUB RECORD", _back.bind(menu, changed))
		return
	SeasonPages.wrapped(
		menu._body,
		(
			"%s • %d in draft • %d stored • %d / 4 live units • %s"
			% [
				StadiumLand.NAMES[view.land].to_upper(),
				_placed_count(checked),
				(
					checked.stored.size()
					+ checked.pieces_stored.size()
					+ checked.scoreboards_stored.size()
				),
				checked.live_units,
				StadiumLightItemsUI.status(checked)
			]
		)
	)
	StadiumLightItemsUI.warning(menu, view.stadium_active, checked, stock, view.land, ledger)
	SeasonPages.wrapped(
		menu._body,
		(
			"DRAFT PREVIEW • "
			+ (
				"Applied for next season"
				if applied and season.phase == SeasonState.Phase.COMPLETE
				else "Applied to this season" if applied else "Save and apply to use this layout"
			)
		)
	)
	if checked.ok:
		var movement: Dictionary = _movement(ledger, view.stadium_active, draft)
		if movement.ok and not movement.displaced.is_empty():
			SeasonPages.wrapped(
				menu._body,
				(
					"Applying stores: "
					+ stored_summary(
						movement.displaced, stock, ledger.wall_pieces(), ledger.scoreboards()
					)
					+ ". No charge."
				)
			)
	if (
		draft.version >= 2
		and season.phase == SeasonState.Phase.DRAFT
		and not season.home_property.has("boundary")
	):
		SeasonPages.wrapped(
			menu._body,
			(
				"This layout previews next season's complete boundary. "
				+ "This older season keeps its field; apply after it finishes."
			)
		)
	var preview: StadiumDraftPreview = StadiumDraftPreview.new()
	menu._button(menu._footer, "FIELD VIEW", preview.overview)
	menu._body.add_child(preview)
	preview.build(
		draft,
		stock,
		(
			draft.version >= 2
			or season.home_property.has("boundary")
			or (
				editable
				and (season.home_property.is_empty() or season.phase == SeasonState.Phase.COMPLETE)
			)
		),
		view.land,
		ledger.wall_pieces(),
		ledger.scoreboards(),
		ledger.surface_owned()
	)
	if is_instance_valid(preview.lighting_kit_preview):
		menu._button(
			menu._body, "DAY / LIGHTING STUDY (NOT SEASON NIGHT)", preview.toggle_environment
		)
	elif preview.night_eligible:
		menu._button(menu._body, "DAY / NIGHT PREVIEW", preview.toggle_environment)
	StadiumWaterfallAnimationUI.offer(menu, ledger, draft, base_revision, editable and not stale)
	StadiumSurfaceUI.show(menu, ledger, draft, base_revision, editable and not stale, not changed)
	StadiumFieldStylesUI.show(
		menu, ledger, draft, base_revision, editable and not stale, not changed
	)
	StadiumBaseMarkersUI.show(
		menu, ledger, draft, base_revision, editable and not stale, not changed
	)
	StadiumGroundStylesUI.show(
		menu, ledger, draft, base_revision, editable and not stale, not changed
	)
	StadiumWallItemsUI.show(
		menu,
		ledger,
		draft,
		base_revision,
		editable and not stale,
		editable and not stale and not changed
	)
	StadiumLowWallUI.show(
		menu,
		ledger,
		draft,
		base_revision,
		editable and not stale,
		editable and not stale and not changed
	)
	if StadiumScoreboardLayout.RUNTIME_READY:
		StadiumScoreboardUI.show(
			menu,
			ledger,
			draft,
			base_revision,
			editable and not stale,
			editable and not stale and not changed
		)
		for row: Dictionary in draft.get("scoreboards", []):
			var focus: Button = menu._button(
				menu._body,
				"FOCUS " + StadiumFieldLabels.item_name(row.item).to_upper(),
				preview.focus_copy.bind(row.copy)
			)
			focus.set_meta("stadium_focus", row.copy)
			focus.disabled = not preview.positions.has(row.copy)
		StadiumAdvancedWallUI.show(
			menu,
			ledger,
			draft,
			base_revision,
			editable and not stale,
			editable and not stale and not changed
		)
	StadiumLandUI.show(menu, ledger, not stale and not changed)
	_purchases(menu, ledger, editable and not stale and not changed)
	StadiumSeatingEditorUI.purchases(menu, ledger, editable and not stale and not changed)
	StadiumClubItemsUI.purchases(
		menu, ledger, editable and not stale and not changed, StadiumScoreboardLayout.RUNTIME_READY
	)
	StadiumClubItemsUI.flag_purchases(menu, ledger, editable and not stale and not changed)
	StadiumClubItemsUI.ground_props_purchases(menu, ledger, editable and not stale and not changed)
	StadiumStraightItemsUI.purchases(menu, ledger, editable and not stale and not changed)
	StadiumRoofItemsUI.purchases(menu, ledger, editable and not stale and not changed)
	StadiumFacilityItemsUI.purchases(menu, ledger, editable and not stale and not changed)
	StadiumReceiverOwnedItemsUI.purchases(menu, ledger, editable and not stale and not changed)
	StadiumLiveFurnishingItemsUI.purchases(menu, ledger, editable and not stale and not changed)
	StadiumMoldedSeatItemsUI.purchases(
		menu, ledger, draft, base_revision, editable and not stale and not changed
	)
	StadiumGroundBoxItemsUI.purchases(
		menu, ledger, draft, base_revision, editable and not stale and not changed
	)
	StadiumPracticeFacilityItemsUI.purchases(
		menu, ledger, draft, base_revision, editable and not stale and not changed
	)
	StadiumTreehouseItemsUI.purchases(
		menu, ledger, draft, base_revision, editable and not stale and not changed
	)
	StadiumLandmarkItemsUI.purchases(
		menu, ledger, draft, base_revision, editable and not stale and not changed
	)
	StadiumOutfieldBleacherItemsUI.purchases(
		menu, ledger, draft, base_revision, editable and not stale and not changed
	)
	StadiumPlayerTunnelItemsUI.purchases(
		menu, ledger, draft, base_revision, editable and not stale and not changed
	)
	StadiumMountedDisplayItemsUI.purchases(
		menu, ledger, draft, base_revision, editable and not stale and not changed
	)
	StadiumStringLightItemsUI.purchases(
		menu, ledger, draft, base_revision, editable and not stale and not changed
	)
	StadiumSalvageCarUI.purchases(
		menu, ledger, base_revision, editable and not stale and not changed
	)
	StadiumWallTopTerraceItemsUI.purchases(
		menu, ledger, draft, base_revision, editable and not stale and not changed
	)
	StadiumRisingAppleItemsUI.purchases(
		menu, ledger, draft, base_revision, editable and not stale and not changed
	)
	StadiumWaterfallItemsUI.purchases(
		menu, ledger, draft, base_revision, editable and not stale and not changed
	)
	StadiumLightingKitItemsUI.purchases(
		menu, ledger, draft, base_revision, editable and not stale and not changed
	)
	StadiumOutfieldPlazaItemsUI.purchases(
		menu, ledger, draft, base_revision, editable and not stale and not changed
	)
	StadiumLandscapeOwnedItemsUI.purchases(menu, ledger, editable and not stale and not changed)
	StadiumFloodlightOwnedItemsUI.purchases(menu, ledger, editable and not stale and not changed)
	StadiumFloodlightOwnedItemsUI.presets(
		menu, ledger, draft, base_revision, editable and not stale
	)
	StadiumBoundaryItemsUI.purchases(menu, ledger, editable and not stale and not changed)
	StadiumBoundaryItemsUI.runs(menu, ledger, draft, base_revision, editable and not stale)
	StadiumBleacherItemsUI.purchases(menu, ledger, editable and not stale and not changed)
	StadiumTargetItemsUI.purchases(menu, ledger, editable and not stale and not changed)
	StadiumNetItemsUI.purchases(menu, ledger, editable and not stale and not changed)
	StadiumLightItemsUI.purchases(menu, ledger, editable and not stale and not changed)
	StadiumPoolWorkshopUI.purchases(menu, ledger, editable and not stale and not changed)
	var copies: Array = stock.copies.keys()
	copies.sort()
	for copy: String in copies:
		var id: String = stock.copies[copy].item
		if id == "ST-006":
			StadiumPoolWorkshopUI.stored_card(menu, ledger, copy, draft, base_revision)
			continue
		if (
			StadiumWallItems.PRICES.has(id)
			or id == "ST-040"
			or (id == "ST-039" and SeasonOwnership._whole(draft.get("version"), 14, 15))
		):
			continue
		var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
		menu._label(card, StadiumFieldLabels.item_name(id), 22)
		SeasonPages.wrapped(
			card,
			(
				"OWNED • "
				+ (
					"Starter grant"
					if (stock.copies[copy].source == "starter-v1")
					else (
						"Earned championship • %s" % copy
						if stock.copies[copy].source == "championship-v1"
						else (
							"Earned Club Legend • %s" % copy
							if stock.copies[copy].source == StadiumPlaqueRewards.SOURCE
							else "Paid %d CB • %s" % [stock.copies[copy].paid, copy]
						)
					)
				)
				+ " • Moving and storage are free"
			)
		)
		if StadiumSmallYardSceneryItems.ITEMS.has(id):
			StadiumSmallYardSceneryItemsUI.card(
				menu, card, draft, copy, id, base_revision, editable and not stale
			)
			var focus: Button = menu._button(
				card, "FOCUS IN PREVIEW", preview.focus_copy.bind(copy)
			)
			focus.disabled = not preview.positions.has(copy)
			focus.set_meta("stadium_focus", copy)
			continue
		if StadiumLiveFurnishingItems.PRICES.has(id):
			StadiumLiveFurnishingItemsUI.card(
				menu, card, draft, copy, id, base_revision, editable and not stale
			)
			var focus: Button = menu._button(
				card, "FOCUS IN PREVIEW", preview.focus_copy.bind(copy)
			)
			focus.disabled = not preview.positions.has(copy)
			focus.set_meta("stadium_focus", copy)
			continue
		if StadiumLandscapeOwnedItems.PRICES.has(id):
			StadiumLandscapeOwnedItemsUI.card(
				menu, card, draft, copy, id, base_revision, editable and not stale
			)
			var focus: Button = menu._button(
				card, "FOCUS IN PREVIEW", preview.focus_copy.bind(copy)
			)
			focus.disabled = not preview.positions.has(copy)
			focus.set_meta("stadium_focus", copy)
			continue
		if StadiumFloodlightOwnedItems.PRICES.has(id):
			StadiumFloodlightOwnedItemsUI.card(
				menu, card, draft, copy, base_revision, editable and not stale
			)
			var focus: Button = menu._button(
				card, "FOCUS IN PREVIEW", preview.focus_copy.bind(copy)
			)
			focus.disabled = not preview.positions.has(copy)
			focus.set_meta("stadium_focus", copy)
			continue
		if StadiumReceiverOwnedItems.PRICES.has(id):
			StadiumReceiverOwnedItemsUI.card(
				menu, card, draft, copy, id, base_revision, editable and not stale
			)
			var focus: Button = menu._button(
				card, "FOCUS IN PREVIEW", preview.focus_copy.bind(copy)
			)
			focus.disabled = not preview.positions.has(copy)
			focus.set_meta("stadium_focus", copy)
			continue
		if StadiumBoundaryItems.PRICES.has(id):
			StadiumBoundaryItemsUI.card(
				menu, card, draft, copy, id, base_revision, editable and not stale
			)
			var focus: Button = menu._button(
				card, "FOCUS IN PREVIEW", preview.focus_copy.bind(copy)
			)
			focus.disabled = not preview.positions.has(copy)
			focus.set_meta("stadium_focus", copy)
			continue
		if StadiumFacilityItems.PRICES.has(id):
			StadiumFacilityItemsUI.card(
				menu, card, draft, copy, id, base_revision, editable and not stale
			)
			var focus: Button = menu._button(
				card, "FOCUS IN PREVIEW", preview.focus_copy.bind(copy)
			)
			focus.disabled = not preview.positions.has(copy)
			focus.set_meta("stadium_focus", copy)
			continue
		if StadiumRoofItems.PRICES.has(id):
			StadiumRoofItemsUI.card(
				menu, card, draft, copy, id, base_revision, editable and not stale
			)
			var focus: Button = menu._button(
				card, "FOCUS IN PREVIEW", preview.focus_copy.bind(copy)
			)
			focus.disabled = not preview.positions.has(copy)
			focus.set_meta("stadium_focus", copy)
			continue
		if StadiumStraightItems.HOSTS.has(id) or StadiumStraightItems.MOUNTS.has(id):
			StadiumStraightItemsUI.card(
				menu, card, draft, copy, id, base_revision, editable and not stale
			)
			var focus: Button = menu._button(
				card, "FOCUS IN PREVIEW", preview.focus_copy.bind(copy)
			)
			focus.disabled = not preview.positions.has(copy)
			focus.set_meta("stadium_focus", copy)
			continue
		if StadiumGroundPropsItems.PRICES.has(id):
			StadiumClubItemsUI.ground_props_card(
				menu, card, draft, copy, id, base_revision, editable and not stale
			)
			continue
		if id == "ST-043":
			StadiumClubItemsUI.flag_card(
				menu, card, draft, copy, base_revision, editable and not stale
			)
			var focus: Button = menu._button(
				card, "FOCUS IN PREVIEW", preview.focus_copy.bind(copy)
			)
			focus.disabled = not preview.positions.has(copy)
			focus.set_meta("stadium_focus", copy)
			continue
		if id == "ST-037":
			StadiumLightItemsUI.card(menu, card, draft, copy, base_revision, editable and not stale)
			var focus: Button = menu._button(
				card, "FOCUS IN PREVIEW", preview.focus_copy.bind(copy)
			)
			focus.disabled = not preview.positions.has(copy)
			focus.set_meta("stadium_focus", copy)
			continue
		if id == "ST-025":
			StadiumNetItemsUI.card(menu, card, draft, copy, base_revision, editable and not stale)
			var focus: Button = menu._button(
				card, "FOCUS IN PREVIEW", preview.focus_copy.bind(copy)
			)
			focus.disabled = not preview.positions.has(copy)
			focus.set_meta("stadium_focus", copy)
			continue
		if id == "ST-026":
			StadiumTargetItemsUI.card(
				menu, card, draft, copy, base_revision, editable and not stale
			)
			var focus: Button = menu._button(
				card, "FOCUS IN PREVIEW", preview.focus_copy.bind(copy)
			)
			focus.disabled = not preview.positions.has(copy)
			focus.set_meta("stadium_focus", copy)
			continue
		if StadiumPurchases.BLEACHERS.has(id):
			StadiumBleacherItemsUI.card(
				menu, card, draft, copy, id, base_revision, editable and not stale, view.land
			)
			var focus: Button = menu._button(
				card, "FOCUS IN PREVIEW", preview.focus_copy.bind(copy)
			)
			focus.disabled = not preview.positions.has(copy)
			focus.set_meta("stadium_focus", copy)
			continue
		if StadiumPurchases.DISPLAYS.has(id):
			StadiumClubItemsUI.card(
				menu, card, draft, copy, id, base_revision, editable and not stale
			)
			var focus: Button = menu._button(
				card, "FOCUS IN PREVIEW", preview.focus_copy.bind(copy)
			)
			focus.disabled = not preview.positions.has(copy)
			focus.set_meta("stadium_focus", copy)
			continue
		if id == "ST-066":
			StadiumPlaqueUI.card(card, stock.copies[copy].earned)
			continue
		if id == "ST-112" or not StadiumOutfieldPlazaItemsUI.placement(draft, copy).is_empty():
			StadiumOutfieldPlazaItemsUI.card(
				menu, card, draft, copy, base_revision, editable and not stale
			)
			continue
		if id == "ST-111":
			StadiumLightingKitItemsUI.card(
				menu, card, draft, copy, base_revision, editable and not stale
			)
			continue
		if id == "ST-046":
			StadiumWaterfallItemsUI.card(
				menu, card, draft, copy, base_revision, editable and not stale
			)
			var focus: Button = menu._button(
				card, "FOCUS IN PREVIEW", preview.focus_copy.bind(copy)
			)
			focus.disabled = not preview.positions.has(copy)
			focus.set_meta("stadium_focus", copy)
			continue
		if id == "ST-067":
			StadiumMasteryBannerItemsUI.card(
				menu, card, draft, copy, base_revision, editable and not stale
			)
			var focus: Button = menu._button(
				card, "FOCUS IN PREVIEW", preview.focus_copy.bind(copy)
			)
			focus.disabled = not preview.positions.has(copy)
			focus.set_meta("stadium_focus", copy)
			continue
		if id == "ST-005":
			StadiumSalvageCarUI.card(menu, card, draft, copy, base_revision, editable and not stale)
			var focus: Button = menu._button(
				card, "FOCUS IN PREVIEW", preview.focus_copy.bind(copy)
			)
			focus.disabled = not preview.positions.has(copy)
			focus.set_meta("stadium_focus", copy)
			continue
		if StadiumStringLightItems.PRICES.has(id):
			StadiumStringLightItemsUI.card(
				menu, card, draft, copy, base_revision, editable and not stale
			)
			var focus: Button = menu._button(
				card, "FOCUS IN PREVIEW", preview.focus_copy.bind(copy)
			)
			focus.disabled = not preview.positions.has(copy)
			focus.set_meta("stadium_focus", copy)
			continue
		if StadiumMountedDisplayItems.PRICES.has(id):
			StadiumMountedDisplayItemsUI.card(
				menu, card, draft, copy, base_revision, editable and not stale
			)
			var focus: Button = menu._button(
				card, "FOCUS IN PREVIEW", preview.focus_copy.bind(copy)
			)
			focus.disabled = not preview.positions.has(copy)
			focus.set_meta("stadium_focus", copy)
			continue
		if id == "ST-058":
			StadiumPlayerTunnelItemsUI.card(
				menu, card, draft, copy, base_revision, editable and not stale
			)
			var focus: Button = menu._button(
				card, "FOCUS IN PREVIEW", preview.focus_copy.bind(copy)
			)
			focus.disabled = not preview.positions.has(copy)
			focus.set_meta("stadium_focus", copy)
			continue
		if id == "ST-087":
			StadiumWallTopTerraceItemsUI.card(
				menu, card, draft, copy, base_revision, editable and not stale
			)
			var focus: Button = menu._button(
				card, "FOCUS IN PREVIEW", preview.focus_copy.bind(copy)
			)
			focus.disabled = not preview.positions.has(copy)
			focus.set_meta("stadium_focus", copy)
			continue
		if id == "ST-047":
			StadiumRisingAppleItemsUI.card(
				menu, card, draft, copy, base_revision, editable and not stale
			)
			var focus: Button = menu._button(
				card, "FOCUS IN PREVIEW", preview.focus_copy.bind(copy)
			)
			focus.disabled = not preview.positions.has(copy)
			focus.set_meta("stadium_focus", copy)
			continue
		if id == "ST-054":
			StadiumOutfieldBleacherItemsUI.card(
				menu, card, draft, copy, base_revision, editable and not stale
			)
			var focus: Button = menu._button(
				card, "FOCUS IN PREVIEW", preview.focus_copy.bind(copy)
			)
			focus.disabled = not preview.positions.has(copy)
			focus.set_meta("stadium_focus", copy)
			continue
		if id in ["ST-048", "ST-049", "ST-050"]:
			StadiumLandmarkItemsUI.card(
				menu, card, draft, copy, base_revision, editable and not stale
			)
			var focus: Button = menu._button(
				card, "FOCUS IN PREVIEW", preview.focus_copy.bind(copy)
			)
			focus.disabled = not preview.positions.has(copy)
			focus.set_meta("stadium_focus", copy)
			continue
		if id == "ST-045":
			StadiumTreehouseItemsUI.card(
				menu, card, draft, copy, base_revision, editable and not stale
			)
			var focus: Button = menu._button(
				card, "FOCUS IN PREVIEW", preview.focus_copy.bind(copy)
			)
			focus.disabled = not preview.positions.has(copy)
			focus.set_meta("stadium_focus", copy)
			continue
		if id in ["ST-060", "ST-061"]:
			StadiumPracticeFacilityItemsUI.card(
				menu, card, draft, copy, base_revision, editable and not stale
			)
			var focus: Button = menu._button(
				card, "FOCUS IN PREVIEW", preview.focus_copy.bind(copy)
			)
			focus.disabled = not preview.positions.has(copy)
			focus.set_meta("stadium_focus", copy)
			continue
		if id == "ST-052":
			StadiumGroundBoxItemsUI.card(
				menu, card, draft, copy, base_revision, editable and not stale
			)
			var focus: Button = menu._button(
				card, "FOCUS IN PREVIEW", preview.focus_copy.bind(copy)
			)
			focus.disabled = not preview.positions.has(copy)
			focus.set_meta("stadium_focus", copy)
			continue
		if id == "ST-051":
			StadiumMoldedSeatItemsUI.card(
				menu, card, draft, copy, base_revision, editable and not stale
			)
			var focus: Button = menu._button(
				card, "FOCUS IN PREVIEW", preview.focus_copy.bind(copy)
			)
			focus.disabled = not preview.positions.has(copy)
			focus.set_meta("stadium_focus", copy)
			continue
		if StadiumPurchases.SEATING.has(id):
			StadiumSeatingEditorUI.card(
				menu, card, draft, copy, id, base_revision, editable and not stale, view.land
			)
			var focus: Button = menu._button(
				card, "FOCUS IN PREVIEW", preview.focus_copy.bind(copy)
			)
			focus.disabled = not preview.positions.has(copy)
			focus.set_meta("stadium_focus", copy)
			continue
		var options: Array[String] = []
		options.assign(
			(
				["Stored", "Receiver primary"]
				if id == "ST-079"
				else ["Stored", "O-L1", "O-L2", "O-R1", "O-R2"]
			)
		)
		var selected: int = 1 if id == "ST-079" and draft.receiver == copy else 0
		var yaw: int = 0
		if id != "ST-079":
			for placement: Dictionary in draft.obstacles:
				if placement.copy == copy:
					selected = options.find(placement.site)
					yaw = int(placement.yaw)
		var choice: OptionButton = _options(card, options, selected)
		choice.set_meta("stadium_copy", copy)
		choice.disabled = not editable or stale
		choice.item_selected.connect(
			func(index: int) -> void:
				var next: Dictionary = draft.duplicate(true)
				if id == "ST-079":
					if index == 1:
						next.receiver = copy
						if next.has("target"):
							next.target = ""
						if next.has("net"):
							next.net = ""
					elif next.receiver == copy:
						next.receiver = ""
				else:
					next.obstacles = next.obstacles.filter(
						func(row: Dictionary) -> bool: return row.copy != copy
					)
					if index > 0:
						next.obstacles.append({"copy": copy, "site": options[index], "yaw": yaw})
					next.obstacles.sort_custom(
						func(a: Dictionary, b: Dictionary) -> bool: return a.site < b.site
					)
				show(menu, next, base_revision)
				_focus_choice.call_deferred(menu, copy, false)
		)
		if id == "ST-003":
			var rotation: OptionButton = _options(
				card, ["0°", "90°", "180°", "270°"], int(yaw / 90)
			)
			rotation.set_meta("stadium_yaw", copy)
			rotation.disabled = not editable or stale or selected == 0
			rotation.item_selected.connect(
				func(index: int) -> void:
					var next: Dictionary = draft.duplicate(true)
					for row: Dictionary in next.obstacles:
						if row.copy == copy:
							row.yaw = index * 90
					show(menu, next, base_revision)
					_focus_choice.call_deferred(menu, copy, true)
			)
		var inspect: Button = menu._button(card, "FOCUS IN PREVIEW", preview.focus_copy.bind(copy))
		inspect.disabled = not preview.positions.has(copy)
		inspect.set_meta("stadium_focus", copy)
	var save: Button = menu._button(
		menu._footer, "SAVE DRAFT", _save.bind(menu, draft, base_revision)
	)
	save.disabled = not editable or stale or not checked.ok or not changed
	var activate: Button = menu._button(
		menu._footer, "APPLY LAYOUT", _apply.bind(menu, draft, base_revision)
	)
	activate.disabled = (
		not ClubConstruction.can_apply(season)
		or stale
		or not checked.ok
		or changed
		or applied
		or (
			draft.version >= 2
			and season.phase == SeasonState.Phase.DRAFT
			and not season.home_property.has("boundary")
		)
	)
	activate.tooltip_text = "Save the draft first. Applying and storage cost no Club Bucks."
	menu._button(menu._footer, "RELOAD SAVED", show.bind(menu, {}, -1))
	menu._button(menu._footer, "CLUB RECORD", _back.bind(menu, changed))


static func _refuse_pool(menu: SeasonMenu, draft: Dictionary, revision: int) -> bool:
	if StadiumPoolWorkshopUI.WORKSHOP_ENABLED:
		return false
	var ledger: ClubAssetLedger = ClubPlayers.assets(menu.app.season.career)
	if not StadiumPoolWorkshopUI.staged(ledger.view(), draft):
		return false
	show(menu, draft, revision)
	return true


static func _mounted_staged(view: Dictionary, draft: Dictionary) -> bool:
	return (
		not StadiumMountedScoreboardLayout.RUNTIME_READY
		and (
			draft.get("version") == 15
			or view.stadium_draft.get("version") == 15
			or view.stadium_active.get("version") == 15
		)
	)


static func _staged_workshop(
	menu: SeasonMenu, draft: Dictionary, revision: int, changed: bool
) -> void:
	menu.app.notice = MOUNTED_STAGED_NOTICE
	menu._screen("stadium", "STADIUM WORKSHOP", "STAGED LAYOUT • NOT AVAILABLE")
	SeasonPages.wrapped(
		menu._body,
		(
			(
				"Preview, editing, purchases, Save Draft and Apply Layout are unavailable for this "
				+ "staged data. "
			)
			+ "Your saved layouts and owned copies are preserved. No Club Bucks are charged."
		)
	)
	SeasonPages.wrapped(
		menu._body, "Any current season keeps its frozen field. No replacement field is shown here."
	)
	var save: Button = menu._button(menu._footer, "SAVE DRAFT", _save.bind(menu, draft, revision))
	save.disabled = true
	save.tooltip_text = MOUNTED_STAGED_NOTICE
	var activate: Button = menu._button(
		menu._footer, "APPLY LAYOUT", _apply.bind(menu, draft, revision)
	)
	activate.disabled = true
	activate.tooltip_text = MOUNTED_STAGED_NOTICE
	menu._button(menu._footer, "RELOAD SAVED", show.bind(menu, {}, -1))
	menu._button(menu._footer, "CLUB RECORD", _back.bind(menu, changed))


static func _refuse_mounted(menu: SeasonMenu, draft: Dictionary, revision: int) -> bool:
	var ledger: ClubAssetLedger = ClubPlayers.assets(menu.app.season.career)
	if not _mounted_staged(ledger.view(), draft):
		return false
	show(menu, draft, revision)
	return true


static func _options(parent: Node, labels: Array[String], selected: int) -> OptionButton:
	var result: OptionButton = OptionButton.new()
	result.custom_minimum_size = Vector2(220, 44)
	result.add_theme_font_size_override("font_size", 18)
	for label: String in labels:
		result.add_item(label)
	result.select(maxi(0, selected))
	parent.add_child(result)
	return result


static func _save(menu: SeasonMenu, draft: Dictionary, revision: int) -> void:
	if _refuse_pool(menu, draft, revision):
		return
	if _refuse_mounted(menu, draft, revision):
		return
	var result: Dictionary = ClubConstruction.save_draft(menu.app.season, draft, revision)
	menu.app.notice = "Draft saved. Apply Layout to use it." if result.ok else result.error
	if result.ok:
		show(menu)
	else:
		show(menu, draft, revision)


static func _apply(menu: SeasonMenu, draft: Dictionary, revision: int) -> void:
	if _refuse_pool(menu, draft, revision):
		return
	if _refuse_mounted(menu, draft, revision):
		return
	var ledger: ClubAssetLedger = ClubPlayers.assets(menu.app.season.career)
	var movement: Dictionary = _movement(ledger, ledger.view().stadium_active, draft)
	if not movement.ok:
		menu.app.notice = movement.error
		show(menu, draft, revision)
		return
	var message: String = _confirmation(ledger, draft, movement)
	if not message.is_empty():
		menu.app._confirm(message, _apply_now.bind(menu, draft, revision))
	else:
		_apply_now(menu, draft, revision)


static func _apply_now(menu: SeasonMenu, draft: Dictionary, revision: int) -> void:
	if _refuse_pool(menu, draft, revision):
		return
	if _refuse_mounted(menu, draft, revision):
		return
	var result: Dictionary = ClubConstruction.apply_draft(menu.app.season, draft, revision)
	menu.app.notice = (
		(
			"Home layout saved for your next Working season."
			if (menu.app.season.phase == SeasonState.Phase.COMPLETE)
			else "Home layout applied. It locks when drafting begins."
		)
		if result.ok
		else result.error
	)
	if result.ok:
		show(menu)
	else:
		show(menu, draft, revision)


static func _back(menu: SeasonMenu, changed: bool) -> void:
	if changed:
		menu.app._confirm(
			"Leave this preview? Unsaved stadium draft changes will be discarded.",
			ClubCareerUI.show.bind(menu, 0)
		)
	else:
		ClubCareerUI.show(menu)


static func _focus_choice(menu: SeasonMenu, copy: String, yaw: bool) -> void:
	if menu.page != "stadium":
		return
	for control: OptionButton in menu._body.find_children("*", "OptionButton", true, false):
		if control.get_meta("stadium_yaw" if yaw else "stadium_copy", "") == copy:
			control.grab_focus()
			return


static func _purchases(menu: SeasonMenu, ledger: ClubAssetLedger, enabled: bool) -> void:
	var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(card, "EXTRA COPIES", 22)
	SeasonPages.wrapped(
		card,
		(
			"Working prices. Uses your player-pack Club Bucks balance. New copies go into storage. "
			+ "Save or reload draft edits before buying. The four-live-object limit still applies."
		)
	)
	for id: String in StadiumPurchases.PRICES:
		var price: int = StadiumPurchases.PRICES[id]
		var buy: Button = menu._button(
			card,
			"%s • %d CB" % [StadiumFieldLabels.item_name(id), price],
			_buy.bind(menu, id, ledger.revision())
		)
		buy.set_meta("stadium_buy", id)
		buy.disabled = not enabled or ledger.balance() < price


static func _buy(menu: SeasonMenu, id: String, revision: int) -> void:
	if id == "ST-006" and not StadiumPoolWorkshopUI.WORKSHOP_ENABLED:
		menu.app.notice = StadiumPoolWorkshopUI.NOTICE
		show(menu)
		return
	var result: Dictionary = ClubConstruction.buy_copy(menu.app.season, id, revision)
	menu.app.notice = (
		"One extra copy purchased and stored. Place it, save, then apply."
		if result.ok
		else result.error
	)
	show(menu)


static func stored_summary(
	copies: Array,
	stock: StadiumStock,
	pieces: StadiumWallPieceOwnership = null,
	boards: StadiumScoreboardOwnership = null
) -> String:
	var counts: Dictionary = {}
	for copy: String in copies:
		var row: Dictionary = stock.copies.get(copy, {})
		if row.is_empty() and pieces != null:
			row = pieces.stock.copies.get(copy, {})
		if row.is_empty() and boards != null:
			row = boards.copies.get(copy, {})
		if row.is_empty():
			return "Unknown stored copy; reload the verified club"
		var item: String = row.item
		counts[item] = int(counts.get(item, 0)) + 1
	var ids: Array = counts.keys()
	ids.sort()
	var names: PackedStringArray = []
	for item: String in ids:
		names.append(
			StadiumFieldLabels.item_name(item) + (" ×%d" % counts[item] if counts[item] > 1 else "")
		)
	return ", ".join(names)


static func _checked(ledger: ClubAssetLedger, layout: Dictionary, tier: String = "") -> Dictionary:
	if layout.get("version") == 15 and not StadiumMountedScoreboardLayout.RUNTIME_READY:
		return StadiumStarterLayout._error(MOUNTED_STAGED_NOTICE)
	var checked: Dictionary = StadiumOwnedLayout.validate(
		layout,
		ledger.construction(),
		ledger.wall_pieces(),
		ledger.surface_owned(),
		ledger.view().land if tier.is_empty() else tier,
		ledger.scoreboards()
	)
	if not checked.ok:
		return checked
	var mounted_transition: Dictionary = StadiumMountedDisplayItems.transition(
		ledger.view().stadium_draft, layout
	)
	if not mounted_transition.ok:
		return mounted_transition
	if (
		SeasonOwnership._whole(layout.get("version"), 12, 15)
		and not StadiumSurfaceLayout.owned(layout, ledger.surface_owned())
	):
		return StadiumStarterLayout._error("This surface selection is not owned.")
	if not checked.has("pieces_stored"):
		checked["pieces_stored"] = ledger.wall_pieces().stock.copies.keys()
	if not checked.has("scoreboards_stored"):
		checked["scoreboards_stored"] = ledger.scoreboards().copies.keys()
	return checked


static func _movement(ledger: ClubAssetLedger, before: Dictionary, after: Dictionary) -> Dictionary:
	return StadiumOwnedLayout.preview(
		before,
		after,
		ledger.construction(),
		ledger.wall_pieces(),
		ledger.surface_owned(),
		ledger.view().land,
		ledger.scoreboards()
	)


static func _placed_count(checked: Dictionary) -> int:
	return (
		checked.get("placements", []).size()
		+ checked.get("wall_panels", []).size()
		+ checked.get("advanced_panels", []).size()
		+ checked.get("board_placements", []).size()
		+ checked.get("low_panels", []).size()
	)


static func _confirmation(
	ledger: ClubAssetLedger, draft: Dictionary, movement: Dictionary
) -> String:
	return Operations1._confirmation(ledger, draft, movement)
