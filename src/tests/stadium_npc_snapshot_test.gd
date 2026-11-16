extends Node
## Qualification-only raw envelopes and production refusal; no engine qualification claim.

const PUBLIC_KEYS: Dictionary = {
	"AY-01": "48d657ac6d22c3cb4616508f9692cc45614bd1042da21c2c8792846e98df7a94",
	"AE-01": "d1526c783d0a550ed7e22350707dbd531f2439b5df7a4f4cfc8cd07824d76b39",
	"AC-01": "0f51d1101f9ad03cfc26bfc059b734372c6c07fecc1703a70777555d6502e999"
}
var _failures: int = 0


func _ready() -> void:
	# Establish all three full P positive controls before any attack or refusal probe.
	var entries: Array[Dictionary] = []
	var fixtures: Array[Dictionary] = []
	for id: String in PUBLIC_KEYS:
		var entry: Dictionary = StadiumNpcSnapshot.raw_entry(id, 2)
		var bound: Dictionary = StadiumNpcSnapshot.raw_fixture(entry, _binding(id), _environment())
		_positive(id, entry, bound)
		entries.append(entry)
		fixtures.append(bound)
	for index in range(entries.size()):
		if entries[index].is_empty() or fixtures[index].is_empty():
			continue
		_schema_attacks(entries[index], fixtures[index])
		_binding_attacks(fixtures[index])
		_manifest_attacks(entries[index])
		_numeric_identity(fixtures[index])
		_copy_isolation(entries[index], fixtures[index])
		_production_controls(entries[index], fixtures[index])
	_constructor_refusals()
	_size_guard()
	_check(ContentDB.get_field(&"field.npc_venue") == null, "private field stays unregistered")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro NPC raw snapshots passed: exact declarations and closed production.")
	get_tree().quit(0 if _failures == 0 else 1)


func _positive(id: String, entry: Dictionary, bound: Dictionary) -> void:
	_check(not entry.is_empty() and not bound.is_empty(), "raw constructors " + id)
	if entry.is_empty() or bound.is_empty():
		return
	var name: String = {"AY-01": "yard", "AE-01": "expanded", "AC-01": "club"}[id]
	var public_bytes: String = FileAccess.get_file_as_string(
		"res://src/tests/fixtures/npc_%s_r2_public_canonical.json" % name)
	_check(entry.manifest_key == PUBLIC_KEYS[id], "full P frozen hash " + id)
	_check(_json(entry.manifest) == public_bytes, "full P exact bytes " + id)
	_check(public_bytes.sha256_text() == PUBLIC_KEYS[id], "independent P fixture identity " + id)
	_check(StadiumNpcDaylightEvidenceV2.matches(entry.manifest), "immutable day evidence " + id)
	_check(SeasonOwnership._keys(entry, StadiumNpcSnapshot.ENTRY_KEYS), "entry16 exact keys")
	_check(entry.version == 16 and bound.version == 17, "separate raw version namespace")
	_check(bound.binding.match_seed != bound.environment.seed, "independent environment stream")
	for value: Dictionary in [entry, bound]:
		_check(StadiumNpcSnapshot.raw_envelope_valid(value), "raw declaration accepted " + id)
		var canonical: Dictionary = StadiumNpcSnapshot.normalize_raw_envelope(value)
		var parsed: Variant = JSON.parse_string(_json(value))
		_check(_json(canonical) == _json(value), "normalization preserves canonical full bytes")
		_check(StadiumNpcSnapshot.raw_envelope_valid(parsed), "parsed raw roundtrip accepted")
		_check(_json(StadiumNpcSnapshot.normalize_raw_envelope(parsed)) == _json(value),
			"parsed raw roundtrip restores exact canonical bytes")
		_check(StadiumNpcSnapshot.raw_envelope_key(parsed) == _json(value).sha256_text(),
			"raw key hashes complete canonical envelope independently")
		_check(StadiumNpcSnapshot.raw_envelope_key(value) != value.manifest_key,
			"envelope identity is distinct from manifest P")
	for fixture_id: int in [0, 29, 30, 31]:
		var binding: Dictionary = _binding(id)
		var environment: Dictionary = _environment()
		binding.fixture = fixture_id
		environment.fixture = fixture_id
		_check(not StadiumNpcSnapshot.raw_fixture(entry, binding, environment).is_empty(),
			"non-neutral regular/semifinal raw bound " + str(fixture_id))
	var boundary: Dictionary = bound.duplicate(true)
	boundary.binding.owner_club = 5
	boundary.binding.batting_home = 5
	boundary.binding.away = 4
	boundary.binding.match_seed = 2147483647
	boundary.environment.seed = 0
	_check(StadiumNpcSnapshot.raw_envelope_valid(boundary), "inclusive bounded declarations")
	for revision: int in [1, 2]:
		var availability: Dictionary = StadiumNpcAvailability.record(id, revision)
		_check(not availability.production_runtime and not availability.selectable,
			"historical availability remains closed")


