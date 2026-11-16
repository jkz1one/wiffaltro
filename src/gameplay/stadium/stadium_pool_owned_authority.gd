class_name StadiumPoolOwnedAuthority
extends StadiumPoolBoundEntitlement
## Real paid-prefix authority, sealed to one match, lab, ledger revision and owned placement.

const LEDGER_SCRIPT: Script = preload("res://src/gameplay/season/club_asset_ledger.gd")
const STOCK_SCRIPT: Script = preload("res://src/gameplay/stadium/stadium_stock.gd")
const WALLS_SCRIPT: Script = preload("res://src/gameplay/stadium/stadium_wall_piece_ownership.gd")
const WALL_STOCK_SCRIPT: Script = preload("res://src/gameplay/stadium/stadium_wall_piece_stock.gd")
const BOARDS_SCRIPT: Script = preload("res://src/gameplay/stadium/stadium_scoreboard_ownership.gd")
const OWNED_AUTHORITY: String = "PAID_OWNED_POOL_V28"
# Policy3 changes ledger sampling only; live Node integrity remains policy2.
const LEDGER_POLICY: String = "SUPPORTED_LEDGER_GENERATION_V61"
static var _owned_serial: int = 0


static func issue_owned(lab: PitchBatLab) -> StadiumPoolOwnedAuthority:
	_prune()
	if lab == null or lab._stadium_ledger == null or not lab._match_mode:
		return null
	var state: MatchState = lab._match_state if lab._match_state != null else lab._configured_match
	if state == null or _issued.has(lab.get_instance_id()):
		return null
	if not exact_owned(state.stadium, lab._stadium_ledger):
		return null
	var source: String = StadiumPoolPartyAssetIntegrity.source_sha256()
	if source.length() != 64:
		return null
	_owned_serial += 1
	var result: StadiumPoolOwnedAuthority = StadiumPoolOwnedAuthority.new()
	result._owner = weakref(lab)
	result._match = weakref(state)
	result._ledger = weakref(lab._stadium_ledger)
	result._record = {
		"version": 1,
		"authority": OWNED_AUTHORITY,
		"lifetime": LIFETIME,
		"serial": _owned_serial,
		"owner": lab.get_instance_id(),
		"match": state.get_instance_id(),
		"copy": state.stadium.layout.pool.copy,
		"item": "ST-006",
		"role": StadiumPoolContract.LIVE,
		"base_key": StadiumLayoutSnapshot.key(state.stadium),
		"source_sha256": source,
		"pose": StadiumPoolOwnedLayout.pose(state.stadium.layout),
		"capacity": 4,
		"reservation_radius": StadiumPoolContract.RESERVATION_RADIUS
	}
	_issued[lab.get_instance_id()] = {
		"owner": weakref(lab), "token": weakref(result),
		"bytes": var_to_bytes(result._record), "snapshot": var_to_bytes(state.stadium),
		"phase": "ISSUED", "property": null, "ledger": weakref(lab._stadium_ledger),
		"revision": lab._stadium_ledger.revision(),
		"ledger_policy": LEDGER_POLICY,
		"mutation_generation": lab._stadium_ledger.mutation_generation(),
		"owned_ledger_state": _ledger_state(lab._stadium_ledger)
	}
	return result


static func exact_owned(snapshot: Dictionary, ledger: ClubAssetLedger) -> bool:
	return (
		ledger != null
		and ledger.get_script() == LEDGER_SCRIPT
		and ledger.mutation_generation() > 0
		and ledger._valid
		and not ledger._loading
		and not _ledger_state(ledger).is_empty()
		and snapshot.get("layout") is Dictionary
		and SeasonOwnership._whole(snapshot.layout.get("version"), 16, 16)
		and snapshot.get("tier") == "backyard"
		and StadiumLayoutSnapshot.matches(snapshot, ledger)
		and snapshot.get("boundary") == StadiumBoundaryGraph.signature()
	)


func valid_for(lab: PitchBatLab, snapshot: Dictionary, phase: String) -> bool:
	return (
		super.valid_for(lab, snapshot, phase)
		and _record.authority == OWNED_AUTHORITY
		and get_script() == load("res://src/gameplay/stadium/stadium_pool_owned_authority.gd")
		and lab._stadium_ledger.get_script() == LEDGER_SCRIPT
		and _issued[lab.get_instance_id()].ledger_policy == LEDGER_POLICY
		and lab._stadium_ledger.mutation_generation() > 0
		and _issued[lab.get_instance_id()].mutation_generation == \
			lab._stadium_ledger.mutation_generation()
		and (phase == "INSTALLED" or _full_ledger_matches(lab))
		and _record.copy == snapshot.layout.pool.copy
		and _record.pose == StadiumPoolOwnedLayout.pose(snapshot.layout)
	)


func full_valid_for(lab: PitchBatLab, snapshot: Dictionary, phase: String) -> bool:
	return valid_for(lab, snapshot, phase) and _full_ledger_matches(lab)


func _full_ledger_matches(lab: PitchBatLab) -> bool:
	return _issued[lab.get_instance_id()].owned_ledger_state == _ledger_state(lab._stadium_ledger)


static func _ledger_state(ledger: ClubAssetLedger) -> PackedByteArray:
	# Every instance field is sealed after paid-prefix verification. Replaying an unchanged
	# journal on each physics sample would add source hashing without stronger evidence.
	if (
		not is_instance_valid(ledger._stock)
		or not is_instance_valid(ledger._wall_pieces)
		or not is_instance_valid(ledger._scoreboards)
		or not is_instance_valid(ledger._wall_pieces.stock)
		or ledger._stock.get_script() != STOCK_SCRIPT
		or ledger._wall_pieces.get_script() != WALLS_SCRIPT
		or ledger._wall_pieces.stock.get_script() != WALL_STOCK_SCRIPT
		or ledger._scoreboards.get_script() != BOARDS_SCRIPT
	):
		return PackedByteArray()
	return var_to_bytes([
		ledger._stock.get_instance_id(), ledger._stock.get_script().get_instance_id(),
		ledger._wall_pieces.get_instance_id(), ledger._wall_pieces.get_script().get_instance_id(),
		ledger._wall_pieces.stock.get_instance_id(),
		ledger._wall_pieces.stock.get_script().get_instance_id(),
		ledger._scoreboards.get_instance_id(), ledger._scoreboards.get_script().get_instance_id(),
		ledger._seed, ledger._credits, ledger._progress, ledger._land,
		ledger._valid, ledger._loading, ledger._events, ledger._requests, ledger._pack_owned,
		ledger._pending, ledger._spent, ledger._opened, ledger._through, ledger._surface_origin,
		ledger._surface_owned, ledger._scoreboards.to_data(), ledger._wall_pieces.to_data(),
		ledger._stock.to_data(), ledger._stadium_draft, ledger._stadium_active
	])
