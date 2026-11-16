extends "res://src/presentation/season/dynasty_owner_controller.gd"
## Development-only labels and empty-slot entry. Domain/store are unchanged.
const Catalog = preload("res://src/presentation/season/league_catalog_ui.gd")


func _init(owner_app: Node) -> void:
	super(owner_app)


func switch_to(target: String, expected: int = -1, seed_value: int = -1) -> bool:
	if target == "other" and found().get("owner", {}).get("other", {}).is_empty():
		app.notice = "Use the closed catalog to prepare your first alternate."
		return false
	return super.switch_to(target, expected, seed_value)


func ask_switch(target: String) -> void:
	if not _safe_hub():
		return
	var current: Dictionary = found()
	var owner: Dictionary = current.get("owner", {})
	if (
		current.get("status") != "ready"
		or owner.is_empty()
		or app.season == null
		or SeasonSave._dynasty_owner_content_blocked
	):
		app.notice = "Recover the saved owner before switching."
		return
	if target == "other" and owner.other.is_empty():
		Catalog.show(app)
		return
	var expected: int = int(current.revision)
	var name: String = Catalog.label(owner.other.profile.league) if target == "other" else "Dynasty"
	app._confirm(
		"Resume your saved %s season? Your current season will be here when you return." % name,
		func() -> void: switch_to(target, expected)
	)
	app._dialog.get_cancel_button().grab_focus()


func add_controls(menu: SeasonMenu, parent: Control) -> void:
	var current: Dictionary = found()
	var owner: Dictionary = current.get("owner", {})
	if (
		current.get("status") != "ready"
		or owner.is_empty()
		or app.season == null
		or SeasonSave._dynasty_owner_content_blocked
	):
		menu._button(parent, "RECOVER SAVE", recover)
		return
	if owner.selected == "other":
		menu._button(parent, "RETURN TO DYNASTY", ask_switch.bind("dynasty"))
	else:
		if not owner.other.is_empty():
			menu._button(
				parent,
				"RESUME " + Catalog.label(owner.other.profile.league).to_upper(),
				ask_switch.bind("other")
			)
		var next_label: String = (
			"NEXT SEASON"
			if owner.lineage.state == "closed"
			else (
				"FINISH SEASON"
				if app.season.phase == SeasonState.Phase.COMPLETE
				else "ABANDON SEASON"
			)
		)
		menu._button(parent, next_label, ask_next)
	menu._button(parent, "PLAYTEST LEAGUES", Catalog.show.bind(app))
