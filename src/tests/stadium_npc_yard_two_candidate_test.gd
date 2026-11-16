extends Node
## Frozen AY-02/r1 data identity and authority refusal. No registry or season admission.

const FIXTURE: String = "res://src/tests/fixtures/npc_yard_two_r1_candidate_canonical.json"
const SOURCE: String = "res://src/tests/fixtures/npc_yard_two_r1_authoring_source.json"
const HISTORICAL_SHA256: Dictionary = {
	"AY-011": "6295c0e4b2221666530fa343c6a0b39d6a7e61cff11b5850b59e13ec10c811e7",
	"AY-012": "48d657ac6d22c3cb4616508f9692cc45614bd1042da21c2c8792846e98df7a94",
	"AE-011": "0e2cbd2e61ac0c2f3b3970053a2d76a2424d4ca3a98f1c8f06ec4d04307f849b",
	"AE-012": "d1526c783d0a550ed7e22350707dbd531f2439b5df7a4f4cfc8cd07824d76b39",
	"AC-011": "066c33dadf47d999ec5bb9bcc0a69c280013633b9d83f7226eab814b68dbd797",
	"AC-012": "0f51d1101f9ad03cfc26bfc059b734372c6c07fecc1703a70777555d6502e999"
}
var _failures: int = 0


func _ready() -> void:
	var value: Dictionary = StadiumNpcYardTwoCandidateV1.definition()
	var ledger: ClubAssetLedger = ClubAssetLedger.new_club()
	var ledger_bytes: String = _json(ledger.to_data())
	var historical: Dictionary = _historical()
	_check(not value.is_empty(), "finite explicit AY-02/r1 candidate exists")
	if value.is_empty():
		get_tree().quit(1)
		return
	_provenance()
	_literal(value)
	_copy_isolation(value)
	_contract_representation()
	_representation(value)
	_malformed(value)
	_coherent_edits(value)
	_authority(value)
	_check(_json(ledger.to_data()) == ledger_bytes, "candidate cannot grant or spend human assets")
	_check(_historical() == historical, "all six r1/r2 historical canonical bytes remain exact")
	if _failures == 0:
		print("Wiffaltro AY02 immutable candidate passed: exact r1 literal and closed authority.")
	get_tree().quit(0 if _failures == 0 else 1)


func _provenance() -> void:
	for sources: Dictionary in [StadiumNpcYardTwoProvenance.SOURCES,
		StadiumNpcYardTwoProvenance.CONSTRUCTION_SOURCES,
		StadiumNpcYardTwoProvenance.PROTECTED_SOURCES]:
		for path: String in sources:
			_check(FileAccess.get_sha256(path) == sources[path], "pinned source bytes " + path)
	var bytes: String = FileAccess.get_file_as_string(SOURCE)
	_check(bytes.sha256_text() == StadiumNpcYardTwoProvenance.AUTHORING_SHA256,
		"genuine historical venue substring remains byte-identical, never reserialized")
	_check(_json(StadiumYardTwoStudy.canonical()) == bytes,
		"current qualified source exactly equals full raw historical venue")
	_check(_json(StadiumNpcYardTwoContractV1.canonical()) == bytes,
		"complete immutable semantic contract exactly equals independent historical bytes")

