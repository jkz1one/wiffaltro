extends Node
## Production catalog pools vs independent original algorithms and real authored content.
## This is pool/RNG integration, not SeasonState/Owner/save or physical-game qualification.
const Catalog = preload("res://src/gameplay/season/club_player_catalog.gd")
const EXCLUDED: StringName = &"player.debug_pitcher"
# Exact historical caller list; independently bound against SeasonState by source review.
const LEGACY_IDS: Array[String] = [
	"player.alex_finch",
	"player.ari_banks",
	"player.ash_cole",
	"player.cal_mercer",
	"player.dev_lin",
	"player.drew_sato",
	"player.eli_frost",
	"player.frankie_bell",
	"player.gray_west",
	"player.harper_fox",
	"player.indy_shaw",
	"player.jo_lane",
	"player.jules_moss",
	"player.kai_soto",
	"player.kit_rowan",
	"player.lee_stone",
	"player.mika_reed",
	"player.morgan_pike",
	"player.nico_vega",
	"player.noel_hart",
	"player.remy_cruz",
	"player.ren_ellis",
	"player.sam_park",
	"player.tess_vale"
]
var checks: int = 0
var failures: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _ready() -> void:
	var owned: Array[String] = Catalog.initial_owned()
	var legacy: Array = LEGACY_IDS.duplicate()
	var second_cap_cases: int = 0
	var changed_cases: int = 0
	for seed_value in range(64):
		for legacy_mode: bool in [false, true]:
			var actual_rng: RandomNumberGenerator = RandomNumberGenerator.new()
			var original_rng: RandomNumberGenerator = RandomNumberGenerator.new()
			actual_rng.seed = seed_value
			original_rng.seed = seed_value
			var expected: Array[String] = _original(original_rng, legacy_mode, legacy)
			var actual: Array[String] = Catalog.draft_pool(actual_rng, EXCLUDED, legacy_mode, legacy)
			check(actual == expected, "full original seeded pool order")
			for team in range(6):
				check(actual_rng.randf() == original_rng.randf(), "same subsequent team RNG draws")
		for count in [0, 1, 6, 12, Catalog.PACK_POOL.size()]:
			var access: Array[String] = owned.duplicate()
			# Explicit owned-access fixture, not a claim of earned achievement provenance.
			access.append_array(["player.alex_finch", "player.bailey_quinn", "player.riley_grant"])
			for index in range(count):
				access.append(Catalog.PACK_POOL[index])
			access.sort()
			check(Catalog.valid_ids(access), "owned access fixture obeys catalog schema")
			var exact: Array[String] = access.duplicate()
			var expected: Array[String] = _owned_original(seed_value, access)
			var frozen: Array[String] = Catalog.owned_draft_pool(seed_value, access, EXCLUDED)
			check(frozen == expected, "owned original exact pool order")
			check(access == exact, "owned input remains unchanged")
			check(frozen.all(func(id: String) -> bool: return access.has(id)), "owned eligibility")
			var before_cap: Array[String] = _full(seed_value)
			before_cap = before_cap.filter(func(id: String) -> bool: return access.has(id))
			if before_cap != frozen:
				second_cap_cases += 1
			var saved_pool: Array[String] = frozen.duplicate()
			var saved_access: Array[String] = access.duplicate()
			var new_id: String = ""
			for id: String in Catalog.PACK_POOL:
				if not access.has(id):
					new_id = id
					break
			if not new_id.is_empty():
				access.append(new_id)
				access.sort()
				var next: Array[String] = Catalog.owned_draft_pool(seed_value, access, EXCLUDED)
				check(next.has(new_id) and not frozen.has(new_id), "purchase enters next pool only")
				check(frozen == saved_pool and not saved_access.has(new_id),
					"previously captured owned pool and access remain frozen")
				if next != frozen:
					changed_cases += 1
		var short: Array = owned.slice(0, 11)
		check(Catalog.owned_draft_pool(seed_value, short, EXCLUDED).is_empty(),
			"fewer than twelve eligible players refuses")
		var picks: Array[String] = [owned[0], owned[1], owned[2], owned[3]]
		var npc: Array[String] = _full(seed_value)
		npc = npc.filter(func(id: String) -> bool: return not picks.has(id))
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_value
		var actual_npc: Array[String] = Catalog.draft_pool(rng, EXCLUDED)
		actual_npc = actual_npc.filter(func(id: String) -> bool: return not picks.has(id))
		check(actual_npc == npc, "NPC draft remains full authored pool minus picks")
	check(second_cap_cases > 0, "post-filter second cap has a nonvacuous witness")
	check(changed_cases > 0, "new ownership changes next draft nonvacuously")
	_exhausted_tail()
	print("Owned draft pool checks: %d, failures: %d, second_cap=%d, changed=%d, Owner=false"
		% [checks, failures, second_cap_cases, changed_cases])
	get_tree().quit(0 if failures == 0 else 1)


func _original(rng: RandomNumberGenerator, legacy: bool, legacy_ids: Array) -> Array[String]:
	var result: Array[String] = []
	for id: StringName in ContentDB.player_by_id:
		if id != EXCLUDED and (not legacy or String(id) in legacy_ids):
			result.append(String(id))
	result.sort()
	for index in range(result.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var held: String = result[index]
		result[index] = result[other]
		result[other] = held
	if not legacy:
		_original_cap(result)
	return result


func _original_cap(pool: Array[String]) -> void:
	var special_seen: bool = false
	for index in range(12):
		if ContentDB.get_player(StringName(pool[index])).starting_pitches.size() < 4:
			continue
		if not special_seen:
			special_seen = true
			continue
		for other in range(12, pool.size()):
			if ContentDB.get_player(StringName(pool[other])).starting_pitches.size() < 4:
				var held: String = pool[index]
				pool[index] = pool[other]
				pool[other] = held
				break


func _full(seed_value: int) -> Array[String]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return _original(rng, false, [])


func _owned_original(seed_value: int, access: Array) -> Array[String]:
	var result: Array[String] = _full(seed_value)
	result = result.filter(func(id: String) -> bool: return access.has(id))
	if result.size() < 12:
		return []
	_original_cap(result)
	return result


func _exhausted_tail() -> void:
	var special: String = ""
	for id: StringName in ContentDB.player_by_id:
		if id != EXCLUDED and ContentDB.get_player(id).starting_pitches.size() >= 4:
			special = String(id)
			break
	check(not special.is_empty(), "authored specialist fixture exists")
	if special.is_empty():
		return
	var actual: Array[String] = []
	for index in range(14):
		actual.append(special)
	var expected: Array[String] = actual.duplicate()
	_original_cap(expected)
	Catalog.limit_draft_specialists(actual)
	check(actual == expected and actual.count(special) == 14,
		"best-effort cap preserves original exhausted-tail behavior")