func _schema_attacks(entry: Dictionary, bound: Dictionary) -> void:
	for source: Dictionary in [entry, bound]:
		for field: String in source:
			var missing: Dictionary = source.duplicate(true)
			missing.erase(field)
			_reject(missing, "missing envelope key " + field)
			for wrong: Variant in [null, false, [], "invalid"]:
				var malformed: Dictionary = source.duplicate(true)
				malformed[field] = wrong
				_reject(malformed, "wrong envelope type " + field)
		var extra: Dictionary = source.duplicate(true)
		extra["selectable"] = true
		_reject(extra, "extra envelope authority flag")
	for container: String in ["binding", "environment"]:
		for field: String in bound[container]:
			var missing: Dictionary = bound.duplicate(true)
			missing[container].erase(field)
			_reject(missing, "missing " + container + "." + field)
			var malformed: Dictionary = bound.duplicate(true)
			malformed[container][field] = null
			_reject(malformed, "null " + container + "." + field)
		var extra: Dictionary = bound.duplicate(true)
		extra[container]["runtime_ready"] = true
		_reject(extra, "extra " + container + " key")
	for version: Variant in [15, 18, 16.5, true, "17", NAN, INF]:
		var bad: Dictionary = bound.duplicate(true)
		bad.version = version
		_reject(bad, "raw envelope version grammar")
	var swapped: Dictionary = bound.duplicate(true)
	swapped.version = 16
	_reject(swapped, "fixture fields on entry16")
	swapped = entry.duplicate(true)
	swapped.version = 17
	_reject(swapped, "missing fixture17 fields")
	swapped = entry.duplicate(true)
	swapped.authority = "npc-authored-v2"
	_reject(swapped, "authority family cannot be relabeled")
	for field: String in StadiumNpcManifest.KEYS:
		var bad: Dictionary = entry.duplicate(true)
		bad.manifest[field] = false
		_reject(bad, "raw manifest field type " + field)
	for container: String in ["envelope", "manifest", "binding", "environment"]:
		var bad: Dictionary = bound.duplicate(true)
		var target: Dictionary = bad if container == "envelope" else bad[container]
		var field: String = target.keys()[0]
		var original: Variant = target[field]
		target.erase(field)
		target[StringName(field)] = original
		_reject(bad, "raw keys must be JSON strings " + container)
	for field: String in entry.manifest.environment_certificates[0]:
		var missing: Dictionary = entry.duplicate(true)
		missing.manifest.environment_certificates[0].erase(field)
		_reject(missing, "missing certificate field " + field)
		var malformed: Dictionary = entry.duplicate(true)
		malformed.manifest.environment_certificates[0][field] = false
		_reject(malformed, "wrong raw certificate field type " + field)