func _literal(value: Dictionary) -> void:
	var bytes: String = _json(value)
	_check(bytes == FileAccess.get_file_as_string(FIXTURE)
		and bytes.sha256_text() == StadiumNpcYardTwoCandidateV1.SHA256,
		"canonical C uses independently preserved historical transform tokens")
	_check(StadiumNpcManifest.payload_key(value) == StadiumNpcYardTwoCandidateV1.SUBJECT_SHA256
		and StadiumNpcYardTwoCandidateV1.key(value) != StadiumNpcManifest.payload_key(value),
		"complete candidate and certificate-excluded subject use distinct hash domains")
	_check(_json(StadiumNpcYardTwoCandidateV1.decode(bytes)) == bytes,
		"JSON decode restores canonical exact types and float32 transforms")
	_check(value.instances.size() == 4 and value.blueprints == ["ST-001", "ST-027", "ST-079"]
		and value.live_units == 1 and value.environment_certificates.is_empty()
		and value.land == {"version": 1, "tier": "backyard", "stages": []}
		and value.valuation.blueprints == 300 and value.valuation.copies == 275
		and value.valuation.land == 0 and value.valuation.total == 575,
		"exact chair, two bleachers, cone, one live unit and nonspendable 575 valuation")
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	var rows: Dictionary = {}
	for original: Dictionary in source.items:
		rows[original.site] = original
	for row: Dictionary in value.instances:
		var original: Dictionary = rows[row.site]
		_check(row.instance == "npc:AY-02:r1:" + original.site and row.site == original.site
			and row.item == original.item and row.host == original.host
			and row.transform == Array(PackedFloat32Array(original.transform)),
			"independent original row and exact float32 pose " + row.site)
	_check(value.models["starter-models"].sha256 == source.model_sources.starter_models
		and value.models["wooden-bleachers"].sha256 == source.model_sources.seating_models
		and value.models["chair-receiver"].sha256 == source.model_sources.receiver_algorithm
		and value.models["authoring-contract"].sha256 == StadiumNpcYardTwoProvenance.AUTHORING_SHA256,
		"models and complete receiver/camera/render semantic source are explicitly bound")
	_check(source.receiver.catching_layer.is_empty() and source.receiver.catalog_item == "ST-079"
		and source.routing.live_obstacles.size() == 1
		and source.environment.certificates.is_empty() and not source.environment.night_eligible,
		"chair-only receiver, cone-only live capacity and closed environmental authority")

func _copy_isolation(value: Dictionary) -> void:
	var original: String = _json(value)
	for returned: Dictionary in [StadiumNpcYardTwoCandidateV1.payload(),
		StadiumNpcYardTwoCandidateV1.definition(), StadiumNpcYardTwoCandidateV1.normalized(value),
		StadiumNpcYardTwoCandidateV1.decode(original)]:
		returned.instances[0].transform[9] = 99.0
		returned.models["starter-models"].version = 99
		returned.valuation.total = 0
	_check(_json(StadiumNpcYardTwoCandidateV1.definition()) == original,
		"all nested return data is isolated from immutable C")
	var contract: Dictionary = StadiumNpcYardTwoContractV1.canonical()
	contract.receiver.transform[11] = 99.0
	contract.camera_profile.batting_entry[2] = 99.0
	contract.routing.live_obstacles.clear()
	_check(_json(StadiumNpcYardTwoContractV1.canonical()) == FileAccess.get_file_as_string(SOURCE),
		"receiver/routing/camera semantics return deeply isolated data")
	for revision: int in [-1, 0, 2, 1000000]:
		_check(StadiumNpcYardTwoCandidateV1.definition("AY-02", revision).is_empty(),
			"unknown revision cannot fall back to latest")
	for id: String in ["AY-01", "AY-02 ", "ay-02", "AY-03", "AE-01", "UNKNOWN"]:
		_check(StadiumNpcYardTwoCandidateV1.definition(id).is_empty(), "no candidate aliases")


