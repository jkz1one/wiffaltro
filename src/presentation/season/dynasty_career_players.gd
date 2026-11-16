extends RefCounted
## Adapter to the existing pack ledger. No per-session career or duplicate wallet.

const Authority = preload("res://src/gameplay/season/dynasty_career_authority.gd")
const Store = preload("res://src/gameplay/season/dynasty_owner_store.gd")


static func view(app: Node) -> Dictionary:
	if not app.dynasty_owner.ready():
		return {}
	var owner: Dictionary = app.dynasty_owner.found().owner
	var result: Dictionary = (load("res://src/gameplay/season/working_pitch_dynasty_authority.gd").player_view(owner.career)
		if owner.get("version") == 3 else Authority.player_view(owner.career))
	if not result.is_empty():
		result["subtitle"] = "Permanent ownership • Shared club collection"
		result["description"] = (
			"Fresh alternate seasons freeze the currently owned draft and recruit pool. Purchases "
			+ "do not expand an active or paused pool. Dynasty keeps its carried roster; buying a "
			+ "player does not replace anyone or create a Dynasty replacement choice."
		)
	return result


static func transact(app: Node, command: Dictionary) -> Dictionary:
	if not app.dynasty_owner.ready() or not app.dynasty_owner._safe_hub():
		return ClubAssetLedger._error("Save or recover the exact session before changing ownership.")
	var current: Dictionary = app.dynasty_owner.found()
	if current.owner.get("version") == 3:
		return ClubAssetLedger._error("Shared player purchases are not yet supported by current-pitch Dynasty. Your ownership is unchanged.")
	# A replayed ledger command is already durable. Verify it without spending,
	# reseeding a reveal or requiring that it remain the owner's latest action.
	var replay: Dictionary = Authority.player_command(current.owner.career, command)
	if replay.get("applied", {}).get("replayed", false) and ClubCareer.same(
		replay.get("authority", {}), current.owner.career
	):
		app._player_asset_pending = {}
		return _notice(replay.applied, command)
	if not app._player_asset_pending.is_empty():
		var prior: Dictionary = app._player_asset_pending
		var prior_replay: Dictionary = Authority.player_command(current.owner.career, prior.command)
		if prior_replay.get("applied", {}).get("replayed", false) and ClubCareer.same(
			prior_replay.get("authority", {}), current.owner.career
		):
			app._player_asset_pending = {}
		elif not ClubCareer.same(prior.command, command):
			return ClubAssetLedger._error("Recover or retry the previous exact player transaction first.")
	if app._player_asset_pending.is_empty():
		app._player_asset_pending = app.dynasty_owner._request("player_assets", current,
			{"command": command.duplicate(true)})
	var request: Dictionary = app._player_asset_pending.duplicate(true)
	var outcome: Dictionary = Store.commit(request, SeasonSave._dynasty_owner_path)
	if not app.dynasty_owner._promote(outcome):
		if app.dynasty_owner.found().get("status") == "ready":
			# A rejected, uncommitted command may be corrected. A pending write may not.
			app._player_asset_pending = {}
		else:
			app.menu.show_home()
		return ClubAssetLedger._error(app.notice)
	var owner: Dictionary = app.dynasty_owner.found().owner
	if not ClubCareer.same(owner.get("operands", {}), request) \
		or not owner.get("asset_receipt", {}).get("ok", false):
		return ClubAssetLedger._error("The saved player transaction needs exact receipt recovery.")
	app._player_asset_pending = {}
	return _notice(owner.asset_receipt, command)


static func _notice(receipt: Dictionary, command: Dictionary) -> Dictionary:
	var result: Dictionary = receipt.duplicate(true)
	if command.get("op") == "player_pack_pick":
		result["notice"] = "Player permanently owned for fresh alternates. Dynasty's roster stays intact."
	return result
