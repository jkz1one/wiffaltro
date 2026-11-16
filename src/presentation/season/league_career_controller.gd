extends RefCounted
## Candidate-only orchestration. Prepare is read-only; save precedes live promotion.

const IDS: Array[String] = [
	"standard", "dugout", "sponsorship", "academy", "doubleheader", "equipment", "earnings", "scramble"
]
const Unlocks = preload("res://src/gameplay/season/league_unlocks.gd")

var app: SeasonApp
var path: String
var error: String = ""
var _candidate: SeasonState
var _source: SeasonState
var _source_digest: String = ""
var _disk_digest: String = ""
var _token: int = 0


func _init(owner_app: SeasonApp, save_path: String) -> void:
	app = owner_app
	path = save_path


func _fail(message: String) -> bool:
	error = message
	app.notice = message
	return false


func _safe() -> bool:
	return (
		SeasonSave.path == path
		and not SeasonSave.dynasty_owner_bound()
		and app.lab == null
		and not app._busy
		and app._unsaved_draft == null
		and (
			app.season == null
			or app.season.physical == null
			or app.season.physical.pending.is_empty()
		)
		and (
			app.season == null or app.season.build == null
			or app.season.build._match_inventory.is_empty()
			or SeasonInventoryRules.closed(app.season.build)
		)
	)


func _disk() -> String:
	return (
		FileAccess.get_file_as_bytes(path).hex_encode().sha256_text()
		if FileAccess.file_exists(path)
		else "absent"
	)


func _digest(season: SeasonState) -> String:
	if season == null:
		return "none"
	var data: Dictionary = SeasonSave.snapshot(season)
	return "" if data.is_empty() else JSON.stringify(data, "", true, true).sha256_text()


func available_leagues() -> Array[String]:
	var club: ClubCareer = app.season.career if app.season != null else ClubCareer.new()
	return club.available_leagues() if club != null else ClubCareer.new().available_leagues()


func available_tiers(league: String) -> Array[int]:
	if league not in IDS or league not in available_leagues():
		return []
	# Ordinary higher-tier Standard saves need the existing owned-venue setup.
	if league == "standard":
		return [0]
	var club: ClubCareer = app.season.career if app.season != null else ClubCareer.new()
	return club.available_tiers(league) if club != null else ClubCareer.new().available_tiers(league)


func prepare(league: String, seed_value: int, tier: int = 0) -> bool:
	if _candidate != null:
		cancel(token())
	if league in IDS and league not in available_leagues():
		return _fail(Unlocks.requirement(league) + " Your current season is unchanged.")
	if (
		not _safe() or league not in IDS or not SeasonOwnership._whole(seed_value, 0, 2147483647)
		or tier not in available_tiers(league)
	):
		return _fail("Choose an available League difficulty. Win its previous tier to unlock the next.")
	if app.season == null and (
		FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")
		or FileAccess.file_exists(path + ".tmp")
	):
		return _fail("The candidate save needs recovery. It was not replaced.")
	var club: ClubCareer = _closed_club()
	if club == null:
		return false
	if league not in club.available_leagues() or tier not in club.available_tiers(league):
		return _fail("This League or difficulty is not unlocked. Your season is unchanged.")
	return _prepare(league, seed_value, tier, club)


func _closed_club() -> ClubCareer:
	if app.season == null:
		return ClubCareer.new()
	var previous: SeasonState = SeasonSave._decode(SeasonSave.snapshot(app.season))
	if previous == null:
		_fail("The current club record could not be validated. Your season is unchanged.")
		return null
	# A validated legacy season has no persistent ledger to close or migrate.
	if previous.career == null:
		return ClubCareer.new()
	var club: ClubCareer = previous.career.fork()
	if not club.close(previous):
		_fail("The current club record could not be closed. Your season is unchanged.")
		return null
	return club


