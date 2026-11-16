class_name StadiumPoolWorkshopUI
extends RefCounted
## Owned Pool workshop controls; the existing transactions retain runtime and save authority.

const WORKSHOP_ENABLED: bool = true
const PREVIEW_EXPOSED: bool = false
const NOTICE: String = "Pool workshop qualification is pending. " \
	+ "Purchases, placement, Save Draft and Apply Layout remain unavailable."
const PLACEMENT_NOTICE: String = "PREVIEW ONLY • Changes stay in memory. " \
	+ "Purchases, Save Draft and Apply Layout remain unavailable."
const LIVE_NOTICE: String = "Place your owned Pool, save the draft, then apply the layout. " \
	+ "Moving and storage cost no Club Bucks."
const STALE: String = "Club data changed. Reload the saved draft before saving again."


static func pool_intent(layout: Variant) -> bool:
	return layout is Dictionary and (layout.get("version") == StadiumPoolOwnedLayout.VERSION \
		or layout.get("family") == StadiumPoolOwnedLayout.FAMILY or layout.has("pool"))


static func staged(view: Dictionary, draft: Dictionary) -> bool:
	return pool_intent(draft) or pool_intent(view.get("stadium_draft")) \
		or pool_intent(view.get("stadium_active"))


static func inspect(layout: Variant, stock: StadiumStock, pieces: StadiumWallPieceOwnership,
	boards: StadiumScoreboardOwnership, access: Array[String], tier: String,
	revision: int, current_revision: int) -> Dictionary:
	var owners: Dictionary = _ownership(stock, pieces, boards)
	if owners.is_empty():
		return StadiumStarterLayout._error("Explicit complete construction ownership is required.")
	var checked: Dictionary = StadiumPoolOwnedLayout.validate(layout, owners.stock, access, tier)
	if not checked.ok:
		return checked
	if revision < 0 or revision > ClubAssetLedger.MAX_EVENTS or revision != current_revision:
		return StadiumStarterLayout._error(STALE)
	return {"ok": true, "error": "", "copy": layout.pool.copy,
		"position": StadiumPoolOwnedLayout.pose(layout).origin, "yaw": int(layout.pool.yaw),
		"surface": layout.surface.duplicate(true), "live_units": checked.live_units,
		"stored": checked.stored.duplicate(), "paid": owners.stock.copies[layout.pool.copy].paid}


static func _ownership(stock: StadiumStock, pieces: StadiumWallPieceOwnership,
	boards: StadiumScoreboardOwnership) -> Dictionary:
	if stock == null or pieces == null or pieces.stock == null or boards == null:
		return {}
	return StadiumPoolOwnedSnapshot.ownership({"inventory": stock.to_data(),
		"wall_piece_inventory": pieces.to_data(), "scoreboard_inventory": boards.to_data()})


static func show_staged(menu: SeasonMenu, ledger: ClubAssetLedger, draft: Dictionary,
	revision: int, changed: bool) -> void:
	# Live workshop activation is separate from the retained private-preview gate.
	var notice: String = NOTICE
	if (WORKSHOP_ENABLED or PREVIEW_EXPOSED) and pool_intent(draft):
		var result: Dictionary = show_placement_preview(menu, draft, revision)
		if result.ok:
			return
		if WORKSHOP_ENABLED:
			notice = result.error
	menu.app.notice = notice
	menu._screen("stadium", "STADIUM WORKSHOP", "POOL DRAFT • NEEDS REVIEW"
		if WORKSHOP_ENABLED else "POOL STAGED • QUALIFICATION PENDING")
	SeasonPages.wrapped(menu._body, notice)
	SeasonPages.wrapped(menu._body,
		"Your saved layouts and owned copies are preserved. No Club Bucks are charged. "
		+ "Any current season keeps its frozen field.")
	var view: Dictionary = ledger.view()
	for entry: Array in [["REQUESTED DRAFT", draft], ["SAVED DRAFT", view.stadium_draft],
		["ACTIVE LAYOUT", view.stadium_active]]:
		if not pool_intent(entry[1]):
			continue
		var status: Dictionary = inspect(entry[1], ledger.construction(), ledger.wall_pieces(),
			ledger.scoreboards(), ledger.surface_owned(), view.land, revision, ledger.revision())
		_status_card(menu, entry[0], status)
	menu._button(menu._footer, "RELOAD SAVED", StadiumEditorUI.show.bind(menu, {}, -1))
	menu._button(menu._footer, "CLUB RECORD", StadiumEditorUI._back.bind(menu, changed))


