extends Node
## Retained operands plus synthetic shape controls. No game or historical-source admission.

const ORIGIN_SOURCE: String = "a1255d38c2b0e6b5580f595fb37c4aa485c300eb45043ff0656a25c8ba044888"
const INPUT_SHA: String = "c5609765f2c0d322549a873b1c1b75c7797cec36601b42c92ddae91aa90004a6"
const MANIFEST_SHA: String = "f82cc9d1892d96c16056da1201ae03c4b92bac3994292bb48101c47ea17646dc"
var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	var input: Dictionary = _load("--pool-party-report-rejection-input=", INPUT_SHA, 554161)
	var manifest: Dictionary = _load("--pool-party-report-source-manifest=", MANIFEST_SHA)
	if not input.is_empty() and not manifest.is_empty():
		_check(manifest.get("runtime_sha256") == ORIGIN_SOURCE
			and input.get("execution") == manifest.get("execution_sha256"),
			"retained operands identify the pinned original source and execution")
		_check(input.get("schema") == "POOL-PARTY-ACTUAL-CAPTURE-REJECTION-v1"
			and input.get("first_site") == "pool_contacts._pool:L38:term9 not "
			+ "StadiumPoolPartyEnvironmentV1._same_profile( "
			+ "value.geometry, geometry(value.source_sha256))",
			"retained first failure is exact native versus parsed geometry comparison")
		_retained(input.operands)
	_current_shapes()
	print("POOL_PARTY_REPORT_CANONICAL checks=%d failures=%d fresh_games=0 current_reports=0" % [
		_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _retained(operands: Dictionary) -> void:
	_check(PhysicalMatchReport.valid(operands.core7), "unchanged retained core7 balances")
	var current_source: String = StadiumPoolPartyAssetIntegrity.source_sha256()
	_check(current_source.length() == 64 and current_source != ORIGIN_SOURCE,
		"fresh source remains distinct from the original game source")
	for key: String in ["report22", "decoded_report22"]:
		var report: Dictionary = operands[key]
		var before: String = _json(report)
		_check(report.pool.source_sha256 == ORIGIN_SOURCE
			and report.pool.geometry.source_sha256 == ORIGIN_SOURCE,
			key + " keeps original source authority")
		_check(_historical_report_envelope(report), key + " retains every report22 envelope guard")
		_check(_historical_pool_envelope(report.pool, report.plays),
			key + " retains every Pool envelope guard under the authenticated original source")
		_check(report.plays.size() == 150 and report.away_runs == 7 and report.home_runs == 6
			and report.pool.water_commits.is_empty() and report.pool.water_outcomes.is_empty(),
			key + " retains actual 150-play 7-6 game with zero water receipts")
		_check(PhysicalMatchReport.valid(StadiumPoolPartyPublicReport._core(report))
			and ClubCareer.same(StadiumPoolPartyPublicReport._core(report), operands.core7),
			key + " unwraps to the unchanged genuine core7")
		_check(not StadiumPoolPartyPublicContacts._pool(report.pool, report.plays)
			and not StadiumPoolPartyPublicReport.valid(report)
			and not PhysicalMatchReport.valid(report),
			key + " cannot pass current-source authority as a historical report")
		var geometry: Variant = report.pool.geometry
		for pass_index: int in range(3):
			_check(StadiumPoolPartyPublicContacts._geometry_matches(geometry, ORIGIN_SOURCE),
				key + " exact historical geometry canonical pass %d" % pass_index)
			geometry = JSON.parse_string(_json(geometry))
		var reference: Dictionary = StadiumPoolPartyPublicContacts._reference(report.property)
		_check(not reference.is_empty(), key + " reference constructs from unchanged property")
		if not reference.is_empty():
			_check(StadiumPoolPartyPublicContacts._rows(
				report.surfaces, report.plays, reference, report.pool),
				key + " retained contact rows and outcomes keep their original semantics")
			_check(StadiumNpcPublicContacts._provenance(report.yard, reference),
				key + " retained yard provenance matches exact reference")
		_check(_json(report) == before, key + " is never rewritten for the new source")


func _historical_report_envelope(value: Variant) -> bool:
	# Test-only original report22 envelope. Evidence components are checked separately above.
	return value is Dictionary \
		and SeasonOwnership._whole(value.get("version"), 22, 22) \
		and StadiumNpcSnapshot._json_types(value) \
		and _json(value).to_utf8_buffer().size() <= StadiumPoolPartyPublicReport.MAX_BYTES \
		and value.get("resolver") is String \
		and value.resolver == StadiumPoolPartyPublicReport.RESOLVER \
		and StadiumNpcSnapshot.valid(value.get("property")) \
		and value.property.version == StadiumNpcSnapshot.POOL_PARTY_FINAL_FIXTURE_VERSION \
		and StadiumPoolPartyPublicReport.supports_definition(
			value.property.manifest.id, value.property.manifest.revision) \
		and StadiumNpcPublicContacts.matches(value.property) \
		and value.get("field") is String and value.field == StadiumNpcSnapshot.FIELD \
		and SeasonOwnership._whole(value.get("seed"), 0, 2147483647) \
		and value.seed == value.property.binding.match_seed \
		and PhysicalMatchReport.valid(StadiumPoolPartyPublicReport._core(value))


func _historical_pool_envelope(value: Variant, plays: Array) -> bool:
	# Only this fixture authenticates the pinned historical source. Public admission is unchanged.
	# The actual retained pair has zero receipts; no per-receipt predicate is skipped for it.
	return StadiumNpcSnapshot._keys(value, ["version", "copy", "pose", "geometry",
		"source_sha256", "water_commits", "water_outcomes"]) \
		and SeasonOwnership._whole(value.version, 1, 1) \
		and value.copy is String and value.copy == StadiumPoolPartyPublicContacts.COPY \
		and StadiumNpcManifest._hash(value.source_sha256) \
		and value.source_sha256 == ORIGIN_SOURCE \
		and StadiumNpcSnapshot._json_types(value) \
		and StadiumPoolPartyEnvironmentV1._same_profile(value.pose, [12, 0, 18, 0]) \
		and StadiumPoolPartyPublicContacts._geometry_matches(value.geometry, value.source_sha256) \
		and value.water_commits is Array and value.water_outcomes is Array \
		and value.water_commits.size() == value.water_outcomes.size() \
		and value.water_commits.size() <= plays.size() and plays.size() <= 9999 \
		and value.water_commits.is_empty() and value.water_outcomes.is_empty()


func _current_shapes() -> void:
	var source: String = StadiumPoolPartyAssetIntegrity.source_sha256()
	var evidence: Dictionary = {"version": 1, "copy": StadiumPoolPartyPublicContacts.COPY,
		"pose": [12, 0, 18, 0], "geometry": StadiumPoolPartyPublicContacts.geometry(source),
		"source_sha256": source, "water_commits": [], "water_outcomes": []}
	var native: Dictionary = evidence.duplicate(true)
	var parsed_geometry: Variant = JSON.parse_string(_json(evidence.geometry))
	_check(not StadiumPoolPartyEnvironmentV1._same_profile(evidence.geometry, parsed_geometry),
		"exact native descriptor reproduces the former parsed-float rejection")
	for pass_index: int in range(4):
		_check(StadiumPoolPartyPublicContacts._pool(evidence, [])
			and StadiumPoolPartyPublicContacts._geometry_matches(evidence.geometry, source),
			"native then repeated parsed current-source shape pass %d" % pass_index)
		_negatives(evidence, source)
		evidence = JSON.parse_string(_json(evidence))
	_check(ClubCareer.same(native.geometry, evidence.geometry),
		"strict canonical comparison agrees with the established Pool report JSON form")


func _negatives(evidence: Dictionary, source: String) -> void:
	for edit: int in range(13):
		var changed: Dictionary = evidence.duplicate(true)
		match edit:
			0: changed.geometry.vertices_xz[0][0] += 0.000000000001
			1: changed.geometry.vertices_xz[0][0] = true
			2: changed.geometry.version = true
			3: changed.geometry.physics_qualified = 0
			4: changed.geometry.vertices_xz[0].append(0)
			5: changed.geometry.vertices_xz.pop_back()
			6: changed.geometry["extra"] = 0
			7: changed.geometry.erase("segments")
			8: changed.geometry.vertices_xz[0][0] = "1.9500000476837158"
			9: changed.geometry.kind = &"WATER_ANALYTIC_POLYGON_PRISM_V2"
			10: changed.geometry.vertices_xz[0][0] = NAN
			11: changed.geometry.source_sha256 = "0".repeat(64)
			12: changed.geometry = []
		_check(not StadiumPoolPartyPublicContacts._geometry_matches(changed.geometry, source)
			and not StadiumPoolPartyPublicContacts._pool(changed, []),
			"wrong float, raw type, non-finite, source, or shape refuses edit %d" % edit)


func _load(prefix: String, expected: String, exact_bytes: int = -1) -> Dictionary:
	var path: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			path = argument.trim_prefix(prefix)
	if path.is_empty() or not FileAccess.file_exists(path):
		_check(false, "required retained artifact missing: " + prefix)
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_check(false, "retained artifact cannot be opened: " + prefix)
		return {}
	var size: int = file.get_length()
	if size > 8 * 1024 * 1024 or (exact_bytes >= 0 and size != exact_bytes) \
		or FileAccess.get_sha256(path) != expected:
		file.close()
		_check(false, "retained artifact bytes/hash do not match: " + prefix)
		return {}
	var value: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	_check(value is Dictionary, "pinned retained artifact parses: " + prefix)
	return value if value is Dictionary else {}


func _json(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("POOL_PARTY_REPORT_CANONICAL " + label)
