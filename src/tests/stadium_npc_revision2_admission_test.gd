extends Node
## Data-only immutable admission. No runtime, fixture, season or ownership activation.

var _failures: int = 0


func _ready() -> void:
	var ledger: ClubAssetLedger = ClubAssetLedger.new_club()
	var ledger_before: String = _json(ledger.to_data())
	for id: String in ["AY-01", "AE-01", "AC-01"]:
		_admission(id)
		_attacks(id)
		_isolation(id)
	_provenance()
	_check(ledger_before == _json(ledger.to_data()), "unchanged complete human ledger")
	_check(ContentDB.get_field(&"field.npc_venue") == null, "private field stays unregistered")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro NPC r2 admission passed: immutable daylight data and closed production.")
	get_tree().quit(0 if _failures == 0 else 1)


func _admission(id: String) -> void:
	var value: Dictionary = StadiumNpcVenues.definition(id, 2)
	var candidate: Dictionary = StadiumNpcCandidatesV2.definition(id)
	var evidence: Dictionary = StadiumNpcDaylightEvidenceV2.record(id)
	_check(not value.is_empty(), "public revision 2 exists " + id)
	if value.is_empty():
		return
	var name: String = {"AY-01": "yard", "AE-01": "expanded", "AC-01": "club"}[id]
	var prefix: String = "res://src/tests/fixtures/npc_%s_r2_" % name
	_check(
		(
			FileAccess.get_sha256(
				"res://src/gameplay/stadium/stadium_npc_%s_candidate_v2.gd" % name
			)
			== evidence.candidate_literal_source_sha256
		),
		"evidence pins the actual executed literal source"
	)
	var candidate_bytes: String = FileAccess.get_file_as_string(prefix + "candidate_canonical.json")
	var public_bytes: String = FileAccess.get_file_as_string(prefix + "public_canonical.json")
	_check(_json(candidate) == candidate_bytes, "frozen complete candidate C bytes")
	_check(_json(value) == public_bytes, "frozen complete public P bytes")
	_check(StadiumNpcCandidatesV2.key(candidate) == evidence.candidate_sha256, "exact C")
	_check(StadiumNpcManifest.payload_key(value) == evidence.subject_sha256, "exact S")
	_check(
		StadiumNpcCandidatesV2.payload_key(candidate) == evidence.subject_sha256,
		"unchanged existing candidate S implementation"
	)
	var public_key: String = StadiumNpcVenues.key(value)
	_check(public_key == public_bytes.sha256_text(), "exact P")
	_check(
		(
			public_key != evidence.candidate_sha256
			and public_key != evidence.subject_sha256
			and evidence.candidate_sha256 != evidence.subject_sha256
		),
		"three distinct hash domains"
	)
	var subject: Dictionary = value.duplicate(true)
	var candidate_subject: Dictionary = candidate.duplicate(true)
	subject.erase("environment_certificates")
	candidate_subject.erase("environment_certificates")
	_check(_json(subject) == _json(candidate_subject), "exact subject bytes, not only hashes")
	var emptied: Dictionary = value.duplicate(true)
	emptied.environment_certificates = []
	_check(_json(emptied) == candidate_bytes, "empty public certificates restores exact C bytes")
	_check(
		(
			not StadiumNpcVenues.valid_manifest(candidate)
			and not StadiumNpcCandidatesV2.valid_manifest(value)
		),
		"mutual domain rejection"
	)
	_check(StadiumNpcVenues.decode(public_bytes) == value, "public canonical roundtrip")
	_numeric_identity(value, public_key)
	for field: String in StadiumNpcManifest.KEYS:
		var malformed: Dictionary = value.duplicate(true)
		malformed[field] = false
		_check(not StadiumNpcVenues.valid_manifest(malformed), "public raw type rejection " + field)

	_check(StadiumNpcDaylightEvidenceV2.matches(value), "exact completed evidence membership")
	_check(
		not StadiumLayoutSnapshot.valid(value) and not PhysicalMatchReport.valid(value),
		"public data is neither human snapshot nor physical report"
	)
	_check(ClubAssetLedger.from_data(value, 0, []) == null, "no human ownership import")
	_check(SeasonSave._decode(value) == null, "no save import")
	var future: Dictionary = value.duplicate(true)
	future.version = 60
	_check(SeasonSave._decode(future) == null, "save60 remains closed")
	for version: int in [16, 17]:
		future = value.duplicate(true)
		future.version = version
		_check(not StadiumLayoutSnapshot.valid(future), "production snapshot version stays closed")
	future = value.duplicate(true)
	future.version = 14
	_check(not PhysicalMatchReport.valid(future), "report14 remains closed")
	var season: SeasonState = SeasonState.create(42, false, true, true)
	for pick in range(4):
		season.choose_player(season.offers()[0])
	var request: MatchState = MatchState.create(season._make_team(1), season._make_team(2))
	_check(PhysicalMatchRequest.capture(request) != null, "ordinary request positive control")
	request.stadium = value
	_check(PhysicalMatchRequest.capture(request) == null, "public manifest cannot issue request")
	var save: Dictionary = SeasonSave.snapshot(season)
	_check(SeasonSave._decode(save) != null, "ordinary save positive control")
	var saved_before: String = _json(save)
	save["npc_venue"] = value
	_check(
		SeasonSave._decode(save) == null, "public NPC selection cannot enter existing season save"
	)
	_check(_json(SeasonSave.snapshot(season)) == saved_before, "NPC probes leave season unchanged")
	_check(
		SeasonState.field_for_fixture({"home": 1}).id != &"field.npc_venue",
		"ordinary away field selection remains unchanged"
	)
	_check(StadiumNpcVenues.definition(id, 3).is_empty(), "no implicit latest/future lookup")
	_production_controls(value)