static func _status_card(menu: SeasonMenu, heading: String, status: Dictionary) -> void:
	var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	card.set_meta("pool_readonly", true)
	card.set_meta("pool_status", status.duplicate(true))
	menu._label(card, heading + " • OWNED POOL", 22)
	if not status.ok:
		SeasonPages.wrapped(card, status.error)
		return
	card.set_meta("pool_copy", status.copy)
	SeasonPages.wrapped(card, "OWNED • Paid %d CB • %s" % [status.paid, status.copy])
	SeasonPages.wrapped(card, "Position (%.1f, %.1f) • Yaw %d° • %d / 4 live units" % [
		status.position.x, status.position.z, status.yaw, status.live_units])
	SeasonPages.wrapped(card, "Surface: %s • %s • %s" % [status.surface.foundation.capitalize(),
		status.surface.condition.capitalize(), status.surface.height.capitalize()])
	SeasonPages.wrapped(card, "READ ONLY • Reload the saved draft to return to the workshop."
		if WORKSHOP_ENABLED else "READ ONLY • Owned Pool preview; gameplay qualification pending.")


static func stored_card(menu: SeasonMenu, ledger: ClubAssetLedger, copy: String,
	draft: Dictionary = {}, revision: int = -1) -> void:
	var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	card.set_meta("pool_readonly", not WORKSHOP_ENABLED)
	card.set_meta("pool_copy", copy)
	menu._label(card, "OWNED POOL • STORED", 22)
	var owners: Dictionary = _ownership(ledger.construction(), ledger.wall_pieces(),
		ledger.scoreboards())
	if owners.is_empty() or not owners.stock.copies.has(copy) \
		or owners.stock.copies[copy].item != "ST-006":
		SeasonPages.wrapped(card, "Explicit complete construction ownership is required.")
		return
	SeasonPages.wrapped(card, "OWNED • Paid %d CB • %s" % [owners.stock.copies[copy].paid, copy])
	SeasonPages.wrapped(card, "Stored • Uses 4 / 4 live units when placed. "
		+ "No small-site placement controls apply to this copy.")
	SeasonPages.wrapped(card, LIVE_NOTICE if WORKSHOP_ENABLED else NOTICE)
	if WORKSHOP_ENABLED or PREVIEW_EXPOSED:
		var session: Dictionary = {"draft": draft.duplicate(true), "revision": revision,
			"copy": copy, "position": Vector2(12, 18), "yaw": 0}
		var feedback: Label = menu._label(card, "", 18)
		feedback.name = "PoolInventoryFeedback"
		feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var open: Button = menu._button(card,
			"POOL INVENTORY" if WORKSHOP_ENABLED else "POOL INVENTORY PREVIEW",
			_inventory_open.bind(menu, card, session))
		open.disabled = WORKSHOP_ENABLED and (not ClubConstruction.editable(menu.app.season)
			or revision != ledger.revision())


static func inventory_candidate(draft: Dictionary, stock: StadiumStock,
	pieces: StadiumWallPieceOwnership, boards: StadiumScoreboardOwnership,
	access: Array[String], tier: String, revision: int, current_revision: int, copy: String,
	position: Vector2 = Vector2(12, 18), yaw: int = 0) -> Dictionary:
	var owners: Dictionary = _ownership(stock, pieces, boards)
	if owners.is_empty():
		return StadiumStarterLayout._error("Explicit complete construction ownership is required.")
	if revision < 0 or revision > ClubAssetLedger.MAX_EVENTS or revision != current_revision:
		return StadiumStarterLayout._error(STALE)
	# Storage is an explicit v1-12 migration, never a projection that discards furniture.
	var error: String = StadiumPoolOwnedLayout.migration_error(draft, owners.stock, access, tier)
	if not error.is_empty():
		return StadiumStarterLayout._error(error)
	var next: Dictionary = StadiumPoolOwnedLayout.upgrade(draft, owners.stock, access, tier,
		copy, position, yaw)
	if next.is_empty():
		return StadiumStarterLayout._error("Stored Pool copy or placement could not be validated.")
	var status: Dictionary = inspect(next, stock, pieces, boards, access, tier,
		revision, current_revision)
	if status.ok:
		status["layout"] = next
	return status


