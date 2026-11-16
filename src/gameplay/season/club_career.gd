class_name ClubCareer
extends "res://src/gameplay/season/club_career_progress.gd"
# gdlint: disable=max-returns
## One persistent ledger, embedded atomically with its active season. No power carries over.

const ClubLeagueCareer = preload("res://src/gameplay/season/club_league_career.gd")
const LeagueUnlocks = preload("res://src/gameplay/season/league_unlocks.gd")

const MAX_RUNS: int = 1024
# Grandstand Gardens III is accepted for Working public D4 entry; genuine title guards still apply.
const D4_PUBLIC_ACTIVATION_ENABLED: bool = true
var _assets: Dictionary = {}
# Empty is legacy history; only a subsequent ordinary start adopts future era records.
var _pennants: Dictionary = {}
# Empty legacy history never grants retrospective Club Legend receipts.
var _plaques: Dictionary = {}
# Explicit Career32 admission, never inferred from a pitch ID in an old record.
var _pitch_catalog: String = ""


func fork() -> ClubCareer:
	var result: ClubCareer = ClubCareer.new()
	result.current = current
	result.runs = runs.duplicate(true)
	result._assets = _assets.duplicate(true)
	result._pennants = _pennants.duplicate(true)
	result._plaques = _plaques.duplicate(true)
	result._pitch_catalog = _pitch_catalog
	return result


func start(season: SeasonState, selected_tier: int = 0) -> bool:
	if season == null or not season.league_rules.is_empty() or season.league_career:
		return false
	return _start(season, selected_tier)


func start_league(season: SeasonState) -> bool:
	if (
		season == null
		or season.career != null
		or season.league_career
		or not ClubLeagueCareer.rules_valid(season.league_rules, season.season_seed)
		or not season._closed_access.is_empty()
		or not season._dynasty_owner_binding.is_empty()
		or not season.league_live
	):
		return false
	if not _start(season, int(season.league_rules.tier)):
		return false
	season.career = self
	season.league_career = true
	return true


func start_owner_projection(season: SeasonState, selected_tier: int) -> bool:
	# A transient Standard validation projection, never an ordinary career save.
	if season == null or not season.league_rules.is_empty() or season.league_career:
		return false
	return _start(season, selected_tier, true)


