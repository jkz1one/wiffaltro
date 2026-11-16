extends Node
## Frozen AM-02/r1 data identity and authority refusal. No registry or season admission.

const FIXTURE: String = "res://src/tests/fixtures/npc_mogul_two_r1_candidate_canonical.json"
const SOURCE: String = "res://src/tests/fixtures/npc_mogul_two_r1_authoring_source.json"
const CONTRACT: String = "res://src/tests/fixtures/npc_mogul_two_r1_contract_canonical.json"
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
	var value: Dictionary = StadiumNpcMogulTwoCandidateV1.definition()
	var ledger: ClubAssetLedger = ClubAssetLedger.new_club()
	var ledger_bytes: String = _json(ledger.to_data())
	var historical: Dictionary = _historical()
	_check(not value.is_empty(), "finite explicit AM-02/r1 candidate exists")
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
		print("Wiffaltro AM02 immutable candidate passed: exact r1 literal and closed authority.")
	get_tree().quit(0 if _failures == 0 else 1)


func _provenance() -> void:
	for sources: Dictionary in [StadiumNpcMogulTwoProvenance.SOURCES,
		StadiumNpcMogulTwoProvenance.CONSTRUCTION_SOURCES,
		StadiumNpcMogulTwoProvenance.PROTECTED_SOURCES]:
		for path: String in sources:
			_check(FileAccess.get_sha256(path) == sources[path], "pinned source bytes " + path)
	_check(FileAccess.get_sha256(SOURCE) == StadiumNpcMogulTwoProvenance.AUTHORING_SHA256,
		"genuine historical complete authoring record remains byte-identical")
	_check(FileAccess.get_sha256(CONTRACT) == StadiumNpcMogulTwoProvenance.CONTRACT_SHA256,
		"raw semantic contract remains byte-identical")
	var fresh: Dictionary = StadiumMogulTwoStudy.canonical()
	fresh.erase("qualification_sources")
	_check(_json(fresh) == FileAccess.get_file_as_string(CONTRACT),
		"fresh source composition exactly equals raw-pinned historical semantic contract")
	_check(_json(StadiumNpcMogulTwoContractV1.canonical()) == FileAccess.get_file_as_string(CONTRACT),
		"complete immutable semantic literal equals independent canonical historical bytes")
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	_check(source.qualification_sources.files.size() == 1529,
		"complete historical 1529-file source packet retained")
	for path: String in source.qualification_sources.files:
		_check(FileAccess.get_sha256("res://" + path) == source.qualification_sources.files[path],
			"historical qualified source remains exact " + path)



func _literal(value: Dictionary) -> void:
	var bytes: String = _json(value)
	_check(bytes == FileAccess.get_file_as_string(FIXTURE)
		and bytes.sha256_text() == StadiumNpcMogulTwoCandidateV1.SHA256,
		"canonical literal bytes have independent pinned fixture and digest")
	_check(StadiumNpcManifest.payload_key(value) == StadiumNpcMogulTwoCandidateV1.SUBJECT_SHA256
		and StadiumNpcMogulTwoCandidateV1.key(value) != StadiumNpcManifest.payload_key(value),
		"complete candidate and certificate-excluded subject use distinct hash domains")
	_check(_json(StadiumNpcMogulTwoCandidateV1.decode(bytes)) == bytes,
		"JSON decode restores canonical exact types and float32 transforms")
	_check(value.instances.size() == 91 and value.blueprints.size() == 17
		and value.live_units == 0 and value.environment_certificates.is_empty()
		and value.land == {"version": 1, "tier": "mogul", "stages": ["expanded", "club", "mogul"]}
		and value.valuation.blueprints == 7390 and value.valuation.copies == 5975
		and value.valuation.land == 6400 and value.valuation.total == 19765,
		"91 copies, 17 SKUs, zero live units and fixed nonspendable valuation")
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	var rows: Dictionary = {}
	for row: Dictionary in source.items:
		rows[row.site] = row
	var counts: Dictionary = {}
	for row: Dictionary in value.instances:
		var original: Dictionary = rows[row.site]
		_check(row.instance == "npc:AM-02:r1:" + original.site and row.site == original.site
			and row.item == original.item and row.host == "field"
			and original.host == "npc-venue:AM-02:left-loft-v1"
			and row.transform == Array(PackedFloat32Array(original.transform)),
			"independent raw source row and explicit field-host mapping " + row.site)
		counts[row.item] = int(counts.get(row.item, 0)) + 1
	_check(counts == StadiumNpcMogulTwoV1.COUNTS and source.crowd.total == 480,
		"complete original composition including 480 represented spectators")
	_check(value.models["premium-tower"].version == 1
		and value.models["baseline-guard"].version == 2 and value.models["catch-net"].version == 2
		and value.models["authoring-contract"].sha256 == StadiumNpcMogulTwoProvenance.AUTHORING_SHA256,
		"premium tower, corrected receiver, guard variant and complete source binding")
	_check(source.lighting.dormant and source.lighting.active_lights == 0
		and source.lighting.towers.size() == 4 and source.environment.certificates.is_empty()
		and not source.environment.night_eligible, "no active/night/environment authority")