func _binding_attacks(bound: Dictionary) -> void:
	var mutations: Dictionary = {
		"season_id": ["", "0".repeat(31), "0".repeat(33), "A".repeat(32), "g".repeat(32), 0],
		"assignment_key": ["", "0".repeat(63), "A".repeat(64), "g".repeat(64), 0],
		"owner_club": [-1, 0, 6, 1.5, true, "1", NAN, INF],
		"venue_id": ["AY-02", "", 1, false],
		"venue_revision": [0, 1, 3, 2.5, true, "2", NAN, INF],
		"fixture": [-1, 32, 33, 0.5, true, "0", NAN, INF],
		"away": [-1, 6, 1, 0.5, true, "0", NAN, INF],
		"batting_home": [-1, 0, 2, 6, 1.5, true, "1", NAN, INF],
		"neutral": [true, 0, 1, "false", []],
		"match_seed": [-1, 2147483648, 0.5, true, "101", NAN, INF],
		"field": ["field.starter_backyard", "", 0, false]
	}
	for field: String in mutations:
		for value: Variant in mutations[field]:
			var bad: Dictionary = bound.duplicate(true)
			bad.binding[field] = value
			_reject(bad, "raw binding type/range/identity " + field)
	var environment_mutations: Dictionary = {
		"version": [0, 2, 1.5, true, "1", NAN, INF],
		"seed": [-1, 2147483648, 0.5, true, "707", NAN, INF],
		"fixture": [-1, 1, 32, 0.5, true, "0", NAN, INF],
		"mode": ["night", "Day", "", 0, false],
		"profile": ["night-profile", 0, false]
	}
	for field: String in environment_mutations:
		for value: Variant in environment_mutations[field]:
			var bad: Dictionary = bound.duplicate(true)
			bad.environment[field] = value
			_reject(bad, "raw environment type/range/identity " + field)
	var neutral: Dictionary = bound.duplicate(true)
	neutral.binding.neutral = true
	neutral.binding.owner_club = -1
	neutral.binding.fixture = 32
	neutral.environment.fixture = 32
	_reject(neutral, "coherent neutral/finals still closed without independent finals authority")
	var swapped: Dictionary = bound.duplicate(true)
	var other: String = "AE-01" if bound.manifest.id == "AY-01" else "AY-01"
	swapped.manifest = StadiumNpcVenues.definition(other, 2)
	swapped.manifest_key = PUBLIC_KEYS[other]
	_reject(swapped, "a complete alternate public P still mismatches the bound venue")
	var changed: Dictionary = bound.duplicate(true)
	changed.binding.season_id = "a".repeat(32)
	changed.binding.assignment_key = "b".repeat(64)
	changed.environment.seed += 1
	_check(StadiumNpcSnapshot.raw_envelope_valid(changed), "raw grammar is not season authority")
	_check(StadiumNpcSnapshot.raw_envelope_key(changed) != StadiumNpcSnapshot.raw_envelope_key(bound),
		"raw hash binds changed season/assignment/environment declarations")
	_check(not StadiumNpcSnapshot.matches_fixture(changed, null, {}),
		"well-formed invented assignment cannot mint saved-season authority")


func _manifest_attacks(entry: Dictionary) -> void:
	var id: String = entry.manifest.id
	var other: String = "AE-01" if id == "AY-01" else "AY-01"
	var evidence: Dictionary = StadiumNpcDaylightEvidenceV2.record(id)
	for hash_value: Variant in ["", "0".repeat(64), "A".repeat(64), evidence.candidate_sha256,
		evidence.subject_sha256, PUBLIC_KEYS[other], false]:
		var bad: Dictionary = entry.duplicate(true)
		bad.manifest_key = hash_value
		_reject(bad, "manifest key must be this full public P")
	for edit in range(17):
		var bad: Dictionary = entry.duplicate(true)
		match edit:
			0:
				bad.manifest.environment_certificates = []
			1:
				bad.manifest.environment_certificates[0].assembly_sha256 = "0".repeat(64)
			2:
				bad.manifest.environment_certificates.append(
					bad.manifest.environment_certificates[0].duplicate(true))
			3:
				bad.manifest.environment_certificates[0].mode = "night"
				bad.manifest.environment_certificates[0].profile = "invented-night"
			4:
				bad.manifest.environment_certificates = StadiumNpcVenues.definition(
					other, 2).environment_certificates
			5:
				bad.manifest.environment_certificates[0].assembly_sha256 = PUBLIC_KEYS[id]
			6:
				bad.manifest.environment_certificates[0].version = 2
			7:
				bad.manifest.environment_certificates[0]["qualified"] = true
			8:
				bad.manifest.field = "field.starter_backyard"
			9:
				bad.manifest.assembly.version += 1
			10:
				bad.manifest.instances[0].transform[9] += 0.25
			11:
				bad.manifest.graph.sha256 = "1".repeat(64)
			12:
				bad.manifest.models.values()[0].version += 1
			13:
				bad.manifest.presentation.profile += "-forged"
			14:
				bad.manifest.valuation.copies += 1
				bad.manifest.valuation.total += 1
			15:
				bad.manifest.instances[1].host = bad.manifest.instances[0].instance
			16:
				bad.manifest.rules_version += 1
		if edit >= 8:
			bad.manifest.environment_certificates[0].assembly_sha256 = (
				StadiumNpcManifest.payload_key(bad.manifest))
		_rehash(bad)
		_reject(bad, "certificate/full-identity attack with recomputed key " + str(edit))
	for revision: int in [1, 3]:
		var historical: Dictionary = entry.duplicate(true)
		historical.manifest = StadiumNpcVenues.definition(id, revision)
		_rehash(historical)
		_reject(historical, "historical/future revisions cannot enter r2 raw family")
	var candidate: Dictionary = entry.duplicate(true)
	candidate.manifest = StadiumNpcCandidatesV2.definition(id)
	candidate.manifest_key = StadiumNpcCandidatesV2.key(candidate.manifest)
	_reject(candidate, "exact executed candidate C is not public P")
	var substituted: Dictionary = entry.duplicate(true)
	substituted.manifest = StadiumNpcVenues.definition(other, 2)
	_reject(substituted, "other public manifest cannot borrow P")


