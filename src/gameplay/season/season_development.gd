class_name SeasonDevelopment
extends RefCounted
## Season-local development ledger. Acquisition/payment belongs to the caller's
## atomic transaction; the playtest path issues explicitly synthetic grants only.
# gdlint: disable=max-returns
# Validation exits before publishing any candidate state.

const VERSION: int = 1
const SCRAMBLE_VERSION: int = 2
const DYNASTY_VERSION: int = 3
const DynastyProfile = preload("res://src/gameplay/season/dynasty_start_profile.gd")
const STAT_CAP: int = SeasonPlayerCatalog.STAT_CAP
const PITCH_CAP: int = 5
const MAX_EVENTS: int = 4096

var _pitch_catalog_version: int = 0
var _exotic_start: Array = []
var _exotic_current: Dictionary = {}
var _exotic_ids: Array[String] = []
var _season_key: String
var _league_rules: Dictionary = {}
var _dynasty_start: Dictionary = {}
var _players: Dictionary = {}
var _events: Array[Dictionary] = []
var _requests: Dictionary = {}


func _init(season_key: String = "", _fork_only: bool = false) -> void:
	_season_key = season_key
	_dynasty_start.make_read_only()
	if _fork_only:
		return
	for player_id: String in SeasonPlayerCatalog.ids():
		_players[player_id] = SeasonPlayerCatalog.profile(player_id)


func enable_pitch_catalog() -> bool:
	if _pitch_catalog_version == ExpandedSeasonCatalog.VERSION or revision() != 0 or not _requests.is_empty() or not _dynasty_start.is_empty():
		return false
	_pitch_catalog_version = WorkingPitchCatalog.VERSION
	return true


func enable_expanded_pitch_catalog() -> bool:
	if _pitch_catalog_version != 0 or revision() != 0 or not _requests.is_empty() \
		or not _dynasty_start.is_empty() or not _league_rules.is_empty() \
		or ExpandedSeasonCatalog.descriptor().is_empty():
		return false
	_pitch_catalog_version = ExpandedSeasonCatalog.VERSION
	return true


func install_exotic_start(proofs: Array) -> bool:
	if revision() != 0 or _pitch_catalog_version != WorkingPitchCatalog.VERSION or not WorkingExoticAccess.valid_history(proofs):
		return false
	_exotic_start = proofs.duplicate(true)
	_exotic_ids = WorkingExoticAccess.ids(_exotic_start)
	return true


func retain_exotic_current(proof: Dictionary) -> void:
	if _pitch_catalog_version == ExpandedSeasonCatalog.VERSION:
		if not proof.is_empty() and not ExpandedExoticEligibility.valid(proof):
			return
		_exotic_current = proof.duplicate(true)
		for id: String in ExpandedExoticEligibility.eligible_ids(proof):
			if not _exotic_ids.has(id):
				_exotic_ids.append(id)
		return
	_exotic_current = proof.duplicate(true)
	for id: String in WorkingExoticEligibility.eligible_ids(proof):
		if not _exotic_ids.has(id):
			_exotic_ids.append(id)


func lesson_supported(recipe: String) -> bool:
	if _pitch_catalog_version == ExpandedSeasonCatalog.VERSION:
		var pitch: PitchDefinition = ExpandedSeasonCatalog.get_recipe(recipe)
		return ExpandedSeasonCatalog.is_active(recipe) and pitch != null \
			and pitch.delivery_profile != null \
			and (ExpandedSeasonCatalog.lesson_price(recipe) >= 0 or _exotic_ids.has(recipe))
	if _pitch_catalog_version == WorkingPitchCatalog.VERSION:
		var pitch: PitchDefinition = WorkingPitchCatalog.get_recipe(recipe)
		return WorkingPitchCatalog.is_active(recipe) and pitch != null \
			and pitch.delivery_profile != null \
			and (WorkingPitchCatalog.lesson_price(recipe) >= 0 or _exotic_ids.has(recipe))
	return SeasonPlayerCatalog.lesson_supported(recipe)


func enable_scramble(value: Variant) -> bool:
	if _pitch_catalog_version == ExpandedSeasonCatalog.VERSION:
		return false
	var rules: Dictionary = LeagueRules.normalized(value)
	if _season_key.is_empty() or revision() != 0 or not LeagueRules.scramble(rules):
		return false
	if not _league_rules.is_empty():
		return context_matches(rules)
	var players: Dictionary = {}
	for player_id: String in SeasonPlayerCatalog.ids():
		if player(player_id) != SeasonPlayerCatalog.profile(player_id):
			return false
		var profile: Dictionary = SeasonScramble.profile(player_id, rules)
		if profile.is_empty():
			return false
		players[player_id] = profile
	_players = players
	_league_rules = rules.duplicate(true)
	return true