func _contract_representation() -> void:
	var raw: Dictionary = StadiumNpcYardTwoContractV1.payload()
	var original: String = _json(raw)
	var canonical: String = _json(StadiumNpcYardTwoContractV1.canonical())
	_check(raw.receiver.sweep_step is float
		and PackedFloat64Array([raw.receiver.sweep_step]).to_byte_array().hex_encode()
			== "111111111111713f",
		"receiver step preserves exact independent historical 1/240 float64 bits")
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	var parsed_scalar: Dictionary = raw.duplicate(true)
	parsed_scalar.receiver.sweep_step = source.receiver.sweep_step
	_check(PackedFloat64Array([source.receiver.sweep_step]).to_byte_array().hex_encode()
			== "091111111111713f"
		and StadiumNpcYardTwoContractV1.normalized(parsed_scalar).is_empty(),
		"known lossy JSON scalar is not silently repaired outside the scene-vector boundary")
	for delta: int in [-1, 1]:
		var adjacent: Dictionary = raw.duplicate(true)
		var bits: PackedByteArray = PackedFloat64Array([raw.receiver.sweep_step]).to_byte_array()
		bits.encode_u64(0, bits.decode_u64(0) + delta)
		adjacent.receiver.sweep_step = bits.decode_double(0)
		_check(adjacent.receiver.sweep_step != raw.receiver.sweep_step
			and StadiumNpcYardTwoContractV1.normalized(adjacent).is_empty(),
			"either adjacent float64 timing value is different immutable content " + str(delta))
	_check(_json(StadiumNpcYardTwoContractV1.normalized(raw)) == canonical
		and canonical == FileAccess.get_file_as_string(SOURCE),
		"finite scene reconstruction retains strict full-contract canonical equality")
	_check(_json(StadiumNpcYardTwoContractV1.normalized(
		StadiumNpcYardTwoContractV1.canonical())) == canonical,
		"scene reconstruction is idempotent")
	var same: Dictionary = raw.duplicate(true)
	same.items[0].transform[11] += 1e-12
	same.receiver.transform[11] += 1e-12
	same.boundary.segments[1].b[1] += 1e-12
	_check(_json(StadiumNpcYardTwoContractV1.normalized(same)) == canonical,
		"only declared scene-vector representation differences reconstruct to the same bits")
	for edit in range(20):
		var bad: Dictionary = raw.duplicate(true)
		match edit:
			0: bad.items[0].transform[11] = _next_float32(bad.items[0].transform[11])
			1: bad.receiver.transform[11] = _next_float32(bad.receiver.transform[11])
			2: bad.boundary.segments[1].b[1] = _next_float32(bad.boundary.segments[1].b[1])
			3: bad.receiver.timeout += 1e-12
			4: bad.field.values.back_wall_z_m += 1e-12
			5: bad.camera_profile.batting_entry[0] += 1e-12
			6: bad.boundary.segments[0]["unexpected_position"] = [0.0, 0.0]
			7: bad.items[0].transform[0] = false
			8: bad.items[0].transform[11] = NAN
			9: bad.receiver.transform[11] = INF
			10: bad.boundary.segments[1].b.append(0.0)
			11: bad.items[0]["extra_transform"] = bad.items[0].transform.duplicate()
			12: bad.boundary.segments.pop_back()
			13: bad.live_units = 1.0
			14: bad.environment.night_eligible = true
			15: bad.routing.defender_radius += 1e-12
			16: bad.items.reverse()
			17: bad.receiver.transform = PackedFloat32Array(bad.receiver.transform)
			18: bad.receiver.sweep_step += 1e-12
			19: bad.render_profile.minimum = "MSAA_DISABLED"
		_check(StadiumNpcYardTwoContractV1.normalized(bad).is_empty(),
			"strict whole-contract scalar/path/type/adjacent-float32 rejection " + str(edit))
	_check(_json(raw) == original and _json(StadiumNpcYardTwoContractV1.payload()) == original,
		"normalization changes neither caller data nor future raw literal returns")


func _next_float32(value: float) -> float:
	var bytes: PackedByteArray = PackedFloat32Array([value]).to_byte_array()
	bytes.encode_u32(0, bytes.decode_u32(0) + 1)
	return bytes.decode_float(0)

