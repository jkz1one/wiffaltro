extends RefCounted
## Explicit editor data/transaction boundary. Shared authority is never disguised
## as a live sequential career, and its changes never refresh a frozen session.
const Authority = preload("res://src/gameplay/season/dynasty_career_authority.gd")
const Assets = preload("res://src/gameplay/season/dynasty_stadium_assets.gd")
const Store = preload("res://src/gameplay/season/dynasty_owner_store.gd")
const PENDING: StringName = &"shared_stadium_pending"


static func shared(_app: Node) -> bool:
	return SeasonSave.dynasty_owner_bound()


static func context(app: Node) -> Dictionary:
	if app.season == null or app.dynasty_owner == null:
		return {}
	var current: Dictionary = app.dynasty_owner.found()
	var owner: Dictionary = current.get("owner", {})
	var binding: Dictionary = app.season._dynasty_owner_binding
	if current.get("status") != "ready" or owner.get("version") != 2 \
		or binding.get("path") != SeasonSave._dynasty_owner_path \
		or binding.get("revision") != current.get("revision") \
		or binding.get("session_id") != owner.get(str(owner.get("selected", "")), {}).get("session_id"):
		return {}
	return current


static func ledger(app: Node) -> ClubAssetLedger:
	if not shared(app):
		return ClubPlayers.assets(app.season.career) if app.season != null and app.season.career != null else null
	var current: Dictionary = context(app)
	return null if current.is_empty() else ClubPlayers.assets(Authority._history(current.owner.career))


static func presentation(app: Node) -> Dictionary:
	## One locally qualified context per render, never retained across callbacks.
	if not shared(app):
		return {"ledger": ledger(app), "editable": ClubConstruction.editable(app.season)}
	var current: Dictionary = context(app)
	if current.is_empty():
		return {"ledger": null, "editable": false}
	return {"ledger": ClubPlayers.assets(Authority._history(current.owner.career)),
		"editable": app.dynasty_owner._safe_hub() and _editable_phase(app)}


static func _editable_phase(app: Node) -> bool:
	return app.season != null and (app.season.phase == SeasonState.Phase.COMPLETE
		or (app.season.phase == SeasonState.Phase.DRAFT and app.season.picks.is_empty()))


static func editable(app: Node) -> bool:
	if not shared(app):
		return ClubConstruction.editable(app.season)
	return not context(app).is_empty() and app.dynasty_owner._safe_hub() and (
		app.season.phase == SeasonState.Phase.COMPLETE
		or (app.season.phase == SeasonState.Phase.DRAFT and app.season.picks.is_empty()))


static func save_draft(app: Node, layout: Dictionary, revision: int) -> Dictionary:
	if not shared(app):
		return ClubConstruction.save_draft(app.season, layout, revision)
	return transact(app, {"id": "shared-stadium-draft:%d" % revision, "rev": revision,
		"op": "stadium_draft", "layout": layout.duplicate(true)})


static func apply_draft(app: Node, layout: Dictionary, revision: int) -> Dictionary:
	if not shared(app):
		return ClubConstruction.apply_draft(app.season, layout, revision)
	var paid: ClubAssetLedger = ledger(app)
	if paid == null:
		return ClubAssetLedger._error("Recover the exact shared owner before applying a field.")
	return transact(app, {"id": "shared-stadium-apply:%d" % revision, "rev": revision,
		"op": "stadium_apply", "layout": layout.duplicate(true),
		"geometry": StadiumOwnedLayout.geometry(paid.view().land, layout)})


static func buy_copy(app: Node, item: String, revision: int) -> Dictionary:
	if not shared(app):
		return ClubConstruction.buy_copy(app.season, item, revision)
	var current: Dictionary = context(app)
	if current.is_empty():
		return ClubAssetLedger._error("Recover the exact shared owner before purchasing.")
	var command: Dictionary = ClubConstruction.copy_command(Authority._history(current.owner.career), item, revision)
	command.id = "shared-stadium-buy:%d" % revision
	return transact(app, command)