func _start(season: SeasonState, selected_tier: int, owner_history: bool = false) -> bool:
	if season == null or selected_tier not in [0, 1, 2, 3, 4]:
		return false
	if season.build == null or season.build.pitch_catalog_expanded() or season.build.pitch_catalog_current() != (not _pitch_catalog.is_empty()):
		return false
	if not season.league_context_consistent():
		return false
	if season.phase != SeasonState.Phase.DRAFT or not season.picks.is_empty():
		return false
	if current != 0 or runs.size() >= MAX_RUNS or season.build == null or season.opponents == null:
		return false
	# Unlocks come from a fully validated, earlier completed career prefix.
	var history: Dictionary = to_data()
	if owner_history:
		history.version = 28
	var checked: ClubCareer = ClubCareer.from_owner_history(history) if owner_history else ClubCareer.from_data(history)
	if checked == null:
		return false
	var selected_league: String = season.league_rules.get("league", "standard")
	if selected_league not in LeagueUnlocks.from_titles(checked._title_history()):
		return false
	if selected_tier > 0:
		# Inspect only the same-call validated rows; do not replay the prefix again.
		var unlocked: bool = false
		for previous: Dictionary in checked.runs:
			if (
				previous.league == selected_league
				and previous.tier == selected_tier - 1
				and previous.status == "completed"
				and previous.receipt.get("finish") == "champion"
			):
				unlocked = true
				break
		if not unlocked:
			return false
	if season.build._market != 0 or not season.build.pricing_context_valid():
		return false
	if (
		(selected_tier == 0 and season.build._pricing_rule != "")
		or (selected_tier < 3 and season.build._sponsor_rule != "")
		or (
			selected_tier == 3
			and season.build._sponsor_rule not in ["", SeasonSponsorCatalog.D3_RULE]
		)
		or (
			selected_tier == 4
			and season.build._sponsor_rule not in ["", SeasonSponsorCatalog.D4_RULE]
		)
	):
		return false
	if (
		not season.opponents.draft_rule_valid()
		or (selected_tier < 2 and season.opponents.draft_rule != "")
	):
		return false
	if runs.is_empty():
		var empty_assets: ClubAssetLedger = ClubPlayers.assets(self)
		if empty_assets == null or empty_assets.revision() != 0:
			return false
		_assets = {}
	if selected_tier > 0:
		if (
			season.opponents._format != 13
			or not season.opponents.clubs.is_empty()
			or season.build.revision() != 0
		):
			return false
		if selected_tier == 4:
			if not season.build.d4_sponsors_valid() and not season.build.enable_d4_sponsors():
				return false
		elif selected_tier == 3:
			if not season.build.d3_sponsors_valid() and not season.build.enable_d3_sponsors():
				return false
		elif not season.build.d1_pricing_valid() and not season.build.enable_d1_pricing():
			return false
	season.opponents.draft_rule = SeasonOpponentDraft.D2_RULE if selected_tier >= 2 else ""
	season.build._gear_progress.enabled = true
	season.build._gear_progress.start = gear_counts()
	season.build._sponsor_progress.enabled = true
	season.build._sponsor_progress.start = sponsor_state()
	season.build._order_start = order_access()
	season.build._rain_start = rain_access()
	season.build._transfer_start = transfer_access()
	season.build._supply_start = supply_count()
	season.build._checkout_start = SeasonLateCheckout.access(self)
	season.build._association_start = SeasonAssociation.access(self)
	season.build._freezer_start = SeasonFreezers.access(self)
	season.build._sides_start = SeasonLeftRight.access(self)
	season.build._jump_start = SeasonJumpstart.access(self)
	season.build._sure_start = SeasonSureShot.access(self)
	season.build._major.start = SeasonDoubleMajor.access(self)
	season.build._abilities.start = SeasonAbilities.access(self)
	season.build._copy.start = SeasonCarbonCopy.access(self)
	season.build._field_start = SeasonFieldSupply.access(self)
	season.build._batch_start = SeasonSmallBatch.access(self)
	if not _pitch_catalog.is_empty():
		if not season.build._book.install_exotic_start(WorkingExoticAccess.history(checked)):
			return false
	current = runs.size() + 1
	runs.append(
		{
			"id": current,
			"seed": season.season_seed,
			"league": season.league_rules.get("league", "standard"),
			"tier": selected_tier,
			"status": "active",
			"proof": ClubSeasonRecord.capture(season),
			"receipt": {},
			"gear": [],
			"sponsors": [],
			"order_rerolls": 0,
			"rain_earned": false,
			"transfer_earned": false,
			"checkout_earned": false,
			"association_earned": false,
			"freezer_earned": false,
			"sides_earned": false,
			"jump_earned": false,
			"sure_earned": false,
			"major_earned": false,
			"sky_outs": 0,
			"copy_earned": false,
			"field_outs": 0,
			"batch_used": [],
			"collection": [],
			"supplies_used": 0,
			"player_progress": WorkingPitchCareerProgress.capture(season) if not _pitch_catalog.is_empty() else ClubPlayerLegend.capture(season)
		}
	)
	if not season.league_rules.is_empty():
		runs[-1]["league_rules"] = season.league_rules.duplicate(true)
	StadiumPennantRewards.adopt(self)
	StadiumPlaqueRewards.adopt(self)
	return true