func _numeric_identity(bound: Dictionary) -> void:
	var numeric: Dictionary = bound.duplicate(true)
	numeric.version = 17.0
	numeric.manifest.revision = 2.0
	numeric.manifest.environment_certificates[0].version = 1.0
	for field: String in ["owner_club", "venue_revision", "fixture", "away", "batting_home",
		"match_seed"]:
		numeric.binding[field] = float(numeric.binding[field])
	for field: String in ["version", "seed", "fixture"]:
		numeric.environment[field] = float(numeric.environment[field])
	var component: int = -1
	var zero_component: int = -1
	for index in range(12):
		var number: float = bound.manifest.instances[0].transform[index]
		if component < 0 and absf(number) >= 0.5:
			component = index
		if zero_component < 0 and number == 0.0:
			zero_component = index
	_check(component >= 0 and zero_component >= 0, "numeric controls have proven bases")
	if component < 0 or zero_component < 0:
		return
	var original: float = bound.manifest.instances[0].transform[component]
	var spelling: float = original + 0.000000000001
	_check(var_to_bytes(spelling) != var_to_bytes(original)
		and PackedFloat32Array([spelling])[0] == PackedFloat32Array([original])[0],
		"raw float64 differs while exact scene float32 is unchanged")
	numeric.manifest.instances[0].transform[component] = spelling
	numeric.manifest.instances[0].transform[zero_component] = -0.0
	_check(StadiumNpcSnapshot.raw_envelope_key(numeric) == StadiumNpcSnapshot.raw_envelope_key(bound),
		"integer spelling, float32 and negative zero normalization preserve full identity")
	var adjacent_bytes: PackedByteArray = PackedFloat32Array([original]).to_byte_array()
	adjacent_bytes.encode_u32(0, adjacent_bytes.decode_u32(0) + 1)
	var adjacent: float = adjacent_bytes.decode_float(0)
	_check(adjacent != original and is_finite(adjacent), "adjacent float32 is a distinct scene pose")
	for value: Variant in [adjacent, NAN, INF, -INF, 1001, -1001, "1", true]:
		var bad: Dictionary = bound.duplicate(true)
		bad.manifest.instances[0].transform[component] = value
		_rehash(bad)
		_reject(bad, "raw transform non-number/nonfinite/range or exact float32 change")
	var zero_changed: Dictionary = bound.duplicate(true)
	zero_changed.manifest.instances[0].transform[zero_component] = 0.000000000001
	_rehash(zero_changed)
	_reject(zero_changed, "zero perturbation is a real float32 change")


func _copy_isolation(entry: Dictionary, bound: Dictionary) -> void:
	var before: String = _json(bound)
	var returned: Dictionary = StadiumNpcSnapshot.normalize_raw_envelope(bound)
	returned.binding.owner_club = 5
	returned.environment.seed += 1
	returned.manifest.instances[0].transform[9] += 10.0
	returned.manifest.environment_certificates[0].assembly_sha256 = "0".repeat(64)
	_check(_json(bound) == before, "normalization returns a deeply isolated copy")
	var binding: Dictionary = _binding(entry.manifest.id)
	var environment: Dictionary = _environment()
	var made: Dictionary = StadiumNpcSnapshot.raw_fixture(entry, binding, environment)
	binding.owner_club = 5
	environment.seed += 1
	_check(_json(made) == before, "fixture constructor retains no binding/environment aliases")
	var fresh: Dictionary = StadiumNpcSnapshot.raw_entry(entry.manifest.id, 2)
	_check(_json(fresh) == _json(entry), "raw entry construction does not mutate immutable registry")
	_check(StadiumNpcVenues.key(fresh.manifest) == PUBLIC_KEYS[entry.manifest.id],
		"deep mutations never alter full public P")


