extends "res://src/tests/league_home_paid_clearance_owner_test.gd"
## Fresh isolated durable owners; synthetic title income, actual public Save/Apply/entry.
const Data = preload("res://src/tests/league_separate_home_replay_test.gd")
var layout_version: int = 14

func _source() -> SeasonState:
	var source: SeasonState = SeasonState.create(38142, false, true, true)
	var wins: Array = []
	for repeat in range(20 if layout_version == 47 else (12 if layout_version in [14, 15] else 0)): wins.append({"league": "standard", "tier": 0})
	for tier in range(4): wins.append({"league": "dugout", "tier": tier})
	source.career = Fixture.prefix(wins)
	return source

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--special-layout="): layout_version = int(argument.trim_prefix("--special-layout="))
	if not require(layout_version in [14, 15, 17, 47], "explicit separate owner test format"): return
	var source: SeasonState = _source()
	if not require(source.career != null and source.career.start(source), "synthetic funded source"): return
	for pick in range(4): check(source.choose_player(source.offers()[0]), "source owned draft")
	var origin: Dictionary = SeasonSave.snapshot(source)
	var profile: Dictionary = Profile.capture_access_season(origin, "special-lineage", "special-owner")
	var dynasty: SeasonState = Bridge.create(profile)
	if not require(dynasty != null, "unchanged source Dynasty"): return
	var context: Dictionary = Closed.binding_for(dynasty, profile.owner_id, profile.lineage_id, 0, 1, "special-lineage:1")
	var created: Dictionary = Store.create({"lineage": Lineage.create(profile),
		"snapshot": Closed.wrap_checkpoint(SeasonSave.snapshot(dynasty), context),
		"session_id": context.session_id, "origin": origin}, path)
	if not require(created.status == "committed", "fresh isolated owner") or not _open(1): return
	var initial: Dictionary = current()
	var frozen: Dictionary = SeasonSave.snapshot(SeasonSave.restore())
	if layout_version in [14, 15, 47]:
		for land: String in ["expanded", "club"]:
			var command: Dictionary = Assets.Upgrades.command(Authority._history(current().career), "stadium_land", land, paid(current()).revision())
			if not _asset(command): return
		var item: String = "ST-046" if layout_version == 47 else "ST-090"
		var command: Dictionary = ClubConstruction.copy_command(Authority._history(current().career), item, paid(current()).revision()) if layout_version == 47 else Assets.Upgrades.command(Authority._history(current().career), "stadium_scoreboard", item, paid(current()).revision())
		if not _asset(command): return
	var ledger: ClubAssetLedger = paid(current())
	var layout: Dictionary = Data.field_for(ledger, layout_version, true)
	if not require(not layout.is_empty() and StadiumOwnedLayout.validate(layout, ledger.construction(), ledger.wall_pieces(), ledger.surface_owned(), ledger.view().land, ledger.scoreboards()).ok, "complete exact paid layout"): return
	if not _asset({"op": "stadium_draft", "layout": layout}): return
	var drafted: Dictionary = current()
	check(paid(drafted).view().stadium_draft.version == layout_version and paid(drafted).view().stadium_active.version == 1, "Save preserves independent preview and active field")
	check(_candidate(drafted, 2).home_property.layout.version == 1, "Save cannot refresh next admission")
	var request: Dictionary = {"op": "stadium_assets", "request_id": "special-apply", "expected_revision": drafted.revision,
		"command": {"id": "special-apply", "rev": paid(drafted).revision(), "op": "stadium_apply", "layout": layout, "geometry": StadiumOwnedLayout.geometry(ledger.view().land, layout)}}
	var wrong: Dictionary = request.duplicate(true)
	wrong.expected_revision -= 1
	check(Store.transact(wrong, path).status == "blocked", "stale owner Apply refused")
	wrong = request.duplicate(true)
	wrong.command.layout.family = "foreign"
	check(Store.transact(wrong, path).status == "blocked", "foreign complete family refused")
	check(ClubCareer.same(current(), drafted), "rejected operations preserve exact owner")
	var applied: Dictionary = Store.transact(request, path)
	if not require(applied.status == "committed", "real owner separate-contract Apply"): return
	check(ClubCareer.same(Store.transact(request, path).owner, applied.owner), "Apply retry cannot charge twice")
	_frozen(initial, applied.owner, frozen)
	var candidate: Dictionary = _candidate(applied.owner, 2)
	if not require(not candidate.is_empty() and Bound.separate_shared_home(candidate.home_property), "future explicit complete home admission"): return
	check(ClubCareer.same(candidate.home_property, StadiumLayoutSnapshot.capture(paid(applied.owner), true)), "full paid journal capture remains exact")
	check(Store.restore(path).status == "committed", "owner cold replay before entry")
	if not _close() or not _open(2): return
	var selected: SeasonState = SeasonSave.restore()
	var runtime: ClubAssetLedger = Runtime.paid_ledger(selected)
	check(selected != null and selected.home_property.layout.version == layout_version and runtime != null
		and ClubCareer.same(StadiumLayoutSnapshot.capture(runtime, true), selected.home_property), "cold selected exact complete paid runtime")
	check(Store.restore(path).status == "committed", "final owner and selected reference cold replay")
	var final: Dictionary = current()
	var altered: SeasonState = SeasonSave.restore()
	altered._dynasty_owner_binding = altered._dynasty_owner_binding.duplicate(true)
	altered._dynasty_owner_binding.revision -= 1
	check(Runtime.paid_ledger(altered) == null and ClubCareer.same(current(), final), "stale selected binding cannot borrow runtime")
	print("SEPARATE_HOME_OWNER layout=", layout_version, " checks=", checks, " failures=", failures)