func sync(season: SeasonState) -> bool:
	if season == null:
		return false
	if current == 0:
		return season.build == null
	if current != runs.size() or season.season_seed != runs[-1].seed:
		return false
	if not _pricing_matches(season):
		return false
	if not _pitch_catalog.is_empty() and not WorkingExoticAccess.matches(self, season):
		return false
	var run: Dictionary = runs[-1]
	if (
		not ClubCollection.matches(self, season, false)
		or not gear_matches(season, false)
		or not sponsor_matches(season, false)
		or not order_matches(season, false)
		or not rain_matches(season, false)
		or not transfer_matches(season, false)
		or not supply_matches(season, false)
		or not SeasonLateCheckout.matches(self, season, false)
		or not SeasonAssociation.matches(self, season, false)
		or not SeasonFreezers.matches(self, season, false)
		or not SeasonLeftRight.matches(self, season, false)
		or not SeasonJumpstart.matches(self, season, false)
		or not SeasonSureShot.matches(self, season, false)
		or not SeasonCarbonCopy.matches(self, season, false)
		or not SeasonFieldSupply.matches(self, season, false)
		or not SeasonDoubleMajor.matches(self, season, false)
		or not SeasonAbilities.matches(self, season, false)
		or not SeasonSmallBatch.matches(self, season, false)
	):
		return false
	var gear: Variant = (
		season.build._gear_progress.games.duplicate(true) if run.gear != null else null
	)
	var sponsors: Variant = (
		season.build._sponsor_progress.games.duplicate(true) if run.sponsors != null else null
	)
	var orders: Variant = season.build._paid_rerolls if run.order_rerolls != null else null
	var rain: Variant = season.build._rain_earned if run.rain_earned != null else null
	var transfer: Variant = season.build._transfer_earned if run.transfer_earned != null else null
	var supplies: Variant = season.build._supply_used if run.supplies_used != null else null
	var checkout: Variant = season.build._checkout_earned if run.checkout_earned != null else null
	var association: Variant = (
		season.build._association_earned if run.association_earned != null else null
	)
	var freezer: Variant = season.build._freezer_earned if run.freezer_earned != null else null
	var sides: Variant = season.build._sides_earned if run.sides_earned != null else null
	var jump: Variant = season.build._jump_earned if run.jump_earned != null else null
	var sure: Variant = season.build._sure_earned if run.sure_earned != null else null
	var major: Variant = season.build._major.earned if run.major_earned != null else null
	var sky: Variant = season.build._abilities.earned if run.sky_outs != null else null
	var copy: Variant = season.build._copy.earned if run.copy_earned != null else null
	var field: Variant = season.build._field_outs if run.field_outs != null else null
	var batch: Variant = season.build._batch_used.duplicate() if run.batch_used != null else null
	var proof: Dictionary = ClubSeasonRecord.capture(season)
	var players: Dictionary = ClubPlayerProgress.capture_for(season, run.player_progress)
	if not _pitch_catalog.is_empty() and not WorkingExoticAccess.prefix(run.player_progress, players):
		return false
	if players.is_empty():
		return false
	if run.status == "completed":
		return (
			season.phase == SeasonState.Phase.COMPLETE
			and ClubCollection.matches(self, season, true)
			and same(run.proof, proof)
			and same(run.player_progress, players)
			and same(run.gear, gear)
			and same(run.sponsors, sponsors)
			and run.order_rerolls == orders
			and run.rain_earned == rain
			and run.transfer_earned == transfer
			and run.supplies_used == supplies
			and run.checkout_earned == checkout
			and run.association_earned == association
			and run.freezer_earned == freezer
			and run.sides_earned == sides
			and run.jump_earned == jump
			and run.sure_earned == sure
			and run.major_earned == major
			and run.sky_outs == sky
			and run.copy_earned == copy
			and run.field_outs == field
			and same(run.batch_used, batch)
		)
	if run.status != "active":
		return false
	var prior_run: Dictionary = run.duplicate(true)
	var prior_assets: Dictionary = _assets.duplicate(true)
	var prior_plaques: Dictionary = _plaques.duplicate(true)
	if season.phase == SeasonState.Phase.COMPLETE:
		var award: Dictionary = ClubSeasonRecord.receipt(
			proof, not cleared(int(run.tier), run.league), int(run.tier)
		)
		if award.is_empty():
			return false
		run.receipt = award
		run.status = "completed"
	run.player_progress = players
	run.collection = ClubCollection.acquired(season.build)
	run.proof = proof
	run.gear = gear
	run.sponsors = sponsors
	run.order_rerolls = orders
	run.rain_earned = rain
	run.transfer_earned = transfer
	run.supplies_used = supplies
	run.checkout_earned = checkout
	run.association_earned = association
	run.freezer_earned = freezer
	run.sides_earned = sides
	run.jump_earned = jump
	run.sure_earned = sure
	run.major_earned = major
	run.sky_outs = sky
	run.copy_earned = copy
	run.field_outs = field
	run.batch_used = batch
	var plaque_step: bool = (
		prior_run.status != run.status or not same(prior_run.player_progress, players)
	)
	if (
		(plaque_step and not StadiumPlaqueRewards.capture(self))
		or (run.status == "completed" and not StadiumPennantRewards.deliver(self))
		or not StadiumPlaqueRewards.deliver(self)
	):
		runs[-1] = prior_run
		_assets = prior_assets
		_plaques = prior_plaques
		return false
	return true


