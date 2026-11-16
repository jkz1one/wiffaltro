extends Node
## Schema probes stay synthetic and unpublished even when independent literal definitions exist.
## Real AY-01 admission is tested separately in stadium_npc_yard_definition_test.gd.

var _failures: int = 0


func _ready() -> void:
	_normalization()
	_exact_comparison()
	_raw_rejection()
	_historical_isolation()
	_authority_rejection()
	_serialized_bounds()
	if _failures == 0:
		print("stadium NPC venues: PASS (synthetic schema and historical-copy mechanics only)")
	get_tree().quit(0 if _failures == 0 else 1)


func _normalization() -> void:
	var raw: Dictionary = _probe()
	raw.version = 1.0
	raw.revision = 1.0
	raw.instances[0].transform[9] = 0.1 + 0.000000000001
	raw.instances[0].transform[10] = -0.0
	var canonical: Dictionary = StadiumNpcManifest.canonical_shape(raw)
	_check(not canonical.is_empty(), "raw valid shape canonicalizes")
	if canonical.is_empty():
		return
	_check(canonical.version is int and canonical.revision is int, "integer types normalized")
	_check(canonical.instances[0].transform[9] == float(PackedFloat32Array([0.1])[0]),
		"float64 parsing perturbation normalizes before exact comparison")
	_check(raw.version is float and raw.instances[0].transform[9] !=
		canonical.instances[0].transform[9],
		"normalization never mutates caller data")
	var zero_bytes: PackedByteArray = PackedFloat64Array(
		[canonical.instances[0].transform[10]]).to_byte_array()
	_check(zero_bytes == PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0]) and
		not JSON.stringify(canonical.instances[0].transform[10], "", true, true).begins_with("-"),
		"negative zero becomes positive zero in both sign and serialization")
	var encoded: String = JSON.stringify(canonical, "", true, true)
	var decoded: Variant = JSON.parse_string(encoded)
	var again: Dictionary = StadiumNpcManifest.canonical_shape(decoded)
	_check(encoded == JSON.stringify(again, "", true, true), "canonical JSON roundtrip byte stability")
	_check(ClubCareer.same(canonical, StadiumNpcManifest.canonical_shape(canonical)),
		"canonicalization is idempotent")
	canonical.instances[0].transform[9] = 3.0
	canonical.models.probe.version = 99
	_check(raw.models.probe.version == 1 and raw.instances[0].transform[9] != 3.0,
		"nested canonical return is a deep copy")


func _raw_rejection() -> void:
	for field: String in StadiumNpcManifest.KEYS:
		var bad: Dictionary = _probe()
		bad[field] = false
		_check(StadiumNpcManifest.canonical_shape(bad).is_empty(), "wrong raw type: " + field)
	for edit in range(26):
		var bad: Dictionary = _probe()
		match edit:
			0: bad.version = 1.00000000001
			1: bad.revision = 0
			2: bad.instances[0].transform[0] = NAN
			3: bad.instances[0].transform[0] = INF
			4: bad.instances[0].transform[0] = true
			5: bad.instances[0].transform[0] = 1000.000001
			6: bad.instances[0].transform.pop_back()
			7: bad.instances[1].instance = bad.instances[0].instance
			8: bad.instances[1].site = bad.instances[0].site
			9: bad.instances[0].host = bad.instances[1].instance
			10: bad.instances[0].host = "missing-host"
			11: bad.instances.reverse()
			12: bad.blueprints.append("uninstalled-item")
			13: bad.blueprints.append(bad.blueprints[0])
			14: bad.catalog.sha256 = "A".repeat(64)
			15: bad.models.probe.version = 1.5
			16: bad.valuation.total += 1
			17: bad.valuation.copies = -1
			18: bad.presentation.options = {"unbounded": []}
			19: bad.environment_certificates = [{"mode": "night", "profile": ""}]
			20: bad.environment_certificates[0].mode = "night"
			21: bad.environment_certificates.append(bad.environment_certificates[0].duplicate(true))
			22: bad.instances[0].paid = 0
			23: bad.status = "VALIDATED"
			24: bad.instances[0].instance = "paid:human-copy"
			25: bad.instances[0].transform[0] = 1e100
		_check(StadiumNpcManifest.canonical_shape(bad).is_empty(), "raw rejection " + str(edit))
	for value: Variant in [null, [], true, "manifest", {}]:
		_check(StadiumNpcManifest.canonical_shape(value).is_empty(), "non-manifest rejected")


