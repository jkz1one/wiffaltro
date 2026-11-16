class_name StadiumWaterfallAnimationUI
extends RefCounted
## Explicit paid-copy presentation selection. No silent migration or placement changes.


static func offer(
	menu: SeasonMenu, ledger: ClubAssetLedger, draft: Dictionary, revision: int, enabled: bool, preview: Callable = Callable()
) -> void:
	var checked: Dictionary = StadiumEditorUI._checked(ledger, draft)
	if not checked.ok:
		return
	var copies: Array[String] = []
	for row: Dictionary in checked.placements:
		if row.item == "ST-046":
			copies.append(row.copy)
	if copies.is_empty():
		return
	var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(card, "WATERFALL MOTION", 22)
	(
		SeasonPages
		. wrapped(
			card,
			(
				"Optional moving-water presentation for these exact installed copies. Full size, "
				+ "placement, reservations and live-ball rules stay unchanged. Old saved layouts stay "
				+ "static. Motion freezes during aiming, pitches, live balls and pause."
			)
		)
	)
	copies.sort()
	for copy: String in copies:
		var button: Button = menu._button(
			card,
			"ENABLE MOTION • " + copy,
			_preview.bind(menu,
				StadiumWaterfallAnimationLayout.select(draft, copy, true, ledger.surface_owned()),
				revision, preview, enabled)
		)
		button.set_meta("waterfall_motion_enable", copy)
		button.disabled = not enabled