func _copy_isolation(value: Dictionary) -> void:
	var original: String = _json(value)
	for returned: Dictionary in [StadiumNpcMogulTwoCandidateV1.payload(),
		StadiumNpcMogulTwoCandidateV1.definition(), StadiumNpcMogulTwoCandidateV1.normalized(value),
		StadiumNpcMogulTwoCandidateV1.decode(original)]:
		returned.instances[0].transform[9] = 99.0
		returned.models["premium-tower"].version = 99
		returned.valuation.total = 0
	_check(_json(StadiumNpcMogulTwoCandidateV1.definition()) == original,
		"all nested returned data is isolated from the retained literal")
	var contract: Dictionary = StadiumNpcMogulTwoContractV1.payload()
	contract.lighting.towers[0].heads[0].origin[0] = 99
	contract.items[0].transform[9] = 99
	_check(_json(StadiumNpcMogulTwoContractV1.canonical()) == FileAccess.get_file_as_string(CONTRACT),
		"semantic and ray return mutation cannot revise retained source literal")
	for revision: int in [-1, 0, 2, 1000000]:
		_check(StadiumNpcMogulTwoCandidateV1.definition("AM-02", revision).is_empty(),
			"unknown revision cannot fall back to latest")
	for id: String in ["AY-01", "AM-02 ", "am-01", "AE-01", "UNKNOWN"]:
		_check(StadiumNpcMogulTwoCandidateV1.definition(id).is_empty(), "no candidate aliases")


