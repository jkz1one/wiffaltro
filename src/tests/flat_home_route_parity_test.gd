extends "res://src/tests/normal_league_home_enrollment_test.gd"
## Actual main/controller/storage route with explicitly authored unlock/income fixtures.
## No natural title, played physical game or source-profile qualification is claimed.
const Normal = preload("res://src/gameplay/season/normal_league_home.gd")
const Carried = preload("res://src/gameplay/season/dynasty_carried_home_live.gd")
const Owner = preload("res://src/gameplay/season/dynasty_career_owner_v2.gd")
const Access = preload("res://src/presentation/stadium/stadium_career_access.gd")
const CarriedRuntime = preload("res://src/gameplay/season/dynasty_carried_home_runtime.gd")

func _run(app: SeasonApp) -> void:
	app.call("_show_main_leagues")
	var choice: Button = _button(app.menu, "sponsorship", "")
	if not check(choice != null and not choice.disabled, "actual earned-fixture chooser exposes Sponsorship"): return
	choice.pressed.emit()
	var start: Button = _button(app.menu, "", "START & SAVE SEASON")
	if not check(start != null and app.league_career.candidate() != null, "detached normal93 review"): return
	start.pressed.emit()
	if not check(app.season != null and app.season._league_home_context.get("format") == 93, "actual main commits normal93"): return
	var initial: Dictionary = app.season.home_property.duplicate(true)
	var paid: ClubAssetLedger = ClubPlayers.assets(app.season.career)
	var balance: int = paid.balance()
	check(initial.version == 8 and initial.layout.version == 40, "genuine modern starting field retained")
	if not check(ClubConstruction.clear_salvage(app.season, paid.revision()).get("ok", false), "ordinary pre-draft real190 clearance recaptures"): return
	paid = ClubPlayers.assets(app.season.career)
	if not check(ClubConstruction.buy_copy(app.season, "ST-001", paid.revision()).get("ok", false), "ordinary real40 obstacle purchase"): return
	paid = ClubPlayers.assets(app.season.career)
	var copy: String = ""
	for id: String in paid.construction().copies:
		if paid.construction().copies[id].item == "ST-001": copy = id
	var layout: Dictionary = StadiumMasteryBannerItems.upgrade(paid.view().stadium_active, paid.surface_owned())
	layout.obstacles = [{"copy": copy, "site": "O-R1", "yaw": 0}]
	var before: Dictionary = app.season.home_property.duplicate(true)
	if not check(ClubConstruction.save_draft(app.season, layout, paid.revision()).get("ok", false), "ordinary Save stages exact paid41"): return
	check(ClubCareer.same(app.season.home_property, before), "draft Save cannot replace admitted active field")
	paid = ClubPlayers.assets(app.season.career)
	var revision: int = paid.revision()
	var disk: String = FileAccess.get_file_as_string(SeasonSave.path)
	DirAccess.make_dir_absolute(SeasonSave.path + ".tmp")
	check(not ClubConstruction.apply_draft(app.season, layout, revision).get("ok", false), "failed ordinary Apply stays atomic")
	check(FileAccess.get_file_as_string(SeasonSave.path) == disk and ClubCareer.same(app.season.home_property, before)
		and ClubCareer.same(app.season._league_home_context.home_property, before), "failed Apply preserves both admission pins and disk")
	DirAccess.remove_absolute(SeasonSave.path + ".tmp")
	if not check(ClubConstruction.apply_draft(app.season, layout, revision).get("ok", false), "same paid41 Apply retry publishes"): return
	check(ClubConstruction.apply_draft(app.season, layout, revision).get("replayed", false), "ordinary Apply retry does not repay")
	paid = ClubPlayers.assets(app.season.career)
	check(paid.balance() == balance - 230 and paid.construction().copies.has(StadiumStock.SALVAGE_COPY), "real debit and original stored copy preserved")
	check(Normal.matches(app.season) and app.season.home_property.layout.version == 41
		and ClubCareer.same(app.season.home_property, app.season._league_home_context.home_property), "normal93 both pins recapture exact paid41")
	var snapshot: Dictionary = SeasonSave.snapshot(app.season)
	var bad: Dictionary = snapshot.duplicate(true)
	bad.home_property = initial
	check(SeasonSave._decode(bad) == null, "old complete field cannot replace normal frozen marker")
	var cold: SeasonState = SeasonSave.restore()
	check(cold != null and ClubCareer.same(SeasonSave.snapshot(cold), snapshot), "paid41 ordinary pre-draft exact cold replay")
	app.choose_player(app.season.offers()[0])
	disk = FileAccess.get_file_as_string(SeasonSave.path)
	check(not ClubConstruction.apply_draft(app.season, layout, paid.revision()).get("ok", false)
		and not Normal.recapture(app.season, initial), "first saved pick locks both structural recapture paths")
	check(FileAccess.get_file_as_string(SeasonSave.path) == disk, "Opening Day refusal preserves disk")
	for pick in range(3): app.choose_player(app.season.offers()[0])
	if not check(app.season.picks.size() == 4 and Normal.matches(app.season), "normal four owned picks retain paid41"): return
	var roster: Array = app.season.picks.duplicate()
	var archived: String = FileAccess.get_file_as_string(SeasonSave.path)
	if not check(app.dynasty_enrollment.prepare(99602), "actual93 paid41 source prepares carried92: " + app.notice): return
	var payload: Dictionary = app.dynasty_enrollment._payload.duplicate(true)
	check(payload.snapshot.version == 92 and payload.snapshot.home_property.layout.version == 41, "review carries complete paid41")
	for field: String in ["owner_reference", "source_reference", "grant", "lineage"]:
		var forged: Dictionary = payload.duplicate(true)
		forged.snapshot[field] = {}
		check(Owner.project({}, {"op": "create", "request_id": "bad-" + field, "expected_revision": 0, "payload": forged}).is_empty(), "forged92 admission " + field + " refused")
	var forged: Dictionary = payload.duplicate(true)
	forged.snapshot.home_property = initial.duplicate(true)
	check(Owner.project({}, {"op": "create", "request_id": "bad-home", "expected_revision": 0, "payload": forged}).is_empty(), "unpaid or stale full home cannot replace92 grant")
	if not check(app.dynasty_enrollment.commit(app.dynasty_enrollment.token()), "actual explicit93 to92 enrollment commits: " + app.notice): return
	check(app.season.picks == roster and app.season._league_home_context.get("format") == 92
		and app.season.home_property.layout.version == 41 and CarriedRuntime.paid_ledger(app.season) != null, "selected92 exact carried roster and paid runtime")
	check(FileAccess.get_file_as_string(SeasonSave.path) == archived, "enrollment preserves ordinary93 source bytes")
	var current: Dictionary = app.dynasty_owner.found()
	if not check(app.dynasty_owner.start_other("dugout", current.revision, 99603), "normal controller opens alternate91 for editable shared hub"): return
	var frozen: Dictionary = app.dynasty_owner.found().owner.duplicate(true)
	var frozen_other: Dictionary = SeasonSave.snapshot(app.season)
	paid = Access.ledger(app)
	layout = StadiumWaterfallLiveItems.upgrade(paid.view().stadium_active, paid.surface_owned())
	layout.obstacles = [{"copy": copy, "site": "O-L1", "yaw": 0}]
	if not check(Access.save_draft(app, layout, paid.revision()).get("ok", false), "actual shared Save stages moved exact copy in named45"): return
	if not check(Access.apply_draft(app, layout, Access.ledger(app).revision()).get("ok", false), "actual shared Apply commits future45"): return
	current = app.dynasty_owner.found()
	check(ClubCareer.same(frozen.career.sessions, current.owner.career.sessions)
		and ClubCareer.same(frozen.dynasty, current.owner.dynasty) and ClubCareer.same(frozen.other, current.owner.other), "shared edit preserves both frozen slot references and grants")
	check(ClubCareer.same(SeasonSave.snapshot(app.season), frozen_other), "selected91 remains on admitted41")
	if not check(app.dynasty_owner.switch_to("dynasty", current.revision), "resume exact paused92 after shared edit"): return
	check(app.season.home_property.layout.version == 41 and app.season.picks == roster
		and CarriedRuntime.paid_ledger(app.season) != null, "paused92 retains paid41 and roster")
	current = app.dynasty_owner.found()
	var generation: int = int(current.owner.lineage.generation)
	if not check(app.dynasty_owner.close_current("abandon", current.revision), "explicit fixture abandonment, no title or completion reward"): return
	current = app.dynasty_owner.found()
	if not check(app.dynasty_owner.begin_next_tier(99604, current.revision, 0), "actual next-generation route captures paid45: " + app.notice): return
	current = app.dynasty_owner.found()
	check(current.owner.lineage.generation == generation + 1 and app.season._dynasty_start.season_ordinal == generation + 2
		and app.season.picks == roster and app.season.home_property.layout.version == 45, "new92 generation owns exact roster ordinal and future field")
	check(ClubCareer.same(current.owner.other, frozen.other), "next generation never rewrites paused alternate")
	check(Store.restore(app.dynasty_enrollment.path).get("status") == "committed"
		and CarriedRuntime.paid_ledger(SeasonSave.restore()) != null, "new45 selected92 owner and paid runtime cold replay")
	check(FileAccess.get_file_as_string(SeasonSave.path) == archived, "entire lineage flow preserves original normal93 archive")
