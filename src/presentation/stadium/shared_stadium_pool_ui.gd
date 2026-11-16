extends RefCounted
## Shared Pool previews use current owner inventory, never SeasonState.career.
const Transaction = preload("res://src/presentation/stadium/shared_stadium_transaction_ui.gd")
const Access = preload("res://src/presentation/stadium/stadium_career_access.gd")
const Pool = preload("res://src/gameplay/season/dynasty_stadium_pool.gd")
static func _workshop() -> GDScript:
	return load("res://src/presentation/stadium/shared_stadium_workshop_ui.gd")


static func entries(app: Node, draft: Dictionary, revision: int) -> void:
	var paid: ClubAssetLedger = Access.ledger(app)
	if paid == null or not StadiumPoolWorkshopUI.WORKSHOP_ENABLED:
		return
	for copy: String in paid.construction().copies:
		if paid.construction().copies[copy].item != "ST-006":
			continue
		var button: Button = app.menu._button(app.menu._body, "PLACE OWNED POOL • " + copy,
			_place.bind(app, draft.duplicate(true), revision, copy, app.menu._body))
		button.set_meta("shared_pool_copy", copy)
		button.disabled = not Access.editable(app) or revision != paid.revision()


static func _place(app: Node, draft: Dictionary, revision: int, copy: String, origin: Control = null) -> void:
	if origin != null and (not is_instance_valid(origin) or app.menu._body != origin):
		return
	var paid: ClubAssetLedger = Access.ledger(app)
	if paid == null or not Access.editable(app) or not StadiumPoolWorkshopUI.WORKSHOP_ENABLED:
		return
	var candidate: Dictionary = StadiumPoolWorkshopUI.inventory_candidate(draft,
		paid.construction(), paid.wall_pieces(), paid.scoreboards(), paid.surface_owned(),
		paid.view().land, revision, paid.revision(), copy)
	if not candidate.ok:
		app.notice = candidate.error
		return
	show(app, candidate.layout, revision)


static func show(app: Node, draft: Dictionary, revision: int) -> void:
	var paid: ClubAssetLedger = Access.ledger(app)
	if paid == null or not Pool.supported(draft):
		_workshop().show(app)
		return
	var menu: SeasonMenu = app.menu
	menu._screen("shared_stadium_pool", "SHARED POOL WORKSHOP", "Future admissions only • Existing fields stay frozen")
	var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	var preview: StadiumDraftPreview = StadiumDraftPreview.new()
	menu._body.add_child(preview)
	var session: Dictionary = {"draft": draft.duplicate(true), "revision": revision,
		"preview": preview, "card": card}
	var live: bool = int(draft.version) == 16
	var status: Dictionary
	if live:
		status = preview.build_pool_readonly(draft, paid.construction(), paid.wall_pieces(),
			paid.scoreboards(), paid.surface_owned(), paid.view().land, revision, paid.revision())
	else:
		status = StadiumOwnedLayout.validate(draft, paid.construction(), paid.wall_pieces(), paid.surface_owned(), paid.view().land, paid.scoreboards())
		preview.build(draft, paid.construction(), true, paid.view().land, paid.wall_pieces(), paid.scoreboards(), paid.surface_owned())
	card.set_meta("shared_pool_draft", draft.duplicate(true))
	var feedback: Label = menu._label(card, "Save the draft, then apply for future seasons." if status.ok else status.error, 18)
	feedback.name = "SharedPoolFeedback"
	var enabled: bool = status.ok and Access.editable(app) and revision == paid.revision()
	if live and status.ok:
		for axis: String in ["X", "Z"]:
			menu._label(card, axis + " position (m)", 18)
			var control: SpinBox = SpinBox.new()
			control.name = "Pool" + axis
			control.min_value = -64
			control.max_value = 64
			control.step = 0.5
			control.value = draft.pool.position[0 if axis == "X" else 1]
			control.editable = enabled
			card.add_child(control)
		var yaw: OptionButton = StadiumEditorUI._options(card, ["0°", "90°", "180°", "270°"], int(draft.pool.yaw) / 90)
		yaw.name = "PoolYaw"
		yaw.disabled = not enabled
		menu._button(card, "UPDATE PREVIEW", _move.bind(app, session)).disabled = not enabled
		menu._button(card, "STORE POOL", _store.bind(app, session)).disabled = not enabled
	else:
		SeasonPages.wrapped(card, "Pool stored. Surface and all saved selections are preserved.")
		menu._button(card, "FIELD FOUNDATION & APPEARANCE", _field_editor.bind(app, session)).disabled = not enabled
		entries(app, draft, revision)
	var changed: bool = not ClubCareer.same(draft, paid.view().stadium_draft)
	menu._label(card, "CLUB BUCKS • %d" % paid.balance(), 22)
	if live and status.ok:
		SeasonPages.wrapped(card, "OWNED • Paid %d CB • %s • %d / 4 live units" % [
			status.paid, status.copy, status.live_units])
	menu._button(card, "OWNED COPY CATALOG", _catalog.bind(app, session)).disabled = not enabled or changed
	menu._button(card, "FIELD UPGRADES", _upgrades.bind(app, session)).disabled = not enabled or changed
	menu._button(menu._footer, "SAVE SHARED DRAFT", _save.bind(app, session)).disabled = not enabled or not changed or not Pool.allowed(app.season, {"op": "stadium_draft", "layout": draft})
	menu._button(menu._footer, "APPLY FOR FUTURE SEASONS", _ask.bind(app, session)).disabled = not enabled or changed or ClubCareer.same(draft, paid.view().stadium_active) or not Pool.allowed(app.season, {"op": "stadium_apply", "layout": draft})
	menu._button(menu._footer, "RELOAD SAVED", _reload.bind(app, session, changed))
	menu._button(menu._footer, "CLUB RECORD", _workshop()._back.bind(app, changed))
	_workshop()._guard_controls(app)


