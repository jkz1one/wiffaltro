extends Node
## Isolated data/ownership checks with explicitly SYNTHETIC credited income and progress.
## Ordinary paid ledger operations only. No physical game, earned title, scan or save writes.

const SYNTHETIC_SEED: int = 37
const SYNTHETIC_ROWS: int = 20
const LIGHT_REQUEST: String = "synthetic-lights"

var _failures: int = 0
var _checks: int = 0
var _credits: Array = []
var _progress: Array = []


func _ready() -> void:
	for index in range(SYNTHETIC_ROWS):
		_credits.append(1000)
		_progress.append({"seasons": 1, "wins": 5})
	var rough: ClubAssetLedger = _fixture(false)
	var grass: ClubAssetLedger = _fixture(true)
	var rough_candidate: Dictionary = StadiumSurfaceNightLayout.capture(rough)
	var grass_candidate: Dictionary = StadiumSurfaceNightLayout.capture(grass)
	_check(not rough_candidate.is_empty(), "paid four-pole rough-dirt Backyard candidate")
	_check(not grass_candidate.is_empty(), "paid four-pole established-grass Expanded candidate")
	if rough_candidate.is_empty() or grass_candidate.is_empty():
		_finish()
		return
	_positive(rough, rough_candidate, false)
	_positive(grass, grass_candidate, true)
	_envelope(rough, rough_candidate)
	_placements(rough, rough_candidate)
	_surface_access(rough, rough_candidate)
	_excluded_compositions(rough, grass)
	_paid_prefix(rough, rough_candidate)
	_public_closure(rough, rough_candidate)
	_public_closure(grass, grass_candidate)
	_finish()


func _fixture(established_grass: bool) -> ClubAssetLedger:
	var ledger: ClubAssetLedger = ClubAssetLedger.new_club(SYNTHETIC_SEED, _credits, _progress)
	_buy(ledger, "ST-037", 5, StadiumPurchases.LIGHT_VERSION, LIGHT_REQUEST)
	if established_grass:
		_land(ledger, "expanded")
		_surface(ledger, "grass")
		_surface(ledger, "ground_prep")
		_style(ledger, "ST-063a", 1)
		_style(ledger, "ST-063i", StadiumGroundStyles.PRICE_VERSION)
	var layout: Dictionary = ledger.view().stadium_active
	var sites: Array = StadiumYardLightModels.SITES.keys()
	sites.sort()
	for index in range(4):
		layout.lights.append({"copy": "purchase:%s:%d" % [LIGHT_REQUEST, index],
			"site": sites[index]})
	if established_grass:
		layout.surface = StadiumSurfaceProgression.selection(ledger.surface_owned(), true)
		layout.styles.grass = "ST-063a"
		layout.ground = "ST-063i"
	_apply(ledger, layout)
	return ledger


func _positive(ledger: ClubAssetLedger, candidate: Dictionary, grass: bool) -> void:
	var before: String = _ledger_bytes(ledger)
	var identity: String = _bytes(candidate)
	var entry: Dictionary = candidate.entry
	_check(entry.version == 8 and entry.layout.version == 12,
		"candidate retains existing complete entry8 and appearance12 versions")
	_check(entry.tier == ("expanded" if grass else "backyard")
		and entry.layout.surface.foundation == ("grass" if grass else "dirt")
		and entry.layout.surface.condition == ("prepared" if grass else "rough"),
		"two bounded synthetic fixtures retain exact paid land and surface choices")
	_check(entry.surface_access == (["grass", "ground_prep"] if grass else []),
		"only the actual surface upgrades are declared")
	_check(ClubCareer.same(entry, StadiumLayoutSnapshot.capture(ledger)),
		"wrapper deep-copies the unchanged complete season-entry snapshot")
	var stock: StadiumStock = StadiumLayoutSnapshot.ownership(entry)
	var checked: Dictionary = StadiumSurfaceLayout.validate(entry.layout, stock, entry.tier)
	_check(checked.ok and checked.stored.has("purchase:%s:4" % LIGHT_REQUEST)
		and entry.layout.lights.size() == 4, "fifth paid pole stays stored")
	for attempt in range(2):
		_check(StadiumSurfaceNightLayout.valid(candidate, ledger)
			and _bytes(StadiumSurfaceNightLayout.capture(ledger)) == identity,
			"repeat capture and validation preserve candidate identity")
	_check(StadiumSurfaceNightLayout.valid(JSON.parse_string(identity), ledger),
		"strict candidate accepts its JSON numeric roundtrip")
	var restored: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(_bytes(ledger.to_data())), SYNTHETIC_SEED, _credits, _progress)
	_check(restored != null and StadiumSurfaceNightLayout.valid(candidate, restored),
		"ordinary paid journal replays using explicitly synthetic credits and progress")
	var detached: Dictionary = StadiumSurfaceNightLayout.capture(ledger)
	detached.entry.layout.lights.clear()
	detached.entry.inventory.copies.clear()
	detached.entry.surface_access.append("forged-access")
	_check(_ledger_bytes(ledger) == before and _bytes(candidate) == identity,
		"returned nested data cannot mutate journal, active/draft layout or prior candidate")
	_check(_bytes(StadiumSurfaceNightLayout.capture(ledger)) == identity,
		"editing one returned candidate cannot poison later capture")


