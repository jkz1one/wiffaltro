class_name StadiumPennantRewards
extends RefCounted
## BU1/BU4: prospective, immutable title records; ownership is issued by the asset journal.

const VERSION: int = 1
const SOURCE: String = "championship-v1"
const MASTERY_VERSION: int = 2
const MASTERY_SOURCE: String = "mastery-v1"
const MASTERY_CONTRACT: String = "standard.d4"


static func mastery_signature() -> String:
	return (
		"ST-067:mastery-v1:standard.d4:first-title:prospective-era-v1:one-per-league".sha256_text()
	)


static func mastery_key() -> String:
	return MASTERY_SOURCE + ":" + MASTERY_CONTRACT


static func record_key(record: Dictionary) -> String:
	return mastery_key() if record.has("mastery_contract") else key(int(record.season_id))


static func valid_mastery_record(value: Variant) -> bool:
	if not value is Dictionary or value.get("mastery_contract") != MASTERY_CONTRACT:
		return false
	var ordinary: Dictionary = value.duplicate(true)
	ordinary.erase("mastery_contract")
	return valid_record(ordinary) and ordinary.difficulty_id == MASTERY_CONTRACT


static func valid_reward(value: Variant) -> bool:
	return valid_record(value) or valid_mastery_record(value)


static func signature() -> String:
	return "ST-044:championship-v1:completed-standard-title:era-v1:one-per-season".sha256_text()


static func key(season_id: int) -> String:
	return "%s:%d" % [SOURCE, season_id]


static func adopt(career: ClubCareer) -> void:
	# Called only by ordinary start after a new row has been admitted.
	if career._pennants.is_empty():
		career._pennants = {"version": VERSION, "from_season": career.current, "eras": {}}
	career._pennants.eras[str(career.current)] = StadiumClubIdentity.current()
	if career._pennants.version == VERSION:
		# Adoption is prospective, only at ordinary season start; loading never backfills.
		career._pennants.version = MASTERY_VERSION
		career._pennants["mastery_from"] = career.current
		career._pennants["mastery_contract"] = MASTERY_CONTRACT


static func valid_history(value: Variant, runs: Array[Dictionary]) -> bool:
	if not value is Dictionary:
		return false
	if value.is_empty():
		return true
	var fields: Array = ["version", "from_season", "eras"]
	if value.get("version") == MASTERY_VERSION:
		fields.append_array(["mastery_from", "mastery_contract"])
		if (
			not SeasonOwnership._whole(value.get("from_season"), 1, runs.size())
			or not SeasonOwnership._whole(
				value.get("mastery_from"), int(value.from_season), runs.size()
			)
			or value.get("mastery_contract") != MASTERY_CONTRACT
		):
			return false
	if (
		not SeasonOwnership._keys(value, fields)
		or not SeasonOwnership._whole(value.version, VERSION, MASTERY_VERSION)
		or not SeasonOwnership._whole(value.from_season, 1, runs.size())
		or not value.eras is Dictionary
		or value.eras.size() != runs.size() - int(value.from_season) + 1
	):
		return false
	for index in range(int(value.from_season) - 1, runs.size()):
		if not StadiumClubIdentity.valid(value.eras.get(str(index + 1))):
			return false
	return true


static func valid_record(value: Variant) -> bool:
	return (
		value is Dictionary
		and SeasonOwnership._keys(
			value, ["version", "season_id", "league_id", "difficulty_id", "season_number", "era"]
		)
		and SeasonOwnership._whole(value.version, VERSION, VERSION)
		and SeasonOwnership._whole(value.season_id, 1, ClubCareer.MAX_RUNS)
		and SeasonOwnership._whole(value.season_number, int(value.season_id), int(value.season_id))
		and value.league_id == "standard"
		and (
			value.difficulty_id
			in ["standard.d0", "standard.d1", "standard.d2", "standard.d3", "standard.d4"]
		)
		and StadiumClubIdentity.valid(value.era)
	)


static func awards(career: ClubCareer) -> Variant:
	if career == null or not valid_history(career._pennants, career.runs):
		return null
	var result: Dictionary = {}
	if career._pennants.is_empty():
		return result
	var titles: Dictionary = {"0": false, "1": false, "2": false, "3": false, "4": false}
	var mastery_seen: bool = false
	for index in range(career.runs.size()):
		var row: Dictionary = career.runs[index]
		if row.get("id") != index + 1 or ClubCareer._progression_record(row, titles).is_empty():
			return null
		var first_mastery: bool = (
			career._pennants.version == MASTERY_VERSION
			and row.league == "standard"
			and row.id >= career._pennants.mastery_from
			and not mastery_seen
			and row.tier == 4
			and row.status == "completed"
			and row.receipt.get("finish") == "champion"
		)
		if first_mastery:
			mastery_seen = true
		if (
			row.league != "standard"
			or row.id < career._pennants.from_season
			or row.status != "completed"
			or row.receipt.get("finish") != "champion"
		):
			continue
		result[key(int(row.id))] = {
			"version": VERSION,
			"season_id": int(row.id),
			"league_id": row.league,
			"difficulty_id": "standard.d%d" % int(row.tier),
			"season_number": int(row.id),
			"era": career._pennants.eras[str(int(row.id))].duplicate(true)
		}
		if (
			first_mastery
			and career._pennants.version == MASTERY_VERSION
			and row.id >= career._pennants.mastery_from
		):
			var record: Dictionary = result[key(int(row.id))].duplicate(true)
			record["mastery_contract"] = career._pennants.mastery_contract
			result[mastery_key()] = record
	return result


static func valid_awards(value: Variant, credits: Array) -> bool:
	if (
		not value is Dictionary
		or value.size() > ClubCareer.MAX_RUNS + 1 + StadiumPlaqueRewards.MAX_AWARDS
	):
		return false
	for id: Variant in value:
		var record: Variant = value[id]
		if StadiumPlaqueRewards.valid_record(record):
			if (
				id != StadiumPlaqueRewards.key(record.player_id)
				or record.season_id > credits.size()
			):
				return false
			continue
		if (
			not valid_reward(record)
			or id != record_key(record)
			or record.season_id > credits.size()
			or credits[int(record.season_id) - 1] <= 0
		):
			return false
	return true


static func deliver(career: ClubCareer) -> bool:
	var ledger: ClubAssetLedger = ClubPlayers.assets(career)
	if ledger == null:
		return false
	var records: Variant = awards(career)
	if not records is Dictionary:
		return false
	# Award derivation inserts each ordinary pennant before the same season's banner.
	for id: String in records:
		if ledger._stock.copies.has(id):
			continue
		if not (
			ledger
			. commit(
				{
					"id": id,
					"rev": ledger.revision(),
					"op":
					"stadium_mastery" if records[id].has("mastery_contract") else "stadium_pennant",
					"earned": records[id].duplicate(true)
				}
			)
			. ok
		):
			return false
	career._assets = ledger.to_data()
	return true


static func delivered(career: ClubCareer, ledger: ClubAssetLedger) -> bool:
	var records: Variant = awards(career)
	if ledger == null or not records is Dictionary:
		return false
	for id: String in records:
		if (
			not ledger._stock.copies.has(id)
			or not ClubCareer.same(ledger._stock.copies[id].get("earned"), records[id])
		):
			return false
	return true
