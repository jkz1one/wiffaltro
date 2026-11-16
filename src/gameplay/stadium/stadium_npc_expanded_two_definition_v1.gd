class_name StadiumNpcExpandedTwoDefinitionV1
extends RefCounted
## Immutable public AE-02/r1 daylight. No catalog recomputation, stock, or candidate install.
## Exact shared 27 copies plus the authored two cones and four dormant yard lights.
# gdlint: disable=max-file-lines

const SHA256: String = "19854bdcd5128341f4de7ec610b6a34e3256bb63efc3bd0df75f21d8a7b8fd27"


static func payload() -> Dictionary:
	return {
		"assembly": {
			"id": "AE-02-public-daylight-r1",
			"version": 1
		},
		"blueprints": [
			"ST-001",
			"ST-024",
			"ST-025",
			"ST-026",
			"ST-028",
			"ST-037",
			"ST-039"
		],
		"catalog": {
			"sha256": "5210c3c47688b06faa35a50ec211f65de0a881debc5d7567a4c0e2abe6df204f",
			"version": 1
		},
		"environment_certificates": [],
		"field": "field.npc_venue",
		"graph": {
			"id": "PERIM-BACKYARD-ANGLED-BX1-v1",
			"sha256": "569e73dd264710a582eae5ef96e7fb554657f06629ff77b3b401daa308c492e7",
			"version": 1
		},
		"id": "AE-02",
		"instances": [
			{
				"host": "field",
				"instance": "npc:AE-02:r1:O-L1",
				"item": "ST-001",
				"site": "O-L1",
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
					-8.0,
					0.0,
					14.0
				]
			},
			{
				"host": "field",
				"instance": "npc:AE-02:r1:O-R1",
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
				"instance": "npc:AE-02:r1:RECEIVER-CATCH",
				"item": "ST-025",
				"site": "RECEIVER-CATCH",
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
					-2.200000047683716
				]
			},
			{
				"host": "field",
				"instance": "npc:AE-02:r1:RECEIVER-PRIMARY",
				"item": "ST-026",
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
				"instance": "npc:AE-02:r1:SCORE-SMALL",
				"item": "ST-039",
				"site": "SCORE-SMALL",
				"transform": [
					-1.0,
					0.0,
					0.0,
					0.0,
					1.0,
					0.0,
					0.0,
					0.0,
					-1.0,
					-20.0,
					0.0,
					30.0
				]
			},
			{
				"host": "field",
				"instance": "npc:AE-02:r1:SIDE-SEAT-L",
				"item": "ST-028",
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
				"instance": "npc:AE-02:r1:SIDE-SEAT-R",
				"item": "ST-028",
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
			},
			{
				"host": "field",
				"instance": "npc:AE-02:r1:ST-024-01",
				"item": "ST-024",
				"site": "ST-024-01",
				"transform": [
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
				"host": "field",
				"instance": "npc:AE-02:r1:ST-024-02",
				"item": "ST-024",
				"site": "ST-024-02",
				"transform": [
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
				"host": "field",
				"instance": "npc:AE-02:r1:ST-024-03",
				"item": "ST-024",
				"site": "ST-024-03",
				"transform": [
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
				"host": "field",
				"instance": "npc:AE-02:r1:ST-024-04",
				"item": "ST-024",
				"site": "ST-024-04",
				"transform": [
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
				"host": "field",
				"instance": "npc:AE-02:r1:ST-024-05",
				"item": "ST-024",
				"site": "ST-024-05",
				"transform": [
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
				"host": "field",
				"instance": "npc:AE-02:r1:ST-024-06",
				"item": "ST-024",
				"site": "ST-024-06",
				"transform": [
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
				"host": "field",
				"instance": "npc:AE-02:r1:ST-024-07",
				"item": "ST-024",
				"site": "ST-024-07",
				"transform": [
					-1.0,
					0.0,
					0.0,
					0.0,
					1.0,
					0.0,
					0.0,
					0.0,
					-1.0,
					9.0,
					0.0,
					26.0
				]
			},
			{
				"host": "field",
				"instance": "npc:AE-02:r1:ST-024-08",
				"item": "ST-024",
				"site": "ST-024-08",
				"transform": [
					-1.0,
					0.0,
					0.0,
					0.0,
					1.0,
					0.0,
					0.0,
					0.0,
					-1.0,
					7.0,
					0.0,
					26.0
				]
			},
			{
				"host": "field",
				"instance": "npc:AE-02:r1:ST-024-09",
				"item": "ST-024",
				"site": "ST-024-09",
				"transform": [
					-1.0,
					0.0,
					0.0,
					0.0,
					1.0,
					0.0,
					0.0,
					0.0,
					-1.0,
					5.0,
					0.0,
					26.0
				]
			},
			{
				"host": "field",
				"instance": "npc:AE-02:r1:ST-024-10",
				"item": "ST-024",
				"site": "ST-024-10",
				"transform": [
					-1.0,
					0.0,
					0.0,
					0.0,
					1.0,
					0.0,
					0.0,
					0.0,
					-1.0,
					3.0,
					0.0,
					26.0
				]
			},
			{
				"host": "field",
				"instance": "npc:AE-02:r1:ST-024-11",
				"item": "ST-024",
				"site": "ST-024-11",
				"transform": [
					-1.0,
					0.0,
					0.0,
					0.0,
					1.0,
					0.0,
					0.0,
					0.0,
					-1.0,
					1.0,
					0.0,
					26.0
				]
			},
			{
				"host": "field",
				"instance": "npc:AE-02:r1:ST-024-12",
				"item": "ST-024",
				"site": "ST-024-12",
				"transform": [
					-1.0,
					0.0,
					0.0,
					0.0,
					1.0,
					0.0,
					0.0,
					0.0,
					-1.0,
					-1.0,
					0.0,
					26.0
				]
			},
			{
				"host": "field",
				"instance": "npc:AE-02:r1:ST-024-13",
				"item": "ST-024",
				"site": "ST-024-13",
				"transform": [
					-1.0,
					0.0,
					0.0,
					0.0,
					1.0,
					0.0,
					0.0,
					0.0,
					-1.0,
					-3.0,
					0.0,
					26.0
				]
			},
			{
				"host": "field",
				"instance": "npc:AE-02:r1:ST-024-14",
				"item": "ST-024",
				"site": "ST-024-14",
				"transform": [
					-1.0,
					0.0,
					0.0,
					0.0,
					1.0,
					0.0,
					0.0,
					0.0,
					-1.0,
					-5.0,
					0.0,
					26.0
				]
			},
			{
				"host": "field",
				"instance": "npc:AE-02:r1:ST-024-15",
				"item": "ST-024",
				"site": "ST-024-15",
				"transform": [
					-1.0,
					0.0,
					0.0,
					0.0,
					1.0,
					0.0,
					0.0,
					0.0,
					-1.0,
					-7.0,
					0.0,
					26.0
				]
			},
			{
				"host": "field",
				"instance": "npc:AE-02:r1:ST-024-16",
				"item": "ST-024",
				"site": "ST-024-16",
				"transform": [
					-1.0,
					0.0,
					0.0,
					0.0,
					1.0,
					0.0,
					0.0,
					0.0,
					-1.0,
					-9.0,
					0.0,
					26.0
				]
			},
			{
				"host": "field",
				"instance": "npc:AE-02:r1:ST-024-17",
				"item": "ST-024",
				"site": "ST-024-17",
				"transform": [
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
				"host": "field",
				"instance": "npc:AE-02:r1:ST-024-18",
				"item": "ST-024",
				"site": "ST-024-18",
				"transform": [
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
				"host": "field",
				"instance": "npc:AE-02:r1:ST-024-19",
				"item": "ST-024",
				"site": "ST-024-19",
				"transform": [
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
				"host": "field",
				"instance": "npc:AE-02:r1:ST-024-20",
				"item": "ST-024",
				"site": "ST-024-20",
				"transform": [
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
				"host": "field",
				"instance": "npc:AE-02:r1:ST-024-21",
				"item": "ST-024",
				"site": "ST-024-21",
				"transform": [
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
				"host": "field",
				"instance": "npc:AE-02:r1:ST-024-22",
				"item": "ST-024",
				"site": "ST-024-22",
				"transform": [
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
			},
			{
				"host": "field",
				"item": "ST-037",
				"site": "YLIGHT-FL",
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
				],
				"instance": "npc:AE-02:r1:YLIGHT-FL"
			},
			{
				"host": "field",
				"item": "ST-037",
				"site": "YLIGHT-FR",
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
				],
				"instance": "npc:AE-02:r1:YLIGHT-FR"
			},
			{
				"host": "field",
				"item": "ST-037",
				"site": "YLIGHT-RL",
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
				],
				"instance": "npc:AE-02:r1:YLIGHT-RL"
			},
			{
				"host": "field",
				"item": "ST-037",
				"site": "YLIGHT-RR",
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
				],
				"instance": "npc:AE-02:r1:YLIGHT-RR"
			}
		],
		"land": {
			"stages": [
				"expanded"
			],
			"tier": "expanded",
			"version": 1
		},
		"live_units": 2,
		"models": {
			"stadium_npc_expanded_v1": {
				"version": 1,
				"sha256": "309016beb60b8512b3170e5d558e496cbfec248c6a386911c7b4f4baee96edf8"
			},
			"stadium_npc_expanded_boundary_v1": {
				"version": 1,
				"sha256": "b70e557ffa7623366179fdf39b7c162d91cd34bf9e25097b8939583f06e57760"
			},
			"stadium_npc_expanded_boundary_body_v1": {
				"version": 1,
				"sha256": "f865ade87aba256305b178cd3b201ddffc33b701552d5b3f3239d02363e0c9a9"
			},
			"stadium_npc_expanded_graph_v1": {
				"version": 1,
				"sha256": "408139d524d156cfb3292cbc47f14e5eafff94bafbce377a7d6f4af9ecda89e2"
			},
			"stadium_npc_expanded_target_v1": {
				"version": 1,
				"sha256": "f56d1442fda50f884f746f505f07fe77c6fcbba8cc71b06fbd500c1a7fe55e92"
			},
			"stadium_npc_expanded_net_v1": {
				"version": 1,
				"sha256": "5c8b1e3984bbb4d559d8cadcc8a09c19710a7c937ef665a9eb7f6c7172367797"
			},
			"stadium_npc_expanded_bleachers_v1": {
				"version": 1,
				"sha256": "dc128ab5b09190af1521dd8fc4e4b2e135522179364ac18d53b7937c9402d564"
			},
			"stadium_npc_expanded_club_v1": {
				"version": 1,
				"sha256": "8c05fbbe6182a7c4e761942f04677695b088bacec397cf297c0eb4b969fa5ece"
			},
			"stadium_npc_expanded_display_v1": {
				"version": 1,
				"sha256": "ae384829742e399a36515c21dd9b788d96b8b342929e8ed39a1251711245dbfd"
			},
			"stadium_starter_models": {
				"version": 1,
				"sha256": "c9e92051b1627a3043ebf6cb802940a24570851676cd8718ae1c475bda964138"
			},
			"stadium_yard_light_models": {
				"version": 1,
				"sha256": "28e58ea8f4dceac92466f4510a97fb28649b9694b1149f98ddf8503aa600d1b9"
			},
			"stadium_seating_models": {
				"version": 1,
				"sha256": "56f1ed7ceb4576b6887a48ad785209bf964965e8eb9bbcd708345a8ee4aa03eb"
			},
			"stadium_npc_retained_receiver": {
				"version": 1,
				"sha256": "c591e3a65504373d70641681e703e5b8e008f73ae327df67c5fb01e04138f79b"
			},
			"stadium_paired_receiver": {
				"version": 1,
				"sha256": "4a5b8429e56c31a8b29e6a22c783e5a8bfa422e0191cb6eebf4a0b44c40bccaf"
			},
			"stadium_expanded_camera_director": {
				"version": 1,
				"sha256": "13044baf5de24345d9a34aa950d4da6684cb6c6c357cec06c819ed7b3a4c4790"
			},
			"stadium_npc_retained_actor_cutaway": {
				"version": 1,
				"sha256": "f578e0c28e35ae43cfc442cf70d69e974e38e0a6f1b593b0a99dc1bbe174e504"
			},
			"stadium_wall_render_quality": {
				"version": 1,
				"sha256": "a342c1bda3e7c5d4d3d8f004eb76d6044a0f7a7305181429226f3c2e3c8c39d7"
			},
			"ball_tracking_visibility": {
				"version": 1,
				"sha256": "344e28784f900c6f660c55574330a8afc2d8c46b7149edfa28841957952253a8"
			},
			"ball_in_play_camera": {
				"version": 1,
				"sha256": "ead78e617b06f824ca37d669e05364eb6df70257729918b58c821c850fae68a0"
			},
			"match_camera_director": {
				"version": 1,
				"sha256": "84f2cd886f686c6dbec4e7aa8a57d72f06c276d36f4b6bee076e33a46430aedb"
			},
			"npc_venue_field": {
				"version": 1,
				"sha256": "a9df5523562f2a237d205e72b252729a6a248dc2bbfd789d51d6f1e4c587b598"
			}
		},
		"presentation": {
			"profile": "AE-02-default-expanded-v1",
			"options": {}
		},
		"revision": 1,
		"routing_version": 1,
		"rules_version": 1,
		"shape": "deeper_center",
		"surface_version": 1,
		"tier": "expanded",
		"valuation": {
			"blueprints": 2010,
			"copies": 1560,
			"land": 600,
			"price_sha256": "5210c3c47688b06faa35a50ec211f65de0a881debc5d7567a4c0e2abe6df204f",
			"price_version": 1,
			"total": 4170
		},
		"version": 1
	}