func _numeric_identity(value: Dictionary, public_key: String) -> void:
	var component: int = -1
	var zero_component: int = -1
	for index in range(12):
		var number: float = value.instances[0].transform[index]
		if component < 0 and absf(number) >= 0.5:
			component = index
		if zero_component < 0 and number == 0.0:
			zero_component = index
	_check(
		component >= 0 and zero_component >= 0, "numeric controls require nonzero and zero bases"
	)
	if component < 0 or zero_component < 0:
		return
	var original: float = value.instances[0].transform[component]
	var spelling: float = original + 0.000000000001
	var same_float32: bool = PackedFloat32Array([spelling])[0] == PackedFloat32Array([original])[0]
	var distinct_float64: bool = var_to_bytes(spelling) != var_to_bytes(original)
	var context: String = (
		"%s component=%d original=%s spelling=%s"
		% [value.id, component, _json(original), _json(spelling)]
	)
	_check(
		distinct_float64 and _json(spelling) != _json(original) and same_float32,
		"independent raw-float64 difference and exact float32 equality: " + context
	)
	if not distinct_float64 or not same_float32:
		return
	var numeric: Dictionary = value.duplicate(true)
	numeric.revision = 2.0
	numeric.environment_certificates[0].version = 1.0
	numeric.instances[0].transform[component] = spelling
	_check(
		StadiumNpcVenues.key(numeric) == public_key,
		"raw integer and proven float32-equivalent spellings preserve identity: " + context
	)
	# One adjacent float32 bit pattern is a real scene change, not a serialization spelling.
	var adjacent_bytes: PackedByteArray = PackedFloat32Array([original]).to_byte_array()
	adjacent_bytes.encode_u32(0, adjacent_bytes.decode_u32(0) + 1)
	var adjacent: float = adjacent_bytes.decode_float(0)
	_check(
		(
			is_finite(adjacent)
			and adjacent != original
			and PackedFloat32Array([adjacent])[0] == adjacent
		),
		"adjacent-float32 negative control is independently distinct: " + context
	)
	for edit in range(2):
		var bad: Dictionary = value.duplicate(true)
		var changed_component: int = component if edit == 0 else zero_component
		bad.instances[0].transform[changed_component] = adjacent if edit == 0 else 0.000000000001
		var canonical: Dictionary = StadiumNpcManifest.canonical_shape(bad)
		_check(
			(
				not canonical.is_empty()
				and (
					canonical.instances[0].transform[changed_component]
					!= value.instances[0].transform[changed_component]
				)
			),
			"adjacent/zero perturbation remains a real canonical scene change " + str(edit)
		)
		_check(
			not StadiumNpcVenues.valid_manifest(bad),
			"real float32 change rejected without a tolerance " + str(edit)
		)
		bad.environment_certificates[0].assembly_sha256 = StadiumNpcManifest.payload_key(bad)
		_check(
			(
				not StadiumNpcVenues.valid_manifest(bad)
				and not StadiumNpcDaylightEvidenceV2.matches(bad)
			),
			"rehashing adjacent/zero changes cannot mint authority " + str(edit)
		)


