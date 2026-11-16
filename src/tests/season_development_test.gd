extends Node

const ALEX: String = "player.alex_finch"
const ROWAN: String = "player.rowan_chase"
const FOUR: String = "pitch.overhand_four_seam"
const EEPHUS: String = "pitch.eephus"
const DROP: String = "pitch.drop"

var _failures: int = 0


func _ready() -> void:
	_catalog()
	_growth()
	_learning()
	_persistence()
	if _failures == 0:
		print(
			"Wiffaltro development checks passed: authored rows, caps, personal mastery and replay."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _catalog() -> void:
	var ids: Array[String] = SeasonPlayerCatalog.ids()
	_check(ids.size() == 48, "48 distinct source identities")
	var holders: Array[String] = []
	var twos: Array[String] = []
	var counts: Dictionary = {2: 0, 3: 0, 4: 0, 5: 0}
	for id: String in ids:
		var definition: PlayerDefinition = ContentDB.get_player(StringName(id))
		_check(definition != null and id != "player.debug_pitcher", "exact authored ID")
		var row: Dictionary = SeasonPlayerCatalog.profile(id)
		_check(row.active.size() <= row.capacity, "starting count is distinct from capacity")
		counts[row.active.size()] += 1
		var fastball: bool = false
		for recipe: String in row.active:
			_check(SeasonPlayerCatalog.lesson_supported(recipe), "ordinary exact recipe supported")
			fastball = fastball or ContentDB.get_pitch(StringName(recipe)).category == 0
			if recipe == EEPHUS:
				holders.append(id)
			if row.mastery[recipe] == 2:
				twos.append(id + ":" + recipe)
		_check(fastball and row.mastery.size() == row.active.size(), "fastball and unique recipes")
		for stat: String in SeasonPlayerCatalog.STATS:
			_check(row.stats[stat] >= 1 and row.stats[stat] <= 5, "authored starting range")
	_check(counts == {2: 6, 3: 39, 4: 2, 5: 1}, "source start-count distribution preserved")
	_check(holders == [ALEX, "player.nico_vega", ROWAN], "only three named Eephus holders")
	_check(twos == [ALEX + ":" + EEPHUS], "Alex's exact Eephus is sole level-2 exception")
	_check(SeasonPlayerCatalog.profile("player.debug_pitcher").is_empty(), "debug profile excluded")


func _growth() -> void:
	var book: SeasonDevelopment = SeasonDevelopment.new("season-a")
	var first: Dictionary = _command(book, ALEX, "stat", "contact")
	var before: Dictionary = book.to_data()
	var preview: Dictionary = book.preview(first)
	_check(preview.ok and preview.after.stats.contact == 3, "exact +1 preview")
	preview.after.stats.contact = 999
	_check(book.to_data() == before and book.player(ALEX).stats.contact == 2, "cancel is inert")
	_check(book.commit(first).ok and book.commit(first).replayed, "idempotent grant")
	_check(book.player(ALEX).stats.contact == 3, "no duplicate development")
	var changed: Dictionary = first.duplicate()
	changed.target = "power"
	_reject(book, changed, "conflicting ID")
	var stale: Dictionary = _command(book, ALEX, "stat", "power")
	stale.rev = 0
	_reject(book, stale, "stale target snapshot")
	for id: String in [ALEX, ROWAN]:
		for stat: String in SeasonPlayerCatalog.STATS:
			while book.player(id).stats[stat] < 10:
				_check(book.commit(_command(book, id, "stat", stat)).ok, "legitimate growth to cap")
			_reject(book, _command(book, id, "stat", stat), "individual stat cap")
	_check(book.revision() > 32, "no legacy player/team combined growth budget")
	_reject(book, _command(book, ALEX, "stat", "velocity"), "retired stat is not hidden growth")
	_reject(book, _command(book, "unknown", "stat", "power"), "unknown player")
	var copy: Dictionary = book.player(ALEX)
	copy.stats.power = 0
	_check(book.player(ALEX).stats.power == 10, "inspection cannot mutate a player")
	_check(book.player(ROWAN).mastery[EEPHUS] == 1, "stats do not inflate recipe mastery")


func _learning() -> void:
	var book: SeasonDevelopment = SeasonDevelopment.new("season-a")
	for _step in range(4):
		_check(book.commit(_command(book, ROWAN, "mastery", EEPHUS)).ok, "personal mastery")
	_reject(book, _command(book, ROWAN, "mastery", EEPHUS), "pitch level 5 cap")
	_check(book.player(ALEX).mastery[EEPHUS] == 2, "same recipe never shares player growth")
	_reject(book, _lesson(book, ROWAN, DROP), "full capacity requires explicit replacement")
	_reject(book, _lesson(book, ROWAN, DROP, "pitch.riser"), "replace only an active recipe")
	_check(book.commit(_lesson(book, ROWAN, DROP, EEPHUS)).ok, "explicit full-capacity lesson")
	_check(book.player(ROWAN).mastery[DROP] == 1, "new recipe starts level 1")
	_check(book.player(ROWAN).mastery[EEPHUS] == 5, "removed mastery is remembered")
	_reject(book, _command(book, ROWAN, "mastery", EEPHUS), "inactive mastery is not usable")
	_check(book.commit(_lesson(book, ROWAN, EEPHUS, DROP)).ok, "relearning exact recipe")
	_check(book.player(ROWAN).mastery[EEPHUS] == 5, "relearning restores earned level 5")
	_check(book.player(ROWAN).active == [FOUR, EEPHUS], "replacement preserves repertoire order")
	_reject(book, _lesson(book, ALEX, "pitch.switchback"), "unready Exotic remains unavailable")
	_check(book.commit(_lesson(book, ALEX, "pitch.riser")).ok, "recipe uses own legal delivery")
	_reject(book, _lesson(book, ALEX, "pitch.riser"), "no duplicate lesson")
	_reject(book, _command(book, ALEX, "round_out", EEPHUS), "Round Out uses lowest active level")
	_check(book.commit(_command(book, ALEX, "round_out", FOUR)).ok, "choose one lowest tie")
	_check(book.player(ALEX).mastery["pitch.overhand_slider"] == 1, "other tied recipe unchanged")
	_check(book.player(ALEX).capacity == 5, "learning never changes capacity")
	var next: SeasonDevelopment = SeasonDevelopment.new("season-b")
	_check(next.player(ROWAN).mastery[EEPHUS] == 1, "new season uses authored baseline")


func _persistence() -> void:
	var book: SeasonDevelopment = SeasonDevelopment.new("season-a")
	var command: Dictionary = _command(book, ROWAN, "mastery", EEPHUS)
	_check(book.commit(command).ok, "journal entry")
	var data: Variant = JSON.parse_string(JSON.stringify(book.to_data()))
	var restored: SeasonDevelopment = SeasonDevelopment.from_data(data, "season-a")
	_check(restored != null and restored.player(ROWAN) == book.player(ROWAN), "JSON round trip")
	_check(restored.commit(command).replayed, "retry remains idempotent after reload")
	_check(SeasonDevelopment.from_data(data, "season-b") == null, "no cross-season import")
	var malformed: Dictionary = data.duplicate(true)
	malformed.events[0].rev = 0.5
	_check(
		SeasonDevelopment.from_data(malformed, "season-a") == null, "fractional revision rejected"
	)
	malformed = data.duplicate(true)
	malformed.events.append(malformed.events[0].duplicate())
	_check(
		SeasonDevelopment.from_data(malformed, "season-a") == null, "duplicate saved event rejected"
	)
	malformed = data.duplicate(true)
	malformed.players = {ROWAN: {"mastery": {EEPHUS: 5}}}
	_check(SeasonDevelopment.from_data(malformed, "season-a") == null, "no authoritative stat blob")
	malformed = data.duplicate(true)
	malformed.catalog = "changed"
	_check(
		SeasonDevelopment.from_data(malformed, "season-a") == null, "changed rows need migration"
	)
	var path: String = "user://development-test-%d.json" % OS.get_process_id()
	_check(SeasonDevelopmentStore.save(book, path, "season-a"), "real file checkpoint")
	var first_bytes: String = FileAccess.get_file_as_string(path)
	_check(not SeasonDevelopmentStore.save(book, path, "season-b"), "invalid checkpoint rejected")
	_check(FileAccess.get_file_as_string(path) == first_bytes, "rejected save preserves bytes")
	_check(book.commit(_command(book, ROWAN, "mastery", EEPHUS)).ok, "next level")
	_check(SeasonDevelopmentStore.save(book, path, "season-a"), "valid save creates backup")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("broken JSON")
	file.close()
	restored = SeasonDevelopmentStore.restore(path, "season-a")
	_check(restored != null and restored.player(ROWAN).mastery[EEPHUS] == 2, "recover last backup")
	_check(FileAccess.get_file_as_string(path) == "broken JSON", "corrupt source left intact")
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(path + suffix)


func _command(book: SeasonDevelopment, player_id: String, op: String, target: String) -> Dictionary:
	return {
		"id": "grant:%d" % book.revision(),
		"rev": book.revision(),
		"player": player_id,
		"op": op,
		"target": target
	}


func _lesson(
	book: SeasonDevelopment, player_id: String, recipe: String, replace: String = ""
) -> Dictionary:
	var result: Dictionary = _command(book, player_id, "learn", recipe)
	result.replace = replace
	return result


func _reject(book: SeasonDevelopment, command: Dictionary, message: String) -> void:
	var before: Dictionary = book.to_data()
	_check(not book.commit(command).ok and book.to_data() == before, message)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