func _envelope(ledger: ClubAssetLedger, candidate: Dictionary) -> void:
	var before: String = _ledger_bytes(ledger)
	_check(StadiumSurfaceNightLayout.capture(null).is_empty()
		and not StadiumSurfaceNightLayout.valid(candidate, null), "null ledger refuses")
	for malformed: Variant in [null, false, 1, "candidate", [], {}]:
		_check(not StadiumSurfaceNightLayout.valid(malformed, ledger),
			"non-envelope values refuse without repair")
	for field: String in ["candidate_version", "family", "contract", "entry"]:
		var missing: Dictionary = candidate.duplicate(true)
		missing.erase(field)
		_check(not StadiumSurfaceNightLayout.valid(missing, ledger), "every envelope key is required")
	for patch: Dictionary in [{"extra": true}, {"candidate_version": 0},
		{"candidate_version": 2}, {"candidate_version": 1.5}, {"candidate_version": true},
		{"candidate_version": "1"}, {"family": "owned-surface-night-candidate-v2"},
		{"family": true}, {"contract": "forged"}, {"contract": 1},
		{"entry": null}, {"entry": []}, {"entry": {}}]:
		var bad: Dictionary = candidate.duplicate(true)
		bad.merge(patch, true)
		_check(not StadiumSurfaceNightLayout.valid(bad, ledger),
			"unknown fields, identity, version and malformed entry refuse")
	var bad: Dictionary = candidate.duplicate(true)
	bad.entry["extra"] = true
	_check(not StadiumSurfaceNightLayout.valid(bad, ledger), "entry retains exact existing keys")
	bad = candidate.duplicate(true)
	bad.entry.layout.receiver = "starter-v1:ST-079"
	_check(StadiumLayoutSnapshot.valid(bad.entry)
		and not StadiumSurfaceNightLayout.valid(bad, ledger),
		"structurally valid substituted layout cannot replace the applied paid-prefix layout")
	bad = candidate.duplicate(true)
	bad.entry.revision += 1
	_check(not StadiumSurfaceNightLayout.valid(bad, ledger), "future ledger revision refuses")
	_check(_ledger_bytes(ledger) == before, "every envelope refusal is read-only")


