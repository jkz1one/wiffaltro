class_name StadiumNpcYardDefinitionV1
extends RefCounted
## Immutable AY-01/r1 data. Never evaluate current authoring/model/catalog code here.
## Sources and the separate retained construction seam: STADIUM_NPC_YARD_ADMISSION.md.

const SHA256: String = "6295c0e4b2221666530fa343c6a0b39d6a7e61cff11b5850b59e13ec10c811e7"


static func payload() -> Dictionary:
	# A fresh literal on every call; historical r1 must never be rewritten for new content.
	return {
		"version": 1,
		"id": "AY-01",
		"revision": 1,
		"assembly": {"id": "AY-01-backyard-v1", "version": 1},
		"field": "field.starter_backyard",
		"tier": "backyard",
		"shape": "straight",
		"rules_version": 1,
		"graph":
		{
			"id": "PERIM-BACKYARD-STRAIGHT-BX1-v1",
			"version": 1,
			"sha256": "93859ee6fb839243e6ac471b45027547e4a47e09e7e57bc957f19c7410b542e9"
		},
		"catalog":
		{
			"version": 1,
			"sha256": "5210c3c47688b06faa35a50ec211f65de0a881debc5d7567a4c0e2abe6df204f"
		},
		"models":
		{
			"spectator-chair":
			{
				"version": 1,
				"sha256": "56f1ed7ceb4576b6887a48ad785209bf964965e8eb9bbcd708345a8ee4aa03eb"
			},
			"free-template":
			{
				"version": 1,
				"sha256": "779ce82a8bc9ff872dc3e1cf5c50552f5cf7eaa5914e5857d9459904cbaf89af"
			},
			"template-boundary":
			{
				"version": 1,
				"sha256": "5b7e8fe60a44b875e5e0e66ce2fe3d8a995e4482c8de79dedbaabcb9adc0d88a"
			}
		},
		"instances":
		[
			{
				"instance": "npc:AY-01:r1:SC-L1",
				"item": "ST-080",
				"site": "SC-L1",
				"host": "field",
				"transform": [0.0, 0.0, -1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -24.0, 0.0, 10.0]
			},
			{
				"instance": "npc:AY-01:r1:SC-L2",
				"item": "ST-080",
				"site": "SC-L2",
				"host": "field",
				"transform": [0.0, 0.0, -1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -24.0, 0.0, 12.0]
			},
			{
				"instance": "npc:AY-01:r1:SC-R1",
				"item": "ST-080",
				"site": "SC-R1",
				"host": "field",
				"transform": [0.0, 0.0, 1.0, 0.0, 1.0, 0.0, -1.0, 0.0, 0.0, 24.0, 0.0, 10.0]
			},
			{
				"instance": "npc:AY-01:r1:SC-R2",
				"item": "ST-080",
				"site": "SC-R2",
				"host": "field",
				"transform": [0.0, 0.0, 1.0, 0.0, 1.0, 0.0, -1.0, 0.0, 0.0, 24.0, 0.0, 12.0]
			}
		],
		"blueprints": ["ST-080"],
		"land": {"version": 1, "tier": "backyard", "stages": []},
		"surface_version": 1,
		"routing_version": 1,
		"environment_certificates": [],
		"presentation": {"profile": "AY-01-default-backyard-v1", "options": {}},
		"live_units": 0,
		"valuation":
		{
			"price_version": 1,
			"price_sha256": "5210c3c47688b06faa35a50ec211f65de0a881debc5d7567a4c0e2abe6df204f",
			"blueprints": 150,
			"copies": 160,
			"land": 0,
			"total": 310
		}
	}