static func _inventory_current(menu: Variant, card: Variant) -> bool:
	return is_instance_valid(menu) and menu is SeasonMenu and is_instance_valid(card) \
		and card is VBoxContainer and menu.page == "stadium" and card.is_inside_tree() \
		and is_instance_valid(menu._body) and menu._body.is_ancestor_of(card)


static func _inventory_open(menu: Variant, card: Variant, session: Dictionary) -> void:
	if not _inventory_current(menu, card):
		return
	var result: Dictionary = show_inventory_preview(menu, session.draft, session.revision,
		session.copy, session.position, session.yaw)
	if not result.ok:
		_inventory_feedback(menu, card, result.error)


static func show_inventory_preview(menu: SeasonMenu, draft: Dictionary, revision: int,
	copy: String, position: Vector2 = Vector2(12, 18), yaw: int = 0) -> Dictionary:
	var ledger: ClubAssetLedger = ClubPlayers.assets(menu.app.season.career)
	var status: Dictionary = inventory_candidate(draft, ledger.construction(),
		ledger.wall_pieces(), ledger.scoreboards(), ledger.surface_owned(), ledger.view().land,
		revision, ledger.revision(), copy, position, yaw)
	if not status.ok:
		return status
	menu.app.notice = LIVE_NOTICE if WORKSHOP_ENABLED else PLACEMENT_NOTICE
	menu._screen("stadium", "STADIUM WORKSHOP",
		"POOL INVENTORY" if WORKSHOP_ENABLED else "POOL INVENTORY • PREVIEW ONLY")
	var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	var session: Dictionary = {"draft": draft.duplicate(true), "revision": revision,
		"copy": copy, "position": position, "yaw": yaw}
	card.set_meta("pool_inventory_draft", draft.duplicate(true))
	card.set_meta("pool_inventory_revision", revision)
	card.set_meta("pool_inventory_copy", copy)
	menu._label(card, "OWNED POOL • STORED" if WORKSHOP_ENABLED
		else "OWNED POOL • STORED IN PREVIEW", 22)
	SeasonPages.wrapped(card, "OWNED • Paid %d CB • %s" % [status.paid, copy])
	SeasonPages.wrapped(card, LIVE_NOTICE if WORKSHOP_ENABLED else PLACEMENT_NOTICE)
	var feedback: Label = menu._label(card, "", 18)
	feedback.name = "PoolInventoryFeedback"
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var place: Button = menu._button(card, "PLACE POOL" if WORKSHOP_ENABLED else "PLACE IN PREVIEW",
		_inventory_place.bind(menu, card, session))
	place.disabled = WORKSHOP_ENABLED and not ClubConstruction.editable(menu.app.season)
	menu._button(menu._footer, "RELOAD SAVED", StadiumEditorUI.show.bind(menu, {}, -1))
	menu._button(menu._footer, "CLUB RECORD", _inventory_back.bind(menu, card, session))
	return status


static func _inventory_place(menu: Variant, card: Variant, session: Dictionary) -> void:
	if not _inventory_current(menu, card):
		return
	if WORKSHOP_ENABLED and not ClubConstruction.editable(menu.app.season):
		_inventory_feedback(menu, card, "Pool placement opens between seasons, before drafting.")
		return
	var ledger: ClubAssetLedger = ClubPlayers.assets(menu.app.season.career)
	var status: Dictionary = inventory_candidate(session.draft, ledger.construction(),
		ledger.wall_pieces(), ledger.scoreboards(), ledger.surface_owned(), ledger.view().land,
		session.revision, ledger.revision(), session.copy, session.position, session.yaw)
	if not status.ok:
		_inventory_feedback(menu, card, status.error)
		return
	var built: Dictionary = show_placement_preview(menu, status.layout, session.revision, true)
	if not built.ok:
		_inventory_feedback(menu, card, built.error)


static func _inventory_back(menu: Variant, card: Variant, session: Dictionary) -> void:
	if not _inventory_current(menu, card):
		return
	var ledger: ClubAssetLedger = ClubPlayers.assets(menu.app.season.career)
	StadiumEditorUI._back(menu,
		not ClubCareer.same(session.draft, ledger.view().stadium_draft))


