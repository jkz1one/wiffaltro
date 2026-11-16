extends Node
## Isolated domain fixtures. Test rewards are NOT earned gameplay or owner history.

const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")
const Frozen = preload("res://src/tests/working_pitch_legacy_fixture.gd")
const PLAYER: String = "player.alex_finch"
const ROSTER: Array[String] = [PLAYER, "player.ari_banks", "player.ash_cole", "player.rowan_chase"]
var failures: int = 0
var checks: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


static func cold(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))


static func command(build: SeasonBuild, op: String, fields: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"id": "fixture:%d" % build.revision(), "rev": build.revision(), "op": op}
	result.merge(fields)
	return result


func _ready() -> void:
	_legacy()
	_neutral_projection()
	_catalog()
	_paid_and_carry()
	_season_and_transport()
	_serialized_discriminators()
	print("Working pitch progression checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _legacy() -> void:
	var old: SeasonDevelopment = SeasonDevelopment.new("old")
	check(old.to_data().version == 1, "historical development stays v1")
	check(DevelopmentShopCatalog.lesson_ids(old).size() == 9, "historical lessons stay nine")
	for id: String in WorkingPitchCatalog.new_ids():
		check(not old.lesson_supported(id), "old decoder rejects " + id)
	for id: String in SeasonPlayerCatalog.RECIPES.values():
		var pitch: PitchDefinition = ContentDB.get_pitch(StringName(id))
		check(ClubCareer.same(SeasonPhysicalFixtures._resource(pitch), Frozen.resource(pitch)),
			"neutral new fields preserve historical resource hash " + id)
		var complete: Dictionary = SeasonPhysicalFixtures._resource(pitch, true)
		check(complete.has("movement_start") and complete.has("source_urls"),
			"current resource hash binds declared neutral fields")
	var old_season: SeasonState = SeasonState.create(317, false, true, true)
	old_season.opponents._format = 13
	for _pick in range(4):
		check(old_season.choose_player(old_season.offers()[0]), "old draft")
	var fixture: Dictionary = old_season.pending_fixture()
	check(SeasonPhysicalFixtures.request_key(old_season, fixture) ==
		Frozen.request_key(old_season, fixture),
		"old physical request key equals frozen60651b3 serializer")
	var build: SeasonBuild = SeasonBuild.new(17, ROSTER)
	var saved: Dictionary = build.to_data()
	check(saved.version == 41 and saved.catalog == SeasonBuild._signature(41), "old Build signature")
	check(SeasonBuild.from_data(cold(saved), 17, ROSTER) != null, "old Build cold replay")


func _catalog() -> void:
	var book: SeasonDevelopment = SeasonDevelopment.new("current-test")
	check(book.enable_pitch_catalog(), "fresh current admission")
	for recipe_id: String in WorkingPitchCatalog.new_ids():
		if WorkingPitchCatalog.lesson_price(recipe_id) < 0:
			check(not book.lesson_supported(recipe_id) and DevelopmentShopCatalog.targets(
				book, ROSTER, "lesson." + recipe_id).is_empty(), "unadmitted recipe stays unavailable")
			continue
		check(book.lesson_supported(recipe_id) and not DevelopmentShopCatalog.targets(
			book, ROSTER, "lesson." + recipe_id).is_empty(), "legal paid target " + recipe_id)
	var id: String = WorkingPitchCatalog.new_ids()[0]
	var learn: Dictionary = {"id": "lesson", "rev": 0, "player": PLAYER,
		"op": "learn", "target": id, "replace": ""}
	check(book.commit(learn).ok, "learn exact current recipe")
	check(not book.commit({"id": "duplicate", "rev": 1, "player": PLAYER,
		"op": "learn", "target": id, "replace": ""}).ok, "duplicate learning fails")
	for level in range(2, 6):
		check(book.commit({"id": "mastery:%d" % level, "rev": book.revision(),
			"player": PLAYER, "op": "mastery", "target": id}).ok, "mastery ladder")
	var definition: PlayerDefinition = ProgressionMatchAdapter.player(book, PLAYER)
	check(definition != null and definition.starting_pitches[-1].mastery_level == 5,
		"materialized learned recipe and mastery")
	var data: Dictionary = cold(book.to_data())
	check(data.version == WorkingPitchProgression.DEVELOPMENT_VERSION and SeasonDevelopment.from_data(data, book._season_key) != null,
		"Development5 cold replay")
	data.pitch_catalog = "wrong"
	check(SeasonDevelopment.from_data(data, book._season_key) == null, "cross-catalog rejects")


func _paid_and_carry() -> void:
	var build: SeasonBuild
	var offer: String = ""
	# Bounded generated-stock search; no forged shop offer or free lesson grant.
	for seed_value in range(64):
		build = SeasonBuild.new(seed_value, ROSTER)
		build.enable_pitch_catalog()
		if not build.commit(command(build, "reward", {"game": 0, "win": true})).ok \
			or not build.commit(command(build, "open")).ok:
			check(false, "controlled domain fixture preparation")
			return
		for key: String in build._visit.offers:
			var item: Dictionary = build.shop_item(build._visit.offers[key])
			if item.get("op") == "learn" and WorkingPitchCatalog.new_ids().has(item.recipe):
				offer = key
				break
		if not offer.is_empty():
			break
	check(not offer.is_empty(), "new lesson appears in ordinary generated shop")
	if offer.is_empty():
		return
	var item_id: String = build._visit.offers[offer]
	var item: Dictionary = build.shop_item(item_id)
	var target: Dictionary = build.targets(item_id)[0]
	var buy: Dictionary = command(build, "buy", {"offer": offer, "mode": "use",
		"player": target.player, "pitch": target.pitch, "replace": target.replace})
	var before: int = build.cash()
	check(build.preview(buy).ok and build.cash() == before, "paid preview is inert")
	check(build.commit(buy).ok and build.cash() == before - int(item.price), "exact lesson charged")
	var paid_cash: int = build.cash()
	check(build.commit(buy).replayed and build.cash() == paid_cash, "paid retry never double charges")
	var duplicate: Dictionary = command(build, "buy", {"offer": offer, "mode": "use",
		"player": target.player, "pitch": target.pitch, "replace": target.replace})
	var saved: Dictionary = build.to_data()
	check(not build.commit(duplicate).ok and ClubCareer.same(saved, build.to_data()),
		"second purchase fails atomically")
	check(not build.enable_pitch_catalog(), "no midseason catalog change")
	var restored: SeasonBuild = SeasonBuild.from_data(cold(saved), build._seed, ROSTER)
	check(restored != null and ClubCareer.same(restored.to_data(), saved), "paid Build47 cold exact")
	var profile: Dictionary = Profile.capture_build(build, "catalog-carry", "test-fixture")
	check(profile.get("version") == 3, "new carry profile binds catalog")
	var decayed: Dictionary = Profile.decay(cold(profile))
	check(not decayed.is_empty(), "new recipe survives normal paid-first decay")
	if decayed.is_empty():
		return
	var carry: SeasonBuild = SeasonBuild.new(build._seed, ROSTER)
	check(carry.enable_pitch_catalog() and
		carry.enable_league_rules(LeagueRules.capture("dynasty"))
		and carry.enable_dynasty_start(decayed.profile), "current carried build admission")
	var loaded: SeasonBuild = SeasonBuild.from_data(cold(carry.to_data()), build._seed, ROSTER)
	check(loaded != null and loaded.player(target.player).active.has(item.recipe),
		"cold carried recipe")
	var old_profile: Dictionary = profile.duplicate(true)
	old_profile.version = 1
	old_profile.erase("pitch_catalog")
	check(Profile.normalize(old_profile).is_empty(), "new recipe cannot masquerade as Profile1")


func _season_and_transport() -> void:
	var season: SeasonState = WorkingPitchProgression.create_season(318)
	check(season != null, "fresh production season entry")
	if season == null:
		return
	for _pick in range(4):
		check(season.choose_player(season.offers()[0]), "current draft preserves admission")
	var data: Dictionary = SeasonSave.snapshot(season)
	check(data.get("version") == 97, "explicit top-level97 envelope")
	if data.is_empty():
		return
	check(SeasonSave._decode(cold(data)) != null, "fresh drafted season cold restore")
	check(SeasonSave._decode(cold(data.checkpoint)) == null, "stripped97 cannot enter old57")
	check(SeasonSave._decode_payload(cold(data.checkpoint)) == null, "old leaf also rejects new book")
	var bad: Dictionary = cold(data)
	bad.pitch_catalog = "wrong"
	check(SeasonSave._decode(bad) == null, "cross-catalog envelope rejects")
	var fixture: Dictionary = season.pending_fixture()
	var key: String = SeasonPhysicalFixtures.request_key(season, fixture)
	check(key != Frozen.request_key(season, fixture), "current request binds separate catalog")
	var request: Dictionary = PhysicalRoundProcess.request_for(season, "catalog-test", key, fixture.id)
	check(request.get("version") == 7, "catalog worker uses explicit7")
	check(PhysicalRoundProcess.decode_request(cold(request), "catalog-test") != null,
		"worker7 cold request restores")
	request.version = 1
	request.erase("pitch_catalog")
	check(PhysicalRoundProcess.decode_request(request, "catalog-test") == null,
		"historical worker1 cannot carry97")


func _serialized_discriminators() -> void:
	var build: SeasonBuild = SeasonBuild.new(320, ROSTER)
	build.enable_pitch_catalog()
	var build_data: Dictionary = cold(build.to_data())
	var book_data: Dictionary = cold(build._book.to_data())
	var season: SeasonState = WorkingPitchProgression.create_season(321)
	var season_data: Dictionary = cold(SeasonSave.snapshot(season))
	var request: Dictionary = cold(PhysicalRoundProcess.request_for(
		season, "numeric-test", "a".repeat(64), 0))
	check(SeasonBuild.from_data(build_data, 320, ROSTER) != null,
		"Build47 integral JSON floats")
	check(SeasonDevelopment.from_data(book_data, "season:320") != null,
		"Development4 integral JSON floats")
	check(SeasonSave._decode(season_data) != null, "Save97 integral JSON floats")
	check(PhysicalRoundProcess.decode_request(request, "numeric-test") != null,
		"worker7 integral JSON floats")
	for invalid: Variant in ["47", true, null, 47.5]:
		var data: Dictionary = build_data.duplicate(true)
		data.version = invalid
		check(SeasonBuild.from_data(data, 320, ROSTER) == null, "malformed Build marker rejects")
		data = book_data.duplicate(true)
		data.version = invalid
		check(SeasonDevelopment.from_data(data, "season:320") == null,
			"malformed Development marker rejects")
		data = season_data.duplicate(true)
		data.version = invalid
		check(SeasonSave._decode(data) == null, "malformed Season marker rejects")
		data = request.duplicate(true)
		data.version = invalid
		check(PhysicalRoundProcess.decode_request(data, "numeric-test") == null,
			"malformed worker marker rejects")
		data = season_data.duplicate(true)
		data.checkpoint.version = invalid
		check(SeasonSave._decode(data) == null, "malformed nested checkpoint marker rejects")
		data = season_data.duplicate(true)
		data.checkpoint.build.version = invalid
		check(SeasonSave._decode(data) == null, "malformed nested Build marker rejects")
		check(SeasonSave._decode_payload(data.checkpoint) == null,
			"old leaf rejects malformed nested Build marker")
		data = request.duplicate(true)
		data.season.checkpoint.build.version = invalid
		check(PhysicalRoundProcess.decode_request(data, "numeric-test") == null,
			"worker7 rejects malformed nested Build marker")
	# Fresh no-earnings source, no accepted historical game or owner read.
	var source: SeasonState = SeasonState.create(322, false, true, true)
	source.career = ClubCareer.new()
	check(source.career.start(source), "legacy access source starts")
	for _pick in range(4):
		source.choose_player(source.offers()[0])
	var access_profile: Dictionary = Profile.capture_access_season(
		SeasonSave.snapshot(source), "numeric-lineage", "numeric-owner")
	check(not access_profile.is_empty() and not Profile.normalize(cold(access_profile)).is_empty(),
		"historical Profile2 actual JSON preserves required access")
	if access_profile.is_empty():
		return
	# Semantic schema control only, not owner enrollment, migration or earned access.
	var current_profile: Dictionary = access_profile.duplicate(true)
	current_profile.version = 4
	current_profile["pitch_catalog"] = WorkingPitchCatalog.signature()
	check(not Profile.normalize(cold(current_profile)).is_empty(),
		"Profile4 actual JSON preserves required access")
	for invalid: Variant in ["4", true, null, 4.5]:
		var profile: Dictionary = current_profile.duplicate(true)
		profile.version = invalid
		check(Profile.normalize(profile).is_empty(), "malformed profile marker rejects")


func _neutral_projection() -> void:
	var source: PitchDefinition = ContentDB.get_pitch(&"pitch.overhand_four_seam")
	var complete: Dictionary = SeasonPhysicalFixtures._resource(source, true)
	var source_urls: Array[String] = ["https://example.invalid/test"]
	var changes: Dictionary = {
		"offering_id": &"offering.test", "design_status": "fixture-only",
		"source_urls": source_urls,
		"movement_start": Vector2(0.1, 0), "movement_end": Vector2(0.9, 1),
		"movement_initial_scale": Vector2(0.5, 1),
		"exotic_shape": &"switchback", "exotic_strength": 0.1}
	for field: String in changes:
		# The same fixture runs before and after the separately composed Exotic exports.
		if not complete.has(field):
			check(field in ["exotic_shape", "exotic_strength"], "required current field exists")
			continue
		check(not SeasonPhysicalFixtures._resource(source).has(field),
			"only exact neutral default omitted from historical projection")
		var changed: PitchDefinition = source.duplicate() as PitchDefinition
		changed.set(field, changes[field])
		check(SeasonPhysicalFixtures._resource(changed).has(field),
			"nonneutral field cannot disappear from legacy resource check")
		check(not ClubCareer.same(complete, SeasonPhysicalFixtures._resource(changed, true)),
			"complete current resource binds every movement field")