func _production_controls(entry: Dictionary, bound: Dictionary) -> void:
	var ledger: ClubAssetLedger = ClubAssetLedger.new()
	var legacy: Dictionary = StadiumLayoutSnapshot.capture(ledger, false)
	var season: SeasonState = SeasonState.create(42, false, true, true)
	for pick in range(4):
		season.choose_player(season.offers()[0])
	var request: MatchState = MatchState.create(season._make_team(1), season._make_team(2))
	var save: Dictionary = SeasonSave.snapshot(season)
	var path: String = "res://src/tests/fixtures/npc_r2_legacy_report_positive.json"
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(not legacy.is_empty() and StadiumLayoutSnapshot.valid(legacy)
		and StadiumLayoutSnapshot.matches(legacy, ledger), "legacy snapshot positive before injection")
	_check(PhysicalMatchRequest.capture(request) != null, "legacy request positive before injection")
	_check(SeasonSave._decode(save) != null, "legacy save positive before injection")
	_check(FileAccess.get_sha256(path) ==
		"f81affe8112489a09e26c3bd914ef6c0099c091e830e72b6c1347de666a35fad",
		"ordinary completed report positive is exact archived fixture")
	_check(PhysicalMatchReport.valid(report), "legacy report positive before injection")
	if legacy.is_empty() or PhysicalMatchRequest.capture(request) == null \
		or SeasonSave._decode(save) == null or not PhysicalMatchReport.valid(report):
		return
	var ledger_before: String = _json(ledger.to_data())
	var legacy_before: String = _json(legacy)
	var save_before: String = _json(save)
	var report_before: String = _json(report)
	for value: Dictionary in [entry, bound]:
		_check(not StadiumNpcSnapshot.valid(value)
			and StadiumNpcSnapshot.normalized(value).is_empty()
			and StadiumNpcSnapshot.key(value).is_empty(), "public NPC admission remains closed")
		_check(not StadiumNpcSnapshot.matches_fixture(value, season, {"id": 0, "home": 1,
			"away": 0, "neutral": false}), "raw declarations cannot match saved season")
		_check(not StadiumLayoutSnapshot.valid(value)
			and not StadiumLayoutSnapshot.valid(value, ledger.construction())
			and not StadiumLayoutSnapshot.matches(value, ledger)
			and StadiumLayoutSnapshot.ownership(value) == null
			and StadiumLayoutSnapshot.normalized(value).is_empty()
			and StadiumLayoutSnapshot.key(value).is_empty(), "human snapshot dispatch rejects raw NPC")
		_check(ClubAssetLedger.from_data(value, 0, []) == null, "raw NPC cannot mint human stock")
		request.stadium = value.duplicate(true)
		_check(PhysicalMatchRequest.capture(request) == null, "raw NPC request injection refused")
		for target: String in ["home_property", "venues", "npc_venue"]:
			var injected_save: Dictionary = save.duplicate(true)
			injected_save[target] = value.duplicate(true)
			_check(SeasonSave._decode(injected_save) == null, "NPC save injection refused " + target)
			injected_save.version = 60
			_check(SeasonSave._decode(injected_save) == null, "save60 remains closed " + target)
		for edit in range(3):
			var injected_report: Dictionary = report.duplicate(true)
			injected_report["property"] = value.duplicate(true)
			if edit >= 1:
				injected_report.version = 14
			if edit == 2:
				injected_report.field = StadiumNpcSnapshot.FIELD
				injected_report.resolver = "physical-ai-npc-venue-v1"
				injected_report["surfaces"] = []
			_check(not PhysicalMatchReport.valid(injected_report), "NPC report14 injection refused")
		var injected_snapshot: Dictionary = legacy.duplicate(true)
		injected_snapshot["manifest"] = value.manifest.duplicate(true)
		_check(not StadiumLayoutSnapshot.valid(injected_snapshot),
			"NPC legacy snapshot injection refused")
	_check(StadiumNpcSnapshot.capture(entry.manifest.id, 2).is_empty(), "public capture closed")
	_check(StadiumNpcSnapshot.fixture(entry, bound.binding, bound.environment).is_empty(),
		"public fixture construction closed")
	request.stadium = {}
	_check(PhysicalMatchRequest.capture(request) != null, "legacy request remains accepted")
	_check(_json(ledger.to_data()) == ledger_before and _json(legacy) == legacy_before
		and StadiumLayoutSnapshot.valid(legacy), "legacy snapshot and ownership preserved")
	_check(_json(save) == save_before and _json(SeasonSave.snapshot(season)) == save_before
		and SeasonSave._decode(save) != null, "legacy save preserved")
	_check(_json(report) == report_before and PhysicalMatchReport.valid(report),
		"complete legacy report remains accepted")


