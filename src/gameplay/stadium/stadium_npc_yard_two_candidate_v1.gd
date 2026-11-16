class_name StadiumNpcYardTwoCandidateV1
extends RefCounted
## Private immutable AY-02/r1 C/S only; no public, runtime or environment authority.
## Historical raw source binds the complete receiver, camera and render semantic contract.

const SHA256: String = "fb15cd5c23ab70e3498e0888aea409e9f03b4dedbac59e8c507fc70014327041"
const SUBJECT_SHA256: String = "d5f2d743639135f4feb51447905a2c17040b6594edadaa83702e25864d2e8dd9"


static func payload() -> Dictionary:
	return {
		"assembly": {
			"id": "AY-02-backyard-r1",
			"version": 1
		},
		"blueprints": [
			"ST-001",
			"ST-027",
			"ST-079"
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
		"id": "AY-02",
		"instances": [
			{
				"host": "field",
				"instance": "npc:AY-02:r1:O-R1",
				"item": "ST-001",
				"site": "O-R1",
				"transform": [
					1.0,
					0.0,
					0.0,
					0.0,
					1.0,
					0.0,
					0.0,
					0.0,
					1.0,
					8.0,
					0.0,
					14.0
				]
			},
			{
				"host": "field",
				"instance": "npc:AY-02:r1:RECEIVER-PRIMARY",
				"item": "ST-079",
				"site": "RECEIVER-PRIMARY",
				"transform": [
					1.0,
					0.0,
					0.0,
					0.0,
					1.0,
					0.0,
					0.0,
					0.0,
					1.0,
					0.0,
					0.0,
					-1.0499999523162842
				]
			},
			{
				"host": "field",
				"instance": "npc:AY-02:r1:SIDE-SEAT-L",
				"item": "ST-027",
				"site": "SIDE-SEAT-L",
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
					12.5
				]
			},
			{
				"host": "field",
				"instance": "npc:AY-02:r1:SIDE-SEAT-R",
				"item": "ST-027",
				"site": "SIDE-SEAT-R",
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
					12.5
				]
			}
		],
		"land": {
			"stages": [],
			"tier": "backyard",
			"version": 1
		},
		"live_units": 1,
		"models": {
			"authoring-contract": {
				"sha256": "08695950bfe72b92dd09532ee9d031c7dc63975f6f4ff87162b3fea4b43bef2e",
				"version": 1
			},
			"chair-receiver": {
				"sha256": "8980a5bd60c3429f01e165ec36a8c9b2bc12387af413dd9edf6b4002c3190e77",
				"version": 1
			},
			"field-semantics": {
				"sha256": "39cf09ce92b00c8c0d784f5e738623b810b512a12c3b3c9294a5133b33f413d2",
				"version": 1
			},
			"free-template": {
				"sha256": "779ce82a8bc9ff872dc3e1cf5c50552f5cf7eaa5914e5857d9459904cbaf89af",
				"version": 1
			},
			"starter-models": {
				"sha256": "c9e92051b1627a3043ebf6cb802940a24570851676cd8718ae1c475bda964138",
				"version": 1
			},
			"template-boundary": {
				"sha256": "5b7e8fe60a44b875e5e0e66ce2fe3d8a995e4482c8de79dedbaabcb9adc0d88a",
				"version": 1
			},
			"wooden-bleachers": {
				"sha256": "56f1ed7ceb4576b6887a48ad785209bf964965e8eb9bbcd708345a8ee4aa03eb",
				"version": 1
			}
		},
		"presentation": {
			"options": {},
			"profile": "AY-02-default-backyard-v1"
		},
		"revision": 1,
		"routing_version": 1,
		"rules_version": 1,
		"shape": "straight",
		"surface_version": 1,
		"tier": "backyard",
		"valuation": {
			"blueprints": 300,
			"copies": 275,
			"land": 0,
			"price_sha256": "5210c3c47688b06faa35a50ec211f65de0a881debc5d7567a4c0e2abe6df204f",
			"price_version": 1,
			"total": 575
		},
		"version": 1
	}


static func definition(id: String = "AY-02", revision: int = 1) -> Dictionary:
	if id != "AY-02" or revision != 1:
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