func _production_controls(value: Dictionary) -> void:
	# Legacy constructor retains the pre-surface ordinary layout grammar.
	var ledger: ClubAssetLedger = ClubAssetLedger.new()
	var ledger_before: String = _json(ledger.to_data())
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(ledger, false)
	_check(
		(
			not snapshot.is_empty()
			and StadiumLayoutSnapshot.valid(snapshot)
			and StadiumLayoutSnapshot.matches(snapshot, ledger)
		),
		"genuine legacy snapshot positive control"
	)
	if snapshot.is_empty() or not StadiumLayoutSnapshot.valid(snapshot):
		return
	var snapshot_before: String = _json(snapshot)
	for edit in range(5):
		var bad: Dictionary = snapshot.duplicate(true)
		match edit:
			0:
				bad.layout = value.duplicate(true)
				bad.geometry = StadiumHomeLayout.geometry(bad.tier, bad.layout)
			1:
				bad["manifest"] = value.duplicate(true)
			2:
				bad["field"] = value.field
			3, 4:
				bad.version = 16 if edit == 3 else 17
				bad["authority"] = "npc-authored-v1"
				bad["manifest"] = value.duplicate(true)
				bad["manifest_key"] = StadiumNpcVenues.key(value)
		_check(
			(
				not StadiumLayoutSnapshot.valid(bad)
				and not StadiumLayoutSnapshot.valid(bad, ledger.construction())
				and not StadiumLayoutSnapshot.matches(bad, ledger)
			),
			"NPC injection into accepted legacy snapshot rejected " + str(edit)
		)
	_check(
		_json(snapshot) == snapshot_before and _json(ledger.to_data()) == ledger_before,
		"snapshot attacks preserve accepted source and human ownership"
	)
	var path: String = "res://src/tests/fixtures/npc_r2_legacy_report_positive.json"
	var artifacts: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(
			"res://src/tests/fixtures/npc_r2_completed_artifact_index.json"
		)
	)
	var original: String = (
		"builds/verification/20261008T170743141012Z/" + "physical-reports/physical-ai-29.json"
	)
	_check(
		FileAccess.get_sha256(path) == artifacts.files[original].sha256,
		"ordinary report positive fixture is exact archived completed-run evidence"
	)
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(PhysicalMatchReport.valid(report), "genuine completed ordinary report positive control")
	if not PhysicalMatchReport.valid(report):
		return
	var report_before: String = _json(report)
	for edit in range(4):
		var bad: Dictionary = report.duplicate(true)
		match edit:
			0:
				bad["property"] = value.duplicate(true)
			1:
				bad.field = value.field
			2:
				bad.version = 14
			3:
				bad.version = 14
				bad.resolver = "physical-ai-npc-venue-v1"
				bad.field = value.field
				bad["property"] = {
					"version": 17,
					"authority": "npc-authored-v1",
					"manifest": value.duplicate(true),
					"manifest_key": StadiumNpcVenues.key(value)
				}
				bad["surfaces"] = []
		_check(
			not PhysicalMatchReport.valid(bad),
			"NPC injection into accepted ordinary report rejected " + str(edit)
		)
	_check(
		_json(report) == report_before and PhysicalMatchReport.valid(report),
		"report attacks preserve accepted complete baseline"
	)


func _attacks(id: String) -> void:
	var value: Dictionary = StadiumNpcVenues.definition(id, 2)
	if value.is_empty():
		return
	for edit in range(16):
		var bad: Dictionary = value.duplicate(true)
		match edit:
			0:
				bad.environment_certificates = []
			1:
				bad.environment_certificates[0].assembly_sha256 = "0".repeat(64)
			2:
				bad.environment_certificates.append(bad.environment_certificates[0].duplicate(true))
			3:
				bad.environment_certificates[0].mode = "night"
				bad.environment_certificates[0].profile = "invented-night"
			4:
				var other: String = "AY-01" if id != "AY-01" else "AE-01"
				bad.environment_certificates = (
					StadiumNpcVenues.definition(other, 2).environment_certificates
				)
			5:
				bad.field = "field.starter_backyard"
			6:
				bad.assembly.version += 1
			7:
				bad.instances[0].transform[9] += 0.25
			8:
				bad.graph.sha256 = "1".repeat(64)
			9:
				bad.models.values()[0].version += 1
			10:
				bad.presentation.profile += "-forged"
			11:
				bad.valuation.copies += 1
				bad.valuation.total += 1
			12:
				bad.instances[1].host = bad.instances[0].instance
			13:
				bad.rules_version += 1
			14:
				bad.instances[0].transform[0] = NAN
			15:
				bad.revision = 2.5
		# Correctly rehashing a changed subject cannot mint a new registered literal.
		if edit >= 5 and edit <= 13:
			bad.environment_certificates[0].assembly_sha256 = StadiumNpcManifest.payload_key(bad)
		_check(not StadiumNpcVenues.valid_manifest(bad), "manifest/certificate attack " + str(edit))
		_check(
			not StadiumNpcDaylightEvidenceV2.matches(bad), "evidence rejects attack " + str(edit)
		)
	for edit in range(10):
		var evidence: Dictionary = StadiumNpcDaylightEvidenceV2.record(id)
		match edit:
			0:
				evidence.subject_sha256 = "0".repeat(64)
			1:
				evidence.candidate_sha256 = "1".repeat(64)
			2:
				evidence.packet.execution_source_sha256 = "2".repeat(64)
			3:
				evidence.packet.scope = "r1-transfer"
			4:
				evidence.packet.daylight.run = evidence.packet.headless.run
			5:
				evidence.packet.candidate_v2 = false
			6:
				evidence.packet.daylight.scene_logs.clear()
			7:
				evidence.packet.artifact_index_sha256 = "3".repeat(64)
			8:
				evidence.candidate_literal_source_sha256 = "4".repeat(64)
			9:
				evidence.packet.daylight_scene = "res://wrong.tscn"
		_check(
			not StadiumNpcDaylightEvidenceV2.accepts(value, evidence),
			"forged evidence membership rejected " + str(edit)
		)


