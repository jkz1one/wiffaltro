class_name SeasonOpponentLessons
extends RefCounted
## Policy5 / market4: five paid Common lessons, bounded secondary-slider buying.

const RECIPES: Array[String] = [
	"pitch.overhand_four_seam", "pitch.overhand_sinker", "pitch.sidearm_sinker",
	"pitch.overhand_slider", "pitch.sidearm_slider"
]


static func _pool_uncached(build: SeasonBuild) -> Array[String]:
	var result: Array[String] = []
	for recipe: String in (ExpandedSeasonCatalog.ids() if build.pitch_catalog_expanded() else (WorkingPitchCatalog.ids() if build.pitch_catalog_current() else RECIPES)):
		var id: String = "lesson." + recipe
		if not build.targets(id).is_empty():
			result.append(id)
	return result


static func offers(build: SeasonBuild, roll: int) -> Dictionary:
	var development: Dictionary = DevelopmentShopCatalog.families(build._book, build.roster())
	var lessons: Array[String] = pool(build)
	var gear: Dictionary = {}
	var owned: Dictionary = build._bank.view().gear
	for id: String in SeasonOpponentGear.INITIAL:
		var slot: String = SeasonGearCatalog.item(id).slot
		if owned[slot].get("item", "") == id:
			continue
		if not gear.has(slot):
			gear[slot] = []
		gear[slot].append(id)
	var weights: Dictionary = {}
	if not development.is_empty():
		weights["development"] = 25.0
	if not lessons.is_empty():
		weights["lesson"] = 12.0
	if not gear.is_empty():
		weights["gear"] = 20.0
	var result: Dictionary = {}
	var seen: Array[String] = []
	var rng: RandomNumberGenerator = build._rng(roll)
	for index in range(4):
		var choices: Dictionary = weights.duplicate()
		if index == 3 and seen.size() == 1 and choices.size() > 1:
			choices.erase(seen[0])
		if choices.is_empty():
			break
		var category: String = SeasonGearCatalog._weighted(choices, rng)
		if not seen.has(category):
			seen.append(category)
		var id: String
		if category == "lesson":
			id = lessons[rng.randi_range(0, lessons.size() - 1)]
		else:
			var groups: Dictionary = development if category == "development" else gear
			var group: String = groups.keys()[rng.randi_range(0, groups.size() - 1)]
			var variants: Array = groups[group]
			id = variants[rng.randi_range(0, variants.size() - 1)]
		result["visit:%d:roll:%d:%d" % [build._visit.number, roll, index]] = id
	return result


static func target(build: SeasonBuild, club: Dictionary) -> Dictionary:
	if club.profile not in ["Distributed", "Pitching / defense"]:
		return {}
	var player: String = club.roles.secondary
	if not build.roster().has(player):
		return {}
	var definition: PlayerDefinition = ContentDB.get_player(StringName(player))
	if definition.natural_delivery == null:
		return {}
	if build.pitch_catalog_current() or build.pitch_catalog_expanded():
		for item: String in build._visit.get("offers", {}).values():
			var lesson: Dictionary = build.shop_item(item)
			if lesson.get("op") != "learn" or int(lesson.price) > build.cash():
				continue
			var destination: Dictionary = {"player": player, "pitch": "", "replace": ""}
			if build.targets(item).has(destination):
				return {"player": player, "pitch": lesson.recipe, "item": item}
		return {}
	var recipe: String
	match definition.natural_delivery.id:
		&"delivery.overhand": recipe = "pitch.overhand_slider"
		&"delivery.sidearm": recipe = "pitch.sidearm_slider"
		_: return {}
	var id: String = "lesson." + recipe
	var destination: Dictionary = {"player": player, "pitch": "", "replace": ""}
	# Stock eligibility remains shared; this first buying policy never forgets a pitch.
	return ({"player": player, "pitch": recipe, "item": id}
		if build.targets(id).has(destination) else {})


