extends Node
## Actual AE-01/r1 data admission and detached construction correspondence only.
## No fixture, season, save, physical-worker, settlement or environment certification.

const EXPECTED_SHA256: String = "0e2cbd2e61ac0c2f3b3970053a2d76a2424d4ca3a98f1c8f06ec4d04307f849b"
var _failures: int = 0


func _ready() -> void:
	var ledger: ClubAssetLedger = ClubAssetLedger.new_club()
	var ledger_bytes: String = _json(ledger.to_data())
	var field_bytes: String = FileAccess.get_sha256("res://src/content/fields/starter_field.tres")
	var literal: Dictionary = StadiumNpcVenues.definition("AE-01", 1)
	_check(not literal.is_empty(), "exact AE-01/r1 literal is admitted")
	if literal.is_empty():
		get_tree().quit(1)
		return
	_provenance()
	_literal(literal)
	_raw_types(literal)
	_canonical_numbers(literal)
	_attacks(literal)
	_copied_revisions(literal)
	_candidate_refusal(literal)
	_assembly(literal)
	_check(
		ledger_bytes == _json(ledger.to_data()),
		"literal lookup and both assemblies preserve complete human ledger bytes"
	)
	_check(
		field_bytes == FileAccess.get_sha256("res://src/content/fields/starter_field.tres"),
		"literal lookup and detached construction never rewrite the shared field"
	)
	_check(
		not StadiumLayoutSnapshot.valid(literal) and not PhysicalMatchReport.valid(literal),
		"admitted definition is neither a human snapshot nor a production report"
	)
	_check(
		ClubAssetLedger.from_data(literal, 0, []) == null,
		"NPC catalog copies cannot be imported as human ownership"
	)
	await get_tree().process_frame
	if _failures == 0:
		print(
			(
				"stadium NPC AE-01 definition: PASS "
				+ "(immutable r1 data and independent assembly correspondence)"
			)
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _provenance() -> void:
	# Admission-test evidence only: neither registry lookup nor retained build reads these files.
	for path: String in StadiumNpcExpandedProvenance.SOURCES:
		_check(
			FileAccess.get_sha256(path) == StadiumNpcExpandedProvenance.SOURCES[path],
			"independent qualified authoring provenance " + path
		)
	for path: String in StadiumNpcExpandedProvenance.CONSTRUCTION_SOURCES:
		_check(
			FileAccess.get_sha256(path) == StadiumNpcExpandedProvenance.CONSTRUCTION_SOURCES[path],
			"retained revision-1 construction provenance " + path
		)


func _literal(value: Dictionary) -> void:
	var encoded: String = _json(value)
	_check(
		(
			encoded.to_utf8_buffer().size() == 8062
			and encoded.sha256_text() == EXPECTED_SHA256
			and StadiumNpcExpandedDefinitionV1.SHA256 == EXPECTED_SHA256
		),
		"exact canonical bytes/hash frozen independently from registry"
	)
	_check(
		(
			encoded
			== FileAccess.get_file_as_string(
				"res://src/tests/fixtures/npc_expanded_r1_canonical.json"
			)
		),
		"complete canonical payload equals independent retained byte fixture"
	)
	_check(
		StadiumNpcVenues.valid_manifest(value) and StadiumNpcVenues.key(value) == EXPECTED_SHA256,
		"actual published literal passes exact production lookup"
	)
	_check(
		(
			_json(StadiumNpcVenues.decode(encoded)) == encoded
			and _json(StadiumNpcVenues.normalized(value)) == encoded
			and (
				_json(StadiumNpcManifest.canonical_shape(StadiumNpcExpandedDefinitionV1.payload()))
				== encoded
			)
		),
		"all canonical entry points retain exact bytes"
	)
	_check(
		(
			value.id == "AE-01"
			and value.revision == 1
			and value.version == 1
			and value.assembly == {"id": "AE-01-expanded-deeper-center-v1", "version": 1}
			and value.field == "field.starter_backyard"
			and value.tier == "expanded"
			and value.shape == "deeper_center"
			and value.rules_version == 1
		),
		"explicit assembly/field/rules identity"
	)
	var source: Dictionary = StadiumExpandedVenueStudy.canonical()
	var models: Dictionary = {}
	for name: String in source.model_sources:
		models[name] = {
			"version": 2 if name == "stadium_net_models" else 1,
			"sha256": source.model_sources[name]
		}
	models["free-template"] = {
		"version": 1, "sha256": "779ce82a8bc9ff872dc3e1cf5c50552f5cf7eaa5914e5857d9459904cbaf89af"
	}
	_check(
		(
			value.models == models
			and value.catalog == {"version": 1, "sha256": StadiumCatalog.signature()}
			and value.valuation.price_sha256 == source.endowment.price_version
		),
		"explicit immutable model/catalog identities match independent source"
	)
	_check(
		(
			value.instances.size() == 27
			and value.blueprints == ["ST-024", "ST-025", "ST-026", "ST-028", "ST-039"]
			and value.live_units == 0
			and value.land == {"version": 1, "tier": "expanded", "stages": ["expanded"]}
		),
		"27 exact copies, five blueprints, Expanded stage, zero live units"
	)
	_check(
		(
			value.valuation
			== {
				"price_version": 1,
				"price_sha256": "5210c3c47688b06faa35a50ec211f65de0a881debc5d7567a4c0e2abe6df204f",
				"blueprints": 1710,
				"copies": 1220,
				"land": 600,
				"total": 3530
			}
		),
		"3530 is historical content valuation, not money or purchase history"
	)
	_check(
		(
			value.environment_certificates.is_empty()
			and value.presentation == {"profile": "AE-01-default-expanded-v1", "options": {}}
			and value.surface_version == 1
			and value.routing_version == 1
		),
		"fixed defaults do not invent environment certification"
	)
	var rows: Dictionary = {}
	for row: Dictionary in source.items:
		rows[row.site] = row
	for row: Dictionary in value.instances:
		_check(
			(
				rows.has(row.site)
				and row.item == rows[row.site].item
				and row.host == "field"
				and row.instance == "npc:AE-01:r1:" + row.site
				and row.transform == rows[row.site].transform
			),
			"exact independently sourced instance/site/pose/host " + row.site
		)
	for revision: int in [-1, 0, 3, 1000000]:
		_check(StadiumNpcVenues.definition("AE-01", revision).is_empty(), "no latest fallback")
	for id: String in ["ae-01", "AE-01 ", "UNKNOWN", "AC-01-unknown", "SCHEMA-ONLY"]:
		_check(StadiumNpcVenues.definition(id, 1).is_empty(), "unknown identity rejects " + id)
	_check(
		(
			StadiumNpcVenues.key(StadiumNpcVenues.definition("AY-01", 1))
			== "6295c0e4b2221666530fa343c6a0b39d6a7e61cff11b5850b59e13ec10c811e7"
		),
		"existing AY canonical bytes/hash remain unchanged"
	)
	_check(
		(
			_json(
				StadiumNpcVenues.decode(
					(
						encoded
						+ " ".repeat(StadiumNpcManifest.MAX_BYTES - encoded.to_utf8_buffer().size())
					)
				)
			)
			== encoded
		),
		"exact maximum input bytes accepts bounded literal"
	)
	_check(
		(
			StadiumNpcVenues
			. decode(
				(
					encoded
					+ " ".repeat(StadiumNpcManifest.MAX_BYTES + 1 - encoded.to_utf8_buffer().size())
				)
			)
			. is_empty()
		),
		"one-byte-over input rejects"
	)


func _canonical_numbers(value: Dictionary) -> void:
	var equivalent: Dictionary = value.duplicate(true)
	equivalent.revision = 1.0
	equivalent.valuation.total = 3530.0
	equivalent.instances[3].transform[9] = -24.0 + 0.000000000001
	equivalent.instances[3].transform[0] = -0.0
	var normalized: Dictionary = StadiumNpcVenues.normalized(equivalent)
	_check(
		not normalized.is_empty() and _json(normalized) == _json(value),
		"real literal comparison occurs after integer and float32 reconstruction"
	)
	if normalized.is_empty():
		return
	_check(
		(
			normalized.revision is int
			and normalized.valuation.total is int
			and (
				PackedFloat64Array([normalized.instances[3].transform[0]]).to_byte_array()
				== PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0])
			)
		),
		"real literal canonical integer types and positive-zero bits"
	)
	_check(
		equivalent.revision is float and equivalent.instances[3].transform[9] != -24.0,
		"representation normalization does not mutate its caller"
	)
	var changed: Dictionary = value.duplicate(true)
	changed.instances[3].transform[9] = float(PackedFloat32Array([-24.0000019073486328125])[0])
	_check(
		(
			changed.instances[3].transform[9] != -24.0
			and not StadiumNpcManifest.canonical_shape(changed).is_empty()
			and not StadiumNpcVenues.valid_manifest(changed)
		),
		"one adjacent float32 scene coordinate is a different literal"
	)


