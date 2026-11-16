extends Node
const Live = preload("res://src/gameplay/season/dynasty_league_home_live.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
	return ok
func _ready() -> void:
	for pattern: String in StadiumLightingKitItems.PATTERNS:
		_run(pattern)
	print("FLAT_DAY_LIGHTING checks=", checks, " failures=", failures, " physical_games=0")
	get_tree().quit(0 if failures == 0 else 1)
func _run(pattern: String) -> void:
	var paid: ClubAssetLedger = ClubAssetLedger.new_club(163, [10000, 10000, 10000],
		[{"seasons": 1, "wins": 3}, {"seasons": 1, "wins": 3}, {"seasons": 1, "wins": 3}])
	if not check(paid.commit({"id": "clear", "rev": 0, "op": "stadium_salvage_clear", "copy": StadiumStock.SALVAGE_COPY,
		"price_version": 1, "through": 3}).ok, pattern + " exact paid car clearance"): return
	if not check(paid.commit({"id": "kit", "rev": paid.revision(), "op": "stadium_buy", "through": 3,
		"progress_through": 3, "price_version": 33, "item": "ST-111", "quantity": 1}).ok, pattern + " actual whole paid kit"): return
	var layout: Dictionary = StadiumLightingKitItems.place(paid.view().stadium_draft, paid.construction(), "purchase:kit:0", pattern)
	if pattern == "MIXED_EDGE":
		if not check(paid.commit({"id": "poles", "rev": paid.revision(), "op": "stadium_buy", "through": 3,
			"progress_through": 3, "price_version": 7, "item": "ST-037", "quantity": 2}).ok, "mixed paid independent poles"): return
		layout.lights = [{"copy": "purchase:poles:0", "site": "YLIGHT-RL"}, {"copy": "purchase:poles:1", "site": "YLIGHT-RR"}]
	if not check(paid.commit({"id": "draft", "rev": paid.revision(), "op": "stadium_draft", "layout": layout}).ok, pattern + " draft kit"): return
	if not check(paid.commit({"id": "apply", "rev": paid.revision(), "op": "stadium_apply", "layout": layout,
		"geometry": StadiumOwnedLayout.geometry("backyard", layout)}).ok, pattern + " Apply kit"): return
	var home: Dictionary = StadiumLayoutSnapshot.capture(paid, true)
	check(home.layout.version == 43 and home.layout.lighting_kits.size() == 1 and Live.flat_shared_home(home)
		and StadiumLayoutSnapshot.matches(home, paid), pattern + " complete paid family43 day admission")
	var validated: Dictionary = StadiumHomeLayout.validate(home.layout, StadiumLayoutSnapshot.ownership(home), home.tier)
	check(validated.ok and not validated.night_qualified, pattern + " complete lighting stays unqualified for Night")
	var seed: int = 0
	while not StadiumFixtureEnvironment.is_night_seed(seed): seed += 1
	var field: Dictionary = home.duplicate(true)
	field.version = 9
	field.environment = StadiumFixtureEnvironment.capture(home, seed, 3)
	check(StadiumFixtureEnvironment.is_night_seed(seed) and field.environment.mode == "day" and field.environment.profile == "",
		pattern + " even legacy-night seed remains exact day")
	check(StadiumLayoutSnapshot.valid(field) and StadiumLayoutSnapshot.matches(field, paid), pattern + " full paid fixture9 unchanged")
	check(not Live.supported(field, {"league": "dugout", "tier": 0}), pattern + " fixture cannot be entry")
	for wrapper: int in [26, 27, 36]:
		var bad: Dictionary = field.duplicate(true)
		bad.version = wrapper
		check(not Live.flat_shared_home(bad), pattern + " Night wrapper excluded " + str(wrapper))
	var season: SeasonState = SeasonState.create(97313)
	season.home_property = home
	check(season.owned_surface_night.is_empty(), pattern + " installed kit creates no season Night policy")
	var bad: Dictionary = home.duplicate(true)
	bad.layout.lighting_kits[0].copy = "unowned-kit"
	check(not Live.flat_shared_home(bad), pattern + " unowned kit refused")