func enable_dynasty(value: Variant, start: Dictionary = {}) -> bool:
	if _pitch_catalog_version == ExpandedSeasonCatalog.VERSION:
		return false
	var rules: Dictionary = LeagueRules.normalized(value)
	if (
		_season_key.is_empty()
		or revision() != 0
		or not _requests.is_empty()
		or not LeagueRules.dynasty(rules)
	):
		return false
	if not _league_rules.is_empty() and not context_matches(rules):
		return false
	var checked: Dictionary = {} if start.is_empty() else DynastyProfile.normalize(start)
	if (not start.is_empty() and checked.is_empty()) or (
		checked.has("pitch_catalog") != (_pitch_catalog_version == WorkingPitchCatalog.VERSION) and not checked.is_empty()
	):
		return false
	if not _dynasty_start.is_empty():
		return DynastyProfile.same(_dynasty_start, checked)
	var players: Dictionary = {}
	for player_id: String in SeasonPlayerCatalog.ids():
		var authored: Dictionary = SeasonPlayerCatalog.profile(player_id)
		if player(player_id) != authored:
			return false
		players[player_id] = authored
	if not checked.is_empty():
		for player_id: String in checked.roster:
			var carried: Dictionary = checked.players[player_id]
			# Keep catalog identity/base/capacity. Gameplay definitions still clone
			# the authored hand and natural delivery via ProgressionMatchAdapter.
			players[player_id].stats = carried.stats.duplicate(true)
			players[player_id].active.assign(carried.active)
			players[player_id].mastery = carried.mastery.duplicate(true)
			if not carried.catchup.origin.is_empty():
				players[player_id]["catchup"] = carried.catchup.origin.duplicate(true)
	_players = players
	_league_rules = rules.duplicate(true)
	_dynasty_start = checked
	DynastyProfile.freeze(_dynasty_start)
	return true


func context_matches(value: Variant) -> bool:
	if value is Dictionary and value.is_empty():
		return _league_rules.is_empty() and _dynasty_start.is_empty()
	var rules: Dictionary = LeagueRules.normalized(value)
	if rules.is_empty():
		return false
	if LeagueRules.scramble(rules):
		return (
			LeagueRules.scramble(_league_rules)
			and _league_rules == rules
			and _dynasty_start.is_empty()
		)
	if LeagueRules.dynasty(rules):
		return LeagueRules.dynasty(_league_rules) and _league_rules == rules
	return _league_rules.is_empty() and _dynasty_start.is_empty()


func recruit_profile(player_id: String, stage: String) -> Dictionary:
	if not SeasonPlayerCatalog.ROWS.has(player_id):
		return {}
	if not LeagueRules.scramble(_league_rules):
		return RecruitCatalog.fresh(player_id, stage)
	return SeasonScramble.fresh(player_id, stage, _league_rules)


func revision() -> int:
	return _events.size()


func fork() -> SeasonDevelopment:
	var result: SeasonDevelopment = SeasonDevelopment.new(_season_key, true)
	result._pitch_catalog_version = _pitch_catalog_version
	result._exotic_start = _exotic_start.duplicate(true)
	result._exotic_current = _exotic_current.duplicate(true)
	result._exotic_ids = _exotic_ids.duplicate()
	result._league_rules = _league_rules.duplicate(true)
	result._dynasty_start = _dynasty_start.duplicate(true)
	DynastyProfile.freeze(result._dynasty_start)
	result._players = _players.duplicate(true)
	result._events = _events.duplicate(true)
	result._requests = _requests.duplicate(true)
	return result


func player(player_id: String) -> Dictionary:
	return _players.get(player_id, {}).duplicate(true)


func to_data() -> Dictionary:
	var data: Dictionary = {
		"version":
		(
			DYNASTY_VERSION
			if LeagueRules.dynasty(_league_rules)
			else (VERSION if _league_rules.is_empty() else SCRAMBLE_VERSION)
		),
		"season": _season_key,
		"catalog": SeasonPlayerCatalog.signature(),
		"events": _events.duplicate(true)
	}
	if not _league_rules.is_empty():
		data["league_rules"] = _league_rules.duplicate(true)
	if LeagueRules.dynasty(_league_rules):
		data["dynasty_start"] = _dynasty_start.duplicate(true)
	if _pitch_catalog_version == ExpandedSeasonCatalog.VERSION:
		return ExpandedSeasonProgression.wrap_development(data, [], _exotic_current)
	return WorkingPitchProgression.wrap_development(data, _exotic_start, _exotic_current) if _pitch_catalog_version == WorkingPitchCatalog.VERSION else data


