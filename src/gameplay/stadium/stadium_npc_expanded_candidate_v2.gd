class_name StadiumNpcExpandedCandidateV2
extends RefCounted
## Unqualified r2 candidate literal. No environment certificate or production authority.


static func payload() -> Dictionary:
	return {
		"version": 1,
		"id": "AE-01",
		"revision": 2,
		"assembly": {"id": "AE-01-common-field-r2", "version": 2},
		"field": "field.npc_venue",
		"tier": "expanded",
		"shape": "deeper_center",
		"rules_version": 1,
		"graph":
		{
			"id": "PERIM-BACKYARD-ANGLED-BX1-v1",
			"version": 1,
			"sha256": "569e73dd264710a582eae5ef96e7fb554657f06629ff77b3b401daa308c492e7"
		},
		"catalog":
		{
			"version": 1,
			"sha256": "5210c3c47688b06faa35a50ec211f65de0a881debc5d7567a4c0e2abe6df204f"
		},
		"models":
		{
			"stadium_bleacher_models":
			{
				"version": 1,
				"sha256": "040edd83c323dc009cfa68d9a8fccfea7ac775dcb05097992cf816187a15c07c"
			},
			"stadium_club_models":
			{
				"version": 1,
				"sha256": "c05a9a6c77791a12cbc9b5191240e3f96e94adec6aa239db5ce6e3f974eaa61f"
			},
			"stadium_expanded_boundary":
			{
				"version": 1,
				"sha256": "818f78a98b9a704175e161d6fbbb9f01b73476b04cc45179e9a9c5a694af785f"
			},
			"stadium_expanded_camera_director":
			{
				"version": 1,
				"sha256": "13044baf5de24345d9a34aa950d4da6684cb6c6c357cec06c819ed7b3a4c4790"
			},
			"stadium_expanded_fixture_study":
			{
				"version": 1,
				"sha256": "e24a6208786de3d606aaace2d09da0f6382f35ec85f35787554a9c9cb1c2531c"
			},
			"stadium_expanded_lab":
			{
				"version": 1,
				"sha256": "5d14f98766193f4df77b83a070be1bb7bf13e00fc1a91a4cb3d34d593d220247"
			},
			"stadium_expanded_property":
			{
				"version": 1,
				"sha256": "2a029f45c22ff9538f5a5a4a03d6adf4abc71e31f91c2e7f47771d6599fb7ea6"
			},
			"stadium_expanded_venue_study":
			{
				"version": 1,
				"sha256": "328001ee65a2a2bea712cd77fd9b8d805f7c86af1f44c108e269d73fec9b7839"
			},
			"stadium_net_models":
			{
				"version": 2,
				"sha256": "e54036913c3937c78d18cdfe857bd54a55ec883158f27eac13aa7e1080185398"
			},
			"stadium_paired_receiver":
			{
				"version": 1,
				"sha256": "4a5b8429e56c31a8b29e6a22c783e5a8bfa422e0191cb6eebf4a0b44c40bccaf"
			},
			"stadium_recipe_boundary":
			{
				"version": 1,
				"sha256": "a98381fd78d1f32fcd58ad7dbd2f29b29634c7b3572159980e781ffb6c66aca8"
			},
			"stadium_recipe_boundary_body":
			{
				"version": 1,
				"sha256": "b97f10a80de3aab812d1f848567c8bdfb42f4dcf269e94b8e4976f427b5a9b72"
			},
			"stadium_target_models":
			{
				"version": 1,
				"sha256": "0334e3bc2588f17a2a7ec1f6d64209dedea8336c67461930415248f228d7ba0a"
			},
			"stadium_wall_panel_models":
			{
				"version": 1,
				"sha256": "aa2cb103cf6998f81466c9173bdb3eb206a91835f84857e73380ca98e38ada7b"
			},
			"stadium_wall_recipes":
			{
				"version": 1,
				"sha256": "2225255afd3ded7bddb8a94ac1ee639e91a4c2c77806e17f70db21f13fd822e5"
			},
			"free-template":
			{
				"version": 1,
				"sha256": "779ce82a8bc9ff872dc3e1cf5c50552f5cf7eaa5914e5857d9459904cbaf89af"
			}
		},
		"instances":
		[
			{
				"instance": "npc:AE-01:r2:RECEIVER-CATCH",
				"item": "ST-025",
				"site": "RECEIVER-CATCH",
				"host": "field",
				"transform":
				[1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, -2.200000047683716]
			},
			{
				"instance": "npc:AE-01:r2:RECEIVER-PRIMARY",
				"item": "ST-026",
				"site": "RECEIVER-PRIMARY",
				"host": "field",
				"transform":
				[1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, -1.0499999523162842]
			},
			{
				"instance": "npc:AE-01:r2:SCORE-SMALL",
				"item": "ST-039",
				"site": "SCORE-SMALL",
				"host": "field",
				"transform": [-1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, -1.0, -20.0, 0.0, 30.0]
			},
			{
				"instance": "npc:AE-01:r2:SIDE-SEAT-L",
				"item": "ST-028",
				"site": "SIDE-SEAT-L",
				"host": "field",
				"transform": [0.0, 0.0, -1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -24.0, 0.0, 12.5]
			},
			{
				"instance": "npc:AE-01:r2:SIDE-SEAT-R",
				"item": "ST-028",
				"site": "SIDE-SEAT-R",
				"host": "field",
				"transform": [0.0, 0.0, 1.0, 0.0, 1.0, 0.0, -1.0, 0.0, 0.0, 24.0, 0.0, 12.5]
			},
			{
				"instance": "npc:AE-01:r2:ST-024-01",
				"item": "ST-024",
				"site": "ST-024-01",
				"host": "field",
				"transform":
				[
					-0.9754621982574463,
					0.0,
					0.22016717493534088,
					0.0,
					1.0,
					0.0,
					-0.22016717493534088,
					0.0,
					-0.9754621982574463,
					20.637039184570312,
					0.0,
					23.599166870117188
				]
			},
			{
				"instance": "npc:AE-01:r2:ST-024-02",
				"item": "ST-024",
				"site": "ST-024-02",
				"host": "field",
				"transform":
				[
					-0.9754621386528015,
					0.0,
					0.22016720473766327,
					0.0,
					1.0,
					0.0,
					-0.22016720473766327,
					0.0,
					-0.9754621386528015,
					18.779159545898438,
					0.0,
					24.01849937438965
				]
			},
			{
				"instance": "npc:AE-01:r2:ST-024-03",
				"item": "ST-024",
				"site": "ST-024-03",
				"host": "field",
				"transform":
				[
					-0.9754624366760254,
					0.0,
					0.22016620635986328,
					0.0,
					1.0,
					0.0,
					-0.22016620635986328,
					0.0,
					-0.9754624366760254,
					16.828235626220703,
					0.0,
					24.458831787109375
				]
			},
			{
				"instance": "npc:AE-01:r2:ST-024-04",
				"item": "ST-024",
				"site": "ST-024-04",
				"host": "field",
				"transform":
				[
					-0.9754621982574463,
					0.0,
					0.2201671004295349,
					0.0,
					1.0,
					0.0,
					-0.2201671004295349,
					0.0,
					-0.9754621982574463,
					14.877309799194336,
					0.0,
					24.899166107177734
				]
			},
			{
				"instance": "npc:AE-01:r2:ST-024-05",
				"item": "ST-024",
				"site": "ST-024-05",
				"host": "field",
				"transform":
				[
					-0.9754623770713806,
					0.0,
					0.22016629576683044,
					0.0,
					1.0,
					0.0,
					-0.22016629576683044,
					0.0,
					-0.9754623770713806,
					12.926385879516602,
					0.0,
					25.339500427246094
				]
			},
			{
				"instance": "npc:AE-01:r2:ST-024-06",
				"item": "ST-024",
				"site": "ST-024-06",
				"host": "field",
				"transform":
				[
					-0.9754621386528015,
					0.0,
					0.22016720473766327,
					0.0,
					1.0,
					0.0,
					-0.22016720473766327,
					0.0,
					-0.9754621386528015,
					10.975461959838867,
					0.0,
					25.77983283996582
				]
			},
			{
				"instance": "npc:AE-01:r2:ST-024-07",
				"item": "ST-024",
				"site": "ST-024-07",
				"host": "field",
				"transform": [-1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, -1.0, 9.0, 0.0, 26.0]
			},
			{
				"instance": "npc:AE-01:r2:ST-024-08",
				"item": "ST-024",
				"site": "ST-024-08",
				"host": "field",
				"transform": [-1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, -1.0, 7.0, 0.0, 26.0]
			},
			{
				"instance": "npc:AE-01:r2:ST-024-09",
				"item": "ST-024",
				"site": "ST-024-09",
				"host": "field",
				"transform": [-1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, -1.0, 5.0, 0.0, 26.0]
			},
			{
				"instance": "npc:AE-01:r2:ST-024-10",
				"item": "ST-024",
				"site": "ST-024-10",
				"host": "field",
				"transform": [-1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, -1.0, 3.0, 0.0, 26.0]
			},
			{
				"instance": "npc:AE-01:r2:ST-024-11",
				"item": "ST-024",
				"site": "ST-024-11",
				"host": "field",
				"transform": [-1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, -1.0, 1.0, 0.0, 26.0]
			},
			{
				"instance": "npc:AE-01:r2:ST-024-12",
				"item": "ST-024",
				"site": "ST-024-12",
				"host": "field",
				"transform": [-1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, -1.0, -1.0, 0.0, 26.0]
			},
			{
				"instance": "npc:AE-01:r2:ST-024-13",
				"item": "ST-024",
				"site": "ST-024-13",
				"host": "field",
				"transform": [-1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, -1.0, -3.0, 0.0, 26.0]
			},
			{
				"instance": "npc:AE-01:r2:ST-024-14",
				"item": "ST-024",
				"site": "ST-024-14",
				"host": "field",
				"transform": [-1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, -1.0, -5.0, 0.0, 26.0]
			},
			{
				"instance": "npc:AE-01:r2:ST-024-15",
				"item": "ST-024",
				"site": "ST-024-15",
				"host": "field",
				"transform": [-1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, -1.0, -7.0, 0.0, 26.0]
			},
			{
				"instance": "npc:AE-01:r2:ST-024-16",
				"item": "ST-024",
				"site": "ST-024-16",
				"host": "field",
				"transform": [-1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, -1.0, -9.0, 0.0, 26.0]
			},
			{
				"instance": "npc:AE-01:r2:ST-024-17",
				"item": "ST-024",
				"site": "ST-024-17",
				"host": "field",
				"transform":
				[
					-0.9754621386528015,
					0.0,
					-0.22016720473766327,
					0.0,
					1.0,
					0.0,
					0.22016720473766327,
					0.0,
					-0.9754621386528015,
					-10.975461959838867,
					0.0,
					25.77983283996582
				]
			},
			{
				"instance": "npc:AE-01:r2:ST-024-18",
				"item": "ST-024",
				"site": "ST-024-18",
				"host": "field",
				"transform":
				[
					-0.9754624366760254,
					0.0,
					-0.22016620635986328,
					0.0,
					1.0,
					0.0,
					0.22016620635986328,
					0.0,
					-0.9754624366760254,
					-12.926385879516602,
					0.0,
					25.339500427246094
				]
			},
			{
				"instance": "npc:AE-01:r2:ST-024-19",
				"item": "ST-024",
				"site": "ST-024-19",
				"host": "field",
				"transform":
				[
					-0.9754621982574463,
					0.0,
					-0.2201671004295349,
					0.0,
					1.0,
					0.0,
					0.2201671004295349,
					0.0,
					-0.9754621982574463,
					-14.877311706542969,
					0.0,
					24.899166107177734
				]
			},
			{
				"instance": "npc:AE-01:r2:ST-024-20",
				"item": "ST-024",
				"site": "ST-024-20",
				"host": "field",
				"transform":
				[
					-0.9754623770713806,
					0.0,
					-0.22016629576683044,
					0.0,
					1.0,
					0.0,
					0.22016629576683044,
					0.0,
					-0.9754623770713806,
					-16.828235626220703,
					0.0,
					24.458831787109375
				]
			},
			{
				"instance": "npc:AE-01:r2:ST-024-21",
				"item": "ST-024",
				"site": "ST-024-21",
				"host": "field",
				"transform":
				[
					-0.9754621386528015,
					0.0,
					-0.22016720473766327,
					0.0,
					1.0,
					0.0,
					0.22016720473766327,
					0.0,
					-0.9754621386528015,
					-18.779159545898438,
					0.0,
					24.01849937438965
				]
			},
			{
				"instance": "npc:AE-01:r2:ST-024-22",
				"item": "ST-024",
				"site": "ST-024-22",
				"host": "field",
				"transform":
				[
					-0.9754621982574463,
					0.0,
					-0.22016717493534088,
					0.0,
					1.0,
					0.0,
					0.22016717493534088,
					0.0,
					-0.9754621982574463,
					-20.637039184570312,
					0.0,
					23.599166870117188
				]
			}
		],
		"blueprints": ["ST-024", "ST-025", "ST-026", "ST-028", "ST-039"],
		"land": {"version": 1, "tier": "expanded", "stages": ["expanded"]},
		"surface_version": 1,
		"routing_version": 1,
		"environment_certificates": [],
		"presentation": {"profile": "AE-01-default-expanded-v1", "options": {}},
		"live_units": 0,
		"valuation":
		{
			"price_version": 1,
			"price_sha256": "5210c3c47688b06faa35a50ec211f65de0a881debc5d7567a4c0e2abe6df204f",
			"blueprints": 1710,
			"copies": 1220,
			"land": 600,
			"total": 3530
		}
	}