static func show_placement_preview(menu: SeasonMenu, draft: Dictionary,
	revision: int, inventory_session: bool = false) -> Dictionary:
	var ledger: ClubAssetLedger = ClubPlayers.assets(menu.app.season.career)
	var status: Dictionary = inspect(draft, ledger.construction(), ledger.wall_pieces(),
		ledger.scoreboards(), ledger.surface_owned(), ledger.view().land, revision, ledger.revision())
	if not status.ok:
		return status
	menu.app.notice = LIVE_NOTICE if WORKSHOP_ENABLED else PLACEMENT_NOTICE
	menu._screen("stadium", "STADIUM WORKSHOP",
		"OWNED POOL • LAYOUT" if WORKSHOP_ENABLED else "POOL PLACEMENT • PREVIEW ONLY")
	if WORKSHOP_ENABLED:
		SeasonPages.wrapped(menu._body, LIVE_NOTICE)
	SeasonPages.wrapped(menu._body,
		"Try a position on the half-meter grid and a quarter-turn. "
		+ "Invalid placements keep the last valid preview. Your current season keeps its frozen field.")
	var preview: StadiumDraftPreview = StadiumDraftPreview.new()
	menu._body.add_child(preview)
	var built: Dictionary = preview.build_pool_readonly(draft, ledger.construction(),
		ledger.wall_pieces(), ledger.scoreboards(), ledger.surface_owned(), ledger.view().land,
		revision, ledger.revision())
	if not built.ok:
		menu._body.remove_child(preview)
		preview.free()
		SeasonPages.wrapped(menu._body, built.error)
		menu._button(menu._footer, "RELOAD SAVED", StadiumEditorUI.show.bind(menu, {}, -1))
		menu._button(menu._footer, "CLUB RECORD", StadiumEditorUI._back.bind(menu,
			not ClubCareer.same(draft, ledger.view().stadium_draft)))
		return built
	var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	# Callback-bound state owns the accepted draft and original revision.
	# Card metadata is a detached diagnostic snapshot, never session authority.
	var session: Dictionary = {"draft": draft.duplicate(true), "preview": preview,
		"revision": revision}
	card.set_meta("pool_placement_draft", draft.duplicate(true))
	card.set_meta("pool_placement_revision", revision)
	menu._label(card, "OWNED POOL • PLACEMENT" if WORKSHOP_ENABLED
		else "OWNED POOL • PLACEMENT PREVIEW", 22)
	SeasonPages.wrapped(card, "OWNED • Paid %d CB • %s" % [status.paid, status.copy])
	SeasonPages.wrapped(card, "Surface: %s • %s • %s • 4 / 4 live units" % [
		status.surface.foundation.capitalize(), status.surface.condition.capitalize(),
		status.surface.height.capitalize()])
	var position: Vector3 = status.position
	_position_control(menu, card, "X position (m)", "PoolPositionX", position.x)
	_position_control(menu, card, "Z position (m)", "PoolPositionZ", position.z)
	menu._label(card, "Rotation", 18)
	var yaw: OptionButton = StadiumEditorUI._options(card,
		["0°", "90°", "180°", "270°"], int(status.yaw / 90))
	yaw.name = "PoolYaw"
	yaw.disabled = WORKSHOP_ENABLED and not ClubConstruction.editable(menu.app.season)
	var feedback: Label = menu._label(card, _placement_summary(status), 18)
	feedback.name = "PoolPlacementFeedback"
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if WORKSHOP_ENABLED:
		var state: Label = menu._label(card, "", 18)
		state.name = "PoolLayoutStatus"
		state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var move: Button = menu._button(card, "UPDATE PREVIEW",
		_placement_move.bind(menu, card, session))
	move.disabled = WORKSHOP_ENABLED and not ClubConstruction.editable(menu.app.season)
	if inventory_session or WORKSHOP_ENABLED:
		var store: Button = menu._button(card, "STORE POOL" if WORKSHOP_ENABLED else "STORE IN PREVIEW",
			_placement_store.bind(menu, card, session))
		store.disabled = WORKSHOP_ENABLED and not ClubConstruction.editable(menu.app.season)
	if WORKSHOP_ENABLED:
		var save: Button = menu._button(menu._footer, "SAVE DRAFT",
			_placement_save.bind(menu, card, session))
		save.name = "PoolSaveDraft"
		var apply: Button = menu._button(menu._footer, "APPLY LAYOUT",
			_placement_apply.bind(menu, card, session))
		apply.name = "PoolApplyLayout"
		_refresh_actions(menu, card, session)
	menu._button(menu._footer, "FIELD VIEW", _placement_overview.bind(menu, card, session))
	menu._button(menu._footer, "RELOAD SAVED", StadiumEditorUI.show.bind(menu, {}, -1))
	menu._button(menu._footer, "CLUB RECORD", _placement_back.bind(menu, card, session))
	return built