func _placements(ledger: ClubAssetLedger, candidate: Dictionary) -> void:
	var before: String = _ledger_bytes(ledger)
	for patch: Dictionary in [{"copy": "purchase:missing:0"},
		{"copy": "starter-v1:ST-001"}, {"copy": candidate.entry.layout.lights[0].copy},
		{"site": candidate.entry.layout.lights[0].site}, {"site": "YLIGHT-UNKNOWN"},
		{"site": true}, {"extra": 1}]:
		var bad: Dictionary = candidate.duplicate(true)
		bad.entry.layout.lights[1].merge(patch, true)
		_check(not StadiumSurfaceNightLayout.valid(bad, ledger),
			"unowned, wrong-item, duplicate copy/site or malformed socket refuses")
	var bad: Dictionary = candidate.duplicate(true)
	bad.entry.layout.lights.reverse()
	_check(not StadiumSurfaceNightLayout.valid(bad, ledger), "socket order stays canonical")
	for count: int in [3, 0]:
		var partial: ClubAssetLedger = ledger.prefix(ledger.revision())
		if partial == null:
			_check(false, "synthetic partial-light fixture prefix could not replay")
			return
		var layout: Dictionary = partial.view().stadium_active
		layout.lights.resize(count)
		_apply(partial, layout)
		var entry: Dictionary = StadiumLayoutSnapshot.capture(partial)
		_check(not entry.is_empty() and StadiumLayoutSnapshot.matches(entry, partial),
			"partial/stored-only fixture is an authentic applied ordinary layout")
		var partial_before: String = _ledger_bytes(partial)
		_check(StadiumSurfaceNightLayout.capture(partial).is_empty()
			and not StadiumSurfaceNightLayout.valid(_wrap(entry), partial),
			"stored fourth/fifth poles cannot supply missing installed sockets")
		_check(_ledger_bytes(partial) == partial_before, "capture refusal cannot place stored poles")
	_check(_ledger_bytes(ledger) == before, "placement refusal preserves the original fixture")


func _surface_access(ledger: ClubAssetLedger, candidate: Dictionary) -> void:
	var before: String = _ledger_bytes(ledger)
	for patch: Dictionary in [{"foundation": "grass"}, {"condition": "prepared"}]:
		var bad: Dictionary = candidate.duplicate(true)
		bad.entry.layout.surface.merge(patch, true)
		_check(not StadiumSurfaceNightLayout.valid(bad, ledger),
			"unowned grass or preparation cannot enter a candidate")
	var bad: Dictionary = candidate.duplicate(true)
	bad.entry.surface_access = ["grass", "ground_prep"]
	_check(StadiumLayoutSnapshot.valid(bad.entry)
		and not StadiumSurfaceNightLayout.valid(bad, ledger),
		"plausible forged access declaration is not a paid receipt")
	bad = candidate.duplicate(true)
	bad.entry.inventory.copies["purchase:forged:0"] = \
		bad.entry.inventory.copies["purchase:%s:4" % LIGHT_REQUEST].duplicate(true)
	_check(StadiumLayoutSnapshot.valid(bad.entry)
		and not StadiumSurfaceNightLayout.valid(bad, ledger),
		"plausible forged inventory declaration is not a paid receipt")
	_check(_ledger_bytes(ledger) == before, "ownership refusal cannot grant upgrades or copies")


func _excluded_compositions(rough: ClubAssetLedger, grass: ClubAssetLedger) -> void:
	var larger: ClubAssetLedger = grass.prefix(grass.revision())
	if larger == null:
		_check(false, "synthetic Club-land fixture prefix could not replay")
		return
	_land(larger, "club")
	var entry: Dictionary = StadiumLayoutSnapshot.capture(larger)
	_check(not entry.is_empty() and StadiumLayoutSnapshot.matches(entry, larger)
		and StadiumSurfaceNightLayout.capture(larger).is_empty()
		and not StadiumSurfaceNightLayout.valid(_wrap(entry), larger),
		"authentic paid Club land is outside the first candidate boundary")
	var walls: ClubAssetLedger = rough.prefix(rough.revision())
	if walls == null:
		_check(false, "synthetic paid-wall fixture prefix could not replay")
		return
	_buy(walls, "ST-022", 19, StadiumWallItems.PRICE_VERSION, "synthetic-left-wall")
	var layout: Dictionary = walls.view().stadium_active
	var proposal: Dictionary = StadiumWallLayout.propose(layout.walls,
		walls.construction(), "left", "ST-022")
	_check(proposal.ok, "synthetic paid nineteen-copy left wall proposes normally")
	if proposal.ok:
		layout.walls = proposal.walls
		_apply(walls, layout)
		entry = StadiumLayoutSnapshot.capture(walls)
		_check(not entry.is_empty() and StadiumLayoutSnapshot.matches(entry, walls)
			and StadiumSurfaceNightLayout.capture(walls).is_empty()
			and not StadiumSurfaceNightLayout.valid(_wrap(entry), walls),
			"authentic paid-wall replacement is excluded without changing wall authority")
	var incompatible: ClubAssetLedger = grass.prefix(grass.revision())
	if incompatible == null:
		_check(false, "synthetic incompatible-item fixture prefix could not replay")
		return
	_buy(incompatible, "ST-075", 1, StadiumPurchases.BLEACHER_VERSION, "synthetic-roof")
	var stored: Dictionary = StadiumSurfaceNightLayout.capture(incompatible)
	_check(not stored.is_empty(), "stored incompatible object does not become an installed object")
	if not stored.is_empty():
		stored.entry.layout.bleachers = [{"copy": "purchase:synthetic-roof:0",
			"site": "SIDE-SEAT-L"}]
		_check(not StadiumSurfaceNightLayout.valid(stored, incompatible),
			"incompatible installed roofed bleacher refuses; existing land gate is not waived")
	# ST-075 also needs Club land. Do not weaken that existing placement rule to reach a check.
	_buy(larger, "ST-075", 1, StadiumPurchases.BLEACHER_VERSION, "synthetic-roof")
	layout = larger.view().stadium_active
	layout.bleachers = [{"copy": "purchase:synthetic-roof:0", "site": "SIDE-SEAT-L"}]
	_apply(larger, layout)
	entry = StadiumLayoutSnapshot.capture(larger)
	_check(not entry.is_empty() and StadiumLayoutSnapshot.matches(entry, larger)
		and not StadiumLightItems.COMPATIBLE_ITEMS.has("ST-075")
		and StadiumSurfaceNightLayout.capture(larger).is_empty(),
		"authentic incompatible installation remains outside the candidate subset")