func _representation(value: Dictionary) -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	_check(value.instances[0].site == "O-R1" and fixture.instances[0].site == "O-R1"
		and value.instances[0].transform[1] is float and value.instances[0].transform[1] == 0.0
		and fixture.instances[0].transform[1] == 0.0,
		"equivalent signed-zero control uses independently pinned zero-valued cone basis component")
	var same: Dictionary = value.duplicate(true)
	same.revision = 1.0
	same.valuation.total = 575.0
	same.instances[0].transform[1] = -0.0
	same.instances[0].transform[9] = 8.0 + 1e-12
	_check(_json(StadiumNpcYardTwoCandidateV1.normalized(same)) == _json(value),
		"integer/float32/positive-zero reconstruction occurs after raw validation")
	var changed: Dictionary = value.duplicate(true)
	changed.instances[0].transform[9] = _next_float32(8.0)
	_check(not StadiumNpcManifest.canonical_shape(changed).is_empty()
		and not StadiumNpcYardTwoCandidateV1.valid_manifest(changed),
		"adjacent float32 is different content, not a rounding tolerance")
	var bytes: String = _json(value)
	_check(not StadiumNpcYardTwoCandidateV1.decode(bytes + " ".repeat(
		StadiumNpcManifest.MAX_BYTES - bytes.to_utf8_buffer().size())).is_empty(),
		"exact decode limit accepted")
	_check(StadiumNpcYardTwoCandidateV1.decode(bytes + " ".repeat(
		StadiumNpcManifest.MAX_BYTES + 1 - bytes.to_utf8_buffer().size())).is_empty(),
		"one-byte-over decode refused")


func _malformed(value: Dictionary) -> void:
	for key: String in StadiumNpcManifest.KEYS:
		var bad: Dictionary = value.duplicate(true)
		bad[key] = false
		_check(StadiumNpcYardTwoCandidateV1.normalized(bad).is_empty(), "raw type " + key)
	for edit in range(12):
		var bad: Dictionary = value.duplicate(true)
		match edit:
			0: bad.instances[0].transform[0] = false
			1: bad.instances[0].transform[9] = NAN
			2: bad.instances[0].transform[9] = INF
			3: bad.revision = 1.0000000001
			4: bad.instances[0].host = "absent"
			5:
				bad.instances[0].host = bad.instances[1].instance
				bad.instances[1].host = bad.instances[0].instance
			6: bad.instances[0]["owned_copy"] = "human"
			7: bad.presentation.options = {"night": true}
			8: bad.environment_certificates = [null]
			9: bad.instances[0].transform.pop_back()
			10: bad.instances.reverse()
			11: bad["data_admitted"] = true
		_check(StadiumNpcManifest.canonical_shape(bad).is_empty()
			and StadiumNpcYardTwoCandidateV1.normalized(bad).is_empty(),
			"strict malformed input refused " + str(edit))


func _coherent_edits(value: Dictionary) -> void:
	for edit in range(24):
		var bad: Dictionary = value.duplicate(true)
		match edit:
			0: bad.instances[1].transform[9] += 0.01
			1: bad.instances[1].host = bad.instances[0].instance
			2: bad.models["starter-models"].sha256 = "1".repeat(64)
			3: bad.models["starter-models"].version = 2
			4: bad.models["wooden-bleachers"].sha256 = "1".repeat(64)
			5: bad.graph.sha256 = "1".repeat(64)
			6: bad.catalog.sha256 = "1".repeat(64)
			7: bad.valuation.price_sha256 = "1".repeat(64)
			8:
				bad.valuation.copies += 65
				bad.valuation.total += 65
			9: bad.live_units = 0
			10: bad.field = "field.starter_backyard"
			11: bad.presentation.profile = "YARD-FOUR-STRAIGHT-v1"
			12: bad.routing_version = 2
			13: bad.surface_version = 2
			14: bad.assembly.version = 2
			15: bad.instances.pop_back()
			16: bad.environment_certificates = StadiumNpcVenues.definition(
				"AY-01", 2).environment_certificates
			17: bad.environment_certificates = [{"mode": "night",
				"profile": "YARD-FOUR-STRAIGHT-v1", "version": 1,
				"assembly_sha256": StadiumNpcManifest.payload_key(bad)}]
			18: bad.environment_certificates = [{"mode": "day", "profile": "", "version": 1,
				"assembly_sha256": StadiumNpcManifest.payload_key(bad)}]
			19: bad.models["field-semantics"].sha256 = "1".repeat(64)
			20: bad.models["chair-receiver"].sha256 = "1".repeat(64)
			21: bad.land.stages = ["expanded"]
			22:
				bad.revision = 2
				for row: Dictionary in bad.instances:
					row.instance = "npc:AY-02:r2:" + row.site
			23:
				bad.blueprints = ["ST-001", "ST-026", "ST-027"]
				for row: Dictionary in bad.instances:
					if row.item == "ST-079":
						row.item = "ST-026"
		_check(not StadiumNpcManifest.canonical_shape(bad).is_empty(),
			"coherent edit has valid schema " + str(edit))
		_check(_json(bad).sha256_text() != StadiumNpcYardTwoCandidateV1.SHA256
			and not StadiumNpcYardTwoCandidateV1.valid_manifest(bad)
			and StadiumNpcYardTwoCandidateV1.key(bad).is_empty()
			and StadiumNpcYardTwoCandidateV1.decode(_json(bad)).is_empty(),
			"coherently rehashed edit cannot replace candidate " + str(edit))