static func _position_control(menu: SeasonMenu, card: VBoxContainer, label: String,
	control_name: String, value: float) -> void:
	menu._label(card, label, 18)
	var control: SpinBox = SpinBox.new()
	control.name = control_name
	control.min_value = -64.0
	control.max_value = 64.0
	control.step = 0.5
	control.value = value
	control.editable = not WORKSHOP_ENABLED or ClubConstruction.editable(menu.app.season)
	control.custom_minimum_size = Vector2(220, 44)
	control.add_theme_font_size_override("font_size", 18)
	card.add_child(control)


static func _placement_summary(status: Dictionary) -> String:
	return "Last valid preview: (%.1f, %.1f) m • Yaw %d° • %s" % [
		status.position.x, status.position.z, status.yaw,
		"Save and apply to use changes." if WORKSHOP_ENABLED else "Unsaved, preview only."]


static func _placement_current(menu: Variant, card: Variant, session: Dictionary) -> bool:
	return is_instance_valid(menu) and menu is SeasonMenu and is_instance_valid(card) \
		and card is VBoxContainer and menu.page == "stadium" and card.is_inside_tree() \
		and is_instance_valid(menu._body) and menu._body.is_ancestor_of(card) \
		and is_instance_valid(session.preview) and session.preview.get_parent() == menu._body


static func _placement_move(menu: Variant, card: Variant, session: Dictionary) -> void:
	if not _placement_current(menu, card, session):
		return
	if WORKSHOP_ENABLED and not ClubConstruction.editable(menu.app.season):
		_inventory_feedback(menu, card, "Pool placement opens between seasons, before drafting.")
		return
	card.set_meta("pool_placement_draft", session.draft.duplicate(true))
	card.set_meta("pool_placement_revision", session.revision)
	var ledger: ClubAssetLedger = ClubPlayers.assets(menu.app.season.career)
	var draft: Dictionary = session.draft
	var revision: int = session.revision
	var x: SpinBox = card.get_node("PoolPositionX")
	var z: SpinBox = card.get_node("PoolPositionZ")
	var yaw: OptionButton = card.get_node("PoolYaw")
	var feedback: Label = card.get_node("PoolPlacementFeedback")
	var status: Dictionary = inspect(draft, ledger.construction(), ledger.wall_pieces(),
		ledger.scoreboards(), ledger.surface_owned(), ledger.view().land, revision, ledger.revision())
	if not status.ok:
		feedback.text = status.error + " Last valid preview kept."
		return
	var trial: Dictionary = draft.duplicate(true)
	trial.pool.position = [x.value, z.value]
	trial.pool.yaw = yaw.selected * 90
	status = inspect(trial, ledger.construction(), ledger.wall_pieces(), ledger.scoreboards(),
		ledger.surface_owned(), ledger.view().land, revision, ledger.revision())
	if not status.ok:
		feedback.text = "Invalid placement: " + status.error + " Last valid preview kept."
		return
	var next: Dictionary = StadiumPoolOwnedLayout.relocated(draft, ledger.construction(),
		ledger.surface_owned(), ledger.view().land, Vector2(x.value, z.value), yaw.selected * 90)
	if next.is_empty():
		feedback.text = "Placement could not be validated. Last valid preview kept."
		return
	# Build a prospective private world before releasing the accepted one. A failure
	# cannot replace either the accepted UI draft or its current scenery model.
	var candidate: StadiumDraftPreview = StadiumDraftPreview.new()
	menu._body.add_child(candidate)
	var built: Dictionary = candidate.build_pool_readonly(next, ledger.construction(),
		ledger.wall_pieces(), ledger.scoreboards(), ledger.surface_owned(), ledger.view().land,
		revision, ledger.revision())
	if not built.ok:
		menu._body.remove_child(candidate)
		candidate.free()
		feedback.text = built.error + " Last valid preview kept."
		return
	var previous: StadiumDraftPreview = session.preview
	menu._body.move_child(candidate, previous.get_index())
	menu._body.remove_child(previous)
	previous.free()
	session.draft = next
	session.preview = candidate
	card.set_meta("pool_placement_draft", next.duplicate(true))
	card.set_meta("pool_placement_revision", session.revision)
	feedback.text = _placement_summary(built)
	if WORKSHOP_ENABLED:
		_refresh_actions(menu, card, session)