func close(season: SeasonState) -> bool:
	if not sync(season):
		return false
	if current > 0 and runs[-1].status == "active":
		runs[-1].status = "abandoned"
	current = 0
	return true


func balance() -> int:
	var ledger: ClubAssetLedger = ClubPlayers.assets(self)
	return 0 if ledger == null else ledger.balance()


func cleared(tier: int = 0, league: String = "standard") -> bool:
	if tier not in [0, 1, 2, 3, 4]:
		return false
	return bool(_title_history().get(ClubLeagueCareer.title_key(league, tier), false))


func available_leagues() -> Array[String]:
	var checked: ClubCareer = ClubCareer.from_data(to_data())
	return [] if checked == null else LeagueUnlocks.from_titles(checked._title_history())


func available_tiers(league: String = "standard") -> Array[int]:
	if league != "standard" and league not in ClubLeagueCareer.IDS:
		return []
	var titles: Dictionary = _title_history()
	if titles.is_empty():
		return []
	var result: Array[int] = [0]
	for tier in range(1, 5):
		if titles.get(ClubLeagueCareer.title_key(league, tier - 1), false):
			result.append(tier)
	return result


func active_tier() -> int:
	# This accessor binds the current row; admission/start validates the whole prefix.
	# Replaying all historic proofs here would repeat that work on every save join.
	if current < 1 or current > MAX_RUNS or current != runs.size():
		return -1
	var run: Dictionary = runs[-1]
	if (
		not SeasonOwnership._whole(run.get("id"), current, current)
		or not SeasonOwnership._whole(run.get("seed"), 0, 2147483647)
		or not ClubLeagueCareer.row_valid(run)
		or not SeasonOwnership._whole(run.get("tier"), 0, 4)
		or run.get("status") not in ["active", "completed"]
	):
		return -1
	return int(run.tier)


func _title_history() -> Dictionary:
	if (
		runs.size() > MAX_RUNS
		or current < 0
		or current > runs.size()
		or (current != 0 and current != runs.size())
	):
		return {}
	var titles: Dictionary = {"0": false, "1": false, "2": false, "3": false, "4": false}
	for index in range(runs.size()):
		var row: Dictionary = runs[index]
		if (
			row.get("id") != index + 1
			or not SeasonOwnership._whole(row.get("seed"), 0, 2147483647)
			or (row.get("status") == "active" and row.id != current)
			or (row.get("status") == "abandoned" and row.id == current)
			or _progression_record(row, titles).is_empty()
		):
			return {}
	return titles