func _raw_types(value: Dictionary) -> void:
	for key: String in StadiumNpcManifest.KEYS:
		var bad: Dictionary = value.duplicate(true)
		bad[key] = false
		_check(
			(
				StadiumNpcManifest.canonical_shape(bad).is_empty()
				and not StadiumNpcVenues.valid_manifest(bad)
			),
			"published raw top-level type " + key
		)
	for edit in range(17):
		var bad: Dictionary = JSON.parse_string(_json(value))
		match edit:
			0:
				bad.instances[0].transform[0] = false
			1:
				bad.instances[0].transform[4] = true
			2:
				bad.instances[0].transform[9] = NAN
			3:
				bad.instances[0].transform[9] = INF
			4:
				bad.instances[0].transform[9] = 1e100
			5:
				bad.instances[0].transform = {"x": 0}
			6:
				bad.instances[0] = null
			7:
				bad.models["stadium_wall_panel_models"] = null
			8:
				bad.valuation.land = false
			9:
				bad.revision = 1.00000000001
			10:
				bad.instances[0].transform.pop_back()
			11:
				bad.instances[0].host = "missing"
			12:
				bad.instances[0].host = bad.instances[1].instance
			13:
				bad.instances[0]["owned_copy"] = "human"
			14:
				bad.instances[1].site = bad.instances[0].site
			15:
				bad.environment_certificates = [null]
			16:
				bad.presentation.options = {"night": true}
		if edit == 12:
			bad.instances[1].host = bad.instances[0].instance
		_check(
			StadiumNpcManifest.canonical_shape(bad).is_empty(),
			"real literal malformed nested raw value " + str(edit)
		)
		_check(
			not StadiumNpcVenues.valid_manifest(bad) and StadiumNpcVenues.key(bad).is_empty(),
			"malformed literal cannot acquire authority " + str(edit)
		)