static func from_data(
	value: Variant, season_key: String, expected_rules: Variant = {}, expected_start: Variant = {}
) -> SeasonDevelopment:
	var expanded: bool = value is Dictionary and WorkingPitchProgression.is_version(value.get("version"), ExpandedSeasonProgression.DEVELOPMENT_VERSION)
	var expanded_proof: Dictionary = {}
	if expanded:
		# A standalone development ledger has no settled reward journal. Only
		# SeasonBuild replay may authorize a nonempty v6 exotic proof.
		if not value.get("exotic_current") is Dictionary or not value.exotic_current.is_empty():
			return null
		expanded_proof = value.exotic_current.duplicate(true)
		value = ExpandedSeasonProgression.unwrap_development(value)
	var current: bool = value is Dictionary and WorkingPitchProgression.is_version(value.get("version"), WorkingPitchProgression.DEVELOPMENT_VERSION)
	var exotic_current: Variant = value.get("exotic_current", {}) if current else {}
	var exotic_start: Variant = value.get("exotic_start", []) if current else []
	if current:
		value = WorkingPitchProgression.unwrap_development(value)
	if not value is Dictionary or not _whole(value.get("version"), VERSION, DYNASTY_VERSION):
		return null
	var fields: Array[String] = ["version", "season", "catalog", "events"]
	if value.version >= SCRAMBLE_VERSION:
		fields.append("league_rules")
	if value.version == DYNASTY_VERSION:
		fields.append("dynasty_start")
	if not _keys(value, fields) or value.season != season_key or season_key.is_empty():
		return null
	if value.catalog != SeasonPlayerCatalog.signature() or not value.events is Array:
		return null
	if value.events.size() > MAX_EVENTS:
		return null
	var result: SeasonDevelopment = SeasonDevelopment.new(season_key)
	if expanded and not result.enable_expanded_pitch_catalog():
		return null
	if expanded:
		exotic_current = expanded_proof
	if current and not result.enable_pitch_catalog():
		return null
	if current and not result.install_exotic_start(exotic_start):
		return null
	result.retain_exotic_current(exotic_current)
	if not result._exotic_current.is_empty() and result._exotic_current.season != season_key:
		return null
	if value.version == SCRAMBLE_VERSION:
		if not result.enable_scramble(value.league_rules):
			return null
	elif value.version == DYNASTY_VERSION:
		if (
			not value.dynasty_start is Dictionary
			or not result.enable_dynasty(value.league_rules, value.dynasty_start)
		):
			return null
	if (
		not expected_start is Dictionary
		or not DynastyProfile.same(result._dynasty_start, expected_start)
	):
		return null
	if not result.context_matches(expected_rules):
		return null
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
	if (
		not _league_rules.is_empty()
		and not LeagueRules.scramble(_league_rules)
		and not LeagueRules.dynasty(_league_rules)
	):
		return _error("Invalid development league context.")
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
	if command.get("op") == "retrain":
		return SeasonRetraining.prepare(self, command)
	if command.get("op") == "learn" and not lesson_supported(str(command.get("target", ""))):
		return _error("This recipe is outside this season's catalog.")
	var after: Dictionary = player(command.player)
	var error: String = (
		_apply_scramble_recruit(after, command)
		if command.get("op") == "recruit" and LeagueRules.scramble(_league_rules)
		else _apply(after, command, _pitch_catalog_version)
	)
	if not error.is_empty():
		return _error(error)
	return {"ok": true, "replayed": false, "after": after}


func _apply_scramble_recruit(after: Dictionary, command: Dictionary) -> String:
	if (
		not _keys(command, ["id", "rev", "player", "op", "target"])
		or not command.get("target") is String
	):
		return "Unexpected development fields."
	var baseline: Dictionary = SeasonScramble.profile(after.id, _league_rules)
	if baseline.is_empty() or after != baseline:
		return "Only a fresh season instance can receive recruit development."
	var fresh: Dictionary = recruit_profile(after.id, command.target)
	if fresh.is_empty():
		return "Unknown recruit stage."
	after.merge(fresh, true)
	return ""


static func _apply(
	after: Dictionary, command: Dictionary, pitch_catalog_version: int = 0
) -> String:
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
			if not command.replace is String or not (
				ExpandedSeasonCatalog.supports(target) if pitch_catalog_version == ExpandedSeasonCatalog.VERSION
				else WorkingPitchCatalog.supports(target) if pitch_catalog_version == WorkingPitchCatalog.VERSION
				else SeasonPlayerCatalog.lesson_supported(target)
			):
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
	for player_id: String in _dynasty_start.get("roster", []):
		if roster.has(player_id) and _dynasty_start.players[player_id].ever_earned:
			result.append(player_id)
	for event: Dictionary in _events:
		if event.op in ["stat", "mastery", "round_out"]:
			if roster.has(event.player) and not result.has(event.player):
				result.append(event.player)
	return result