func _contract_representation() -> void:
	var raw: Dictionary = StadiumNpcMogulTwoContractV1.payload()
	var raw_bytes: String = _json(raw)
	var canonical: Dictionary = StadiumNpcMogulTwoContractV1.canonical()
	_check(_json(StadiumNpcMogulTwoContractV1.normalized(raw))
		== FileAccess.get_file_as_string(CONTRACT),
		"declared exact scene reconstruction preserves strict whole original contract")
	_check(_json(StadiumNpcMogulTwoContractV1.normalized(canonical)) == _json(canonical),
		"canonical contract normalization is idempotent")
	var same: Dictionary = raw.duplicate(true)
	same.items[0].transform[9] += 1e-12
	_check(_json(StadiumNpcMogulTwoContractV1.normalized(same)) == _json(canonical),
		"scene-only sub-float32 representation difference reconstructs exactly")
	for edit in range(16):
		var bad: Dictionary = raw.duplicate(true)
		match edit:
			0:
				var bytes: PackedByteArray = PackedFloat32Array(
					[bad.items[0].transform[9]]).to_byte_array()
				bytes.encode_u32(0, bytes.decode_u32(0) + 1)
				bad.items[0].transform[9] = bytes.decode_float(0)
			1: bad.crowd.total += 1
			2: bad.field.back_wall_z_m += 1e-12
			3: bad.camera_profile.right_entry[0] += 1e-12
			4: bad.graph.segments[0]["unexpected_position"] = [0.0, 0.0]
			5: bad.items[0].transform[0] = false
			6: bad.items[0].transform[9] = NAN
			7: bad.lighting.towers[0].heads[0].direction.append(0.0)
			8: bad.items[0]["extra_transform"] = bad.items[0].transform.duplicate()
			9: bad.graph.segments.append(bad.graph.segments[0].duplicate(true))
			10: bad.live_units = 0.0
			11: bad.environment.night_eligible = true
			12: bad.items[0].wall.width += 1e-12
			13: bad.items[0].wall.a[0] = false
			14: bad.items[0].support["unexpected"] = 1
			15:
				var bytes: PackedByteArray = PackedFloat32Array([bad.items[0].wall.a[0]]).to_byte_array()
				bytes.encode_u32(0, bytes.decode_u32(0) + 1)
				bad.items[0].wall.a[0] = bytes.decode_float(0)
		_check(StadiumNpcMogulTwoContractV1.normalized(bad).is_empty(),
			"strict contract scalar/path/type/adjacent-float32 control " + str(edit))
	_check(_json(raw) == raw_bytes and _json(StadiumNpcMogulTwoContractV1.payload()) == raw_bytes,
		"normalization never rewrites caller data or raw literal getter")


func _representation(value: Dictionary) -> void:
	var same: Dictionary = value.duplicate(true)
	same.revision = 1.0
	same.valuation.total = 19765.0
	same.instances[0].transform[1] = -0.0
	same.instances[0].transform[9] += 1e-12
	_check(_json(StadiumNpcMogulTwoCandidateV1.normalized(same)) == _json(value),
		"integer/float32/positive-zero reconstruction occurs after raw validation")
	var changed: Dictionary = value.duplicate(true)
	var binary: PackedByteArray = PackedFloat32Array(
		[changed.instances[0].transform[9]]).to_byte_array()
	binary.encode_u32(0, binary.decode_u32(0) + 1)
	changed.instances[0].transform[9] = binary.decode_float(0)
	_check(not StadiumNpcManifest.canonical_shape(changed).is_empty()
		and not StadiumNpcMogulTwoCandidateV1.valid_manifest(changed),
		"adjacent float32 is different content, not a rounding tolerance")
	var bytes: String = _json(value)
	_check(not StadiumNpcMogulTwoCandidateV1.decode(bytes + " ".repeat(
		StadiumNpcManifest.MAX_BYTES - bytes.to_utf8_buffer().size())).is_empty(),
		"exact decode limit accepted")
	_check(StadiumNpcMogulTwoCandidateV1.decode(bytes + " ".repeat(
		StadiumNpcManifest.MAX_BYTES + 1 - bytes.to_utf8_buffer().size())).is_empty(),
		"one-byte-over decode refused")


func _malformed(value: Dictionary) -> void:
	for key: String in StadiumNpcManifest.KEYS:
		var bad: Dictionary = value.duplicate(true)
		bad[key] = false
		_check(StadiumNpcMogulTwoCandidateV1.normalized(bad).is_empty(), "raw type " + key)
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
			and StadiumNpcMogulTwoCandidateV1.normalized(bad).is_empty(),
			"strict malformed input refused " + str(edit))