func _attacks(value: Dictionary) -> void:
	for edit in range(21):
		var bad: Dictionary = value.duplicate(true)
		match edit:
			0:
				bad.instances[0].transform[9] += 0.125
			1:
				bad.models["stadium_wall_panel_models"].version = 2
			2:
				bad.models["stadium_wall_panel_models"].sha256 = "1".repeat(64)
			3:
				bad.graph.sha256 = "1".repeat(64)
			4:
				bad.graph.version = 2
			5:
				bad.instances[1].host = bad.instances[0].instance
			6:
				bad.instances.pop_back()
			7:
				bad.valuation.price_version = 2
			8:
				bad.valuation.price_sha256 = "1".repeat(64)
			9:
				bad.catalog.sha256 = "1".repeat(64)
			10:
				bad.valuation.copies += 40
			11:
				bad.field = "field.foreign"
			12:
				bad.presentation.profile = "foreign-default"
			13:
				bad.surface_version = 2
			14:
				bad.routing_version = 2
			15:
				bad.assembly.version = 2
			16:
				bad.instances[3].site = "SIDE-SEAT-M"
			17:
				bad.blueprints = ["ST-079"]
			18:
				bad.environment_certificates = [
					{
						"mode": "night",
						"profile": "invented",
						"version": 1,
						"assembly_sha256": EXPECTED_SHA256
					}
				]
			19:
				bad.land.stages = ["unearned"]
			20:
				bad.live_units = 1
		if edit == 10:
			bad.valuation.total += 40
		if edit == 16:
			bad.instances[3].instance = "npc:AE-01:r1:SIDE-SEAT-M"
		if edit == 17:
			for row: Dictionary in bad.instances:
				row.item = "ST-079"
		_check(
			not StadiumNpcManifest.canonical_shape(bad).is_empty(),
			"attack is structurally valid and has no malformed-input excuse " + str(edit)
		)
		var rehashed: String = _json(bad).sha256_text()
		_check(
			(
				rehashed != EXPECTED_SHA256
				and StadiumNpcVenues.normalized(bad).is_empty()
				and StadiumNpcVenues.key(bad).is_empty()
				and StadiumNpcVenues.decode(_json(bad)).is_empty()
			),
			"complete literal authority rejects changed and rehashed payload " + str(edit)
		)