func _authority(value: Dictionary) -> void:
	var subject: Dictionary = value.duplicate(true)
	subject.erase("environment_certificates")
	_check(not StadiumNpcYardTwoCandidateV1.valid_manifest(subject)
		and not StadiumNpcVenues.valid_manifest(subject), "subject S is not complete C or public P")
	_check(not StadiumNpcYardTwoCandidateV1.valid_manifest(
		StadiumNpcVenues.definition("AY-01", 2)), "historical public P is not this candidate C")
	var source: Dictionary = StadiumYardTwoStudy.canonical()
	var fixture: Dictionary = StadiumYardTwoFixture.capture(source)
	_check(not StadiumNpcYardTwoCandidateV1.valid_manifest(source)
		and not StadiumNpcYardTwoCandidateV1.valid_manifest(fixture),
		"authoring record/envelope cannot become immutable candidate C")
	for candidate: Dictionary in [value, source, fixture]:
		_check(not StadiumNpcVenues.valid_manifest(candidate)
			and not StadiumNpcSnapshot.valid(candidate)
			and not StadiumLayoutSnapshot.valid(candidate)
			and not PhysicalMatchReport.valid(candidate) and SeasonSave._decode(candidate) == null,
			"candidate C and authoring data cannot become public P or production")
	_check(StadiumNpcVenues.definition("AY-02", 1).is_empty()
		and StadiumNpcAvailability.record("AY-02", 1).is_empty()
		and StadiumNpcSnapshot.capture("AY-02", 1).is_empty()
		and StadiumNpcSnapshot.raw_entry("AY-02", 1).is_empty()
		and not StadiumNpcDaylightEvidenceV2.matches(value),
		"public definition/runtime gates stay closed")
	_check(not StadiumNpcDaylightEvidenceV2.accepts(value,
		StadiumNpcDaylightEvidenceV2.record("AY-01", 2)), "AY01 evidence cannot certify AY02 subject")
	_check(StadiumNpcRuntime._construct(null, "AY-02") == null
		and StadiumNpcRetainedRuntime._construct(null, "AY-02", 1) == null,
		"runtime constructors reject before inspecting absent lab")
	_check(ClubAssetLedger.from_data(value, 0, []) == null,
		"literal instances cannot import as human ownership")
	_check(ContentDB.get_field(&"field.npc_venue") == null,
		"private field is not a human field option")


func _historical() -> Dictionary:
	var result: Dictionary = {}
	for id: String in ["AY-01", "AE-01", "AC-01"]:
		for revision: int in [1, 2]:
			var value: Dictionary = StadiumNpcVenues.definition(id, revision)
			var bytes: String = _json(value)
			_check(not value.is_empty() and bytes.sha256_text() == HISTORICAL_SHA256[
				id + str(revision)], "independent historical canonical byte pin " + id + str(revision))
			result[id + str(revision)] = bytes
	var yard_three: Dictionary = StadiumNpcYardThreeCandidateV1.definition()
	_check(not yard_three.is_empty() and _json(yard_three).sha256_text()
		== "4ce7a2b451994bd64a0173c80bb30dc001f4229b6f6d1e5383b253012415e652",
		"integrated AY03 private C remains independently hash-pinned")
	result["AY-031-private"] = _json(yard_three)
	return result


func _json(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