func _paid_prefix(ledger: ClubAssetLedger, original: Dictionary) -> void:
	var later: ClubAssetLedger = ledger.prefix(ledger.revision())
	if later == null:
		_check(false, "synthetic later-purchase fixture prefix could not replay")
		return
	_buy(later, "ST-037", 1, StadiumPurchases.LIGHT_VERSION, "synthetic-later-pole")
	_surface(later, "grass")
	_surface(later, "ground_prep")
	var current: Dictionary = StadiumSurfaceNightLayout.capture(later)
	_check(not current.is_empty() and StadiumSurfaceNightLayout.valid(original, later),
		"authentic historical prefix remains valid after later paid purchases")
	if current.is_empty():
		return
	var before: String = _ledger_bytes(later)
	for field: String in ["inventory", "surface_access"]:
		var borrowed: Dictionary = original.duplicate(true)
		borrowed.entry[field] = current.entry[field].duplicate(true)
		_check(StadiumLayoutSnapshot.valid(borrowed.entry)
			and not StadiumSurfaceNightLayout.valid(borrowed, later),
			"later inventory/access cannot be borrowed into an earlier revision")
	var borrowed: Dictionary = original.duplicate(true)
	borrowed.entry.inventory = current.entry.inventory.duplicate(true)
	borrowed.entry.layout.lights[3].copy = "purchase:synthetic-later-pole:0"
	_check(StadiumLayoutSnapshot.valid(borrowed.entry)
		and not StadiumSurfaceNightLayout.valid(borrowed, later),
		"later paid pole cannot replace an earlier prefix's installed pole")
	var prefix: ClubAssetLedger = later.prefix(int(original.entry.revision))
	if prefix == null:
		_check(false, "synthetic historical candidate prefix could not replay")
		return
	_check(StadiumSurfaceNightLayout.valid(original, prefix)
		and not StadiumSurfaceNightLayout.valid(current, prefix),
		"exact prefix accepts its original candidate and rejects future candidate")
	_check(_ledger_bytes(later) == before, "historical validation never rewrites the current ledger")