func _copied_revisions(value: Dictionary) -> void:
	var baseline: String = _json(value)
	var returned: Dictionary = StadiumNpcVenues.definition("AE-01", 1)
	returned.instances[0].transform[9] = 99.0
	returned.models["stadium_wall_panel_models"].version = 99
	returned.land.stages.append("foreign")
	var normalized: Dictionary = StadiumNpcVenues.normalized(value)
	normalized.instances.clear()
	var decoded: Dictionary = StadiumNpcVenues.decode(baseline)
	decoded.valuation.total = 0
	var raw: Dictionary = StadiumNpcExpandedDefinitionV1.payload()
	raw.instances.clear()
	_check(
		(
			_json(StadiumNpcVenues.definition("AE-01", 1)) == baseline
			and (
				_json(StadiumNpcManifest.canonical_shape(StadiumNpcExpandedDefinitionV1.payload()))
				== baseline
			)
		),
		"nested mutations through every return path leave the published literal immutable"
	)
	# Local copied revisions exercise retention mechanics; this does not publish revision 2.
	var second: Dictionary = _relabel(value, "AE-01", 2)
	second.instances[0].transform[9] = -23.0
	var records: Dictionary = {"AE-01": {"1": value.duplicate(true), "2": second}}
	_check(
		not StadiumNpcVenues._definition_from(records, "AE-01", 2).is_empty(),
		"locally copied revision remains structurally independent"
	)
	second.models["stadium_wall_panel_models"].version = 2
	_check(
		_json(StadiumNpcVenues._definition_from(records, "AE-01", 1)) == baseline,
		"a later copied definition never remodels retained revision 1"
	)
	records["AE-01"]["1"] = second
	_check(
		(
			StadiumNpcVenues._definition_from(records, "AE-01", 1).is_empty()
			and StadiumNpcVenues.definition("AE-01", 3).is_empty()
			and not StadiumNpcVenues.valid_manifest(second)
		),
		"copied/relabeled revision keys cannot mint production authority"
	)


func _candidate_refusal(value: Dictionary) -> void:
	var authored: Dictionary = StadiumExpandedVenueStudy.canonical()
	_check(
		(
			_json(authored).to_utf8_buffer().size() == 8217
			and (
				_json(authored).sha256_text()
				== "cefa97353df75ebc50c936946b6299e0cf4fff5e3a8f36531b874b2c5d903152"
			)
		),
		"independent authoring bytes retain qualified provenance, not registry authority"
	)
	_check(_json(authored) == FileAccess.get_file_as_string(
		"res://src/tests/fixtures/npc_expanded_authoring_source.json"),
		"source-bound authoring payload retains exact independent bytes")
	var envelope: Dictionary = StadiumExpandedFixtureStudy.capture(authored)
	_check(
		not envelope.is_empty() and StadiumExpandedFixtureStudy.valid(envelope),
		"negative control starts with a real qualified-source authoring fixture"
	)
	_check(
		(
			not StadiumNpcVenues.valid_manifest(authored)
			and not StadiumNpcVenues.valid_manifest(envelope)
		),
		"actual authored record and envelope remain outside registry authority"
	)
	envelope.kind = "npc-authored-v1"
	envelope.venue.status = "VALIDATED"
	envelope.venue["revision"] = 1
	envelope.sha256 = _json(envelope.venue).sha256_text()
	_check(
		(
			StadiumNpcVenues.decode(_json(envelope)).is_empty()
			and not StadiumNpcVenues.valid_manifest(envelope.venue)
		),
		"correctly rehashed/relabelled real candidate is not a definition"
	)
	var foreign: Dictionary = _relabel(value, "FOREIGN-01", 1)
	_check(
		(
			not StadiumNpcManifest.canonical_shape(foreign).is_empty()
			and not StadiumNpcVenues.valid_manifest(foreign)
		),
		"structurally valid foreign identity cannot borrow published assembly authority"
	)


func _assembly(value: Dictionary) -> void:
	for message: String in StadiumNpcExpandedCorrespondence.verify(value):
		_check(false, message)


func _relabel(value: Dictionary, id: String, revision: int) -> Dictionary:
	var result: Dictionary = value.duplicate(true)
	result.id = id
	result.revision = revision
	for row: Dictionary in result.instances:
		row.instance = "npc:%s:r%d:%s" % [id, revision, row.site]
	return result


func _json(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