static func _progression_record(row: Dictionary, titles: Dictionary) -> Dictionary:
	if (
		not ClubLeagueCareer.row_valid(row)
		or not SeasonOwnership._whole(row.get("tier"), 0, 4)
		or row.get("status") not in ["active", "completed", "abandoned"]
		or not row.get("receipt") is Dictionary
	):
		return {}
	# Check the strict earlier prefix. No Standard tier can unlock itself.
	if row.tier > 0 and not titles.get(
		ClubLeagueCareer.title_key(row.league, int(row.tier) - 1), false
	):
		return {}
	var record: Dictionary = ClubSeasonRecord.analyze(row.get("proof"))
	if record.is_empty():
		return {}
	var key: String = ClubLeagueCareer.title_key(row.league, int(row.tier))
	if row.status == "completed":
		var expected: Dictionary = ClubSeasonRecord.receipt(
			row.proof, not titles.get(key, false), int(row.tier)
		)
		if expected.is_empty() or not same(row.receipt, expected):
			return {}
		if record.finish == "champion":
			titles[key] = true
	elif not row.receipt.is_empty() or record.finish != "unfinished":
		return {}
	return record


func _pricing_matches(season: SeasonState) -> bool:
	if season == null or season.build == null or season.build.pitch_catalog_current() != (not _pitch_catalog.is_empty()):
		return false
	if (
		season == null
		or not season.league_context_consistent()
		or not ClubLeagueCareer.context_matches(season, self)
	):
		return false
	var tier: int = active_tier()
	if (
		tier < 0
		or season.build == null
		or season.opponents == null
		or season.build._market != 0
		or not season.build.pricing_context_valid()
	):
		return false
	if (
		(tier > 0) != season.build.d1_pricing_valid()
		or (tier == 3) != season.build.d3_sponsors_valid()
		or (tier == 4) != season.build.d4_sponsors_valid()
	):
		return false
	if tier > 0 and season.opponents._format != 13:
		return false
	var draft_rule: String = SeasonOpponentDraft.D2_RULE if tier >= 2 else ""
	if not season.opponents.draft_rule_valid() or season.opponents.draft_rule != draft_rule:
		return false
	if season.phase == SeasonState.Phase.DRAFT and season.picks.size() < 4:
		return season.opponents.clubs.is_empty()
	if season.opponents.clubs.size() != 5:
		return false
	for index in range(1, 6):
		var club: Variant = season.opponents.clubs.get(str(index))
		if not club is Dictionary or not club.get("build") is SeasonBuild:
			return false
		var build: SeasonBuild = club.build
		if (
			not build.pricing_context_valid()
			or (tier > 0) != build.d1_pricing_valid()
			or (tier > 0 and build._market != 12)
			or (tier == 3) != build.d3_sponsors_valid()
			or (tier == 4) != build.d4_sponsors_valid()
		):
			return false
	return true


func standard_version() -> int:
	var version: int = 22
	for run: Dictionary in runs:
		if (
			run.get("league") == "standard"
			and SeasonOwnership._whole(run.get("tier"), 1, 4)
		):
			version = maxi(version, 22 + int(run.tier))
	return version


func to_data() -> Dictionary:
	var ledger: ClubAssetLedger = ClubPlayers.assets(self)
	var version: int = standard_version()
	for run: Dictionary in runs:
		if run.get("league") != "standard":
			version = ClubLeagueCareer.VERSION
	var result: Dictionary = {
		"version": version,
		"current": current,
		"runs": runs.duplicate(true),
		"assets": ledger.to_data() if ledger != null else null
	}
	if not _pennants.is_empty():
		result["pennants"] = _pennants.duplicate(true)
	if not _plaques.is_empty():
		result["plaques"] = _plaques.duplicate(true)
	return WorkingPitchCareerProgress.wrap_career(result) if not _pitch_catalog.is_empty() else result


static func from_data(value: Variant) -> ClubCareer:
	if value is Dictionary and WorkingPitchProgression.is_version(value.get("version"), WorkingPitchCareerProgress.CAREER_VERSION):
		return WorkingPitchCareerProgress.restore_career(value)
	if not value is Dictionary or not SeasonOwnership._whole(
		value.get("version"), 1, ClubLeagueCareer.VERSION
	):
		return null
	return _decode_history(value, false)


