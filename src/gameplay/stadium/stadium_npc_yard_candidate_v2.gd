class_name StadiumNpcYardCandidateV2
extends RefCounted
## Unqualified r2 candidate literal. No environment certificate or production authority.


static func payload() -> Dictionary:
	return {
		"version": 1,
		"id": "AY-01",
		"revision": 2,
		"assembly": {"id": "AY-01-common-field-r2", "version": 2},
		"field": "field.npc_venue",
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
				"instance": "npc:AY-01:r2:SC-L1",
				"item": "ST-080",
				"site": "SC-L1",
				"host": "field",
				"transform": [0.0, 0.0, -1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -24.0, 0.0, 10.0]
			},
			{
				"instance": "npc:AY-01:r2:SC-L2",
				"item": "ST-080",
				"site": "SC-L2",
				"host": "field",
				"transform": [0.0, 0.0, -1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -24.0, 0.0, 12.0]
			},
			{
				"instance": "npc:AY-01:r2:SC-R1",
				"item": "ST-080",
				"site": "SC-R1",
				"host": "field",
				"transform": [0.0, 0.0, 1.0, 0.0, 1.0, 0.0, -1.0, 0.0, 0.0, 24.0, 0.0, 10.0]
			},
			{
				"instance": "npc:AY-01:r2:SC-R2",
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