static func show(
	menu: SeasonMenu, ledger: ClubAssetLedger, draft: Dictionary, revision: int
) -> void:
	var season: SeasonState = menu.app.season
	var view: Dictionary = ledger.view()
	var changed: bool = not ClubCareer.same(draft, view.stadium_draft)
	var stale: bool = revision != ledger.revision()
	var editable: bool = ClubConstruction.editable(season)
	var checked: Dictionary = StadiumEditorUI._checked(ledger, draft)
	var ready_now: bool = (
		not season.home_property.is_empty() and ClubCareer.same(season.home_property.layout, draft)
	)
	var applied: bool = (
		ClubCareer.same(draft, view.stadium_active)
		and (season.phase != SeasonState.Phase.DRAFT or ready_now)
	)
	menu._screen(
		"stadium", "STADIUM WORKSHOP", "MOVING WATER • Exact owned copies • Save, then Apply"
	)
	if not checked.ok:
		SeasonPages.wrapped(menu._body, checked.error)
		# Reject malformed motion drafts before allocating a world or exposing edit actions.
		menu._button(menu._footer, "RELOAD SAVED", StadiumEditorUI.show.bind(menu, {}, -1))
		menu._button(menu._footer, "CLUB RECORD", StadiumEditorUI._back.bind(menu, changed))
		return
	(
		SeasonPages
		. wrapped(
			menu._body,
			(
				(
					"Retained base revision %d. This choice adds presentation only; live waterfalls and "
					+ "out-of-play plaza waterfalls keep their separate rules. Water is animated between "
					+ "plays and freezes during aiming, active play, pause and long frames."
				)
				% draft.get("animation_base", 0)
			)
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
	var preview: StadiumDraftPreview = StadiumDraftPreview.new()
	menu._body.add_child(preview)
	preview.build(
		draft,
		ledger.construction(),
		true,
		view.land,
		ledger.wall_pieces(),
		ledger.scoreboards(),
		ledger.surface_owned()
	)
	menu._button(menu._footer, "FIELD VIEW", preview.overview)
	SeasonPages.wrapped(
		menu._body,
		(
			"READ-ONLY DRAFT PREVIEW • "
			+ ("Applied" if applied else "Save and apply to use this layout")
		)
	)
	if checked.ok:
		for row: Dictionary in checked.placements:
			if row.item != "ST-046":
				continue
			var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
			menu._label(card, "OWNED WATERFALL • " + row.copy, 22)
			var moving: bool = draft.waterfall_motion.has(row.copy)
			SeasonPages.wrapped(
				card,
				(
					("MOVING WATER" if moving else "STATIC WATER")
					+ " • "
					+ row.site
					+ " • Moving and storage are free"
				)
			)
			var toggle: Button = menu._button(
				card,
				"KEEP STATIC" if moving else "ENABLE MOTION",
				StadiumEditorUI.show.bind(
					menu,
					StadiumWaterfallAnimationLayout.select(draft, row.copy, not moving),
					revision
				)
			)
			toggle.set_meta("waterfall_motion_toggle", row.copy)
			toggle.disabled = not editable or stale
			var store: Button = menu._button(
				card,
				"STORE THIS COPY",
				StadiumEditorUI.show.bind(
					menu, StadiumWaterfallAnimationLayout.store_copy(draft, row.copy), revision
				)
			)
			store.set_meta("waterfall_motion_store", row.copy)
			store.disabled = not editable or stale
			menu._button(card, "FOCUS IN PREVIEW", preview.focus_copy.bind(row.copy))
	var edit_base: Button = menu._button(
		menu._body,
		"KEEP ALL STATIC / EDIT UNDERLYING LAYOUT",
		StadiumEditorUI.show.bind(menu, StadiumWaterfallAnimationLayout.base(draft), revision)
	)
	edit_base.disabled = not editable or stale
	edit_base.tooltip_text = ("Explicitly removes only motion selection from this draft; all owned " \
		+ "placements are retained. Save and Apply are still required.")
	var save: Button = menu._button(
		menu._footer, "SAVE DRAFT", StadiumEditorUI._save.bind(menu, draft, revision)
	)
	save.disabled = not editable or stale or not checked.ok or not changed
	var apply: Button = menu._button(
		menu._footer, "APPLY LAYOUT", StadiumEditorUI._apply.bind(menu, draft, revision)
	)
	apply.disabled = (
		not ClubConstruction.can_apply(season)
		or stale
		or not checked.ok
		or changed
		or applied
		or (season.phase == SeasonState.Phase.DRAFT and not season.home_property.has("boundary"))
	)
	apply.tooltip_text = "Save the draft first. Applying and storage cost no Club Bucks."
	menu._button(menu._footer, "RELOAD SAVED", StadiumEditorUI.show.bind(menu, {}, -1))
	menu._button(menu._footer, "CLUB RECORD", StadiumEditorUI._back.bind(menu, changed))

# Shared owners use the ordinary explicit motion successor, never generic base cards.
static func controls(menu: SeasonMenu, draft: Dictionary, revision: int,
	enabled: bool, preview: Callable) -> void:
	for copy: String in StadiumWaterfallAnimationLayout.placed_copies(draft):
		var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
		menu._label(panel, "OWNED WATERFALL • " + copy, 22)
		var moving: bool = draft.waterfall_motion.has(copy)
		var toggle: Button = menu._button(panel, "KEEP STATIC" if moving else "ENABLE MOTION",
			_preview.bind(menu, StadiumWaterfallAnimationLayout.select(draft, copy, not moving),
				revision, preview, enabled))
		toggle.set_meta("waterfall_motion_toggle", copy)
		toggle.disabled = not enabled
		var storage: Button = menu._button(panel, "STORE THIS COPY",
			_preview.bind(menu, StadiumWaterfallAnimationLayout.store_copy(draft, copy),
				revision, preview, enabled))
		storage.set_meta("waterfall_motion_store", copy)
		storage.disabled = not enabled
	var base: Button = menu._button(menu._body, "KEEP ALL STATIC / EDIT UNDERLYING LAYOUT",
		_preview.bind(menu, StadiumWaterfallAnimationLayout.base(draft),
			revision, preview, enabled))
	base.set_meta("waterfall_motion_base", true)
	base.disabled = not enabled

static func _preview(menu: SeasonMenu, draft: Dictionary, revision: int,
	preview: Callable, enabled: bool) -> void:
	if enabled:
		preload("res://src/presentation/stadium/stadium_career_access.gd").editor_preview(menu, draft, revision, preview)
