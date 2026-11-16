class_name StadiumNpcYardThreeCandidateV1
extends RefCounted
## Immutable AY-03/r1 candidate data only. No public definition or environment authority.
## Exact literal from the qualified eight-copy authoring source, never a current factory lookup.

const SHA256: String = "4ce7a2b451994bd64a0173c80bb30dc001f4229b6f6d1e5383b253012415e652"
const SUBJECT_SHA256: String = "1ba39621a6b93ce887360cf04cd38ecbfd19a36cba06e754f94e9fb459d423d7"


static func payload() -> Dictionary:
	return {
		"assembly": {
			"id": "AY-03-dormant-backyard-r1",
			"version": 1
		},
		"blueprints": [
			"ST-037",
			"ST-080"
		],
		"catalog": {
			"sha256": "5210c3c47688b06faa35a50ec211f65de0a881debc5d7567a4c0e2abe6df204f",
			"version": 1
		},
		"environment_certificates": [],
		"field": "field.npc_venue",
		"graph": {
			"id": "PERIM-BACKYARD-STRAIGHT-BX1-v1",
			"sha256": "93859ee6fb839243e6ac471b45027547e4a47e09e7e57bc957f19c7410b542e9",
			"version": 1
		},
		"id": "AY-03",
		"instances": [
			{
				"instance": "npc:AY-03:r1:SC-L1",
				"item": "ST-080",
				"site": "SC-L1",
				"host": "field",
				"transform": [
					0.0,
					0.0,
					-1.0,
					0.0,
					1.0,
					0.0,
					1.0,
					0.0,
					0.0,
					-24.0,
					0.0,
					10.0
				]
			},
			{
				"instance": "npc:AY-03:r1:SC-L2",
				"item": "ST-080",
				"site": "SC-L2",
				"host": "field",
				"transform": [
					0.0,
					0.0,
					-1.0,
					0.0,
					1.0,
					0.0,
					1.0,
					0.0,
					0.0,
					-24.0,
					0.0,
					12.0
				]
			},
			{
				"instance": "npc:AY-03:r1:SC-R1",
				"item": "ST-080",
				"site": "SC-R1",
				"host": "field",
				"transform": [
					0.0,
					0.0,
					1.0,
					0.0,
					1.0,
					0.0,
					-1.0,
					0.0,
					0.0,
					24.0,
					0.0,
					10.0
				]
			},
			{
				"instance": "npc:AY-03:r1:SC-R2",
				"item": "ST-080",
				"site": "SC-R2",
				"host": "field",
				"transform": [
					0.0,
					0.0,
					1.0,
					0.0,
					1.0,
					0.0,
					-1.0,
					0.0,
					0.0,
					24.0,
					0.0,
					12.0
				]
			},
			{
				"instance": "npc:AY-03:r1:YLIGHT-FL",
				"item": "ST-037",
				"site": "YLIGHT-FL",
				"host": "field",
				"transform": [
					0.30477574467658997,
					0.0,
					-0.952424168586731,
					0.0,
					1.0,
					0.0,
					0.952424168586731,
					0.0,
					0.30477574467658997,
					-25.0,
					0.0,
					0.0
				]
			},
			{
				"instance": "npc:AY-03:r1:YLIGHT-FR",
				"item": "ST-037",
				"site": "YLIGHT-FR",
				"host": "field",
				"transform": [
					0.30477574467658997,
					0.0,
					0.952424168586731,
					0.0,
					1.0,
					0.0,
					-0.952424168586731,
					0.0,
					0.30477574467658997,
					25.0,
					0.0,
					0.0
				]
			},
			{
				"instance": "npc:AY-03:r1:YLIGHT-RL",
				"item": "ST-037",
				"site": "YLIGHT-RL",
				"host": "field",
				"transform": [
					-0.26962995529174805,
					0.0,
					-0.9629639983177185,
					0.0,
					1.0,
					0.0,
					0.9629639983177185,
					0.0,
					-0.26962995529174805,
					-25.0,
					0.0,
					25.0
				]
			},
			{
				"instance": "npc:AY-03:r1:YLIGHT-RR",
				"item": "ST-037",
				"site": "YLIGHT-RR",
				"host": "field",
				"transform": [
					-0.26962995529174805,
					0.0,
					0.9629639983177185,
					0.0,
					1.0,
					0.0,
					-0.9629639983177185,
					0.0,
					-0.26962995529174805,
					25.0,
					0.0,
					25.0
				]
			}
		],
		"land": {
			"stages": [],
			"tier": "backyard",
			"version": 1
		},
		"live_units": 0,
		"models": {
			"free-template": {
				"sha256": "779ce82a8bc9ff872dc3e1cf5c50552f5cf7eaa5914e5857d9459904cbaf89af",
				"version": 1
			},
			"spectator-chair": {
				"sha256": "56f1ed7ceb4576b6887a48ad785209bf964965e8eb9bbcd708345a8ee4aa03eb",
				"version": 1
			},
			"template-boundary": {
				"sha256": "5b7e8fe60a44b875e5e0e66ce2fe3d8a995e4482c8de79dedbaabcb9adc0d88a",
				"version": 1
			},
			"yard-light": {
				"version": 2,
				"sha256": "28e58ea8f4dceac92466f4510a97fb28649b9694b1149f98ddf8503aa600d1b9"
			},
			"light-parts": {
				"version": 1,
				"sha256": "c9e92051b1627a3043ebf6cb802940a24570851676cd8718ae1c475bda964138"
			},
			"field-semantics": {
				"version": 1,
				"sha256": "39cf09ce92b00c8c0d784f5e738623b810b512a12c3b3c9294a5133b33f413d2"
			},
			"free-receiver": {
				"version": 1,
				"sha256": "79a51e1fd14077d0ab1be26a61bed531124e9c4349806af9bc9a0321efb7464d"
			}
		},
		"presentation": {
			"profile": "AY-03-default-backyard-v1",
			"options": {}
		},
		"revision": 1,
		"routing_version": 1,
		"rules_version": 1,
		"shape": "straight",
		"surface_version": 1,
		"tier": "backyard",
		"valuation": {
			"blueprints": 450,
			"copies": 420,
			"land": 0,
			"price_sha256": "5210c3c47688b06faa35a50ec211f65de0a881debc5d7567a4c0e2abe6df204f",
			"price_version": 1,
			"total": 870
		},
		"version": 1
	}


static func definition(id: String = "AY-03", revision: int = 1) -> Dictionary:
	if id != "AY-03" or revision != 1:
		return {}
	return StadiumNpcManifest.canonical_shape(payload())


static func normalized(value: Variant) -> Dictionary:
	return StadiumNpcVenues._normalized_against(value, definition())


static func valid_manifest(value: Variant) -> bool:
	return not normalized(value).is_empty()


static func key(value: Variant) -> String:
	var canonical: Dictionary = normalized(value)
	return "" if canonical.is_empty() else JSON.stringify(canonical, "", true, true).sha256_text()


static func decode(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > StadiumNpcManifest.MAX_BYTES:
		return {}
	var parser: JSON = JSON.new()
	return normalized(parser.data) if parser.parse(text) == OK else {}
