extends Node
## Frozen AY-03/r1 data identity and authority refusal. No registry or season admission.

const FIXTURE: String = "res://src/tests/fixtures/npc_yard_three_r1_candidate_canonical.json"
const SOURCE: String = "res://src/tests/fixtures/npc_yard_three_r1_authoring_source.json"
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
	var value: Dictionary = StadiumNpcYardThreeCandidateV1.definition()
	var ledger: ClubAssetLedger = ClubAssetLedger.new_club()
	var ledger_bytes: String = _json(ledger.to_data())
	var historical: Dictionary = _historical()
	_check(not value.is_empty(), "finite explicit AY-03/r1 candidate exists")
	if value.is_empty():
		get_tree().quit(1)
		return
	_provenance()
	_literal(value)
	_copy_isolation(value)
	_representation(value)
	_malformed(value)
	_coherent_edits(value)
	_authority(value)
	_check(_json(ledger.to_data()) == ledger_bytes, "candidate cannot grant or spend human assets")
	_check(_historical() == historical, "all six r1/r2 historical canonical bytes remain exact")
	if _failures == 0:
		print("Wiffaltro AY03 immutable candidate passed: exact r1 literal and closed authority.")
	get_tree().quit(0 if _failures == 0 else 1)


func _provenance() -> void:
	for sources: Dictionary in [StadiumNpcYardThreeProvenance.SOURCES,
		StadiumNpcYardThreeProvenance.CONSTRUCTION_SOURCES,
		StadiumNpcYardThreeProvenance.PROTECTED_SOURCES]:
		for path: String in sources:
			_check(FileAccess.get_sha256(path) == sources[path], "pinned source bytes " + path)
	_check(FileAccess.get_sha256(SOURCE) == StadiumNpcYardThreeProvenance.AUTHORING_SHA256,
		"genuine historical complete authoring record remains byte-identical")
	_check(_json(StadiumYardThreeStudy.canonical()) == FileAccess.get_file_as_string(SOURCE),
		"current source composition exactly equals frozen full authoring record")


func _literal(value: Dictionary) -> void:
	var bytes: String = _json(value)
	_check(bytes == FileAccess.get_file_as_string(FIXTURE)
		and bytes.sha256_text() == StadiumNpcYardThreeCandidateV1.SHA256,
		"canonical literal bytes have independent pinned fixture and digest")
	_check(StadiumNpcManifest.payload_key(value) == StadiumNpcYardThreeCandidateV1.SUBJECT_SHA256
		and StadiumNpcYardThreeCandidateV1.key(value) != StadiumNpcManifest.payload_key(value),
		"complete candidate and certificate-excluded subject use distinct hash domains")
	_check(_json(StadiumNpcYardThreeCandidateV1.decode(bytes)) == bytes,
		"JSON decode restores canonical exact types and float32 transforms")
	_check(value.instances.size() == 8 and value.blueprints == ["ST-037", "ST-080"]
		and value.live_units == 0 and value.environment_certificates.is_empty()
		and value.land == {"version": 1, "tier": "backyard", "stages": []}
		and value.valuation.blueprints == 450 and value.valuation.copies == 420
		and value.valuation.land == 0 and value.valuation.total == 870,
		"four chairs plus four dormant lights, zero live units, fixed nonspendable valuation")
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	for index in range(8):
		var row: Dictionary = value.instances[index]
		var original: Dictionary = source.items[index]
		_check(row.instance == "npc:AY-03:r1:" + original.site and row.site == original.site
			and row.item == original.item and row.host == original.host
			and row.transform == Array(PackedFloat32Array(original.transform)),
			"independent literal source row " + row.site)
		if row.item == "ST-037":
			# Both raw GDScript literals and JSON numbers are float64 representations.
			# Reconstruct only these scene-pose operands to exact Vector3 float32 semantics.
			_check(Array(PackedFloat32Array(StadiumNpcYardThreePosesV1.beams()[row.site]))
				== Array(PackedFloat32Array(original.beam_transform)),
				"exact float32 beam pose independently matches historical source " + row.site)
	_check(value.models["yard-light"] == {"version": 2, "sha256": source.model_sources.yard_light}
		and value.models["light-parts"].sha256 == source.model_sources.light_parts
		and value.models["free-receiver"].sha256 == source.model_sources.receiver
		and value.models["field-semantics"].sha256 == source.model_sources.field_semantics,
		"actual light revision and receiver/field/helper source identities are explicit")


func _copy_isolation(value: Dictionary) -> void:
	var original: String = _json(value)
	for returned: Dictionary in [StadiumNpcYardThreeCandidateV1.payload(),
		StadiumNpcYardThreeCandidateV1.definition(), StadiumNpcYardThreeCandidateV1.normalized(value),
		StadiumNpcYardThreeCandidateV1.decode(original)]:
		returned.instances[0].transform[9] = 99.0
		returned.models["yard-light"].version = 99
		returned.valuation.total = 0
	_check(_json(StadiumNpcYardThreeCandidateV1.definition()) == original,
		"all nested returned data is isolated from the retained literal")
	var beams: Dictionary = StadiumNpcYardThreePosesV1.beams()
	beams["YLIGHT-FL"][9] = 99
	_check(StadiumNpcYardThreePosesV1.beams()["YLIGHT-FL"][9] == 0.0,
		"beam return mutation cannot revise retained optical pose")
	for revision: int in [-1, 0, 2, 1000000]:
		_check(StadiumNpcYardThreeCandidateV1.definition("AY-03", revision).is_empty(),
			"unknown revision cannot fall back to latest")
	for id: String in ["AY-01", "AY-03 ", "ay-03", "AE-01", "UNKNOWN"]:
		_check(StadiumNpcYardThreeCandidateV1.definition(id).is_empty(), "no candidate aliases")