static func purchase(build: SeasonBuild, club: Dictionary, game: int) -> bool:
	var goal: Dictionary = target(build, club)
	if goal.is_empty():
		return false
	var price: int = build.shop_item(goal.item).price
	if build.cash() < price:
		return false
	for offer: String in build._visit.offers:
		if build._visit.offers[offer] != goal.item:
			continue
		var request: Dictionary = SeasonOpponentPolicy.command(build, "buy", {
			"offer": offer, "mode": "use", "player": goal.player, "pitch": "", "replace": ""})
		if not build.commit(request).ok:
			return false
		club.decisions.append({"game": game, "request": request.id, "player": goal.player,
			"stat": "lesson", "item": goal.item, "pitch": goal.pitch,
			"level": build.player(goal.player).mastery[goal.pitch], "paid": price,
			"reason": "paid catalog lesson" if (build.pitch_catalog_current() or build.pitch_catalog_expanded()) else "secondary slider"})
		return true
	return false


static func checkout(build: SeasonBuild, club: Dictionary, game: int) -> void:
	if not build.commit(SeasonOpponentPolicy.command(build, "open")).ok:
		return
	for step in range(100):
		var goals: Array[Dictionary] = SeasonOpponentMastery.objectives(build, club)
		if (SeasonOpponentMastery._develop(build, club, game, goals)
			or SeasonOpponentGear._equip(build, club, game) or purchase(build, club, game)):
			continue
		var price: int = SeasonOpponentMastery.useful_price(build, club, goals)
		var lesson: Dictionary = target(build, club)
		if not lesson.is_empty():
			var lesson_price: int = build.shop_item(lesson.item).price
			price = lesson_price if price == 0 else mini(price, lesson_price)
		if (build._visit.rerolls == 0 and price > 0
			and build.cash() >= SeasonReclamation.price(build._visit) + price):
			if build.commit(SeasonOpponentPolicy.command(build, "reroll")).ok:
				continue
		break


const SOURCE_PINS: Dictionary = {
  "src/gameplay/season/development_shop_catalog.gd": "567308d0471994f9d767bc8f87da2714042c7228e75e28f30618a158b1ed5138",
  "src/gameplay/season/expanded_season_progression.gd": "e4ed317f366f714691c47d991f052078c114aa9c308aa8cf49f1d1fd83a0e01d",
  "src/gameplay/season/season_development.gd": "11ad6cbce2ddd79a4511f9da92f5a51a74f846ad1865ffdd022be6cec31f26b3",
  "src/gameplay/season/season_build.gd": "e939b05034c6137c0e25cb394d2495c822ff89e4599d06088b32d48d9ffb9d10",
  "src/gameplay/season/season_sure_shot.gd": "d817141505869cd388f4e1a61591ebbf40aec0c294dbc29bda68cabe18ff060e",
  "src/gameplay/season/season_physical_fixtures.gd": "722819cc18617689043af61ec1d88a1c9f520c0b2e2fde4144c6d4f05b48b710",
  "src/gameplay/pitching/expanded_season_catalog.gd": "cb1ff9e70025ce4166ce38edcc1aa4d2790767ad13c505a36800280fd6cd2fb0",
  "src/gameplay/pitching/working_pitch_catalog_v6.gd": "0e709f6bda6fa95a8fa7cc666ad31354cc223633c8c0782254adeb8d16820dff",
  "src/gameplay/pitching/working_pitch_catalog.gd": "6285ae5b772796bedbf50a56cc7d47142bd7a2e656aef85efef1c215ff67c33c",
  "src/gameplay/season/expanded_exotic_access.gd": "b05c4f2220ec0fb94c0e9ea36a741504a86c20ab90ed5eef050b67cf5f473b37",
  "src/gameplay/pitching/expanded_exotic_eligibility.gd": "8b1da27f69b94574f24ef03c410849009487585051e74f19dc054e61c52df3fd",
  "src/content/definitions/pitch_definition.gd": "32c1569fc3565545b134f729a96fed72c36c37600ab3148ef90e5b603e7db9a9",
  "src/content/definitions/delivery_profile_definition.gd": "2e771baf8f4f39c9929909295f75020994c0cd80a9ad53099d7694628fe1b4a9",
  "src/content/manifest/content_manifest.gd": "18d7f35b06e6f6b9174fa2e3e3e9a2ee698917ab4eee8f20baaf6498d99ee0de",
  "src/content/manifest/working_pitch_manifest.tres": "53e55e7a17dd71d3d2509c543983add050331c3fd79115a62979ca1bbc6f4ce2",
  "src/content/manifest/working_pitch_manifest_v6.tres": "cd8a10842248dea023b3df0ad4216b0d8fb88797560152b7b71513f93692e318",
  "src/content/definitions/definition_base.gd": "d03b3f1f855f51f1f2e3a99f1be99a626cfe523e39c76bd9576b16cb6af4876f"
}