static func from_owner_history(value: Variant) -> ClubCareer:
	# Private owner projection only; never an ordinary career save decoder.
	if not value is Dictionary or not SeasonOwnership._whole(value.get("version"), 28, 28) \
		or value.get("current") != 0 or not value.get("runs") is Array:
		return null
	var sessions: Dictionary = {}
	var owner: String = ""
	for row: Variant in value.runs:
		if not row is Dictionary:
			return null
		if row.get("league") != "dynasty":
			continue
		var session: Dictionary = preload("res://src/gameplay/season/dynasty_career_save.gd").binding(row.get("dynasty_session"))
		if session.is_empty() or session.league != "dynasty" or sessions.has(session.session_id) \
			or (not owner.is_empty() and owner != session.owner_id):
			return null
		owner = session.owner_id
		sessions[session.session_id] = true
	if sessions.is_empty():
		return null
	return _decode_history(value, true)


static func _decode_history(value: Dictionary, owner_history: bool, pitch_catalog: bool = false) -> ClubCareer:
	var top: Array = ["version", "current", "runs"]
	if value.get("version") >= 22:
		top.append("assets")
		if value.has("pennants"):
			top.append("pennants")
		if value.has("plaques"):
			top.append("plaques")
	if not SeasonOwnership._keys(value, top):
		return null
	if (
		not SeasonOwnership._whole(value.version, 28 if owner_history else 1, 28 if owner_history else ClubLeagueCareer.VERSION)
		or not value.runs is Array
		or value.runs.size() > MAX_RUNS
	):
		return null
	if not SeasonOwnership._whole(value.current, 0, value.runs.size()):
		return null
	if value.current != 0 and value.current != value.runs.size():
		return null
	var result: ClubCareer = ClubCareer.new()
	result._pitch_catalog = WorkingPitchCatalog.signature() if pitch_catalog else ""
	result.current = int(value.current)
	var titles: Dictionary = {"0": false, "1": false, "2": false, "3": false, "4": false}
	var has_d1: bool = false
	var has_d2: bool = false
	var has_d3: bool = false
	var has_d4: bool = false
	var has_league: bool = false
	for row: Variant in value.runs:
		if (
			not row is Dictionary
			or not SeasonOwnership._keys(
				row,
				(
					["id", "seed", "league", "tier", "status", "proof", "receipt"]
					+ (
						["league_rules"]
						if (owner_history or value.version == ClubLeagueCareer.VERSION) and row.get("league") != "standard"
						else []
					)
					+ (["dynasty_session"] if owner_history and row.get("league") == "dynasty" else [])
					+ (["player_progress"] if value.version >= 22 else [])
					+ (["collection"] if value.version >= 19 else [])
					+ (["gear"] if value.version >= 2 else [])
					+ (["sponsors"] if value.version >= 3 else [])
					+ (["order_rerolls"] if value.version >= 4 else [])
					+ (["rain_earned"] if value.version >= 5 else [])
					+ (["transfer_earned"] if value.version >= 6 else [])
					+ (["supplies_used"] if value.version >= 7 else [])
					+ (["checkout_earned"] if value.version >= 8 else [])
					+ (["association_earned"] if value.version >= 9 else [])
					+ (["freezer_earned"] if value.version >= 10 else [])
					+ (["sides_earned"] if value.version >= 11 else [])
					+ (["jump_earned"] if value.version >= 12 else [])
					+ (["batch_used"] if value.version >= 13 else [])
					+ (["sure_earned"] if value.version >= 14 else [])
					+ (["copy_earned"] if value.version >= 16 else [])
					+ (["sky_outs"] if value.version >= 17 else [])
					+ (["major_earned"] if value.version >= 18 else [])
					+ (["field_outs"] if value.version >= 15 else [])
				)
			)
		):
			return null
		if row.id != result.runs.size() + 1 or not SeasonOwnership._whole(row.seed, 0, 2147483647):
			return null
		if not SeasonOwnership._whole(row.tier, 0, mini(4, maxi(0, int(value.version) - 22))):
			return null
		var record: Dictionary = _progression_record(row, titles)
		if record.is_empty():
			return null
		has_d1 = has_d1 or row.tier == 1
		has_d2 = has_d2 or row.tier == 2
		has_d3 = has_d3 or row.tier == 3
		has_d4 = has_d4 or row.tier == 4
		has_league = has_league or row.league != "standard"
		if row.status == "active" and row.id != result.current:
			return null
		if row.status == "abandoned" and row.id == result.current:
			return null
		var migrated: Dictionary = row.duplicate(true)
		if pitch_catalog and (not WorkingPitchCareerProgress.is_current(migrated.get("player_progress")) or not migrated.player_progress.get("exotic") is Dictionary or migrated.player_progress.exotic.get("season") != "season:%d" % int(row.seed)):
			return null  # A current career cannot relabel historical evidence.
		if value.version < 22:
			migrated["player_progress"] = null
		elif row.id == result.current and migrated.player_progress == null:
			return null
		if (
			migrated.player_progress != null
			and not (WorkingPitchCareerProgress.valid(migrated.player_progress, row.proof.scores)
				if pitch_catalog and WorkingPitchCareerProgress.is_current(migrated.player_progress)
				else ClubPlayerProgress.valid(migrated.player_progress, row.proof.scores))
		):
			return null
		if value.version < 19:
			migrated["collection"] = null
		if value.version >= 19 and row.id == result.current and migrated.collection == null:
			return null
		if (
			migrated.collection != null
			and not ClubCollection.valid(migrated.collection, value.version >= 21)
		):
			return null
		if value.version == 1:
			migrated["gear"] = null
		if (
			migrated.gear != null
			and not SeasonGearProgress.valid_games(
				migrated.gear, row.proof.scores, result.gear_counts(), value.version >= 20
			)
		):
			return null
		if value.version < 3:
			migrated["sponsors"] = null
		if (
			migrated.sponsors != null
			and not SeasonSponsorProgress.valid_games(migrated.sponsors, row.proof.scores)
		):
			return null
		if value.version < 4:
			migrated["order_rerolls"] = null
		if (
			migrated.order_rerolls != null
			and not SeasonOwnership._whole(migrated.order_rerolls, 0, SeasonBuild.MAX_EVENTS)
		):
			return null
		if value.version < 5:
			migrated["rain_earned"] = null
		if migrated.rain_earned != null and not migrated.rain_earned is bool:
			return null
		if value.version < 6:
			migrated["transfer_earned"] = null
		if migrated.transfer_earned != null and not migrated.transfer_earned is bool:
			return null
		if value.version < 7:
			migrated["supplies_used"] = null
		if migrated.supplies_used != null:
			if not SeasonOwnership._whole(migrated.supplies_used, 0, SeasonBuild.MAX_EVENTS):
				return null
		if value.version < 8:
			migrated["checkout_earned"] = null
		if migrated.checkout_earned != null and not migrated.checkout_earned is bool:
			return null
		if value.version < 9:
			migrated["association_earned"] = null
		if migrated.association_earned != null and not migrated.association_earned is bool:
			return null
		if value.version < 10:
			migrated["freezer_earned"] = null
		if migrated.freezer_earned != null and not migrated.freezer_earned is bool:
			return null
		if value.version < 11:
			migrated["sides_earned"] = null
		if migrated.sides_earned != null and not migrated.sides_earned is bool:
			return null
		if value.version < 12:
			migrated["jump_earned"] = null
		if migrated.jump_earned != null and not migrated.jump_earned is bool:
			return null
		if value.version < 18:
			migrated["major_earned"] = null
		if migrated.major_earned != null and not migrated.major_earned is bool:
			return null
		if value.version < 17:
			migrated["sky_outs"] = null
		if migrated.sky_outs != null and not SeasonOwnership._whole(migrated.sky_outs, 0, 3):
			return null
		if value.version < 16:
			migrated["copy_earned"] = null
		if migrated.copy_earned != null and not migrated.copy_earned is bool:
			return null
		if value.version < 15:
			migrated["field_outs"] = null
		if (
			migrated.field_outs != null
			and not SeasonOwnership._whole(migrated.field_outs, 0, 329967)
		):
			return null
		if value.version < 14:
			migrated["sure_earned"] = null
		if migrated.sure_earned != null and not migrated.sure_earned is bool:
			return null
		if value.version < 13:
			migrated["batch_used"] = null
		if migrated.batch_used != null and not SeasonSmallBatch.valid(migrated.batch_used):
			return null
		result.runs.append(migrated)
	if (
		(value.version == ClubLeagueCareer.VERSION and not has_league)
		or (value.version < ClubLeagueCareer.VERSION and has_league)
		or (value.version == 23 and not has_d1)
		or (value.version == 24 and not has_d2)
		or (value.version == 25 and not has_d3)
		or (value.version == 26 and not has_d4)
	):
		return null
	if value.has("pennants"):
		if (
			not StadiumPennantRewards.valid_history(value.pennants, result.runs)
			or value.pennants.is_empty()
		):
			return null
		result._pennants = value.pennants.duplicate(true)
	if value.has("plaques"):
		if (
			not StadiumPlaqueRewards.valid_history(value.plaques, result.runs, pitch_catalog)
			or value.plaques.is_empty()
		):
			return null
		result._plaques = value.plaques.duplicate(true)
		result._plaques.version = int(result._plaques.version)
		result._plaques.from_season = int(result._plaques.from_season)
		for id: String in result._plaques.records:
			result._plaques.records[id] = StadiumPlaqueRewards.canonical(
				result._plaques.records[id]
			)
	if value.version >= 22:
		result._assets = value.assets.duplicate(true) if value.assets is Dictionary else {}
		var ledger: ClubAssetLedger = ClubPlayers.assets(result)
		if (
			result._assets.is_empty()
			or ledger == null
			or not StadiumPennantRewards.delivered(result, ledger)
			or not StadiumPlaqueRewards.delivered(result, ledger)
		):
			return null
	return result