func _coherent_edits(value: Dictionary) -> void:
	for edit in range(24):
		var bad: Dictionary = value.duplicate(true)
		match edit:
			0: bad.instances[4].transform[9] += 0.01
			1: bad.instances[4].host = bad.instances[0].instance
			2: bad.models["premium-tower"].sha256 = "1".repeat(64)
			3: bad.models["premium-tower"].version = 2
			4: bad.models["starter-parts"].sha256 = "1".repeat(64)
			5: bad.graph.sha256 = "1".repeat(64)
			6: bad.catalog.sha256 = "1".repeat(64)
			7: bad.valuation.price_sha256 = "1".repeat(64)
			8:
				bad.valuation.copies += 65
				bad.valuation.total += 65
			9: bad.live_units = 1
			10: bad.field = "field.starter_backyard"
			11: bad.presentation.profile = "MOGUL6-STANDARD"
			12: bad.routing_version = 2
			13: bad.surface_version = 2
			14: bad.assembly.version = 2
			15: bad.instances.pop_back()
			16: bad.environment_certificates = StadiumNpcVenues.definition(
				"AY-01", 2).environment_certificates
			17: bad.environment_certificates = [{"mode": "night",
				"profile": "MOGUL6-STANDARD", "version": 1,
				"assembly_sha256": StadiumNpcManifest.payload_key(bad)}]
			18: bad.environment_certificates = [{"mode": "day", "profile": "", "version": 1,
				"assembly_sha256": StadiumNpcManifest.payload_key(bad)}]
			19: bad.models["field-semantics"].sha256 = "1".repeat(64)
			20: bad.models["pitch-receiver"].sha256 = "1".repeat(64)
			21: bad.land.stages = ["club", "expanded", "mogul"]
			22:
				bad.revision = 2
				for row: Dictionary in bad.instances:
					row.instance = "npc:AM-02:r2:" + row.site
			23:
				bad.models["baseline-guard"].version = 1

		_check(not StadiumNpcManifest.canonical_shape(bad).is_empty(),
			"coherent edit has valid schema " + str(edit))
		_check(_json(bad).sha256_text() != StadiumNpcMogulTwoCandidateV1.SHA256
			and not StadiumNpcMogulTwoCandidateV1.valid_manifest(bad)
			and StadiumNpcMogulTwoCandidateV1.key(bad).is_empty()
			and StadiumNpcMogulTwoCandidateV1.decode(_json(bad)).is_empty(),
			"coherently rehashed edit cannot replace candidate " + str(edit))


func _authority(value: Dictionary) -> void:
	var subject: Dictionary = value.duplicate(true)
	subject.erase("environment_certificates")
	_check(not StadiumNpcMogulTwoCandidateV1.valid_manifest(subject)
		and not StadiumNpcVenues.valid_manifest(subject), "subject S is not complete C or public P")
	_check(not StadiumNpcMogulTwoCandidateV1.valid_manifest(
		StadiumNpcVenues.definition("AY-01", 2)), "historical public P is not this candidate C")
	var source: Dictionary = StadiumMogulTwoStudy.canonical()
	var fixture: Dictionary = StadiumMogulTwoFixture.capture(source)
	_check(not StadiumNpcMogulTwoCandidateV1.valid_manifest(source)
		and not StadiumNpcMogulTwoCandidateV1.valid_manifest(fixture),
		"authoring record/envelope cannot become immutable candidate C")
	for candidate: Dictionary in [value, source, fixture]:
		_check(not StadiumNpcVenues.valid_manifest(candidate)
			and not StadiumNpcSnapshot.valid(candidate)
			and not StadiumLayoutSnapshot.valid(candidate)
			and not PhysicalMatchReport.valid(candidate) and SeasonSave._decode(candidate) == null,
			"candidate C and authoring data cannot become public P or production")
	_check(StadiumNpcVenues.definition("AM-02", 1).is_empty()
		and StadiumNpcAvailability.record("AM-02", 1).is_empty()
		and StadiumNpcSnapshot.capture("AM-02", 1).is_empty()
		and StadiumNpcSnapshot.raw_entry("AM-02", 1).is_empty()
		and not StadiumNpcDaylightEvidenceV2.matches(value),
		"public definition/runtime gates stay closed")
	_check(not StadiumNpcDaylightEvidenceV2.accepts(value,
		StadiumNpcDaylightEvidenceV2.record("AY-01", 2)), "AY01 evidence cannot certify AM02 subject")
	_check(StadiumNpcRuntime._construct(null, "AM-02") == null
		and StadiumNpcRetainedRuntime._construct(null, "AM-02", 1) == null,
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
	return result


func _json(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