static func _source_pins_match(pins: Dictionary) -> bool:
	for path: String in pins:
		if FileAccess.get_sha256("res://" + path) != pins[path]: return false
	return true

static func _raw_manifest_supported(value: Variant, count: int) -> bool:
	if not value is ContentManifest or value.get_script() != ContentManifest:
		return false
	if value.pitches.size() != count: return false
	for pitch: PitchDefinition in value.pitches:
		if pitch == null or pitch.get_script() != PitchDefinition:
			return false
		if pitch.delivery_profile == null \
			or pitch.delivery_profile.get_script() != DeliveryProfileDefinition:
			return false
	return true

static func _raw_resources_supported() -> bool:
	return _raw_manifest_supported(load(WorkingPitchCatalog.MANIFEST_PATH), 41) \
		and _raw_manifest_supported(load(ExpandedSeasonCatalog.Provider.MANIFEST_PATH), 43)

static func _eligible(build: SeasonBuild) -> bool:
	if build == null or build.get_script() != SeasonBuild: return false
	if build._market != 12: return false
	if not SeasonSureShot._memo_eligible_scope(build, {}, {}): return false
	if not _source_pins_match(SOURCE_PINS): return false
	var budget: Array[int] = [100000, 8 * 1024 * 1024]
	if not SeasonPhysicalFixtures._current_report_value_graph(build._book._exotic_ids, budget, 0):
		return false
	for player_id: String in build.roster():
		var profile: Dictionary = build._book.player(player_id)
		if profile.is_empty(): continue
		if not profile.get("active") is Array or not profile.get("capacity") is int:
			return false
		for recipe: Variant in profile.active:
			if not recipe is String: return false
	return true

static func pool(build: SeasonBuild) -> Array[String]:
	if not _eligible(build): return _pool_uncached(build)
	if not _raw_resources_supported(): return _pool_uncached(build)
	# Raw exact scripts checked BEFORE any provider detachment or signature call.
	# One live full provider validation, no cached/hardcoded catalog signature.
	if ExpandedSeasonCatalog.signature().is_empty(): return _pool_uncached(build)
	var recipes: Array[PitchDefinition] = ExpandedSeasonCatalog.recipes()
	if recipes.size() != 43: return _pool_uncached(build)
	var metadata: Array[Dictionary] = []
	var seen: Array[String] = []
	for pitch: PitchDefinition in recipes:
		if pitch == null or pitch.get_script() != PitchDefinition \
			or pitch.delivery_profile == null \
			or pitch.delivery_profile.get_script() != DeliveryProfileDefinition:
			return _pool_uncached(build)
		var id: String = String(pitch.id)
		if seen.has(id): return _pool_uncached(build)
		seen.append(id)
		# Keep original public price calculation, including legacy and exotic rules.
		var ordinary_price: int = ExpandedSeasonCatalog.lesson_price(id)
		var lesson_price: int = ordinary_price
		if lesson_price < 0: lesson_price = ExpandedExoticAccess.price(id)
		metadata.append({"id": id, "ordinary_price": ordinary_price,
			"lesson_price": lesson_price})
	# Only immutable scalar metadata survives the observation, no Resource cache.
	recipes.clear()
	var profiles: Array[Dictionary] = []
	for player_id: String in build.roster():
		profiles.append(build._book.player(player_id))
	var exotic_ids: Array = build._book._exotic_ids.duplicate()
	var result: Array[String] = _select(metadata, profiles, exotic_ids)
	return result

static func _select(metadata: Array[Dictionary], profiles: Array[Dictionary], exotic_ids: Array) -> Array[String]:
	var result: Array[String] = []
	for row: Dictionary in metadata:
		# lesson() must exist AND lesson_supported() must accept learning.
		if row.lesson_price < 0 or (row.ordinary_price < 0 and not exotic_ids.has(row.id)):
			continue
		for profile: Dictionary in profiles:
			if profile.is_empty() or profile.active.has(row.id): continue
			# Full slots can still yield replacement targets. Empty capacity-zero cannot.
			if profile.active.size() < profile.capacity or not profile.active.is_empty():
				result.append("lesson." + row.id)
				break
	return result
