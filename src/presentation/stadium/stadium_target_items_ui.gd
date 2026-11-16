class_name StadiumTargetItemsUI
extends RefCounted
## Target-only socket and earned strikeout gate; no paid catching backstop is bundled.


static func card(
	menu: SeasonMenu,
	parent: VBoxContainer,
	draft: Dictionary,
	copy: String,
	revision: int,
	enabled: bool,
	on_preview: Callable = Callable()
) -> void:
	var active: bool = draft.get("target", "") == copy
	var choice: OptionButton = StadiumEditorUI._options(
		parent, ["Stored", "Receiver primary • Framed target"], 1 if active else 0
	)
	choice.set_meta("stadium_copy", copy)
	choice.disabled = not enabled
	(
		SeasonPages
		. wrapped(
			parent,
			(
				"Replaces the backstop chair in this socket and stores it free. "
				+ ("A catching assembly is purchased separately. Removing the target " + \
					"stores a legacy portable net; an owned cage or tall net stays " + "installed.")
			)
		)
	)
	choice.item_selected.connect(
		func(index: int) -> void:
			if not choice.is_inside_tree() or choice.disabled or index < 0 or index >= choice.item_count:
				return
			if choice.is_item_disabled(index):
				return
			if index == 0 and not active:
				return
			var next: Dictionary = StadiumTargetItems.upgrade(draft)
			next.target = copy if index == 1 else ""
			if index == 1:
				next.receiver = ""
			elif next.has("net"):
				next.net = ""
			if on_preview.is_valid():
				on_preview.call(next, revision)
			else:
				StadiumEditorUI.show(menu, next, revision)
				StadiumEditorUI._focus_choice.call_deferred(menu, copy, false)
	)


static func purchases(menu: SeasonMenu, ledger: ClubAssetLedger, enabled: bool) -> void:
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "STRIKE-ZONE TARGET", 22)
	var rows: Array = StadiumCareerProgress.capture(menu.app.season.career)
	var progress: Dictionary = StadiumCareerProgress.metrics(rows, rows.size())
	SeasonPages.wrapped(
		panel,
		(
			"Unlock after one completed season and 40 recorded club pitching "
			+ (
				"strikeouts. Your closed career: %d seasons • %d recorded strikeouts."
				% [progress.seasons, int(progress.get("strikeouts", 0))]
			)
		)
	)
	var quote: Dictionary = StadiumPurchases.quote(
		ledger.construction(),
		"ST-026",
		1,
		"target-preview",
		StadiumPurchases.TARGET_VERSION,
		progress
	)
	var blueprint: int = 0 if ledger.construction().blueprints.has("ST-026") else 230
	var cost: int = blueprint + 70
	SeasonPages.wrapped(
		panel,
		(
			"Blueprint owned • 70 CB per copy"
			if blueprint == 0
			else "230 blueprint + 70 copy = 300 CB • Target only"
		)
	)
	var buy: Button = menu._button(
		panel,
		"BUY FRAMED STRIKE-ZONE TARGET",
		StadiumEditorUI._buy.bind(menu, "ST-026", ledger.revision())
	)
	buy.set_meta("stadium_buy", "ST-026")
	buy.disabled = not enabled or not quote.ok or ledger.balance() < cost
	if not quote.ok:
		buy.tooltip_text = quote.error
