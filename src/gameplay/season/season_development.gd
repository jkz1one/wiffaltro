class_name SeasonDevelopment
extends RefCounted
## Season-local development ledger. Acquisition/payment belongs to the caller's
## atomic transaction; the playtest path issues explicitly synthetic grants only.
# gdlint: disable=max-returns
# Validation exits before publishing any candidate state.

const VERSION: int = 1
const STAT_CAP: int = 10
const PITCH_CAP: int = 5
const MAX_EVENTS: int = 4096

var _season_key: String
var _players: Dictionary = {}
var _events: Array[Dictionary] = []
var _requests: Dictionary = {}


func _init(season_key: String = "") -> void:
	_season_key = season_key
	for player_id: String in SeasonPlayerCatalog.ids():
		_players[player_id] = SeasonPlayerCatalog.profile(player_id)


func revision() -> int:
	return _events.size()


func fork() -> SeasonDevelopment:
	var result: SeasonDevelopment = SeasonDevelopment.new(_season_key)
	result._players = _players.duplicate(true)
	result._events = _events.duplicate(true)
	result._requests = _requests.duplicate(true)
	return result


func player(player_id: String) -> Dictionary:
	return _players.get(player_id, {}).duplicate(true)


func to_data() -> Dictionary:
	return {
		"version": VERSION,
		"season": _season_key,
		"catalog": SeasonPlayerCatalog.signature(),
		"events": _events.duplicate(true)
	}


static func from_data(value: Variant, season_key: String) -> SeasonDevelopment:
	if not value is Dictionary or not _keys(value, ["version", "season", "catalog", "events"]):
		return null
	if value.version != VERSION or value.season != season_key or season_key.is_empty():
		return null
	if value.catalog != SeasonPlayerCatalog.signature() or not value.events is Array:
		return null
	if value.events.size() > MAX_EVENTS:
		return null
	var result: SeasonDevelopment = SeasonDevelopment.new(season_key)
	for event: Variant in value.events:
		if not event is Dictionary:
			return null
		var applied: Dictionary = result.commit(event)
		if not applied.ok or applied.replayed:
			return null
	return result


func preview(command: Dictionary) -> Dictionary:
	return _prepare(command).duplicate(true)


func commit(command: Dictionary) -> Dictionary:
	var prepared: Dictionary = _prepare(command)
	if not prepared.ok or prepared.replayed:
		return prepared.duplicate(true)
	var normalized: Dictionary = command.duplicate(true)
	normalized.rev = int(normalized.rev)
	_players[normalized.player] = prepared.after.duplicate(true)
	if normalized.get("op") == "exchange":
		_players[normalized.other] = prepared.other_after.duplicate(true)
	_events.append(normalized)
	_requests[normalized.id] = JSON.stringify(normalized)
	return prepared.duplicate(true)


func _prepare(command: Dictionary) -> Dictionary:
	if _season_key.is_empty():
		return _error("A season instance is required.")
	if not command.get("id") is String or command.id.is_empty() or command.id.length() > 120:
		return _error("Invalid development request ID.")
	if not _whole(command.get("rev"), 0, MAX_EVENTS):
		return _error("Invalid revision.")
	if not command.get("player") is String or not _players.has(command.player):
		return _error("Unknown season-player.")
	var normalized: Dictionary = command.duplicate(true)
	normalized.rev = int(command.rev)
	if _requests.has(command.id):
		if _requests[command.id] != JSON.stringify(normalized):
			return _error("This request ID already means something else.")
		return {"ok": true, "replayed": true, "after": player(command.player)}
	if command.rev != revision() or revision() >= MAX_EVENTS:
		return _error("Development changed. Preview this action again.")
	if command.get("op") == "exchange":
		return SeasonPitchExchange.prepare(self, command)
	var after: Dictionary = player(command.player)
	var error: String = _apply(after, command)
	if not error.is_empty():
		return _error(error)
	return {"ok": true, "replayed": false, "after": after}


static func _apply(after: Dictionary, command: Dictionary) -> String:
	var fields: Array[String] = ["id", "rev", "player", "op", "target"]
	if command.get("op") == "learn":
		fields.append("replace")
	if not _keys(command, fields) or not command.get("target") is String:
		return "Unexpected development fields."
	var target: String = command.target
	match command.get("op"):
		"recruit":
			if after != SeasonPlayerCatalog.profile(after.id):
				return "Only a fresh season instance can receive recruit development."
			var fresh: Dictionary = RecruitCatalog.fresh(after.id, target)
			if fresh.is_empty():
				return "Unknown recruit stage."
			after.merge(fresh, true)
		"stat":
			if not SeasonPlayerCatalog.STATS.has(target):
				return "Only the four visible stats can grow."
			if after.stats[target] >= STAT_CAP:
				return "That stat is already at level 10."
			after.stats[target] += 1
		"mastery", "round_out":
			if not after.active.has(target):
				return "Choose an active exact recipe on this player."
			if after.mastery[target] >= PITCH_CAP:
				return "That recipe is already at level 5."
			if command.op == "round_out":
				for recipe: String in after.active:
					if after.mastery[recipe] < after.mastery[target]:
						return "Choose one of this player's lowest active pitches."
			after.mastery[target] += 1
		"learn":
			if not command.replace is String or not SeasonPlayerCatalog.lesson_supported(target):
				return "This recipe's lesson is not supported."
			if after.active.has(target):
				return "This player already knows that recipe."
			if command.replace.is_empty():
				if after.active.size() >= after.capacity:
					return "At capacity: explicitly choose a recipe to replace."
				after.active.append(target)
			else:
				var index: int = after.active.find(command.replace)
				if index < 0:
					return "The replacement must be one of this player's active recipes."
				after.active[index] = target
			after.mastery[target] = after.mastery.get(target, 1)
		_:
			return "Unsupported development operation."
	return ""


static func _error(message: String) -> Dictionary:
	return {"ok": false, "replayed": false, "error": message}


static func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	return (
		(value is int or value is float)
		and is_finite(float(value))
		and float(value) == floor(float(value))
		and value >= minimum
		and value <= maximum
	)


static func _keys(value: Dictionary, fields: Array[String]) -> bool:
	if value.size() != fields.size():
		return false
	for field: String in fields:
		if not value.has(field):
			return false
	return true


func earned_players(roster: Array) -> Array[String]:
	# Provenance, not a comparison against base stats: recruit catch-up is not earned.
	var result: Array[String] = []
	for event: Dictionary in _events:
		if event.op in ["stat", "mastery", "round_out"]:
			if roster.has(event.player) and not result.has(event.player):
				result.append(event.player)
	return result