func _representation(value: Dictionary) -> void:
	var same: Dictionary = value.duplicate(true)
	same.revision = 1.0
	same.valuation.total = 870.0
	same.instances[0].transform[0] = -0.0
	same.instances[0].transform[9] = -24.0 + 1e-12
	_check(_json(StadiumNpcYardThreeCandidateV1.normalized(same)) == _json(value),
		"integer/float32/positive-zero reconstruction occurs after raw validation")
	var changed: Dictionary = value.duplicate(true)
	changed.instances[0].transform[9] = -24.000001907348633
	_check(not StadiumNpcManifest.canonical_shape(changed).is_empty()
		and not StadiumNpcYardThreeCandidateV1.valid_manifest(changed),
		"adjacent float32 is different content, not a rounding tolerance")
	var bytes: String = _json(value)
	_check(not StadiumNpcYardThreeCandidateV1.decode(bytes + " ".repeat(
		StadiumNpcManifest.MAX_BYTES - bytes.to_utf8_buffer().size())).is_empty(),
		"exact decode limit accepted")
	_check(StadiumNpcYardThreeCandidateV1.decode(bytes + " ".repeat(
		StadiumNpcManifest.MAX_BYTES + 1 - bytes.to_utf8_buffer().size())).is_empty(),
		"one-byte-over decode refused")


func _malformed(value: Dictionary) -> void:
	for key: String in StadiumNpcManifest.KEYS:
		var bad: Dictionary = value.duplicate(true)
		bad[key] = false
		_check(StadiumNpcYardThreeCandidateV1.normalized(bad).is_empty(), "raw type " + key)
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
			and StadiumNpcYardThreeCandidateV1.normalized(bad).is_empty(),
			"strict malformed input refused " + str(edit))


func _coherent_edits(value: Dictionary) -> void:
	for edit in range(24):
		var bad: Dictionary = value.duplicate(true)
		match edit:
			0: bad.instances[4].transform[9] += 0.01
			1: bad.instances[4].host = bad.instances[0].instance
			2: bad.models["yard-light"].sha256 = "1".repeat(64)
			3: bad.models["yard-light"].version = 1
			4: bad.models["light-parts"].sha256 = "1".repeat(64)
			5: bad.graph.sha256 = "1".repeat(64)
			6: bad.catalog.sha256 = "1".repeat(64)
			7: bad.valuation.price_sha256 = "1".repeat(64)
			8:
				bad.valuation.copies += 65
				bad.valuation.total += 65
			9: bad.live_units = 1
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
			20: bad.models["free-receiver"].sha256 = "1".repeat(64)
			21: bad.land.stages = ["expanded"]
			22:
				bad.revision = 2
				for row: Dictionary in bad.instances:
					row.instance = "npc:AY-03:r2:" + row.site
			23:
				bad.blueprints = ["ST-038", "ST-080"]
				for row: Dictionary in bad.instances:
					if row.item == "ST-037":
						row.item = "ST-038"
		_check(not StadiumNpcManifest.canonical_shape(bad).is_empty(),
			"coherent edit has valid schema " + str(edit))
		_check(_json(bad).sha256_text() != StadiumNpcYardThreeCandidateV1.SHA256
			and not StadiumNpcYardThreeCandidateV1.valid_manifest(bad)
			and StadiumNpcYardThreeCandidateV1.key(bad).is_empty()
			and StadiumNpcYardThreeCandidateV1.decode(_json(bad)).is_empty(),
			"coherently rehashed edit cannot replace candidate " + str(edit))


func _authority(value: Dictionary) -> void:
	var subject: Dictionary = value.duplicate(true)
	subject.erase("environment_certificates")
	_check(not StadiumNpcYardThreeCandidateV1.valid_manifest(subject)
		and not StadiumNpcVenues.valid_manifest(subject), "subject S is not complete C or public P")
	_check(not StadiumNpcYardThreeCandidateV1.valid_manifest(
		StadiumNpcVenues.definition("AY-01", 2)), "historical public P is not this candidate C")
	var source: Dictionary = StadiumYardThreeStudy.canonical()
	var fixture: Dictionary = StadiumYardThreeFixture.capture(source)
	_check(not StadiumNpcYardThreeCandidateV1.valid_manifest(source)
		and not StadiumNpcYardThreeCandidateV1.valid_manifest(fixture),
		"authoring record/envelope cannot become immutable candidate C")
	for candidate: Dictionary in [value, source, fixture]:
		_check(not StadiumNpcVenues.valid_manifest(candidate)
			and not StadiumNpcSnapshot.valid(candidate)
			and not StadiumLayoutSnapshot.valid(candidate)
			and not PhysicalMatchReport.valid(candidate) and SeasonSave._decode(candidate) == null,
			"candidate C and authoring data cannot become public P or production")
	_check(StadiumNpcVenues.definition("AY-03", 1).is_empty()
		and StadiumNpcAvailability.record("AY-03", 1).is_empty()
		and StadiumNpcSnapshot.capture("AY-03", 1).is_empty()
		and StadiumNpcSnapshot.raw_entry("AY-03", 1).is_empty()
		and not StadiumNpcDaylightEvidenceV2.matches(value),
		"public definition/runtime gates stay closed")
	_check(not StadiumNpcDaylightEvidenceV2.accepts(value,
		StadiumNpcDaylightEvidenceV2.record("AY-01", 2)), "AY01 evidence cannot certify AY03 subject")
	_check(StadiumNpcRuntime._construct(null, "AY-03") == null
		and StadiumNpcRetainedRuntime._construct(null, "AY-03", 1) == null,
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