func _isolation(id: String) -> void:
	var value: Dictionary = StadiumNpcVenues.definition(id, 2)
	if value.is_empty():
		return
	var before: String = _json(value)
	var historical: String = _json(StadiumNpcVenues.definition(id, 1))
	value.instances[0].transform[9] += 1.0
	value.environment_certificates.clear()
	_check(_json(StadiumNpcVenues.definition(id, 2)) == before, "public nested copy isolation")
	_check(_json(StadiumNpcVenues.definition(id, 1)) == historical, "historical revision isolation")
	var evidence: Dictionary = StadiumNpcDaylightEvidenceV2.record(id)
	evidence.packet.headless.run = "forged"
	_check(
		StadiumNpcDaylightEvidenceV2.record(id).packet.headless.run != "forged",
		"nested evidence copy isolation"
	)
	for revision: int in [1, 2]:
		var availability: Dictionary = StadiumNpcAvailability.record(id, revision)
		_check(
			(
				availability.data_admitted
				and not availability.production_runtime
				and not availability.selectable
			),
			"data-only availability for exact historical revision"
		)
		availability.production_runtime = true
		availability.selectable = true
		_check(
			not StadiumNpcAvailability.record(id, revision).selectable,
			"availability copy isolation"
		)
	_check(StadiumNpcAvailability.record(id, 3).is_empty(), "unknown availability fails closed")
	_check(
		_json(StadiumNpcVenues.definition(id, 2)) == before,
		"availability never enters manifest hash"
	)
	_check(StadiumNpcDaylightEvidenceV2.record(id, 1).is_empty(), "no borrowed r1 evidence")


func _provenance() -> void:
	var packet: Dictionary = StadiumNpcDaylightEvidenceV2.record("AY-01").packet
	var source_path: String = "res://src/tests/fixtures/npc_r2_executed_source_index.json"
	var artifact_path: String = "res://src/tests/fixtures/npc_r2_completed_artifact_index.json"
	_check(
		FileAccess.get_sha256(source_path) == packet.source_index_sha256,
		"immutable executed source packet index"
	)
	_check(
		FileAccess.get_sha256(artifact_path) == packet.artifact_index_sha256,
		"immutable actual completed-run artifact index"
	)
	var artifacts: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(artifact_path))
	for kind: String in ["headless", "daylight"]:
		var run: Dictionary = packet[kind]
		var prefix: String = "builds/verification/%s/" % run.run
		for file: String in ["summary", "checkpoint"]:
			_check(
				artifacts.files[prefix + file + ".json"].sha256 == run[file + "_sha256"],
				"exact completed packet hash membership"
			)
		for file: String in run.scene_logs:
			_check(
				artifacts.files[prefix + file].sha256 == run.scene_logs[file],
				"exact executed scene log hash membership"
			)
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source_path))
	_check(
		source.execution_source_sha256 == packet.execution_source_sha256,
		"source packet binds original completed execution source, never admission self-reference"
	)
	for path: String in source.files:
		# Only the approved helpers and obsolete registry absence assertions change.
		if (
			path
			in [
				"src/gameplay/stadium/stadium_npc_manifest.gd",
				"src/gameplay/stadium/stadium_npc_venues.gd",
				"src/tests/stadium_npc_candidate_v2_test.gd",
				"src/tests/stadium_npc_venues_test.gd",
				"src/tests/stadium_npc_yard_definition_test.gd",
				"src/tests/stadium_npc_expanded_definition_test.gd",
				"src/tests/stadium_npc_club_definition_test.gd",
				"tools/verify.py",
				"tools/verification_checkpoint.py"
			]
		):
			continue
		_check(
			FileAccess.get_sha256("res://" + path) == source.files[path],
			"executed source and all historical files unchanged " + path
		)
	_check(
		FileAccess.get_sha256(packet.daylight_scene) == packet.daylight_scene_sha256,
		"exact candidate_v2 scene source"
	)
	_check(
		FileAccess.get_sha256(packet.daylight_runtime) == packet.daylight_runtime_sha256,
		"exact installed candidate runtime source"
	)


func _json(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