static func _attached(app: Node, session: Dictionary) -> bool:
	return is_instance_valid(app) and app.menu.page == "shared_stadium_pool" \
		and is_instance_valid(session.card) and session.card.is_inside_tree() \
		and app.menu._body.is_ancestor_of(session.card)


static func _current(app: Node, session: Dictionary) -> bool:
	if not _attached(app, session) or Transaction.busy(app.menu) or not Access.editable(app) or not StadiumPoolWorkshopUI.WORKSHOP_ENABLED:
		return false
	var paid: ClubAssetLedger = Access.ledger(app)
	return paid != null and paid.revision() == session.revision


static func _reload(app: Node, session: Dictionary, changed: bool) -> void:
	if _attached(app, session):
		_workshop()._navigate(app, changed, _reload_confirmed.bind(app, session))


static func _reload_confirmed(app: Node, session: Dictionary) -> void:
	# Reload must remain available when owner revision/access changed; only the
	# originating view may navigate, including after a discard confirmation.
	if _attached(app, session):
		_workshop().show(app)


static func _feedback(session: Dictionary, message: String) -> void:
	session.card.get_node("SharedPoolFeedback").text = message


static func _move(app: Node, session: Dictionary) -> void:
	if not _current(app, session):
		return
	var paid: ClubAssetLedger = Access.ledger(app)
	if paid == null or paid.revision() != session.revision:
		_feedback(session, StadiumPoolWorkshopUI.STALE)
		return
	var card: VBoxContainer = session.card
	var next: Dictionary = StadiumPoolOwnedLayout.relocated(session.draft, paid.construction(),
		paid.surface_owned(), paid.view().land, Vector2(card.get_node("PoolX").value,
		card.get_node("PoolZ").value), card.get_node("PoolYaw").selected * 90)
	if next.is_empty():
		_feedback(session, "Invalid placement. Last valid preview kept.")
		return
	show(app, next, session.revision)


static func _store(app: Node, session: Dictionary) -> void:
	if _current(app, session):
		var paid: ClubAssetLedger = Access.ledger(app)
		if paid != null and paid.revision() == session.revision:
			show(app, StadiumPoolOwnedLayout.base(session.draft), session.revision)


static func _save(app: Node, session: Dictionary) -> void:
	if not _current(app, session):
		return
	Transaction.run(app, _workshop()._origin_guard(app.menu), "SAVING SHARED POOL DRAFT…",
		Access.save_draft.bind(app, session.draft, session.revision), _finished.bind(app, session, false))


static func _finished(result: Dictionary, app: Node, session: Dictionary, applied: bool) -> void:
	if result.ok:
		app.notice = "Field saved for future season admissions. Existing fields are unchanged." if applied else "Shared draft saved. Apply it for future seasons."
		_workshop().show(app)
	elif Access.ledger(app) == null:
		app.notice = result.error
		_workshop().show(app)
	else:
		_feedback(session, result.error)


static func _ask(app: Node, session: Dictionary) -> void:
	if _current(app, session):
		app._confirm("Apply this shared Pool layout for future seasons? Current and paused fields stay unchanged. No Club Bucks are charged.", _workshop()._route_action(app, _apply.bind(app, session)))


static func _apply(app: Node, session: Dictionary) -> void:
	if not _current(app, session):
		return
	Transaction.run(app, _workshop()._origin_guard(app.menu), "APPLYING SHARED POOL FIELD…",
		Access.apply_draft.bind(app, session.draft, session.revision), _finished.bind(app, session, true))


static func _catalog(app: Node, session: Dictionary) -> void:
	if _current(app, session):
		var paid: ClubAssetLedger = Access.ledger(app)
		if paid != null and ClubCareer.same(session.draft, paid.view().stadium_draft):
			_workshop().show_catalog(app, "ST-006")


static func _upgrades(app: Node, session: Dictionary) -> void:
	if _current(app, session):
		var paid: ClubAssetLedger = Access.ledger(app)
		if paid != null and ClubCareer.same(session.draft, paid.view().stadium_draft):
			_workshop().show_upgrades(app, 0, 1)


static func _field_editor(app: Node, session: Dictionary) -> void:
	if _current(app, session) and session.draft.get("version") == 12:
		# Carry the exact unsaved storage base forward; no silent discard or owner write.
		_workshop().show(app, session.draft.duplicate(true), session.revision)