func _prepare(league: String, seed_value: int, tier: int, club: ClubCareer) -> bool:
	var fresh_club: bool = club.runs.is_empty()
	var next: SeasonState
	if league == "standard":
		next = SeasonState.create(seed_value, false, true, true)
		next.physical = SeasonPhysicalFixtures.new()
		next.opponents._format = 13
		if (fresh_club or not club._pitch_catalog.is_empty()) and not WorkingPitchCareerProgress.admit(next, club):
			return _fail("Could not prepare the pitch catalog. Your season is unchanged.")
		if not ClubPlayerDraft.apply(next, ClubPlayers.owned(club)) or not club.start(next):
			return _fail("Could not prepare Standard / Base. Your season is unchanged.")
		next.career = club
	else:
		next = SeasonState.create_closed_league(
			seed_value,
			LeagueRules.capture_tier(league, tier, seed_value if league == "scramble" else null),
			true
		)
		if next != null and (fresh_club or not club._pitch_catalog.is_empty()) \
			and not WorkingPitchCareerProgress.admit(next, club):
			return _fail("Could not prepare the pitch catalog. Your season is unchanged.")
		if next == null or not ClubPlayerDraft.apply(next, ClubPlayers.owned(club)) \
			or not club.start_league(next):
			return _fail("Could not prepare this League career. Your season is unchanged.")
	if fresh_club:
		# Match normal Standard's new-club origin without replacing retained assets.
		club._assets = ClubAssetLedger.new_club(int(club.runs[0].seed),
			ClubPlayers.income(club), StadiumCareerProgress.capture(club)).to_data()
	if league != "standard" and not load("res://src/gameplay/season/normal_league_home.gd").prepare(next):
		return _fail("This owned field is not supported for a new League yet. Your season is unchanged.")
	if SeasonSave._decode(SeasonSave.snapshot(next)) == null:
		return _fail("The prepared season failed validation. Your season is unchanged.")
	_candidate = next
	_source = app.season
	_source_digest = _digest(_source)
	_disk_digest = _disk()
	_token += 1
	error = ""
	app.notice = ""
	return true


func starting_profile(ticket: int, profile: String) -> bool:
	# Explicit candidate operation. Public controls remain source-gated separately.
	if ticket < 0 or ticket != token() or not _safe() or app.season != _source \
		or _digest(app.season) != _source_digest or _disk() != _disk_digest \
		or profile not in ["day", "sunset", "night"]:
		return _fail("This time choice is out of date. Reopen League selection.")
	var adapter = load("res://src/gameplay/season/normal_league_time_candidate.gd")
	var source: SeasonState = _candidate
	if source._league_home_context.get("format") == 94:
		source = adapter.qualify_prephysical(adapter.capture(source)).get("source")
	var next: SeasonState = adapter.admit(source, profile)
	if next == null:
		return _fail("This paid field does not support that starting time. Your season is unchanged.")
	_candidate = next
	_token += 1  # Retained callbacks from the prior review cannot commit this choice.
	error = ""
	app.notice = ""
	return true


func token() -> int:
	return _token if _candidate != null else -1


func candidate() -> SeasonState:
	return _candidate


func cancel(ticket: int) -> bool:
	if ticket < 0 or ticket != token():
		return false
	_candidate = null
	_source = null
	_token += 1
	return true


func commit(ticket: int) -> bool:
	if (
		ticket < 0 or ticket != token() or not _safe()
		or app.season != _source or _digest(app.season) != _source_digest
		or _disk() != _disk_digest
	):
		return _fail("This start choice is out of date. Reopen League selection.")
	var league: String = str(_candidate.league_rules.get("league", "standard"))
	if league not in available_leagues():
		return _fail(Unlocks.requirement(league) + " Reopen League selection.")
	if not SeasonSave.save(_candidate):
		return _fail(SeasonSave.last_error)
	app.season = _candidate
	_candidate = null
	_source = null
	_token += 1
	app.notice = ""
	error = ""
	app.menu.draft_selection = ""
	app.show_season()
	return true


func draft_pick(player_id: String) -> bool:
	if not _safe() or app.season == null or app.season.phase != SeasonState.Phase.DRAFT:
		return _fail("Return to the current draft before choosing a player.")
	var next: SeasonState = SeasonSave._decode(SeasonSave.snapshot(app.season))
	if next == null or not next.choose_player(player_id):
		return _fail("Choose one of the current three offers.")
	if (
		not next.league_rules.is_empty() and next.picks.size() == 4
		and not SeasonInventoryRules.enable(next)
	):
		return _fail("Could not prepare the League inventory. Your previous picks remain saved.")
	if not SeasonSave.save(next):
		return _fail(SeasonSave.last_error + " Your previous picks remain saved; retry this pick.")
	app.season = next
	app.menu.draft_selection = ""
	app.notice = ""
	error = ""
	return true


func player_transaction(request: Dictionary) -> Dictionary:
	if not _safe() or app.season == null or app.season.player_access.is_empty():
		return ClubAssetLedger._error("Return to the saved candidate hub before changing ownership.")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var saved: SeasonState = SeasonSave._decode(data) if data is Dictionary else null
	var live_digest: String = _digest(app.season)
	if saved == null or live_digest.is_empty() or _digest(saved) != live_digest:
		return ClubAssetLedger._error("Save or recover this exact candidate before buying or choosing.")
	return ClubPlayers.transact(app.season, request)