func _historical_isolation() -> void:
	# Test private pure lookup mechanics; these probes are never inserted in production.
	var first: Dictionary = _probe(1)
	var second: Dictionary = _probe(2)
	second.instances[0].transform[9] = 5.0
	var records: Dictionary = {"SCHEMA-ONLY": {"1": first, "2": second}}
	var historical: Dictionary = StadiumNpcVenues._definition_from(records, "SCHEMA-ONLY", 1)
	var latest: Dictionary = StadiumNpcVenues._definition_from(records, "SCHEMA-ONLY", 2)
	_check(not historical.is_empty() and not latest.is_empty(), "explicit revisions resolve")
	if historical.is_empty() or latest.is_empty():
		return
	var frozen: String = JSON.stringify(historical, "", true, true)
	latest.instances[0].transform[9] = 50.0
	second.models.probe.version = 7
	second.valuation.total = 99
	_check(frozen == JSON.stringify(StadiumNpcVenues._definition_from(records, "SCHEMA-ONLY", 1),
		"", true, true), "later definition and caller mutations cannot remodel old revision")
	historical.instances[0].transform[9] = 99.0
	historical.land.stages.append("unexpected")
	_check(frozen == JSON.stringify(StadiumNpcVenues._definition_from(records, "SCHEMA-ONLY", 1),
		"", true, true), "returned nested mutation cannot rewrite source record")
	_check(StadiumNpcVenues._definition_from(records, "SCHEMA-ONLY", 3).is_empty(),
		"missing revision never resolves to latest")
	_check(StadiumNpcVenues._definition_from(records, "UNKNOWN", 1).is_empty(),
		"unknown definition never resolves a fallback")
	records["SCHEMA-ONLY"]["1"] = _probe(2)
	_check(StadiumNpcVenues._definition_from(records, "SCHEMA-ONLY", 1).is_empty(),
		"revision key cannot relabel another payload")
	_check(not StadiumNpcVenues.valid_manifest(latest),
		"lookup seam cannot inject production authority")


func _authority_rejection() -> void:
	var ledger: ClubAssetLedger = ClubAssetLedger.new_club()
	var ledger_bytes: String = JSON.stringify(ledger.to_data(), "", true, true)
	var value: Dictionary = _probe()
	var encoded: String = JSON.stringify(value, "", true, true)
	_check(StadiumNpcVenues.definition("SCHEMA-ONLY", 1).is_empty(), "no synthetic published assets")
	_check(StadiumNpcVenues.definition("AC-01", 3).is_empty(),
		"unadmitted future AC does not auto-publish")
	_check(not StadiumNpcVenues.valid_manifest(value) and StadiumNpcVenues.key(value).is_empty(),
		"canonical shape and self-consistent values grant no authority")
	_check(StadiumNpcVenues.normalized(value).is_empty() and
		StadiumNpcVenues.decode(encoded).is_empty(),
		"normalization and decode cannot publish arbitrary manifests")
	var envelope: Dictionary = {"kind": "UNQUALIFIED_CLUB_AUTHORING_FIXTURE", "version": 1,
		"venue": value, "sha256": encoded.sha256_text()}
	_check(not StadiumNpcVenues.valid_manifest(envelope), "correctly hashed candidate stays rejected")
	envelope.kind = "npc-authored-v1"
	envelope.sha256 = JSON.stringify(envelope.venue, "", true, true).sha256_text()
	_check(not StadiumNpcVenues.valid_manifest(envelope), "relabeling and rehashing never promotes")
	_check(StadiumNpcVenues.decode("{").is_empty() and StadiumNpcVenues.decode(
		" ".repeat(StadiumNpcManifest.MAX_BYTES + 1)).is_empty(), "malformed and oversized decode")
	_check(not StadiumLayoutSnapshot.valid(value), "NPC schema never becomes a human snapshot")
	_check(not StadiumNpcVenues.valid_manifest(ledger.to_data()), "paid journal cannot entitle NPCs")
	_check(ClubAssetLedger.from_data(value, 0, []) == null, "NPC copies cannot enter human journal")
	_check(ledger_bytes == JSON.stringify(ledger.to_data(), "", true, true),
		"all authority checks leave human ledger bytes and inventory unchanged")


