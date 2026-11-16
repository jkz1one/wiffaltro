class_name StadiumPoolBoundEntitlement
extends RefCounted
## Private in-memory admission only. Never a stock grant, purchase receipt or save schema.
## One issued token per exact configured MatchState/lab lifetime; never transferable/replayable.
# gdlint: disable=max-returns

const VERSION: int = 1
const AUTHORITY: String = "EXPLICIT_PRIVATE_POOL_V26_FIXTURE"
const LIFETIME: String = "ONE_CONFIGURED_MATCH_AND_LAB_LIFETIME"
const FIELDS: Array[String] = [
	"version",
	"authority",
	"lifetime",
	"serial",
	"owner",
	"match",
	"copy",
	"item",
	"role",
	"base_key",
	"source_sha256",
	"pose",
	"capacity",
	"reservation_radius"
]
static var _serial: int = 0
static var _issued: Dictionary = {}
var _record: Dictionary = {}
var _owner: WeakRef
var _match: WeakRef
var _ledger: WeakRef


static func issue_private(
	lab: PitchBatLab, snapshot: Dictionary, ledger: ClubAssetLedger
) -> StadiumPoolBoundEntitlement:
	# Calling this named private API is the explicit grant. Public paths never call it.
	_prune()
	if (
		lab == null
		or lab.is_inside_tree()
		or lab.get_parent() != null
		or lab.get_script() != load("res://src/labs/pitch_bat_lab/pitch_bat_lab.gd")
		or lab._configured_match == null
		or lab._stadium_ledger != ledger
		or _issued.has(lab.get_instance_id())
		or not exact_base(snapshot, ledger)
		or not ClubCareer.same(snapshot, lab._configured_match.stadium)
	):
		return null
	var source: String = StadiumPoolPartyAssetIntegrity.source_sha256()
	if source.length() != 64:
		return null
	_serial += 1
	var result: StadiumPoolBoundEntitlement = StadiumPoolBoundEntitlement.new()
	result._owner = weakref(lab)
	result._match = weakref(lab._configured_match)
	result._ledger = weakref(ledger)
	result._record = {
		"version": VERSION,
		"authority": AUTHORITY,
		"lifetime": LIFETIME,
		"serial": _serial,
		"owner": lab.get_instance_id(),
		"match": lab._configured_match.get_instance_id(),
		"copy": "private-pool-v26:%d:%d" % [lab.get_instance_id(), _serial],
		"item": "ST-006",
		"role": StadiumPoolContract.LIVE,
		"base_key": StadiumLayoutSnapshot.key(snapshot),
		"source_sha256": source,
		"pose": StadiumPoolContract.placement(),
		"capacity": 4,
		"reservation_radius": StadiumPoolContract.RESERVATION_RADIUS
	}
	_issued[lab.get_instance_id()] = {
		"owner": weakref(lab),
		"token": weakref(result),
		"bytes": var_to_bytes(result._record),
		"snapshot": var_to_bytes(snapshot),
		"phase": "ISSUED",
		"property": null,
		"ledger": weakref(ledger),
		"revision": ledger.revision()
	}
	return result


static func exact_base(snapshot: Dictionary, ledger: ClubAssetLedger) -> bool:
	if (
		ledger == null
		or not StadiumLayoutSnapshot.valid(snapshot)
		or not SeasonOwnership._whole(snapshot.get("version"), 3, 3)
		or snapshot.get("tier") != "backyard"
		or not ClubCareer.same(snapshot.get("layout"), base_layout())
		or snapshot.get("boundary") != StadiumBoundaryGraph.signature()
		or not StadiumLayoutSnapshot.matches(snapshot, ledger)
	):
		return false
	var stock: StadiumStock = StadiumLayoutSnapshot.ownership(snapshot)
	if stock == null or not ClubCareer.same(stock.to_data(), StadiumStock.new_club().to_data()):
		return false
	var checked: Dictionary = StadiumHomeLayout.validate(snapshot.layout, stock, "backyard")
	return (
		checked.ok
		and checked.placements.size() == 1
		and checked.live_units == 0
		and checked.stored == ["starter-v1:ST-001", "starter-v1:ST-003"]
		and StadiumCatalog.within_live_budget(["ST-006"])
		and StadiumCatalog.LIVE_UNITS.get("ST-006") == 4
	)


static func base_layout() -> Dictionary:
	return {
		"version": 1,
		"family": "reference-starter-v1",
		"receiver": "starter-v1:ST-079",
		"obstacles": []
	}


func descriptor() -> Dictionary:
	return _record.duplicate(true)


func valid_for(lab: PitchBatLab, snapshot: Dictionary, phase: String) -> bool:
	if (
		lab == null
		or _owner == null
		or _owner.get_ref() != lab
		or _match == null
		or _ledger == null
		or _ledger.get_ref() == null
		or lab._stadium_ledger != _ledger.get_ref()
		or not SeasonOwnership._keys(_record, FIELDS)
	):
		return false
	var row: Dictionary = _issued.get(lab.get_instance_id(), {})
	if (
		row.is_empty()
		or row.owner.get_ref() != lab
		or row.token.get_ref() != self
		or row.phase != phase
		or var_to_bytes(_record) != row.bytes
		or var_to_bytes(snapshot) != row.snapshot
		or row.ledger.get_ref() != lab._stadium_ledger
		or row.revision != lab._stadium_ledger.revision()
	):
		return false
	var state: MatchState = lab._match_state if lab._match_state != null else lab._configured_match
	return (
		state != null
		and _match.get_ref() == state
		and _record.owner == lab.get_instance_id()
		and _record.match == state.get_instance_id()
	)


func configure_for(lab: PitchBatLab, snapshot: Dictionary) -> bool:
	if not valid_for(lab, snapshot, "ISSUED"):
		return false
	_issued[lab.get_instance_id()].phase = "CONFIGURED"
	return true


func claim(lab: PitchBatLab, snapshot: Dictionary, property: Node) -> bool:
	if property == null or not valid_for(lab, snapshot, "CONFIGURED"):
		return false
	_issued[lab.get_instance_id()].phase = "INSTALLED"
	_issued[lab.get_instance_id()].property = weakref(property)
	return true


func owns(lab: PitchBatLab, snapshot: Dictionary, property: Node) -> bool:
	if not valid_for(lab, snapshot, "INSTALLED"):
		return false
	var reference: Variant = _issued[lab.get_instance_id()].property
	return reference is WeakRef and reference.get_ref() == property


func retire() -> void:
	if _owner == null or _owner.get_ref() == null:
		return
	var id: int = _owner.get_ref().get_instance_id()
	var row: Dictionary = _issued.get(id, {})
	if not row.is_empty() and row.token.get_ref() == self:
		row.phase = "RETIRED"
		row.property = null


static func _prune() -> void:
	for id: int in _issued.keys():
		if _issued[id].owner.get_ref() == null:
			_issued.erase(id)
