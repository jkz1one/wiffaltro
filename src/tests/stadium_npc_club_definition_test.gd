extends Node3D
## Actual AC-01/r1 data admission and detached construction correspondence only.
## No fixture, season, save, physical-worker, settlement or environment certification.

const EXPECTED_SHA256: String = "066c33dadf47d999ec5bb9bcc0a69c280013633b9d83f7226eab814b68dbd797"
var _failures: int = 0


func _ready() -> void:
	var ledger: ClubAssetLedger = ClubAssetLedger.new_club()
	var ledger_bytes: String = _json(ledger.to_data())
	var field_bytes: String = FileAccess.get_sha256("res://src/content/fields/starter_field.tres")
	var literal: Dictionary = StadiumNpcVenues.definition("AC-01", 1)
	_check(not literal.is_empty(), "exact AC-01/r1 literal is admitted")
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
				"stadium NPC AC-01 definition: PASS "
				+ "(immutable r1 data and independent assembly correspondence)"
			)
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _provenance() -> void:
	# Admission-test evidence only: neither registry lookup nor retained build reads these files.
	for path: String in StadiumNpcClubProvenance.SOURCES:
		_check(
			FileAccess.get_sha256(path) == StadiumNpcClubProvenance.SOURCES[path],
			"independent qualified authoring provenance " + path
		)
	for path: String in StadiumNpcClubProvenance.CONSTRUCTION_SOURCES:
		_check(
			FileAccess.get_sha256(path) == StadiumNpcClubProvenance.CONSTRUCTION_SOURCES[path],
			"retained revision-1 construction provenance " + path
		)