func _probe(revision: int = 1) -> Dictionary:
	# Inert shape probe: no real field, asset model, pricing or qualification is claimed.
	var signature: Dictionary = {"version": 1, "sha256": "0".repeat(64)}
	var prefix: String = "npc:SCHEMA-ONLY:r%d:" % revision
	return {"version": 1, "id": "SCHEMA-ONLY", "revision": revision,
		"assembly": {"id": "schema-probe", "version": 1}, "field": "schema-only.field",
		"tier": "club", "shape": "schema-only", "rules_version": 1,
		"graph": {"id": "schema-only.graph", "version": 1, "sha256": "0".repeat(64)},
		"catalog": signature.duplicate(true), "models": {"probe": signature.duplicate(true)},
		"instances": [
			{"instance": prefix + "A", "item": "schema-only.item", "site": "A", "host": "field",
				"transform": [1, 0, 0, 0, 1, 0, 0, 0, 1, 0.1, 0, 0]},
			{"instance": prefix + "B", "item": "schema-only.item", "site": "B", "host": prefix + "A",
				"transform": [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0]}],
		"blueprints": ["schema-only.item"], "land": {"version": 1, "tier": "club", "stages": []},
		"surface_version": 1, "routing_version": 1,
		"environment_certificates": [{"mode": "day", "profile": "", "version": 1,
			"assembly_sha256": "0".repeat(64)}],
		"presentation": {"profile": "schema-only", "options": {}}, "live_units": 0,
		"valuation": {"price_version": 1, "price_sha256": "0".repeat(64),
			"blueprints": 0, "copies": 0, "land": 0, "total": 0}}


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


func _exact_comparison() -> void:
	var expected: Dictionary = _probe()
	var equivalent: Dictionary = _probe()
	equivalent.instances[0].transform[9] += 0.000000000001
	equivalent.revision = 1.0
	_check(not StadiumNpcVenues._normalized_against(equivalent, expected).is_empty(),
		"exact comparator accepts only representation-equivalent canonical copies")
	for edit in range(8):
		var changed: Dictionary = _probe()
		match edit:
			0: changed.instances[0].transform[9] += 0.000001
			1: changed.models.probe.version = 2
			2: changed.graph.sha256 = "1".repeat(64)
			3: changed.instances[1].host = "field"
			4: changed.instances.pop_back()
			5: changed.valuation.price_version = 2
			6: changed.field = "different-field"
			7: changed.environment_certificates[0].assembly_sha256 = "1".repeat(64)
		_check(not StadiumNpcManifest.canonical_shape(changed).is_empty(),
			"comparison attack is structurally valid " + str(edit))
		_check(StadiumNpcVenues._normalized_against(changed, expected).is_empty(),
			"canonical identity rejects changed whole definition " + str(edit))
	_check(StadiumNpcVenues._normalized_against(expected, {}).is_empty(),
		"empty trusted definition never grants authority")