func matches(season: SeasonState) -> bool:
	if season == null:
		return false
	if current == 0:
		return season.build == null
	if season.build == null or season.opponents == null or current != runs.size():
		return false
	if not _pricing_matches(season):
		return false
	if not _pitch_catalog.is_empty() and not WorkingExoticAccess.matches(self, season):
		return false
	var run: Dictionary = runs[-1]
	return (
		run.seed == season.season_seed
		and (run.status == "completed") == (season.phase == SeasonState.Phase.COMPLETE)
		and same(run.proof, ClubSeasonRecord.capture(season))
		and (
			run.player_progress == null
			or same(
				run.player_progress, ClubPlayerProgress.capture_for(season, run.player_progress)
			)
		)
		and ClubCollection.matches(self, season, true)
		and gear_matches(season, true)
		and sponsor_matches(season, true)
		and order_matches(season, true)
		and rain_matches(season, true)
		and transfer_matches(season, true)
		and supply_matches(season, true)
		and SeasonLateCheckout.matches(self, season, true)
		and SeasonAssociation.matches(self, season, true)
		and SeasonFreezers.matches(self, season, true)
		and SeasonLeftRight.matches(self, season, true)
		and SeasonJumpstart.matches(self, season, true)
		and SeasonSureShot.matches(self, season, true)
		and SeasonCarbonCopy.matches(self, season, true)
		and SeasonFieldSupply.matches(self, season, true)
		and SeasonDoubleMajor.matches(self, season, true)
		and SeasonAbilities.matches(self, season, true)
		and SeasonSmallBatch.matches(self, season, true)
	)