func _constructor_refusals() -> void:
	for id: Variant in ["", "AY-02", "AC-01-r2", 1, null, false]:
		_check(StadiumNpcSnapshot.raw_entry(id, 2).is_empty(), "constructor raw id refusal")
	for revision: Variant in [0, 1, 3, 2.5, "2", true, null, NAN, INF]:
		_check(StadiumNpcSnapshot.raw_entry("AY-01", revision).is_empty(),
			"constructor raw revision refusal")
	var entry: Dictionary = StadiumNpcSnapshot.raw_entry("AY-01", 2)
	var bound: Dictionary = StadiumNpcSnapshot.raw_fixture(entry, _binding("AY-01"), _environment())
	_check(StadiumNpcSnapshot.raw_fixture(bound, _binding("AY-01"), _environment()).is_empty(),
		"fixture17 cannot be rebound as entry16")
	for bad: Variant in [null, false, 17, "17", [], {}]:
		_reject(bad, "non-envelope raw input")
		_check(StadiumNpcSnapshot.raw_fixture(bad, _binding("AY-01"), _environment()).is_empty(),
			"raw fixture rejects invalid entry")
		_check(StadiumNpcSnapshot.raw_fixture(entry, bad, _environment()).is_empty(),
			"raw fixture rejects invalid binding")
		_check(StadiumNpcSnapshot.raw_fixture(entry, _binding("AY-01"), bad).is_empty(),
			"raw fixture rejects invalid environment")


func _size_guard() -> void:
	var value: Dictionary = StadiumNpcSnapshot.raw_entry("AY-01", 2)
	# A structurally valid raw shape can still exceed the serialized byte budget.
	# Four-byte Unicode and valid acyclic long hosts avoid assumptions about JSON escaping.
	# Every individual text value remains within the existing 128-codepoint bound.
	var pose: Array = value.manifest.instances[0].transform.duplicate()
	value.manifest.instances = []
	value.manifest.blueprints = []
	var previous: String = "field"
	for index in range(StadiumNpcManifest.MAX_INSTANCES):
		var site: String = "🙂".repeat(110) + "%03d" % index
		var item: String = "🚀".repeat(125) + "%03d" % index
		var identity: String = "npc:AY-01:r2:" + site
		value.manifest.instances.append({"instance": identity, "item": item,
			"site": site, "host": previous, "transform": pose.duplicate()})
		value.manifest.blueprints.append(item)
		previous = identity
	_check(StadiumNpcManifest._shape(value.manifest),
		"oversize control satisfies bounded manifest raw schema before byte validation")
	var raw_bytes: int = _json(value).to_utf8_buffer().size()
	_check(raw_bytes > StadiumNpcSnapshot.MAX_BYTES,
		"oversize refusal control really exceeds 256 KiB: %d bytes" % raw_bytes)
	_check(not StadiumNpcSnapshot._raw_shape(value), "256 KiB raw byte guard rejects before identity")
	_reject(value, "oversize raw envelope refused")
	value = StadiumNpcSnapshot.raw_entry("AY-01", 2)
	value.manifest.instances[0]["paid"] = 0
	_reject(value, "human paid inventory fields cannot enter authored instances")
	value = StadiumNpcSnapshot.raw_entry("AY-01", 2)
	value.manifest.presentation.options["self"] = value.manifest.presentation.options
	_reject(value, "recursive or nonempty option object refused before JSON serialization")
	value.manifest.presentation.options.clear()


func _binding(id: String) -> Dictionary:
	return {"season_id": "0123456789abcdef0123456789abcdef", "assignment_key": "a".repeat(64),
		"owner_club": 1, "venue_id": id, "venue_revision": 2, "fixture": 0,
		"away": 0, "batting_home": 1, "neutral": false, "match_seed": 101,
		"field": "field.npc_venue"}


func _environment() -> Dictionary:
	return {"version": 1, "seed": 707, "fixture": 0, "mode": "day", "profile": ""}


func _rehash(value: Dictionary) -> void:
	var manifest: Dictionary = StadiumNpcManifest.canonical_shape(value.manifest)
	value.manifest_key = _json(manifest).sha256_text()


func _reject(value: Variant, message: String) -> void:
	_check(not StadiumNpcSnapshot.raw_envelope_valid(value)
		and StadiumNpcSnapshot.normalize_raw_envelope(value).is_empty()
		and StadiumNpcSnapshot.raw_envelope_key(value).is_empty(), message)


func _json(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("NPC raw snapshot: " + message)