func _literal(value: Dictionary) -> void:
	var encoded: String = _json(value)
	_check(
		(
			encoded.to_utf8_buffer().size() == 19948
			and encoded.sha256_text() == EXPECTED_SHA256
			and StadiumNpcClubDefinitionV1.SHA256 == EXPECTED_SHA256
		),
		"exact canonical bytes/hash frozen independently from registry"
	)
	_check(
		(
			encoded
			== FileAccess.get_file_as_string("res://src/tests/fixtures/npc_club_r1_canonical.json")
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
				_json(StadiumNpcManifest.canonical_shape(StadiumNpcClubDefinitionV1.payload()))
				== encoded
			)
		),
		"all canonical entry points retain exact bytes"
	)
	_check(
		(
			value.id == "AC-01"
			and value.revision == 1
			and value.version == 1
			and value.assembly == {"id": "AC-01-club-offset-gables-v1", "version": 1}
			and value.field == "field.starter_backyard"
			and value.tier == "club"
			and value.shape == "offset_gables"
			and value.rules_version == 1
		),
		"explicit assembly/field/rules identity"
	)
	var source: Dictionary = _authoring()
	for model: String in value.models:
		var stem: String = "stadium_property_geometry" if model == "free-template" else model
		var path: String = "res://src/presentation/stadium/" + stem + ".gd"
		if not FileAccess.file_exists(path):
			path = "res://src/gameplay/stadium/" + stem + ".gd"
		_check(
			FileAccess.get_sha256(path) == value.models[model].sha256,
			"independent construction source identity " + model
		)
	_check(
		value.catalog.sha256 == source.catalog and value.graph.sha256 == source.boundary,
		"qualified source graph/catalog identities"
	)
	_check(
		(
			value.instances.size() == 72
			and (
				value.blueprints
				== [
					"ST-021",
					"ST-022",
					"ST-023",
					"ST-026",
					"ST-029",
					"ST-039",
					"ST-053",
					"ST-065",
					"ST-073",
					"ST-074"
				]
			)
			and value.live_units == 0
			and value.land == {"version": 1, "tier": "club", "stages": ["expanded", "club"]}
		),
		"72 exact copies, ten blueprints, ordered Expanded/Club stages, zero live units"
	)
	_check(
		(
			value.valuation
			== {
				"price_version": 1,
				"price_sha256": "5210c3c47688b06faa35a50ec211f65de0a881debc5d7567a4c0e2abe6df204f",
				"blueprints": 3750,
				"copies": 3125,
				"land": 2200,
				"total": 9075
			}
		),
		"9075 is historical content valuation, not money or purchase history"
	)
	_check(
		(
			value.environment_certificates.is_empty()
			and value.presentation == {"profile": "AC-01-default-club-offset-v1", "options": {}}
			and value.surface_version == 1
			and value.routing_version == 1
		),
		"fixed defaults do not invent environment certification"
	)
	var rows: Dictionary = {}
	for row: Dictionary in source.items:
		rows[row.site] = row
	for row: Dictionary in value.instances:
		var roof: bool = row.site.ends_with(".ROOF-LOWER")
		var expected_host: String = (
			"npc:AC-01:r1:" + row.site.get_slice(".", 0) if roof else "field"
		)
		var expected_pose: Array = (
			[1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0]
			if roof
			else rows[row.site].transform
		)
		_check(
			(
				rows.has(row.site)
				and row.item == rows[row.site].item
				and row.host == expected_host
				and row.instance == "npc:AC-01:r1:" + row.site
				and row.transform == expected_pose
			),
			"exact independently sourced instance/site/pose/host " + row.site
		)
	for revision: int in [-1, 0, 3, 1000000]:
		_check(StadiumNpcVenues.definition("AC-01", revision).is_empty(), "no latest fallback")
	for id: String in ["ac-01", "AC-01 ", "UNKNOWN", "AC-01-unknown", "SCHEMA-ONLY"]:
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
			StadiumNpcVenues.key(StadiumNpcVenues.definition("AE-01", 1))
			== "0e2cbd2e61ac0c2f3b3970053a2d76a2424d4ca3a98f1c8f06ec4d04307f849b"
		),
		"existing AE canonical bytes/hash remain unchanged"
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
	equivalent.valuation.total = 9075.0
	equivalent.instances[0].transform[9] = -18.24445152282715 + 0.000000000001
	equivalent.instances[0].transform[1] = -0.0
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
				PackedFloat64Array([normalized.instances[0].transform[1]]).to_byte_array()
				== PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0])
			)
		),
		"real literal canonical integer types and positive-zero bits"
	)
	_check(
		equivalent.revision is float and equivalent.instances[0].transform[9] != -18.24445152282715,
		"representation normalization does not mutate its caller"
	)
	var changed: Dictionary = value.duplicate(true)
	changed.instances[0].transform[9] = float(PackedFloat32Array([-18.24445343017578125])[0])
	_check(
		(
			changed.instances[0].transform[9] != -18.24445152282715
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
				bad.models["stadium_wall_panel_models"].version = 3
			2:
				bad.models["stadium_wall_panel_models"].sha256 = "1".repeat(64)
			3:
				bad.graph.sha256 = "1".repeat(64)
			4:
				bad.graph.version = 3
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
				bad.instances[3].site = "BASE-R1-foreign"
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
			bad.instances[3].instance = "npc:AC-01:r1:BASE-R1-foreign"
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
	var returned: Dictionary = StadiumNpcVenues.definition("AC-01", 1)
	returned.instances[0].transform[9] = 99.0
	returned.models["stadium_wall_panel_models"].version = 99
	returned.land.stages.append("foreign")
	var normalized: Dictionary = StadiumNpcVenues.normalized(value)
	normalized.instances.clear()
	var decoded: Dictionary = StadiumNpcVenues.decode(baseline)
	decoded.valuation.total = 0
	var raw: Dictionary = StadiumNpcClubDefinitionV1.payload()
	raw.instances.clear()
	_check(
		(
			_json(StadiumNpcVenues.definition("AC-01", 1)) == baseline
			and (
				_json(StadiumNpcManifest.canonical_shape(StadiumNpcClubDefinitionV1.payload()))
				== baseline
			)
		),
		"nested mutations through every return path leave the published literal immutable"
	)
	# Local copied revisions exercise retention mechanics; this does not publish revision 2.
	var second: Dictionary = _relabel(value, "AC-01", 2)
	second.instances[0].transform[9] = -23.0
	var records: Dictionary = {"AC-01": {"1": value.duplicate(true), "2": second}}
	_check(
		not StadiumNpcVenues._definition_from(records, "AC-01", 2).is_empty(),
		"locally copied revision remains structurally independent"
	)
	second.models["stadium_wall_panel_models"].version = 3
	_check(
		_json(StadiumNpcVenues._definition_from(records, "AC-01", 1)) == baseline,
		"a later copied definition never remodels retained revision 1"
	)
	records["AC-01"]["1"] = second
	_check(
		(
			StadiumNpcVenues._definition_from(records, "AC-01", 1).is_empty()
			and StadiumNpcVenues.definition("AC-01", 3).is_empty()
			and not StadiumNpcVenues.valid_manifest(second)
		),
		"copied/relabeled revision keys cannot mint production authority"
	)


func _candidate_refusal(value: Dictionary) -> void:
	var authored: Dictionary = _authoring()
	_check(
		(
			_json(authored).to_utf8_buffer().size() == 17341
			and (
				_json(authored).sha256_text()
				== "bf99606b260904ff90eae18999bc3fe5695095a0351175bef14077c51036196d"
			)
		),
		"independent authoring bytes retain qualified provenance, not registry authority"
	)
	_check(
		(
			_json(authored)
			== FileAccess.get_file_as_string(
				"res://src/tests/fixtures/npc_club_authoring_source.json"
			)
		),
		"source-bound authoring payload retains exact independent bytes"
	)
	var envelope: Dictionary = StadiumClubOffsetFixtureStudy.capture(authored)
	_check(
		not envelope.is_empty() and StadiumClubOffsetFixtureStudy.valid(envelope),
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
	for message: String in StadiumNpcClubCorrespondence.verify(value, self):
		_check(false, message)


func _relabel(value: Dictionary, id: String, revision: int) -> Dictionary:
	var result: Dictionary = value.duplicate(true)
	var old_prefix: String = "npc:%s:r%d:" % [value.id, value.revision]
	var new_prefix: String = "npc:%s:r%d:" % [id, revision]
	result.id = id
	result.revision = revision
	for row: Dictionary in result.instances:
		row.instance = new_prefix + row.site
		if row.host != "field":
			row.host = new_prefix + row.host.trim_prefix(old_prefix)
	return result


func _json(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


func _authoring() -> Dictionary:
	var source: StadiumPropertyGeometry = StadiumClubOffsetVenueStudy.build(self)
	_check(source != null, "independent source assembly builds on identity host")
	if source == null:
		return {}
	var result: Dictionary = source.get_meta("candidate_venue").duplicate(true)
	source.free()
	return result