static func _placement_overview(menu: Variant, card: Variant, session: Dictionary) -> void:
	if _placement_current(menu, card, session):
		var preview: StadiumDraftPreview = session.preview
		preview.overview()


static func _placement_back(menu: Variant, card: Variant, session: Dictionary) -> void:
	if not _placement_current(menu, card, session):
		return
	var ledger: ClubAssetLedger = ClubPlayers.assets(menu.app.season.career)
	StadiumEditorUI._back(menu,
		not ClubCareer.same(session.draft, ledger.view().stadium_draft))


static func _placement_store(menu: Variant, card: Variant, session: Dictionary) -> void:
	if not _placement_current(menu, card, session):
		return
	if WORKSHOP_ENABLED and not ClubConstruction.editable(menu.app.season):
		_inventory_feedback(menu, card, "Pool placement opens between seasons, before drafting.")
		return
	var ledger: ClubAssetLedger = ClubPlayers.assets(menu.app.season.career)
	var status: Dictionary = inspect(session.draft, ledger.construction(), ledger.wall_pieces(),
		ledger.scoreboards(), ledger.surface_owned(), ledger.view().land,
		session.revision, ledger.revision())
	if not status.ok:
		_inventory_feedback(menu, card, status.error)
		return
	var base: Dictionary = StadiumPoolOwnedLayout.base(session.draft)
	if WORKSHOP_ENABLED:
		StadiumEditorUI.show(menu, base, session.revision)
		return
	var result: Dictionary = show_inventory_preview(menu, base, session.revision, status.copy,
		Vector2(status.position.x, status.position.z), status.yaw)
	if not result.ok:
		_inventory_feedback(menu, card, result.error)


static func _inventory_feedback(menu: SeasonMenu, card: VBoxContainer, error: String) -> void:
	menu.app.notice = error
	if not _inventory_current(menu, card):
		return
	var feedback: Label = card.get_node_or_null("PoolInventoryFeedback") as Label
	if feedback == null:
		feedback = card.get_node_or_null("PoolPlacementFeedback") as Label
	if feedback != null:
		feedback.text = error + " Last valid preview kept."


static func purchases(menu: SeasonMenu, ledger: ClubAssetLedger, enabled: bool) -> void:
	if not WORKSHOP_ENABLED:
		return
	var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(card, "ROUND ABOVE-GROUND POOL", 22)
	var rows: Array = StadiumCareerProgress.capture(menu.app.season.career)
	var progress: Dictionary = StadiumCareerProgress.metrics(rows, rows.size())
	var quote: Dictionary = StadiumPurchases.quote(ledger.construction(), "ST-006", 1,
		"pool-preview", StadiumPurchases.POOL_VERSION, progress)
	var blueprint: int = 0 if ledger.construction().blueprints.has("ST-006") else 540
	SeasonPages.wrapped(card, "Unlock after 6 completed seasons and 18 regular-season wins. "
		+ "Your closed career: %d seasons • %d wins." % [progress.seasons, progress.wins])
	SeasonPages.wrapped(card, "Blueprint owned • 160 CB per copy" if blueprint == 0
		else "540 blueprint + 160 first copy = 700 CB")
	SeasonPages.wrapped(card, "Backyard only • Uses all 4 live units. Keep the ordinary receiver; "
		+ "store other active furniture and walls before placing. Save or reload edits before buying.")
	var buy: Button = menu._button(card, "BUY POOL",
		StadiumEditorUI._buy.bind(menu, "ST-006", ledger.revision()))
	buy.set_meta("stadium_buy", "ST-006")
	buy.disabled = not enabled or not quote.ok or ledger.balance() < blueprint + 160
	if not quote.ok:
		buy.tooltip_text = quote.error