static func transact(app: Node, command: Dictionary) -> Dictionary:
	var current: Dictionary = context(app)
	if current.is_empty() or not app.dynasty_owner._safe_hub():
		return ClubAssetLedger._error("Save or recover the exact shared session before changing the stadium.")
	var replay: Dictionary = Assets.command(current.owner.career, command)
	if replay.get("applied", {}).get("replayed", false) \
		and ClubCareer.same(replay.get("authority", {}), current.owner.career):
		app.remove_meta(PENDING)
		return replay.applied
	if not _editable_phase(app):
		return ClubAssetLedger._error("Shared stadium editing opens between seasons, before the first draft pick.")
	var pending: Dictionary = app.get_meta(PENDING, {})
	if not pending.is_empty() and not ClubCareer.same(pending.command, command):
		return ClubAssetLedger._error("Recover or retry the previous exact stadium transaction first.")
	if pending.is_empty():
		pending = app.dynasty_owner._request("stadium_assets", current, {"command": command.duplicate(true)})
		app.set_meta(PENDING, pending.duplicate(true))
	var outcome: Dictionary = Store.commit(pending, SeasonSave._dynasty_owner_path)
	if not app.dynasty_owner._promote(outcome):
		if app.dynasty_owner.found().get("status") == "ready":
			app.remove_meta(PENDING)
		return ClubAssetLedger._error(app.notice)
	var owner: Dictionary = app.dynasty_owner.found().owner
	if not ClubCareer.same(owner.get("operands", {}), pending) \
		or not owner.get("asset_receipt", {}).get("ok", false):
		return ClubAssetLedger._error("The saved stadium transaction needs exact receipt recovery.")
	app.remove_meta(PENDING)
	return owner.asset_receipt.duplicate(true)


static func copy_quote(app: Node, item: String) -> Dictionary:
	var current: Dictionary = context(app)
	if current.is_empty() or not app.dynasty_owner._safe_hub() or not _editable_phase(app):
		return ClubAssetLedger._error("Open the shared catalog between seasons, before drafting.")
	var club: ClubCareer = Authority._history(current.owner.career)
	var paid: ClubAssetLedger = ClubPlayers.assets(club)
	var command: Dictionary = ClubConstruction.copy_command(club, item, paid.revision())
	command.id = "shared-stadium-buy:%d" % paid.revision()
	return _quoted(current, paid, command)


static func commit_quote(app: Node, quote: Dictionary) -> Dictionary:
	var current: Dictionary = context(app)
	if current.is_empty() or current.revision != quote.get("owner_revision"):
		return ClubAssetLedger._error("The shared career changed. Review a new quote before buying.")
	return transact(app, quote.get("command", {}))


static func upgrade_quote(app: Node, operation: String, item: String, quantity: int = 1) -> Dictionary:
	var current: Dictionary = context(app)
	if current.is_empty() or not app.dynasty_owner._safe_hub() or not _editable_phase(app):
		return ClubAssetLedger._error("Open shared upgrades between seasons, before drafting.")
	var club: ClubCareer = Authority._history(current.owner.career)
	var paid: ClubAssetLedger = ClubPlayers.assets(club)
	var command: Dictionary = Assets.Upgrades.command(club, operation, item, paid.revision(), quantity)
	if command.is_empty():
		return ClubAssetLedger._error("This upgrade is not enabled in the existing public workshop.")
	if not Assets.allowed(app.season, command):
		return ClubAssetLedger._error("This operation requires a completed season or the existing complete-boundary field profile. Night fields remain frozen until completion.")
	return _quoted(current, paid, command)


static func _quoted(current: Dictionary, paid: ClubAssetLedger, command: Dictionary) -> Dictionary:
	var proposed: Dictionary = Assets.command(current.owner.career, command)
	if not proposed.applied.ok:
		return proposed.applied
	return {"ok": true, "error": "", "command": command, "owner_revision": current.revision,
		"cost": paid.balance() - Authority.view(proposed.authority).balance}


static func editor_ledger(menu: SeasonMenu, supplied: ClubAssetLedger = null) -> ClubAssetLedger:
	# Shared cards receive a render-local paid ledger explicitly. Ordinary defaults stay ordinary.
	return supplied if supplied != null else ClubPlayers.assets(menu.app.season.career)


static func editor_preview(menu: SeasonMenu, draft: Dictionary, revision: int, preview: Callable) -> void:
	if preview.is_valid():
		preview.call(draft, revision)
	else:
		StadiumEditorUI.show(menu, draft, revision)
