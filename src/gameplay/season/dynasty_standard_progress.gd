extends RefCounted
## Standard contribution primitive. Never imports the embedded validation
## career's wallet, earlier rows, or receipt as shared authority.
## Caller must first qualify the physical session and its bound admission.
const Grant = preload("res://src/gameplay/season/dynasty_standard_grant.gd")
const Progress = preload("res://src/gameplay/season/dynasty_career_progress.gd")
const Authority = preload("res://src/gameplay/season/dynasty_career_authority.gd")
const Save = preload("res://src/gameplay/season/dynasty_career_save.gd")
const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")
const VERSION: int = 3


static func capture(
	season: SeasonState, witness: Dictionary, qualified_admission: Dictionary
) -> Dictionary:
	var grant: Dictionary = Grant.qualify(witness, qualified_admission)
	return _capture_bound(season, grant) if not grant.is_empty() else {}


static func _capture_bound(season: SeasonState, expected_grant: Dictionary) -> Dictionary:
	var grant: Dictionary = Grant._claim(expected_grant)
	if season != null and not season._standard_live_context.is_empty():
		return _capture_live(season, grant)
	if grant.is_empty() or season == null or season.career == null \
		or not season.league_rules.is_empty() or season.league_career \
		or not ClosedContentAccess.matches(season.build, grant.access) \
		or not ClubCareer.same(season.player_access, grant.player_access) \
		or not ClubPlayerDraft.frozen_matches(season):
		return {}
	var career: ClubCareer = season.career.fork()
	if not career.sync(season) or not career.matches(season) or career.current != career.runs.size():
		return {}
	var prefix: ClubCareer = preload("res://src/gameplay/season/dynasty_standard_grant.gd").history_club(grant.history)
	if career.runs.size() != prefix.runs.size() + 1 \
		or not ClubCareer.same(career.runs.slice(0, -1), prefix.runs):
		return {}
	var row: Dictionary = career.runs[-1]
	if row.league != "standard" or row.seed != season.season_seed:
		return {}
	var delta: Dictionary = {"version": VERSION, "tier": row.tier,
		"grant_reference": Save.snapshot_reference(grant)}
	for field: String in Progress.FIELDS:
		if field != "version":
			delta[field] = row[field]
	for flag: String in Progress.FLAGS:
		delta[flag + "_earned"] = row[flag + "_earned"]
	return delta.duplicate(true) if _valid_bound(delta, grant) else {}


static func valid(value: Variant, witness: Dictionary, qualified_admission: Dictionary) -> bool:
	var grant: Dictionary = Grant.qualify(witness, qualified_admission)
	return not grant.is_empty() and _valid_bound(value, grant)


static func _valid_bound(value: Variant, expected_grant: Dictionary) -> bool:
	var grant: Dictionary = Grant._claim(expected_grant)
	var fields: Array = Progress.FIELDS.duplicate()
	fields.append_array(["tier", "grant_reference"])
	for flag: String in Progress.FLAGS:
		fields.append(flag + "_earned")
	if grant.is_empty() or not Profile.keys(value, fields) \
		or not Profile.whole(value.version, VERSION, VERSION) \
		or not Profile.whole(value.tier, 0, 4) \
		or not ClubCareer.same(value.grant_reference, Save.snapshot_reference(grant)) \
		or not Profile.keys(value.proof, ["draws", "scores"]) \
		or ClubSeasonRecord.analyze(value.proof).is_empty() \
		or not Progress._metrics_valid(value, grant.access.progress):
		return false
	var prefix: ClubCareer = preload("res://src/gameplay/season/dynasty_standard_grant.gd").history_club(grant.history)
	if int(value.tier) not in prefix.available_tiers():
		return false
	for flag: String in Progress.FLAGS:
		if not value[flag + "_earned"] is bool:
			return false
	return true


static func receipt(
	value: Dictionary, witness: Dictionary, qualified_admission: Dictionary, first_title: bool
) -> Dictionary:
	if not valid(value, witness, qualified_admission):
		return {}
	return ClubSeasonRecord.receipt(value.proof, first_title, int(value.tier))


static func extends_progress(
	before: Dictionary, after: Dictionary, witness: Dictionary, qualified_admission: Dictionary
) -> bool:
	if not valid(before, witness, qualified_admission) \
		or not valid(after, witness, qualified_admission):
		return false
	return before.tier == after.tier \
		and ClubCareer.same(before.grant_reference, after.grant_reference) \
		and ClubCareer.same(before.proof.draws, after.proof.draws) \
		and before.proof.scores.size() <= after.proof.scores.size() \
		and ClubCareer.same(before.proof.scores,
			after.proof.scores.slice(0, before.proof.scores.size()))


static func _capture_live(season: SeasonState, grant: Dictionary) -> Dictionary:
	if grant.is_empty() or not load("res://src/gameplay/season/dynasty_standard_live.gd").matches(season) \
		or not ClubCareer.same(grant, season._standard_live_context.grant):
		return {}
	var build: SeasonBuild = season.build
	var delta: Dictionary = {"version": VERSION, "tier": season._standard_live_context.session.tier,
		"grant_reference": Save.snapshot_reference(grant), "proof": ClubSeasonRecord.capture(season),
		"gear": build._gear_progress.games.duplicate(true), "sponsors": build._sponsor_progress.games.duplicate(true),
		"order_rerolls": build._paid_rerolls, "supplies_used": build._supply_used,
		"sky_outs": build._abilities.earned, "field_outs": build._field_outs,
		"batch_used": build._batch_used.duplicate(), "collection": ClubCollection.acquired(build),
		"player_progress": ClubPlayerLegend.capture(season)}
	for flag: String in Progress.FLAGS:
		delta[flag + "_earned"] = build._major.earned if flag == "major" else (
			build._copy.earned if flag == "copy" else build.get("_" + flag + "_earned"))
	return delta if _valid_bound(delta, grant) else {}
