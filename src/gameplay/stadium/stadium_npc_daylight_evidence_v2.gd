class_name StadiumNpcDaylightEvidenceV2
extends RefCounted
## Immutable completed-run membership. Hashes alone never grant public authority.
## No FileAccess, current-source capture, candidate generator or registry recursion.


static func record(id: String, revision: int = 2) -> Dictionary:
	if revision != 2:
		return {}
	var records: Dictionary = {
		"AY-01":
		{
			"id": "AY-01",
			"revision": 2,
			"field": "field.npc_venue",
			"subject_sha256": "927c36635239e92d5ac29c3c5f7fa1801d9b4a163769e8cb0fe1f6f46442ac20",
			"candidate_sha256": "5805567786857ff45db89285fcf76fa5b878a77692eaa47cb133ac381aabb5e1",
			"candidate_literal_source_sha256":
			"de7fcc16cf58bebf17b2a07a9468d6c15c65e943cb7b7715a2d67bbb3b5a90de"
		},
		"AE-01":
		{
			"id": "AE-01",
			"revision": 2,
			"field": "field.npc_venue",
			"subject_sha256": "23fb72a4050989a093d833e543eccd2fa0cf894862be7577ae610956dffe2390",
			"candidate_sha256": "9f38f59aeeceea10bcead9a6887291d9df0a60085f327b30a2bc287e39f280d5",
			"candidate_literal_source_sha256":
			"222abb41fd51d922a42e4c08be8aa8b5157cfce322fb4bb9a1974d4edf84422c"
		},
		"AC-01":
		{
			"id": "AC-01",
			"revision": 2,
			"field": "field.npc_venue",
			"subject_sha256": "8debdc42683650f5921845b9af5d794dfbc1c04d136cbde39a9bd98711f13841",
			"candidate_sha256": "5cedf5df70c33240704da26cf63c10f277e544349ead4a6098b1c5f6c133ec7d",
			"candidate_literal_source_sha256":
			"262389ffd2176784de95567481dfa7ba2e5894abfcfbad2fe92eeb4c8978dc21"
		}
	}
	if not records.has(id):
		return {}
	var result: Dictionary = records[id].duplicate(true)
	result["packet"] = _packet()
	return result


static func matches(value: Variant) -> bool:
	var canonical: Dictionary = StadiumNpcManifest.canonical_shape(value)
	if canonical.is_empty():
		return false
	return accepts(canonical, record(canonical.id, int(canonical.revision)))


static func accepts(value: Variant, evidence: Variant) -> bool:
	var canonical: Dictionary = StadiumNpcManifest.canonical_shape(value)
	if canonical.is_empty() or not evidence is Dictionary:
		return false
	var expected: Dictionary = record(canonical.id, int(canonical.revision))
	if (
		expected.is_empty()
		or JSON.stringify(evidence, "", true, true) != JSON.stringify(expected, "", true, true)
	):
		return false
	var certificate: Array = [
		{"mode": "day", "profile": "", "version": 1, "assembly_sha256": expected.subject_sha256}
	]
	if canonical.field != expected.field or canonical.environment_certificates != certificate:
		return false
	if StadiumNpcManifest.payload_key(canonical) != expected.subject_sha256:
		return false
	canonical.environment_certificates = []
	return JSON.stringify(canonical, "", true, true).sha256_text() == expected.candidate_sha256


static func _packet() -> Dictionary:
	return {
		"execution_source_sha256":
		"969372b7fe6156ae7885bba027350fb205966fc8cd7ade552a0aa55221eb2cf1",
		"retained_source_commit": "335594142d736f986cdaf0fa42ea07e717276bbb",
		"execution_base_commit": "fa789a7b34e8c2cc05605aa2557c36ea82848e1c",
		"engine": "4.7.2.stable.official.ed1daf0bf",
		"scope": "independent_complete_layout_candidate_v2_daylight",
		"candidate_v2": true,
		"subject_binding":
		(
			"executed source + exact candidate canonical fixture + candidate_v2 scene/runtime; "
			+ "subject was not logged"
		),
		"daylight_scene": "res://src/tests/stadium_npc_candidate_v2_daylight_test.tscn",
		"daylight_scene_sha256": "ce8e676e3196588454700810946f76b880425ce58490175ea8c5a6e0eb29e9a5",
		"daylight_runtime": "res://src/presentation/stadium/stadium_npc_candidate_runtime_v2.gd",
		"daylight_runtime_sha256":
		"9f9d49929b9bfc32bfd4c671809fbb4cff38e57fefd573e81020735ad0308d6d",
		"source_index_sha256": "0f3bbef04217c2709f51113fccad1949e879c668a64c0b6661b258ae1a89e9ba",
		"artifact_index_sha256": "f83742e6f5abf58d2621927556b47a399faf37e948b7417f19f778f937425705",
		"comparator_sha256": "b9319fbe4b212e628089126d73635126c37d7c511cabfd6171d7e7293cfbdc0c",
		"comparison_receipt_sha256":
		"44643bd51cbc247e8f9f5712d60424dadafb362ce569c92892d0742953501f60",
		"comparison_log_sha256": "a0eba81084b601ec8a55324f2a29a09245b0bc07d531a2b5e963d2fdde705395",
		"sample_positions": 46080,
		"qualifying_pixel_proofs": 318,
		"diagnostic_baseline_proofs": 8,
		"ground_only_partial_rim_cases": 18,
		"ground_only_partial_rim_hits": 66,
		"diameter_policy": "nominal three content pixels before ground depth clipping",
		"minimum_contrast": 0.03,
		"static_cross_world_transfer": false,
		"night": false,
		"production_runtime": false,
		"headless":
		{
			"run": "20261008T170743141012Z",
			"summary_sha256": "c6c793f221d355e6bd07f199d597e897d448de9f0f8cc5bacb72a8394434bf60",
			"checkpoint_sha256": "5428695c4aeabfa9aba6795773e6030ea06b99e20b2c7e8b5c17d59c8878a0b3",
			"steps": 23,
			"scene_logs":
			{
				"stadium-npc-candidate-v2-data.log":
				"bfe70756ce4cd7fe4101c39b69450beadb5f10bbb7ea1c767806367dd8b70ad8",
				"stadium-npc-candidate-v2-games.log":
				"75a5660cc708ed254aec98bc54c9bdf6b20c7a3432ba372ad6e5214f1fc42785",
				"stadium-npc-candidate-v2-presentation.log":
				"647d6a132f302752daf0f2d19fe82181cfd871ac4cf337c78f539ec803a2e10e",
				"stadium-npc-candidate-v2-runtime.log":
				"167f03bed7c1892b05d5c3d81c101995c9b51591d2edf4f3d0ac5e6126d73d39"
			}
		},
		"daylight":
		{
			"run": "20261008T174510851875Z",
			"summary_sha256": "072822fac0f0e708ea972bc1b2633d5e42654d8be62f675b4a431683a621df9e",
			"checkpoint_sha256": "f307c882443e1264948f9c14dd34bbaa12c34d0475df81cd9d8bcbc4ca0877a7",
			"steps": 9,
			"scene_logs":
			{
				"stadium-npc-candidate-v2-daylight.log":
				"a39ab2950762d85ffe73862943958724783c882de3529eadbef5bd14e32cbb50"
			}
		}
	}