func _public_closure(ledger: ClubAssetLedger, candidate: Dictionary) -> void:
	var entry: Dictionary = candidate.entry
	var checked: Dictionary = StadiumSurfaceLayout.validate(entry.layout,
		StadiumLayoutSnapshot.ownership(entry), entry.tier)
	_check(not StadiumSurfaceNightLayout.RUNTIME_READY and not StadiumSurfaceNightLayout.PUBLIC_READY,
		"both candidate activation flags remain false")
	_check(checked.ok and not checked.night_qualified,
		"structural candidate validity never promotes original v12 night qualification")
	_check(not StadiumLayoutSnapshot.valid(candidate)
		and not StadiumHomeLayout.validate(candidate, ledger.construction(), entry.tier).ok,
		"candidate wrapper is neither an ordinary snapshot nor a production layout")
	var fixture: Dictionary = entry.duplicate(true)
	fixture.version = 9
	fixture["environment"] = StadiumFixtureEnvironment.capture(fixture, 1, 0)
	_check(StadiumFixtureEnvironment.is_night_seed(1) and StadiumLayoutSnapshot.valid(fixture)
		and fixture.environment.mode == "day" and fixture.environment.profile.is_empty(),
		"unchanged v12 fixture stays daylight even for an existing night-pool seed")
	fixture.environment.mode = "night"
	_check(not StadiumLayoutSnapshot.valid(fixture), "forged old-family night fixture still refuses")


func _wrap(entry: Dictionary) -> Dictionary:
	return {"candidate_version": StadiumSurfaceNightLayout.CANDIDATE_VERSION,
		"family": StadiumSurfaceNightLayout.FAMILY, "contract": StadiumSurfaceNightLayout.signature(),
		"entry": entry.duplicate(true)}


func _buy(ledger: ClubAssetLedger, item: String, quantity: int,
	price_version: int, request: String) -> void:
	_paid(ledger, {"id": request, "rev": ledger.revision(), "op": "stadium_buy",
		"item": item, "quantity": quantity, "price_version": price_version,
		"through": SYNTHETIC_ROWS, "progress_through": SYNTHETIC_ROWS})


func _land(ledger: ClubAssetLedger, tier: String) -> void:
	_paid(ledger, {"id": "synthetic-land:" + tier, "rev": ledger.revision(),
		"op": "stadium_land", "tier": tier, "price_version": StadiumLand.VERSION,
		"through": SYNTHETIC_ROWS, "progress_through": SYNTHETIC_ROWS})


func _surface(ledger: ClubAssetLedger, item: String) -> void:
	_paid(ledger, {"id": "synthetic-surface:" + item, "rev": ledger.revision(),
		"op": "stadium_surface", "item": item, "price_version": StadiumSurfaceProgression.VERSION,
		"through": SYNTHETIC_ROWS})


func _style(ledger: ClubAssetLedger, item: String, price_version: int) -> void:
	_paid(ledger, {"id": "synthetic-style:" + item, "rev": ledger.revision(),
		"op": "stadium_style", "item": item, "price_version": price_version,
		"through": SYNTHETIC_ROWS, "progress_through": SYNTHETIC_ROWS})


func _paid(ledger: ClubAssetLedger, command: Dictionary) -> void:
	var balance: int = ledger.balance()
	var revision: int = ledger.revision()
	var preview: Dictionary = ledger.preview(command)
	var result: Dictionary = ledger.commit(command)
	_check(preview.ok and result.ok and not result.replayed
		and ledger.revision() == revision + 1 and ledger.balance() < balance
		and ledger.balance() == preview.get("balance_after", -1),
		"ordinary paid transaction using synthetic credits/progress: " + str(command.id))


func _apply(ledger: ClubAssetLedger, layout: Dictionary) -> void:
	var balance: int = ledger.balance()
	_check(ledger.commit({"id": "synthetic-draft:%d" % ledger.revision(),
		"rev": ledger.revision(), "op": "stadium_draft", "layout": layout}).ok,
		"ordinary exact draft using only owned items")
	_check(ledger.commit({"id": "synthetic-apply:%d" % ledger.revision(),
		"rev": ledger.revision(), "op": "stadium_apply", "layout": layout,
		"geometry": StadiumHomeLayout.geometry(ledger.view().land, layout)}).ok
		and ledger.balance() == balance, "ordinary free apply retains exact active paid layout")


func _ledger_bytes(ledger: ClubAssetLedger) -> String:
	return _bytes({"journal": ledger.to_data(), "view": ledger.view(),
		"inventory": ledger.construction().to_data(), "generation": ledger.mutation_generation()})


func _bytes(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(message)


func _finish() -> void:
	if _failures == 0:
		print("Wiffaltro surface-night candidate checks passed (%d): " % _checks
			+ "synthetic paid data fixtures only; runtime/public remain false; no optical pass.")
	get_tree().quit(0 if _failures == 0 else 1)