func _serialized_bounds() -> void:
	var maximum: Dictionary = _maximum_probe()
	if maximum.is_empty():
		return # Generator already reports its precise failure; avoid misleading cascades.
	var bytes: int = JSON.stringify(maximum, "", true, true).to_utf8_buffer().size()
	_check(bytes == StadiumNpcManifest.MAX_BYTES, "escaped multibyte probe reaches exact byte limit")
	_check(not StadiumNpcManifest.canonical_shape(maximum).is_empty(),
		"canonical serialized bytes exactly at maximum are structurally accepted")
	maximum.presentation.profile += "x"
	_check(JSON.stringify(maximum, "", true, true).to_utf8_buffer().size() ==
		StadiumNpcManifest.MAX_BYTES + 1, "over-limit probe differs by one byte")
	_check(StadiumNpcManifest.canonical_shape(maximum).is_empty(),
		"direct canonicalization rejects oversized canonical serialization")
	_check(StadiumNpcVenues._definition_from({"SCHEMA-ONLY": {"1": maximum}},
		"SCHEMA-ONLY", 1).is_empty(), "lookup seam cannot bypass serialized bounds")
	_check(StadiumNpcVenues._normalized_against(maximum, maximum).is_empty(),
		"exact matching cannot bypass serialized bounds")
	_check(StadiumNpcVenues.decode(JSON.stringify(maximum, "", true, true)).is_empty(),
		"decode enforces the same serialized bound")
	for edit in range(6):
		var bad: Dictionary = _probe()
		match edit:
			0: bad.models.probe = null
			1: bad.models = {1: {"version": 1, "sha256": "0".repeat(64)}}
			2: bad.environment_certificates[0] = false
			3: bad.land.stages = [null]
			4: bad.instances[0].transform[0] = {"nested": []}
			5: bad.valuation = {"price_version": 1}
		_check(StadiumNpcManifest.canonical_shape(bad).is_empty(),
			"malformed nested value rejects before serialization " + str(edit))


func _maximum_probe() -> Dictionary:
	# Measure UTF-8 expansion; do not assume JSON escapes arbitrary control characters.
	var value: Dictionary = _probe()
	value.instances = []
	value.blueprints = []
	value.presentation.profile = "multibyte-é-😀-\n-\""
	var wide: String = String.chr(0x1f642)
	var host: String = "field"
	for index in range(StadiumNpcManifest.MAX_INSTANCES):
		var site: String = "%03d:" % index + wide.repeat(100)
		var item: String = "%03d:" % index + "a".repeat(100)
		var instance: String = "npc:SCHEMA-ONLY:r1:" + site
		value.instances.append({"instance": instance, "item": item, "site": site, "host": host,
			"transform": [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0]})
		value.blueprints.append(item)
		host = instance
	# Work from an actually canonical baseline, including transform numeric spelling.
	value = StadiumNpcManifest.canonical_shape(value)
	if value.is_empty():
		_check(false, "size probe canonical baseline must be valid and below the cap")
		return {}
	var current: int = JSON.stringify(value, "", true, true).to_utf8_buffer().size()
	var unit: int = 2 * (JSON.stringify(wide).to_utf8_buffer().size() -
		JSON.stringify("a").to_utf8_buffer().size())
	var needed: int = StadiumNpcManifest.MAX_BYTES - current
	if needed < 0 or unit <= 0 or floori(float(needed) / unit) > 12800:
		_check(false, "size probe padding: current=%d unit=%d needed=%d" % [current, unit, needed])
		return {}
	var replacements: int = floori(float(needed) / unit)
	for index in range(StadiumNpcManifest.MAX_INSTANCES):
		var count: int = mini(100, replacements)
		var item: String = "%03d:" % index + wide.repeat(count) + "a".repeat(100 - count)
		value.instances[index].item = item
		value.blueprints[index] = item
		replacements -= count
	value.presentation.profile += "x".repeat(needed % unit)
	return value