static func _refresh_actions(menu: SeasonMenu, card: VBoxContainer, session: Dictionary) -> void:
	if not _placement_current(menu, card, session):
		return
	var ledger: ClubAssetLedger = ClubPlayers.assets(menu.app.season.career)
	var view: Dictionary = ledger.view()
	var draft: Dictionary = session.draft
	var changed: bool = not ClubCareer.same(draft, view.stadium_draft)
	var current: bool = WORKSHOP_ENABLED and session.revision == ledger.revision()
	var applied: bool = ClubCareer.same(draft, view.stadium_active) and (
		menu.app.season.phase != SeasonState.Phase.DRAFT or (
			not menu.app.season.home_property.is_empty()
			and ClubCareer.same(menu.app.season.home_property.layout, draft)))
	var save: Button = menu._footer.get_node("PoolSaveDraft")
	var apply: Button = menu._footer.get_node("PoolApplyLayout")
	save.disabled = not current or not ClubConstruction.editable(menu.app.season) or not changed
	apply.disabled = not current or not ClubConstruction.can_apply(menu.app.season) \
		or changed or applied or (menu.app.season.phase == SeasonState.Phase.DRAFT \
		and not menu.app.season.home_property.has("boundary"))
	apply.tooltip_text = "Save the draft first. Applying and storage cost no Club Bucks."
	var state: Label = card.get_node("PoolLayoutStatus")
	state.text = "Unsaved placement changes." if changed else (
		"Applied for next season." if applied and menu.app.season.phase == SeasonState.Phase.COMPLETE
		else "Applied to this season." if applied else "Draft saved. Apply Layout to use it.")
	if not ClubConstruction.editable(menu.app.season):
		state.text += " Editing opens between seasons; this season keeps its frozen field."


static func _live_session(menu: Variant, card: Variant, session: Dictionary) -> bool:
	if not _placement_current(menu, card, session):
		return false
	if not WORKSHOP_ENABLED:
		_inventory_feedback(menu, card, NOTICE)
		return false
	if not ClubConstruction.editable(menu.app.season):
		_inventory_feedback(menu, card, "Stadium editing opens between seasons, before drafting.")
		return false
	var ledger: ClubAssetLedger = ClubPlayers.assets(menu.app.season.career)
	var status: Dictionary = inspect(session.draft, ledger.construction(), ledger.wall_pieces(),
		ledger.scoreboards(), ledger.surface_owned(), ledger.view().land,
		session.revision, ledger.revision())
	if not status.ok:
		_inventory_feedback(menu, card, status.error)
	return status.ok


static func _placement_save(menu: Variant, card: Variant, session: Dictionary) -> void:
	if _live_session(menu, card, session):
		StadiumEditorUI._save(menu, session.draft.duplicate(true), session.revision)


static func _placement_apply(menu: Variant, card: Variant, session: Dictionary) -> void:
	if not _live_session(menu, card, session):
		return
	var ledger: ClubAssetLedger = ClubPlayers.assets(menu.app.season.career)
	var draft: Dictionary = session.draft.duplicate(true)
	if not ClubCareer.same(draft, ledger.view().stadium_draft):
		_inventory_feedback(menu, card, "Save the draft before applying it.")
		return
	var movement: Dictionary = StadiumEditorUI._movement(ledger, ledger.view().stadium_active, draft)
	if not movement.ok:
		_inventory_feedback(menu, card, movement.error)
		return
	var message: String = StadiumEditorUI._confirmation(ledger, draft, movement)
	var commit: Callable = _placement_apply_now.bind(menu, card, session, draft)
	if message.is_empty():
		commit.call()
	else:
		menu.app._confirm(message, commit)


static func _placement_apply_now(menu: Variant, card: Variant, session: Dictionary,
	expected: Dictionary) -> void:
	if _live_session(menu, card, session) and ClubCareer.same(session.draft, expected):
		StadiumEditorUI._apply_now(menu, expected, session.revision)
