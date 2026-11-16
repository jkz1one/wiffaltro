class_name StadiumNpcMogulTwoContractV1
extends RefCounted
## Complete original AM-02 semantic contract; exact scalar and finite scene-vector domains.
# gdlint: disable=max-file-lines


static func payload() -> Dictionary:
	return {
		"batting_home": "ordinary-match-role-independent-of-venue-owner",
		"blueprint_entitlements": [
			"ST-021",
			"ST-022",
			"ST-023",
			"ST-026",
			"ST-029",
			"ST-030",
			"ST-031",
			"ST-039",
			"ST-053",
			"ST-065",
			"ST-065-T",
			"ST-073",
			"ST-074",
			"ST-076",
			"ST-081",
			"ST-085",
			"ST-088"
		],
		"boundary": "aad63b46850cfe962a41b9289172c0d8d5e6f3331184f3f524dff296beb3203f",
		"camera_profile": {
			"acquisition": "pre-pitch-only-no-pitch-no-batted-body-no-contact-cut",
			"focus": [
				0,
				1.1,
				7.1
			],
			"id": "AM02-BATTING-BEHIND-RECEIVER-v2",
			"left_entry": [
				-0.18,
				2.1,
				-6.5
			],
			"live_motion": "unchanged-inherited-continuous-motion-turn-and-collision",
			"optics": "unchanged-inherited-75-degree-base-and-Club-live-FOV",
			"qualification": "requires-independent-AM02-whole-layout-check",
			"reference": "frozen-AM01-entry-source-pattern-only",
			"right_entry": [
				0.18,
				2.1,
				-6.5
			],
			"scope": "installed-AM02-precontact-batting-entry-only"
		},
		"catalog": "5210c3c47688b06faa35a50ec211f65de0a881debc5d7567a4c0e2abe6df204f",
		"crowd": {
			"baseline_lower": 200,
			"baseline_upper": 64,
			"bowl_lower": 180,
			"status": "Working-art-density",
			"sway": 0.04,
			"total": 480,
			"transition_lower": 36
		},
		"empty_sites": [
			"LANDMARK-A",
			"SCORE-LARGE-A",
			"BOWL-CONCOURSES",
			"BOWL-UPPERS",
			"BOWL-ROOFS",
			"JOIN-CONCOURSES",
			"ELEVATED-CORRIDORS"
		],
		"endowment": {
			"blueprint_value": 7390,
			"copy_value": 5975,
			"land_value": 6400,
			"total_value": 19765
		},
		"environment": {
			"certificates": [],
			"future_night_profile": "MOGUL4-PREMIUM",
			"night_eligible": false,
			"qualification": "requires-complete-ordinary-layout-profile",
			"target_slots": [
				"13:10",
				"16:10"
			],
			"target_weather": [
				"clear"
			]
		},
		"field": {
			"back_wall_z_m": 23.4,
			"dead_ball_z_m": 29.0,
			"deep_air_z_m": 17.0,
			"deep_anchor_z_m": 19.5,
			"environment_style": 0,
			"fair_half_angle_degrees": 42.0,
			"home_run_height_m": 3.25,
			"id": "field.npc_venue",
			"middle_anchor_z_m": 14.0,
			"middle_center_anchor_z_m": 17.0,
			"middle_center_available": false,
			"mound_origin": [
				0.0,
				0.0,
				13.715999603271484
			],
			"safe_hit_z_m": 11.25,
			"shallow_anchor_z_m": 8.5,
			"shallow_center_available": false,
			"side_anchor_x_m": 5.5
		},
		"graph": {
			"ball_radius": 0.0365,
			"defender_radius": 0.54,
			"id": "PROTOTYPE-CLUB-DUGOUT-LEFT-LOFT-v1",
			"ordering": "first-sphere-contact-or-clear-v1",
			"poles": [
				{
					"height": 8.0,
					"position": [
						-20.35363006591797,
						0.0,
						22.604995727539062
					],
					"radius": 0.09,
					"segment": "BACK-05",
					"site": "FOUL-POLE-L",
					"split": 4.875
				},
				{
					"height": 8.0,
					"position": [
						21.156484603881836,
						0.0,
						23.49665641784668
					],
					"radius": 0.09,
					"segment": "BACK-01",
					"site": "FOUL-POLE-R",
					"split": 3.25
				}
			],
			"prism_margin": 0.0,
			"query_layer": 32,
			"segments": [
				{
					"a": [
						-8.0,
						-6.0
					],
					"b": [
						8.0,
						-6.0
					],
					"height": 1.2,
					"id": "REAR-01",
					"priority": 300,
					"role": "REAR_PERIMETER_DEAD"
				},
				{
					"a": [
						8.0,
						-6.0
					],
					"b": [
						12.780145645141602,
						2.7835187911987305
					],
					"height": 1.2,
					"id": "SIDE-R-01-IN",
					"priority": 50,
					"role": "SIDE_RETURN_LIVE"
				},
				{
					"a": [
						12.780145645141602,
						2.7835187911987305
					],
					"b": [
						13.736175537109375,
						4.54022216796875
					],
					"height": 1.2,
					"id": "DUGOUT-R-FACE-IN",
					"priority": 350,
					"role": "DUGOUT_FACE_LIVE"
				},
				{
					"a": [
						13.736175537109375,
						4.54022216796875
					],
					"b": [
						14.692204475402832,
						6.296926498413086
					],
					"height": 2.4,
					"id": "DUGOUT-R-OPEN",
					"priority": 250,
					"role": "DUGOUT_OPENING_DEAD"
				},
				{
					"a": [
						14.692204475402832,
						6.296926498413086
					],
					"b": [
						15.648233413696289,
						8.053629875183105
					],
					"height": 1.2,
					"id": "DUGOUT-R-FACE-OUT",
					"priority": 350,
					"role": "DUGOUT_FACE_LIVE"
				},
				{
					"a": [
						15.648233413696289,
						8.053629875183105
					],
					"b": [
						24.0,
						23.399999618530273
					],
					"height": 1.2,
					"id": "SIDE-R-01-OUT",
					"priority": 50,
					"role": "SIDE_RETURN_LIVE"
				},
				{
					"a": [
						24.0,
						23.399999618530273
					],
					"b": [
						21.519454956054688,
						23.399999618530273
					],
					"height": 1.2,
					"id": "RETURN-R-01",
					"priority": 100,
					"role": "SIDE_RETURN_LIVE"
				},
				{
					"a": [
						21.519454956054688,
						23.399999618530273
					],
					"b": [
						8.0,
						27.0
					],
					"height": 3.25,
					"id": "BACK-01",
					"priority": 200,
					"role": "BACK_WALL_TERMINAL"
				},
				{
					"a": [
						8.0,
						27.0
					],
					"b": [
						-4.0,
						27.0
					],
					"height": 3.25,
					"id": "BACK-02",
					"priority": 200,
					"role": "BACK_WALL_TERMINAL"
				},
				{
					"a": [
						-4.0,
						27.0
					],
					"b": [
						-10.0,
						22.0
					],
					"height": 4.875,
					"id": "BACK-03",
					"priority": 200,
					"role": "BACK_WALL_TERMINAL"
				},
				{
					"a": [
						-10.0,
						22.0
					],
					"b": [
						-18.0,
						21.0
					],
					"height": 4.875,
					"id": "BACK-04",
					"priority": 200,
					"role": "BACK_WALL_TERMINAL"
				},
				{
					"a": [
						-18.0,
						21.0
					],
					"b": [
						-21.519454956054688,
						23.399999618530273
					],
					"height": 4.875,
					"id": "BACK-05",
					"priority": 200,
					"role": "BACK_WALL_TERMINAL"
				},
				{
					"a": [
						-21.519454956054688,
						23.399999618530273
					],
					"b": [
						-24.0,
						23.399999618530273
					],
					"height": 1.2,
					"id": "RETURN-L-01",
					"priority": 100,
					"role": "SIDE_RETURN_LIVE"
				},
				{
					"a": [
						-24.0,
						23.399999618530273
					],
					"b": [
						-15.648233413696289,
						8.053629875183105
					],
					"height": 1.2,
					"id": "SIDE-L-01-OUT",
					"priority": 50,
					"role": "SIDE_RETURN_LIVE"
				},
				{
					"a": [
						-15.648233413696289,
						8.053629875183105
					],
					"b": [
						-14.692204475402832,
						6.296926498413086
					],
					"height": 1.2,
					"id": "DUGOUT-L-FACE-OUT",
					"priority": 350,
					"role": "DUGOUT_FACE_LIVE"
				},
				{
					"a": [
						-14.692204475402832,
						6.296926498413086
					],
					"b": [
						-13.736175537109375,
						4.54022216796875
					],
					"height": 2.4,
					"id": "DUGOUT-L-OPEN",
					"priority": 250,
					"role": "DUGOUT_OPENING_DEAD"
				},
				{
					"a": [
						-13.736175537109375,
						4.54022216796875
					],
					"b": [
						-12.780145645141602,
						2.7835187911987305
					],
					"height": 1.2,
					"id": "DUGOUT-L-FACE-IN",
					"priority": 350,
					"role": "DUGOUT_FACE_LIVE"
				},
				{
					"a": [
						-12.780145645141602,
						2.7835187911987305
					],
					"b": [
						-8.0,
						-6.0
					],
					"height": 1.2,
					"id": "SIDE-L-01-IN",
					"priority": 50,
					"role": "SIDE_RETURN_LIVE"
				}
			],
			"signature": "aad63b46850cfe962a41b9289172c0d8d5e6f3331184f3f524dff296beb3203f",
			"thickness": 0.35,
			"version": 1
		},
		"id": "AM-02",
		"items": [
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:left_loft-00",
				"item": "ST-065",
				"model_variant": "",
				"model_version": 1,
				"site": "left_loft-00",
				"span": "",
				"support": {},
				"transform": [
					-0.9663271903991699,
					0.0,
					0.2573164701461792,
					0.0,
					1.0,
					0.0,
					-0.2573164701461792,
					0.0,
					-0.9663271903991699,
					20.55312728881836,
					0.0,
					23.657316207885742
				],
				"wall": {
					"a": [
						21.519454956054688,
						23.399999618530273
					],
					"b": [
						19.58679962158203,
						23.91463279724121
					],
					"height": 3.25,
					"thickness": 0.35,
					"width": 2.0000009536743164
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:left_loft-01",
				"item": "ST-065",
				"model_variant": "",
				"model_version": 1,
				"site": "left_loft-01",
				"span": "",
				"support": {},
				"transform": [
					-0.9663271903991699,
					0.0,
					0.2573164701461792,
					0.0,
					1.0,
					0.0,
					-0.2573164701461792,
					0.0,
					-0.9663271903991699,
					18.620471954345703,
					0.0,
					24.17194938659668
				],
				"wall": {
					"a": [
						19.58679962158203,
						23.91463279724121
					],
					"b": [
						17.654144287109375,
						24.42926597595215
					],
					"height": 3.25,
					"thickness": 0.35,
					"width": 2.0000009536743164
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:left_loft-02",
				"item": "ST-065",
				"model_variant": "",
				"model_version": 1,
				"site": "left_loft-02",
				"span": "",
				"support": {},
				"transform": [
					-0.9663271903991699,
					0.0,
					0.25731658935546875,
					0.0,
					1.0,
					0.0,
					-0.25731658935546875,
					0.0,
					-0.9663271903991699,
					16.687816619873047,
					0.0,
					24.686582565307617
				],
				"wall": {
					"a": [
						17.654144287109375,
						24.42926597595215
					],
					"b": [
						15.721489906311035,
						24.943899154663086
					],
					"height": 3.25,
					"thickness": 0.35,
					"width": 2.0
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:left_loft-03",
				"item": "ST-065",
				"model_variant": "",
				"model_version": 1,
				"site": "left_loft-03",
				"span": "",
				"support": {},
				"transform": [
					-0.9663271903991699,
					0.0,
					0.25731658935546875,
					0.0,
					1.0,
					0.0,
					-0.25731658935546875,
					0.0,
					-0.9663271903991699,
					14.755163192749023,
					0.0,
					25.201215744018555
				],
				"wall": {
					"a": [
						15.721489906311035,
						24.943899154663086
					],
					"b": [
						13.788835525512695,
						25.458532333374023
					],
					"height": 3.25,
					"thickness": 0.35,
					"width": 2.0
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:left_loft-04",
				"item": "ST-065",
				"model_variant": "",
				"model_version": 1,
				"site": "left_loft-04",
				"span": "",
				"support": {},
				"transform": [
					-0.9663271903991699,
					0.0,
					0.25731658935546875,
					0.0,
					1.0,
					0.0,
					-0.25731658935546875,
					0.0,
					-0.9663271903991699,
					12.822507858276367,
					0.0,
					25.715848922729492
				],
				"wall": {
					"a": [
						13.788835525512695,
						25.458532333374023
					],
					"b": [
						11.856181144714355,
						25.97316551208496
					],
					"height": 3.25,
					"thickness": 0.35,
					"width": 2.0
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:left_loft-05",
				"item": "ST-065",
				"model_variant": "",
				"model_version": 1,
				"site": "left_loft-05",
				"span": "",
				"support": {},
				"transform": [
					-0.9663271903991699,
					0.0,
					0.25731658935546875,
					0.0,
					1.0,
					0.0,
					-0.25731658935546875,
					0.0,
					-0.9663271903991699,
					10.889854431152344,
					0.0,
					26.23048210144043
				],
				"wall": {
					"a": [
						11.856181144714355,
						25.97316551208496
					],
					"b": [
						9.923526763916016,
						26.4877986907959
					],
					"height": 3.25,
					"thickness": 0.35,
					"width": 2.0
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:left_loft-06",
				"item": "ST-065",
				"model_variant": "",
				"model_version": 1,
				"site": "left_loft-06",
				"span": "",
				"support": {},
				"transform": [
					-0.9663271307945251,
					0.0,
					0.2573166787624359,
					0.0,
					1.0,
					0.0,
					-0.2573166787624359,
					0.0,
					-0.9663271307945251,
					8.961762428283691,
					0.0,
					26.743900299072266
				],
				"wall": {
					"a": [
						9.923526763916016,
						26.4877986907959
					],
					"b": [
						7.999998569488525,
						27.000001907348633
					],
					"height": 3.25,
					"thickness": 0.35,
					"width": 1.9905558824539185
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:left_loft-07",
				"item": "ST-065",
				"model_variant": "",
				"model_version": 1,
				"site": "left_loft-07",
				"span": "",
				"support": {},
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
					27.0
				],
				"wall": {
					"a": [
						8.0,
						27.0
					],
					"b": [
						6.0,
						27.0
					],
					"height": 3.25,
					"thickness": 0.35,
					"width": 2.0
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:left_loft-08",
				"item": "ST-065",
				"model_variant": "",
				"model_version": 1,
				"site": "left_loft-08",
				"span": "",
				"support": {},
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
					27.0
				],
				"wall": {
					"a": [
						6.0,
						27.0
					],
					"b": [
						4.0,
						27.0
					],
					"height": 3.25,
					"thickness": 0.35,
					"width": 2.0
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:left_loft-09",
				"item": "ST-065",
				"model_variant": "",
				"model_version": 1,
				"site": "left_loft-09",
				"span": "",
				"support": {},
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
					27.0
				],
				"wall": {
					"a": [
						4.0,
						27.0
					],
					"b": [
						2.0,
						27.0
					],
					"height": 3.25,
					"thickness": 0.35,
					"width": 2.0
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:left_loft-10",
				"item": "ST-065",
				"model_variant": "",
				"model_version": 1,
				"site": "left_loft-10",
				"span": "",
				"support": {},
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
					27.0
				],
				"wall": {
					"a": [
						2.0,
						27.0
					],
					"b": [
						0.0,
						27.0
					],
					"height": 3.25,
					"thickness": 0.35,
					"width": 2.0
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:left_loft-11",
				"item": "ST-065",
				"model_variant": "",
				"model_version": 1,
				"site": "left_loft-11",
				"span": "",
				"support": {},
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
					27.0
				],
				"wall": {
					"a": [
						0.0,
						27.0
					],
					"b": [
						-2.0,
						27.0
					],
					"height": 3.25,
					"thickness": 0.35,
					"width": 2.0
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:left_loft-12",
				"item": "ST-065",
				"model_variant": "",
				"model_version": 1,
				"site": "left_loft-12",
				"span": "",
				"support": {},
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
					27.0
				],
				"wall": {
					"a": [
						-2.0,
						27.0
					],
					"b": [
						-4.0,
						27.0
					],
					"height": 3.25,
					"thickness": 0.35,
					"width": 2.0
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:left_loft-13",
				"item": "ST-065-T",
				"model_variant": "",
				"model_version": 1,
				"site": "left_loft-13",
				"span": "",
				"support": {},
				"transform": [
					-0.768221378326416,
					0.0,
					-0.6401844024658203,
					0.0,
					1.0,
					0.0,
					0.6401844024658203,
					0.0,
					-0.768221378326416,
					-4.768221378326416,
					0.0,
					26.35981559753418
				],
				"wall": {
					"a": [
						-4.0,
						27.0
					],
					"b": [
						-5.536442756652832,
						25.71963119506836
					],
					"height": 4.875,
					"thickness": 0.35,
					"width": 2.0
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:left_loft-14",
				"item": "ST-065-T",
				"model_variant": "",
				"model_version": 1,
				"site": "left_loft-14",
				"span": "",
				"support": {},
				"transform": [
					-0.768221378326416,
					0.0,
					-0.6401844024658203,
					0.0,
					1.0,
					0.0,
					0.6401844024658203,
					0.0,
					-0.768221378326416,
					-6.304664134979248,
					0.0,
					25.07944679260254
				],
				"wall": {
					"a": [
						-5.536442756652832,
						25.71963119506836
					],
					"b": [
						-7.072885513305664,
						24.43926239013672
					],
					"height": 4.875,
					"thickness": 0.35,
					"width": 2.0
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:left_loft-15",
				"item": "ST-065-T",
				"model_variant": "",
				"model_version": 1,
				"site": "left_loft-15",
				"span": "",
				"support": {},
				"transform": [
					-0.768221378326416,
					0.0,
					-0.6401844024658203,
					0.0,
					1.0,
					0.0,
					0.6401844024658203,
					0.0,
					-0.768221378326416,
					-7.84110689163208,
					0.0,
					23.7990779876709
				],
				"wall": {
					"a": [
						-7.072885513305664,
						24.43926239013672
					],
					"b": [
						-8.609328269958496,
						23.158893585205078
					],
					"height": 4.875,
					"thickness": 0.35,
					"width": 2.0
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:left_loft-16",
				"item": "ST-065-T",
				"model_variant": "",
				"model_version": 1,
				"site": "left_loft-16",
				"span": "",
				"support": {},
				"transform": [
					-0.768221378326416,
					0.0,
					-0.6401842832565308,
					0.0,
					1.0,
					0.0,
					0.6401842832565308,
					0.0,
					-0.768221378326416,
					-9.304664611816406,
					0.0,
					22.57944679260254
				],
				"wall": {
					"a": [
						-8.609328269958496,
						23.158893585205078
					],
					"b": [
						-10.000000953674316,
						22.0
					],
					"height": 4.875,
					"thickness": 0.35,
					"width": 1.810249924659729
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:left_loft-17",
				"item": "ST-065-T",
				"model_variant": "",
				"model_version": 1,
				"site": "left_loft-17",
				"span": "",
				"support": {},
				"transform": [
					-0.9922778606414795,
					0.0,
					-0.12403485178947449,
					0.0,
					1.0,
					0.0,
					0.12403485178947449,
					0.0,
					-0.9922778606414795,
					-10.992278099060059,
					0.0,
					21.875965118408203
				],
				"wall": {
					"a": [
						-10.0,
						22.0
					],
					"b": [
						-11.984556198120117,
						21.751930236816406
					],
					"height": 4.875,
					"thickness": 0.35,
					"width": 2.000000476837158
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:left_loft-18",
				"item": "ST-065-T",
				"model_variant": "",
				"model_version": 1,
				"site": "left_loft-18",
				"span": "",
				"support": {},
				"transform": [
					-0.9922778606414795,
					0.0,
					-0.12403485178947449,
					0.0,
					1.0,
					0.0,
					0.12403485178947449,
					0.0,
					-0.9922778606414795,
					-12.976834297180176,
					0.0,
					21.62789535522461
				],
				"wall": {
					"a": [
						-11.984556198120117,
						21.751930236816406
					],
					"b": [
						-13.969112396240234,
						21.503860473632812
					],
					"height": 4.875,
					"thickness": 0.35,
					"width": 2.000000476837158
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:left_loft-19",
				"item": "ST-065-T",
				"model_variant": "",
				"model_version": 1,
				"site": "left_loft-19",
				"span": "",
				"support": {},
				"transform": [
					-0.9922778606414795,
					0.0,
					-0.12403485178947449,
					0.0,
					1.0,
					0.0,
					0.12403485178947449,
					0.0,
					-0.9922778606414795,
					-14.961390495300293,
					0.0,
					21.379825592041016
				],
				"wall": {
					"a": [
						-13.969112396240234,
						21.503860473632812
					],
					"b": [
						-15.953668594360352,
						21.25579071044922
					],
					"height": 4.875,
					"thickness": 0.35,
					"width": 2.000000476837158
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:left_loft-20",
				"item": "ST-065-T",
				"model_variant": "",
				"model_version": 1,
				"site": "left_loft-20",
				"span": "",
				"support": {},
				"transform": [
					-0.9922779202461243,
					0.0,
					-0.12403427809476852,
					0.0,
					1.0,
					0.0,
					0.12403427809476852,
					0.0,
					-0.9922779202461243,
					-16.465251922607422,
					0.0,
					21.191843032836914
				],
				"wall": {
					"a": [
						-15.953668594360352,
						21.25579071044922
					],
					"b": [
						-16.976835250854492,
						21.12789535522461
					],
					"height": 4.875,
					"thickness": 0.35,
					"width": 1.0311291217803955
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:left_loft-21",
				"item": "ST-065-T",
				"model_variant": "",
				"model_version": 1,
				"site": "left_loft-21",
				"span": "",
				"support": {},
				"transform": [
					-0.9922779202461243,
					0.0,
					-0.12403427809476852,
					0.0,
					1.0,
					0.0,
					0.12403427809476852,
					0.0,
					-0.9922779202461243,
					-17.488418579101562,
					0.0,
					21.063947677612305
				],
				"wall": {
					"a": [
						-16.976835250854492,
						21.12789535522461
					],
					"b": [
						-18.000001907348633,
						21.0
					],
					"height": 4.875,
					"thickness": 0.35,
					"width": 1.0311291217803955
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:left_loft-22",
				"item": "ST-065-T",
				"model_variant": "",
				"model_version": 1,
				"site": "left_loft-22",
				"span": "",
				"support": {},
				"transform": [
					-0.8261868357658386,
					0.0,
					0.5633962750434875,
					0.0,
					1.0,
					0.0,
					-0.5633962750434875,
					0.0,
					-0.8261868357658386,
					-18.826187133789062,
					0.0,
					21.563396453857422
				],
				"wall": {
					"a": [
						-18.0,
						21.0
					],
					"b": [
						-19.652374267578125,
						22.126792907714844
					],
					"height": 4.875,
					"thickness": 0.35,
					"width": 2.0000007152557373
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:left_loft-23",
				"item": "ST-065-T",
				"model_variant": "",
				"model_version": 1,
				"site": "left_loft-23",
				"span": "",
				"support": {},
				"transform": [
					-0.8261863589286804,
					0.0,
					0.5633969306945801,
					0.0,
					1.0,
					0.0,
					-0.5633969306945801,
					0.0,
					-0.8261863589286804,
					-20.119144439697266,
					0.0,
					22.44509506225586
				],
				"wall": {
					"a": [
						-19.652374267578125,
						22.126792907714844
					],
					"b": [
						-20.585914611816406,
						22.763397216796875
					],
					"height": 4.875,
					"thickness": 0.35,
					"width": 1.1299391984939575
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:left_loft-24",
				"item": "ST-065-T",
				"model_variant": "",
				"model_version": 1,
				"site": "left_loft-24",
				"span": "",
				"support": {},
				"transform": [
					-0.8261863589286804,
					0.0,
					0.5633969306945801,
					0.0,
					1.0,
					0.0,
					-0.5633969306945801,
					0.0,
					-0.8261863589286804,
					-21.052684783935547,
					0.0,
					23.08169937133789
				],
				"wall": {
					"a": [
						-20.585914611816406,
						22.763397216796875
					],
					"b": [
						-21.519454956054688,
						23.400001525878906
					],
					"height": 4.875,
					"thickness": 0.35,
					"width": 1.1299391984939575
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:ST-023-01",
				"item": "ST-023",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-023-01",
				"span": "full",
				"support": {},
				"transform": [
					0.4780144989490509,
					0.0,
					0.8783519864082336,
					0.0,
					1.0,
					0.0,
					-0.8783519864082336,
					0.0,
					0.4780144989490509,
					8.47801399230957,
					0.0,
					-5.121647834777832
				],
				"wall": {
					"a": [
						8.0,
						-6.0
					],
					"b": [
						8.956028938293457,
						-4.243296146392822
					],
					"height": 1.2,
					"thickness": 0.35,
					"width": 1.9999998807907104
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:ST-023-02",
				"item": "ST-023",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-023-02",
				"span": "full",
				"support": {},
				"transform": [
					0.4780145287513733,
					0.0,
					0.8783519268035889,
					0.0,
					1.0,
					0.0,
					-0.8783519268035889,
					0.0,
					0.4780145287513733,
					9.434043884277344,
					0.0,
					-3.3649444580078125
				],
				"wall": {
					"a": [
						8.956028938293457,
						-4.243296146392822
					],
					"b": [
						9.912057876586914,
						-2.4865925312042236
					],
					"height": 1.2,
					"thickness": 0.35,
					"width": 1.999999761581421
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:ST-023-03",
				"item": "ST-023",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-023-03",
				"span": "full",
				"support": {},
				"transform": [
					0.47801488637924194,
					0.0,
					0.8783516883850098,
					0.0,
					1.0,
					0.0,
					-0.8783516883850098,
					0.0,
					0.47801488637924194,
					10.3900728225708,
					0.0,
					-1.6082407236099243
				],
				"wall": {
					"a": [
						9.912057876586914,
						-2.4865925312042236
					],
					"b": [
						10.868087768554688,
						-0.729888916015625
					],
					"height": 1.2,
					"thickness": 0.35,
					"width": 2.000000238418579
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:ST-023-04",
				"item": "ST-023",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-023-04",
				"span": "full",
				"support": {},
				"transform": [
					0.4780144989490509,
					0.0,
					0.8783519864082336,
					0.0,
					1.0,
					0.0,
					-0.8783519864082336,
					0.0,
					0.4780144989490509,
					11.346101760864258,
					0.0,
					0.14846301078796387
				],
				"wall": {
					"a": [
						10.868087768554688,
						-0.729888916015625
					],
					"b": [
						11.824116706848145,
						1.0268149375915527
					],
					"height": 1.2,
					"thickness": 0.35,
					"width": 1.9999998807907104
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:ST-023-05",
				"item": "ST-023",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-023-05",
				"span": "full",
				"support": {},
				"transform": [
					0.4780144989490509,
					0.0,
					0.8783519864082336,
					0.0,
					1.0,
					0.0,
					-0.8783519864082336,
					0.0,
					0.4780144989490509,
					12.302131652832031,
					0.0,
					1.9051668643951416
				],
				"wall": {
					"a": [
						11.824116706848145,
						1.0268149375915527
					],
					"b": [
						12.780145645141602,
						2.7835187911987305
					],
					"height": 1.2,
					"thickness": 0.35,
					"width": 1.9999998807907104
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:ST-023-09",
				"item": "ST-023",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-023-09",
				"span": "full",
				"support": {},
				"transform": [
					0.4780149757862091,
					0.0,
					0.8783517479896545,
					0.0,
					1.0,
					0.0,
					-0.8783517479896545,
					0.0,
					0.4780149757862091,
					16.12624740600586,
					0.0,
					8.931982040405273
				],
				"wall": {
					"a": [
						15.648233413696289,
						8.053629875183105
					],
					"b": [
						16.604263305664062,
						9.810333251953125
					],
					"height": 1.2,
					"thickness": 0.35,
					"width": 1.9999998807907104
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:ST-023-10",
				"item": "ST-023",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-023-10",
				"span": "full",
				"support": {},
				"transform": [
					0.4780140221118927,
					0.0,
					0.8783522248268127,
					0.0,
					1.0,
					0.0,
					-0.8783522248268127,
					0.0,
					0.4780140221118927,
					17.082277297973633,
					0.0,
					10.688685417175293
				],
				"wall": {
					"a": [
						16.604263305664062,
						9.810333251953125
					],
					"b": [
						17.560291290283203,
						11.567037582397461
					],
					"height": 1.2,
					"thickness": 0.35,
					"width": 1.9999998807907104
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:ST-023-11",
				"item": "ST-023",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-023-11",
				"span": "full",
				"support": {},
				"transform": [
					0.4780147671699524,
					0.0,
					0.8783518671989441,
					0.0,
					1.0,
					0.0,
					-0.8783518671989441,
					0.0,
					0.4780147671699524,
					18.038307189941406,
					0.0,
					12.445389747619629
				],
				"wall": {
					"a": [
						17.560291290283203,
						11.567037582397461
					],
					"b": [
						18.516321182250977,
						13.323741912841797
					],
					"height": 1.2,
					"thickness": 0.35,
					"width": 2.0000007152557373
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:ST-023-12",
				"item": "ST-023",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-023-12",
				"span": "full",
				"support": {},
				"transform": [
					0.4780151844024658,
					0.0,
					0.878351628780365,
					0.0,
					1.0,
					0.0,
					-0.878351628780365,
					0.0,
					0.4780151844024658,
					18.994335174560547,
					0.0,
					14.202093124389648
				],
				"wall": {
					"a": [
						18.516321182250977,
						13.323741912841797
					],
					"b": [
						19.47235107421875,
						15.0804443359375
					],
					"height": 1.2,
					"thickness": 0.35,
					"width": 1.9999990463256836
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:ST-023-13",
				"item": "ST-023",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-023-13",
				"span": "full",
				"support": {},
				"transform": [
					0.4780140221118927,
					0.0,
					0.8783522248268127,
					0.0,
					1.0,
					0.0,
					-0.8783522248268127,
					0.0,
					0.4780140221118927,
					19.95036506652832,
					0.0,
					15.958796501159668
				],
				"wall": {
					"a": [
						19.47235107421875,
						15.0804443359375
					],
					"b": [
						20.42837905883789,
						16.837148666381836
					],
					"height": 1.2,
					"thickness": 0.35,
					"width": 1.9999998807907104
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:ST-023-14",
				"item": "ST-023",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-023-14",
				"span": "full",
				"support": {},
				"transform": [
					0.4780147671699524,
					0.0,
					0.8783518671989441,
					0.0,
					1.0,
					0.0,
					-0.8783518671989441,
					0.0,
					0.4780147671699524,
					20.906394958496094,
					0.0,
					17.715499877929688
				],
				"wall": {
					"a": [
						20.42837905883789,
						16.837148666381836
					],
					"b": [
						21.384408950805664,
						18.593852996826172
					],
					"height": 1.2,
					"thickness": 0.35,
					"width": 2.0000007152557373
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:ST-023-15",
				"item": "ST-023",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-023-15",
				"span": "full",
				"support": {},
				"transform": [
					0.4780151844024658,
					0.0,
					0.878351628780365,
					0.0,
					1.0,
					0.0,
					-0.878351628780365,
					0.0,
					0.4780151844024658,
					21.862422943115234,
					0.0,
					19.472204208374023
				],
				"wall": {
					"a": [
						21.384408950805664,
						18.593852996826172
					],
					"b": [
						22.340438842773438,
						20.350555419921875
					],
					"height": 1.2,
					"thickness": 0.35,
					"width": 1.9999990463256836
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:ST-023-16",
				"item": "ST-023",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-023-16",
				"span": "full",
				"support": {},
				"transform": [
					0.4780140221118927,
					0.0,
					0.8783522248268127,
					0.0,
					1.0,
					0.0,
					-0.8783522248268127,
					0.0,
					0.4780140221118927,
					22.818452835083008,
					0.0,
					21.22890853881836
				],
				"wall": {
					"a": [
						22.340438842773438,
						20.350555419921875
					],
					"b": [
						23.296466827392578,
						22.10725975036621
					],
					"height": 1.2,
					"thickness": 0.35,
					"width": 1.9999998807907104
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:ST-023-17",
				"item": "ST-023",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-023-17",
				"span": "side_end",
				"support": {},
				"transform": [
					0.47801530361175537,
					0.0,
					0.8783515691757202,
					0.0,
					1.0,
					0.0,
					-0.8783515691757202,
					0.0,
					0.47801530361175537,
					23.64823341369629,
					0.0,
					22.753629684448242
				],
				"wall": {
					"a": [
						23.296466827392578,
						22.10725975036621
					],
					"b": [
						24.0,
						23.399999618530273
					],
					"height": 1.2,
					"thickness": 0.35,
					"width": 1.4717795848846436
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:ST-023-18",
				"item": "ST-023",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-023-18",
				"span": "full",
				"support": {},
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
					23.0,
					0.0,
					23.399999618530273
				],
				"wall": {
					"a": [
						24.0,
						23.399999618530273
					],
					"b": [
						22.0,
						23.399999618530273
					],
					"height": 1.2,
					"thickness": 0.35,
					"width": 2.0
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:ST-023-19",
				"item": "ST-023",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-023-19",
				"span": "return_end",
				"support": {},
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
					21.759727478027344,
					0.0,
					23.399999618530273
				],
				"wall": {
					"a": [
						22.0,
						23.399999618530273
					],
					"b": [
						21.519454956054688,
						23.399999618530273
					],
					"height": 1.2,
					"thickness": 0.35,
					"width": 0.4805450439453125
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:ST-022-01",
				"item": "ST-022",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-022-01",
				"span": "return_end",
				"support": {},
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
					-21.759727478027344,
					0.0,
					23.399999618530273
				],
				"wall": {
					"a": [
						-21.519454956054688,
						23.399999618530273
					],
					"b": [
						-22.0,
						23.399999618530273
					],
					"height": 1.2,
					"thickness": 0.35,
					"width": 0.4805450439453125
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:ST-022-02",
				"item": "ST-022",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-022-02",
				"span": "full",
				"support": {},
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
					-23.0,
					0.0,
					23.399999618530273
				],
				"wall": {
					"a": [
						-22.0,
						23.399999618530273
					],
					"b": [
						-24.0,
						23.399999618530273
					],
					"height": 1.2,
					"thickness": 0.35,
					"width": 2.0
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:ST-022-03",
				"item": "ST-022",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-022-03",
				"span": "side_end",
				"support": {},
				"transform": [
					0.47801530361175537,
					0.0,
					-0.8783515691757202,
					0.0,
					1.0,
					0.0,
					0.8783515691757202,
					0.0,
					0.47801530361175537,
					-23.64823341369629,
					0.0,
					22.753629684448242
				],
				"wall": {
					"a": [
						-24.0,
						23.399999618530273
					],
					"b": [
						-23.296466827392578,
						22.10725975036621
					],
					"height": 1.2,
					"thickness": 0.35,
					"width": 1.4717795848846436
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:ST-022-04",
				"item": "ST-022",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-022-04",
				"span": "full",
				"support": {},
				"transform": [
					0.4780140221118927,
					0.0,
					-0.8783522248268127,
					0.0,
					1.0,
					0.0,
					0.8783522248268127,
					0.0,
					0.4780140221118927,
					-22.818452835083008,
					0.0,
					21.22890853881836
				],
				"wall": {
					"a": [
						-23.296466827392578,
						22.10725975036621
					],
					"b": [
						-22.340438842773438,
						20.350555419921875
					],
					"height": 1.2,
					"thickness": 0.35,
					"width": 1.9999998807907104
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:ST-022-05",
				"item": "ST-022",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-022-05",
				"span": "full",
				"support": {},
				"transform": [
					0.4780151844024658,
					0.0,
					-0.878351628780365,
					0.0,
					1.0,
					0.0,
					0.878351628780365,
					0.0,
					0.4780151844024658,
					-21.862422943115234,
					0.0,
					19.472204208374023
				],
				"wall": {
					"a": [
						-22.340438842773438,
						20.350555419921875
					],
					"b": [
						-21.384408950805664,
						18.593852996826172
					],
					"height": 1.2,
					"thickness": 0.35,
					"width": 1.9999990463256836
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:ST-022-06",
				"item": "ST-022",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-022-06",
				"span": "full",
				"support": {},
				"transform": [
					0.4780147671699524,
					0.0,
					-0.8783518671989441,
					0.0,
					1.0,
					0.0,
					0.8783518671989441,
					0.0,
					0.4780147671699524,
					-20.906394958496094,
					0.0,
					17.715499877929688
				],
				"wall": {
					"a": [
						-21.384408950805664,
						18.593852996826172
					],
					"b": [
						-20.42837905883789,
						16.837148666381836
					],
					"height": 1.2,
					"thickness": 0.35,
					"width": 2.0000007152557373
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:ST-022-07",
				"item": "ST-022",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-022-07",
				"span": "full",
				"support": {},
				"transform": [
					0.4780140221118927,
					0.0,
					-0.8783522248268127,
					0.0,
					1.0,
					0.0,
					0.8783522248268127,
					0.0,
					0.4780140221118927,
					-19.95036506652832,
					0.0,
					15.958796501159668
				],
				"wall": {
					"a": [
						-20.42837905883789,
						16.837148666381836
					],
					"b": [
						-19.47235107421875,
						15.0804443359375
					],
					"height": 1.2,
					"thickness": 0.35,
					"width": 1.9999998807907104
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:ST-022-08",
				"item": "ST-022",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-022-08",
				"span": "full",
				"support": {},
				"transform": [
					0.4780151844024658,
					0.0,
					-0.878351628780365,
					0.0,
					1.0,
					0.0,
					0.878351628780365,
					0.0,
					0.4780151844024658,
					-18.994335174560547,
					0.0,
					14.202093124389648
				],
				"wall": {
					"a": [
						-19.47235107421875,
						15.0804443359375
					],
					"b": [
						-18.516321182250977,
						13.323741912841797
					],
					"height": 1.2,
					"thickness": 0.35,
					"width": 1.9999990463256836
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:ST-022-09",
				"item": "ST-022",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-022-09",
				"span": "full",
				"support": {},
				"transform": [
					0.4780147671699524,
					0.0,
					-0.8783518671989441,
					0.0,
					1.0,
					0.0,
					0.8783518671989441,
					0.0,
					0.4780147671699524,
					-18.038307189941406,
					0.0,
					12.445389747619629
				],
				"wall": {
					"a": [
						-18.516321182250977,
						13.323741912841797
					],
					"b": [
						-17.560291290283203,
						11.567037582397461
					],
					"height": 1.2,
					"thickness": 0.35,
					"width": 2.0000007152557373
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:ST-022-10",
				"item": "ST-022",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-022-10",
				"span": "full",
				"support": {},
				"transform": [
					0.4780140221118927,
					0.0,
					-0.8783522248268127,
					0.0,
					1.0,
					0.0,
					0.8783522248268127,
					0.0,
					0.4780140221118927,
					-17.082277297973633,
					0.0,
					10.688685417175293
				],
				"wall": {
					"a": [
						-17.560291290283203,
						11.567037582397461
					],
					"b": [
						-16.604263305664062,
						9.810333251953125
					],
					"height": 1.2,
					"thickness": 0.35,
					"width": 1.9999998807907104
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:ST-022-11",
				"item": "ST-022",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-022-11",
				"span": "full",
				"support": {},
				"transform": [
					0.4780149757862091,
					0.0,
					-0.8783517479896545,
					0.0,
					1.0,
					0.0,
					0.8783517479896545,
					0.0,
					0.4780149757862091,
					-16.12624740600586,
					0.0,
					8.931982040405273
				],
				"wall": {
					"a": [
						-16.604263305664062,
						9.810333251953125
					],
					"b": [
						-15.648233413696289,
						8.053629875183105
					],
					"height": 1.2,
					"thickness": 0.35,
					"width": 1.9999998807907104
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:ST-022-15",
				"item": "ST-022",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-022-15",
				"span": "full",
				"support": {},
				"transform": [
					0.4780144989490509,
					0.0,
					-0.8783519864082336,
					0.0,
					1.0,
					0.0,
					0.8783519864082336,
					0.0,
					0.4780144989490509,
					-12.302131652832031,
					0.0,
					1.9051668643951416
				],
				"wall": {
					"a": [
						-12.780145645141602,
						2.7835187911987305
					],
					"b": [
						-11.824116706848145,
						1.0268149375915527
					],
					"height": 1.2,
					"thickness": 0.35,
					"width": 1.9999998807907104
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:ST-022-16",
				"item": "ST-022",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-022-16",
				"span": "full",
				"support": {},
				"transform": [
					0.4780144989490509,
					0.0,
					-0.8783519864082336,
					0.0,
					1.0,
					0.0,
					0.8783519864082336,
					0.0,
					0.4780144989490509,
					-11.346101760864258,
					0.0,
					0.14846301078796387
				],
				"wall": {
					"a": [
						-11.824116706848145,
						1.0268149375915527
					],
					"b": [
						-10.868087768554688,
						-0.729888916015625
					],
					"height": 1.2,
					"thickness": 0.35,
					"width": 1.9999998807907104
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:ST-022-17",
				"item": "ST-022",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-022-17",
				"span": "full",
				"support": {},
				"transform": [
					0.47801488637924194,
					0.0,
					-0.8783516883850098,
					0.0,
					1.0,
					0.0,
					0.8783516883850098,
					0.0,
					0.47801488637924194,
					-10.3900728225708,
					0.0,
					-1.6082407236099243
				],
				"wall": {
					"a": [
						-10.868087768554688,
						-0.729888916015625
					],
					"b": [
						-9.912057876586914,
						-2.4865925312042236
					],
					"height": 1.2,
					"thickness": 0.35,
					"width": 2.000000238418579
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:ST-022-18",
				"item": "ST-022",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-022-18",
				"span": "full",
				"support": {},
				"transform": [
					0.4780145287513733,
					0.0,
					-0.8783519268035889,
					0.0,
					1.0,
					0.0,
					0.8783519268035889,
					0.0,
					0.4780145287513733,
					-9.434043884277344,
					0.0,
					-3.3649444580078125
				],
				"wall": {
					"a": [
						-9.912057876586914,
						-2.4865925312042236
					],
					"b": [
						-8.956028938293457,
						-4.243296146392822
					],
					"height": 1.2,
					"thickness": 0.35,
					"width": 1.999999761581421
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:ST-022-19",
				"item": "ST-022",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-022-19",
				"span": "full",
				"support": {},
				"transform": [
					0.4780144989490509,
					0.0,
					-0.8783519864082336,
					0.0,
					1.0,
					0.0,
					0.8783519864082336,
					0.0,
					0.4780144989490509,
					-8.47801399230957,
					0.0,
					-5.121647834777832
				],
				"wall": {
					"a": [
						-8.956028938293457,
						-4.243296146392822
					],
					"b": [
						-8.0,
						-6.0
					],
					"height": 1.2,
					"thickness": 0.35,
					"width": 1.9999998807907104
				}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:DUGOUT-R",
				"item": "ST-074",
				"model_variant": "",
				"model_version": 1,
				"site": "DUGOUT-R",
				"span": "",
				"support": {},
				"transform": [
					-0.4780147671699524,
					0.0,
					-0.8783518671989441,
					0.0,
					1.0,
					0.0,
					0.8783518671989441,
					0.0,
					-0.4780147671699524,
					14.214189529418945,
					0.0,
					5.418574333190918
				],
				"wall": {}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:DUGOUT-L",
				"item": "ST-074",
				"model_variant": "",
				"model_version": 1,
				"site": "DUGOUT-L",
				"span": "",
				"support": {},
				"transform": [
					-0.4780147671699524,
					0.0,
					0.8783518671989441,
					0.0,
					1.0,
					0.0,
					-0.8783518671989441,
					0.0,
					-0.4780147671699524,
					-14.214189529418945,
					0.0,
					5.418574333190918
				],
				"wall": {}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:FOUL-POLE-L",
				"item": "ST-021",
				"model_variant": "",
				"model_version": 1,
				"site": "FOUL-POLE-L",
				"span": "",
				"support": {},
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
					-20.35363006591797,
					0.0,
					22.604995727539062
				],
				"wall": {}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:FOUL-POLE-R",
				"item": "ST-021",
				"model_variant": "",
				"model_version": 1,
				"site": "FOUL-POLE-R",
				"span": "",
				"support": {},
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
					21.156484603881836,
					0.0,
					23.49665641784668
				],
				"wall": {}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:RECEIVER-PRIMARY",
				"item": "ST-026",
				"model_variant": "",
				"model_version": 1,
				"site": "RECEIVER-PRIMARY",
				"span": "",
				"support": {},
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
				],
				"wall": {}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:RECEIVER-CATCH",
				"item": "ST-073",
				"model_variant": "",
				"model_version": 2,
				"site": "RECEIVER-CATCH",
				"span": "",
				"support": {},
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
					0.0
				],
				"wall": {}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:BASE-L1",
				"item": "ST-029",
				"model_variant": "BASE-LOWER-SIGHTLINE-v2",
				"model_version": 2,
				"site": "BASE-L1",
				"span": "",
				"support": {},
				"transform": [
					-0.4780147671699524,
					0.0,
					0.8783518671989441,
					0.0,
					1.0,
					0.0,
					-0.8783518671989441,
					0.0,
					-0.4780147671699524,
					-18.24445152282715,
					0.0,
					5.502226829528809
				],
				"wall": {}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:BASE-L1.CONCOURSE",
				"item": "ST-031",
				"model_variant": "STRAIGHT-CONCOURSE-GUARD-v2",
				"model_version": 2,
				"site": "BASE-L1.CONCOURSE",
				"span": "",
				"support": {
					"interface": "ST029-guard-v2_REAR-STAIR-SADDLE-v2",
					"lower": "npc-candidate:AM-02:left-loft-v1:BASE-L1"
				},
				"transform": [
					-0.4780147671699524,
					0.0,
					0.8783518671989441,
					0.0,
					1.0,
					0.0,
					-0.8783518671989441,
					0.0,
					-0.4780147671699524,
					-18.24445152282715,
					0.0,
					5.502226829528809
				],
				"wall": {}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:BASE-L1.UPPER",
				"item": "ST-030",
				"model_variant": "STRAIGHT-UPPER-GUARD-v2",
				"model_version": 2,
				"site": "BASE-L1.UPPER",
				"span": "",
				"support": {
					"concourse": "npc-candidate:AM-02:left-loft-v1:BASE-L1.CONCOURSE",
					"interface": "ST031-guard-v2_STRAIGHT-CANTILEVER-v2",
					"lower": "npc-candidate:AM-02:left-loft-v1:BASE-L1"
				},
				"transform": [
					-0.4780147671699524,
					0.0,
					0.8783518671989441,
					0.0,
					1.0,
					0.0,
					-0.8783518671989441,
					0.0,
					-0.4780147671699524,
					-18.24445152282715,
					0.0,
					5.502226829528809
				],
				"wall": {}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:BASE-L1.ROOF-UPPER",
				"item": "ST-053",
				"model_variant": "STRAIGHT-UPPER-CANOPY-v2",
				"model_version": 2,
				"site": "BASE-L1.ROOF-UPPER",
				"span": "",
				"support": {
					"concourse": "npc-candidate:AM-02:left-loft-v1:BASE-L1.CONCOURSE",
					"interface": "ST030-guard-v2_PYLON-CAP-v2",
					"lower": "npc-candidate:AM-02:left-loft-v1:BASE-L1",
					"mount": "BASE-UPPER-ROOF-v1",
					"upper": "npc-candidate:AM-02:left-loft-v1:BASE-L1.UPPER"
				},
				"transform": [
					-0.4780147671699524,
					0.0,
					0.8783518671989441,
					0.0,
					1.0,
					0.0,
					-0.8783518671989441,
					0.0,
					-0.4780147671699524,
					-18.24445152282715,
					0.0,
					5.502226829528809
				],
				"wall": {}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:BASE-L2",
				"item": "ST-029",
				"model_variant": "BASE-LOWER-SIGHTLINE-v2",
				"model_version": 2,
				"site": "BASE-L2",
				"span": "",
				"support": {},
				"transform": [
					-0.4780147671699524,
					0.0,
					0.8783518671989441,
					0.0,
					1.0,
					0.0,
					-0.8783518671989441,
					0.0,
					-0.4780147671699524,
					-21.112539291381836,
					0.0,
					10.772337913513184
				],
				"wall": {}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:BASE-L2.CONCOURSE",
				"item": "ST-031",
				"model_variant": "STRAIGHT-CONCOURSE-GUARD-v2",
				"model_version": 2,
				"site": "BASE-L2.CONCOURSE",
				"span": "",
				"support": {
					"interface": "ST029-guard-v2_REAR-STAIR-SADDLE-v2",
					"lower": "npc-candidate:AM-02:left-loft-v1:BASE-L2"
				},
				"transform": [
					-0.4780147671699524,
					0.0,
					0.8783518671989441,
					0.0,
					1.0,
					0.0,
					-0.8783518671989441,
					0.0,
					-0.4780147671699524,
					-21.112539291381836,
					0.0,
					10.772337913513184
				],
				"wall": {}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:BASE-L2.UPPER",
				"item": "ST-030",
				"model_variant": "STRAIGHT-UPPER-GUARD-v2",
				"model_version": 2,
				"site": "BASE-L2.UPPER",
				"span": "",
				"support": {
					"concourse": "npc-candidate:AM-02:left-loft-v1:BASE-L2.CONCOURSE",
					"interface": "ST031-guard-v2_STRAIGHT-CANTILEVER-v2",
					"lower": "npc-candidate:AM-02:left-loft-v1:BASE-L2"
				},
				"transform": [
					-0.4780147671699524,
					0.0,
					0.8783518671989441,
					0.0,
					1.0,
					0.0,
					-0.8783518671989441,
					0.0,
					-0.4780147671699524,
					-21.112539291381836,
					0.0,
					10.772337913513184
				],
				"wall": {}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:BASE-L2.ROOF-UPPER",
				"item": "ST-053",
				"model_variant": "STRAIGHT-UPPER-CANOPY-v2",
				"model_version": 2,
				"site": "BASE-L2.ROOF-UPPER",
				"span": "",
				"support": {
					"concourse": "npc-candidate:AM-02:left-loft-v1:BASE-L2.CONCOURSE",
					"interface": "ST030-guard-v2_PYLON-CAP-v2",
					"lower": "npc-candidate:AM-02:left-loft-v1:BASE-L2",
					"mount": "BASE-UPPER-ROOF-v1",
					"upper": "npc-candidate:AM-02:left-loft-v1:BASE-L2.UPPER"
				},
				"transform": [
					-0.4780147671699524,
					0.0,
					0.8783518671989441,
					0.0,
					1.0,
					0.0,
					-0.8783518671989441,
					0.0,
					-0.4780147671699524,
					-21.112539291381836,
					0.0,
					10.772337913513184
				],
				"wall": {}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:BASE-R1",
				"item": "ST-029",
				"model_variant": "BASE-LOWER-SIGHTLINE-v2",
				"model_version": 2,
				"site": "BASE-R1",
				"span": "",
				"support": {},
				"transform": [
					-0.4780147671699524,
					0.0,
					-0.8783518671989441,
					0.0,
					1.0,
					0.0,
					0.8783518671989441,
					0.0,
					-0.4780147671699524,
					18.24445152282715,
					0.0,
					5.502226829528809
				],
				"wall": {}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:BASE-R1.CONCOURSE",
				"item": "ST-031",
				"model_variant": "STRAIGHT-CONCOURSE-GUARD-v2",
				"model_version": 2,
				"site": "BASE-R1.CONCOURSE",
				"span": "",
				"support": {
					"interface": "ST029-guard-v2_REAR-STAIR-SADDLE-v2",
					"lower": "npc-candidate:AM-02:left-loft-v1:BASE-R1"
				},
				"transform": [
					-0.4780147671699524,
					0.0,
					-0.8783518671989441,
					0.0,
					1.0,
					0.0,
					0.8783518671989441,
					0.0,
					-0.4780147671699524,
					18.24445152282715,
					0.0,
					5.502226829528809
				],
				"wall": {}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:BASE-R1.UPPER",
				"item": "ST-030",
				"model_variant": "STRAIGHT-UPPER-GUARD-v2",
				"model_version": 2,
				"site": "BASE-R1.UPPER",
				"span": "",
				"support": {
					"concourse": "npc-candidate:AM-02:left-loft-v1:BASE-R1.CONCOURSE",
					"interface": "ST031-guard-v2_STRAIGHT-CANTILEVER-v2",
					"lower": "npc-candidate:AM-02:left-loft-v1:BASE-R1"
				},
				"transform": [
					-0.4780147671699524,
					0.0,
					-0.8783518671989441,
					0.0,
					1.0,
					0.0,
					0.8783518671989441,
					0.0,
					-0.4780147671699524,
					18.24445152282715,
					0.0,
					5.502226829528809
				],
				"wall": {}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:BASE-R1.ROOF-UPPER",
				"item": "ST-053",
				"model_variant": "STRAIGHT-UPPER-CANOPY-v2",
				"model_version": 2,
				"site": "BASE-R1.ROOF-UPPER",
				"span": "",
				"support": {
					"concourse": "npc-candidate:AM-02:left-loft-v1:BASE-R1.CONCOURSE",
					"interface": "ST030-guard-v2_PYLON-CAP-v2",
					"lower": "npc-candidate:AM-02:left-loft-v1:BASE-R1",
					"mount": "BASE-UPPER-ROOF-v1",
					"upper": "npc-candidate:AM-02:left-loft-v1:BASE-R1.UPPER"
				},
				"transform": [
					-0.4780147671699524,
					0.0,
					-0.8783518671989441,
					0.0,
					1.0,
					0.0,
					0.8783518671989441,
					0.0,
					-0.4780147671699524,
					18.24445152282715,
					0.0,
					5.502226829528809
				],
				"wall": {}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:BASE-R2",
				"item": "ST-029",
				"model_variant": "BASE-LOWER-SIGHTLINE-v2",
				"model_version": 2,
				"site": "BASE-R2",
				"span": "",
				"support": {},
				"transform": [
					-0.4780147671699524,
					0.0,
					-0.8783518671989441,
					0.0,
					1.0,
					0.0,
					0.8783518671989441,
					0.0,
					-0.4780147671699524,
					21.112539291381836,
					0.0,
					10.772337913513184
				],
				"wall": {}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:BASE-R2.CONCOURSE",
				"item": "ST-031",
				"model_variant": "STRAIGHT-CONCOURSE-GUARD-v2",
				"model_version": 2,
				"site": "BASE-R2.CONCOURSE",
				"span": "",
				"support": {
					"interface": "ST029-guard-v2_REAR-STAIR-SADDLE-v2",
					"lower": "npc-candidate:AM-02:left-loft-v1:BASE-R2"
				},
				"transform": [
					-0.4780147671699524,
					0.0,
					-0.8783518671989441,
					0.0,
					1.0,
					0.0,
					0.8783518671989441,
					0.0,
					-0.4780147671699524,
					21.112539291381836,
					0.0,
					10.772337913513184
				],
				"wall": {}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:BASE-R2.UPPER",
				"item": "ST-030",
				"model_variant": "STRAIGHT-UPPER-GUARD-v2",
				"model_version": 2,
				"site": "BASE-R2.UPPER",
				"span": "",
				"support": {
					"concourse": "npc-candidate:AM-02:left-loft-v1:BASE-R2.CONCOURSE",
					"interface": "ST031-guard-v2_STRAIGHT-CANTILEVER-v2",
					"lower": "npc-candidate:AM-02:left-loft-v1:BASE-R2"
				},
				"transform": [
					-0.4780147671699524,
					0.0,
					-0.8783518671989441,
					0.0,
					1.0,
					0.0,
					0.8783518671989441,
					0.0,
					-0.4780147671699524,
					21.112539291381836,
					0.0,
					10.772337913513184
				],
				"wall": {}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:BASE-R2.ROOF-UPPER",
				"item": "ST-053",
				"model_variant": "STRAIGHT-UPPER-CANOPY-v2",
				"model_version": 2,
				"site": "BASE-R2.ROOF-UPPER",
				"span": "",
				"support": {
					"concourse": "npc-candidate:AM-02:left-loft-v1:BASE-R2.CONCOURSE",
					"interface": "ST030-guard-v2_PYLON-CAP-v2",
					"lower": "npc-candidate:AM-02:left-loft-v1:BASE-R2",
					"mount": "BASE-UPPER-ROOF-v1",
					"upper": "npc-candidate:AM-02:left-loft-v1:BASE-R2.UPPER"
				},
				"transform": [
					-0.4780147671699524,
					0.0,
					-0.8783518671989441,
					0.0,
					1.0,
					0.0,
					0.8783518671989441,
					0.0,
					-0.4780147671699524,
					21.112539291381836,
					0.0,
					10.772337913513184
				],
				"wall": {}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:BOWL-01",
				"item": "ST-081",
				"model_variant": "",
				"model_version": 1,
				"site": "BOWL-01",
				"span": "",
				"support": {},
				"transform": [
					-0.5000000596046448,
					0.0,
					-0.8660253882408142,
					0.0,
					1.0,
					0.0,
					0.8660253882408142,
					0.0,
					-0.5000000596046448,
					0.0,
					0.0,
					0.0
				],
				"wall": {}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:BOWL-02",
				"item": "ST-081",
				"model_variant": "",
				"model_version": 1,
				"site": "BOWL-02",
				"span": "",
				"support": {},
				"transform": [
					-0.8660253882408142,
					0.0,
					-0.5000000596046448,
					0.0,
					1.0,
					0.0,
					0.5000000596046448,
					0.0,
					-0.8660253882408142,
					0.0,
					0.0,
					0.0
				],
				"wall": {}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:BOWL-03",
				"item": "ST-081",
				"model_variant": "",
				"model_version": 1,
				"site": "BOWL-03",
				"span": "",
				"support": {},
				"transform": [
					-1.0,
					0.0,
					8.742277657347586e-08,
					0.0,
					1.0,
					0.0,
					-8.742277657347586e-08,
					0.0,
					-1.0,
					0.0,
					0.0,
					0.0
				],
				"wall": {}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:BOWL-04",
				"item": "ST-081",
				"model_variant": "",
				"model_version": 1,
				"site": "BOWL-04",
				"span": "",
				"support": {},
				"transform": [
					-0.8660253882408142,
					0.0,
					0.4999999701976776,
					0.0,
					1.0,
					0.0,
					-0.4999999701976776,
					0.0,
					-0.8660253882408142,
					0.0,
					0.0,
					0.0
				],
				"wall": {}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:BOWL-05",
				"item": "ST-081",
				"model_variant": "",
				"model_version": 1,
				"site": "BOWL-05",
				"span": "",
				"support": {},
				"transform": [
					-0.49999991059303284,
					0.0,
					0.866025447845459,
					0.0,
					1.0,
					0.0,
					-0.866025447845459,
					0.0,
					-0.49999991059303284,
					0.0,
					0.0,
					0.0
				],
				"wall": {}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:JOIN-R",
				"item": "ST-085",
				"model_variant": "",
				"model_version": 1,
				"site": "JOIN-R",
				"span": "",
				"support": {},
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
					0.0
				],
				"wall": {}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:JOIN-L",
				"item": "ST-088",
				"model_variant": "",
				"model_version": 1,
				"site": "JOIN-L",
				"span": "",
				"support": {},
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
					0.0
				],
				"wall": {}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:SCORE-SMALL",
				"item": "ST-039",
				"model_variant": "",
				"model_version": 1,
				"site": "SCORE-SMALL",
				"span": "",
				"support": {},
				"transform": [
					-1.0,
					0.0,
					8.742277657347586e-08,
					0.0,
					1.0,
					0.0,
					-8.742277657347586e-08,
					0.0,
					-1.0,
					-20.0,
					0.0,
					30.0
				],
				"wall": {}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:PLIGHT-HL",
				"item": "ST-076",
				"model_variant": "",
				"model_version": 1,
				"site": "PLIGHT-HL",
				"span": "",
				"support": {},
				"transform": [
					0.6667948365211487,
					0.0,
					-0.7452412843704224,
					0.0,
					1.0,
					0.0,
					0.7452412843704224,
					0.0,
					0.6667948365211487,
					-46.0,
					0.0,
					-22.0
				],
				"wall": {}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:PLIGHT-HR",
				"item": "ST-076",
				"model_variant": "",
				"model_version": 1,
				"site": "PLIGHT-HR",
				"span": "",
				"support": {},
				"transform": [
					0.6667948365211487,
					0.0,
					0.7452412843704224,
					0.0,
					1.0,
					0.0,
					-0.7452412843704224,
					0.0,
					0.6667948365211487,
					46.0,
					0.0,
					-22.0
				],
				"wall": {}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:PLIGHT-OL",
				"item": "ST-076",
				"model_variant": "",
				"model_version": 1,
				"site": "PLIGHT-OL",
				"span": "",
				"support": {},
				"transform": [
					-0.6441357731819153,
					0.0,
					-0.7649111747741699,
					0.0,
					1.0,
					0.0,
					0.7649111747741699,
					0.0,
					-0.6441357731819153,
					-46.0,
					0.0,
					50.0
				],
				"wall": {}
			},
			{
				"host": "npc-venue:AM-02:left-loft-v1",
				"instance": "npc-candidate:AM-02:left-loft-v1:PLIGHT-OR",
				"item": "ST-076",
				"model_variant": "",
				"model_version": 1,
				"site": "PLIGHT-OR",
				"span": "",
				"support": {},
				"transform": [
					-0.6441357731819153,
					0.0,
					0.7649111747741699,
					0.0,
					1.0,
					0.0,
					-0.7649111747741699,
					0.0,
					-0.6441357731819153,
					46.0,
					0.0,
					50.0
				],
				"wall": {}
			}
		],
		"kind": "npc-authored-candidate",
		"lighting": {
			"active_lights": 0,
			"dormant": true,
			"preset": "LIGHT-MOGUL-4X076-v1",
			"profile": "MOGUL4-PREMIUM",
			"towers": [
				{
					"heads": [
						{
							"direction": [
								0.7258239984512329,
								-0.2916414439678192,
								0.6229966878890991
							],
							"id": "HEAD-1",
							"origin": [
								-46.588356018066406,
								17.00508689880371,
								-21.12155532836914
							]
						},
						{
							"direction": [
								0.717193603515625,
								-0.29169172048568726,
								0.6328897476196289
							],
							"id": "HEAD-2",
							"origin": [
								-46.122928619384766,
								17.00507926940918,
								-21.641700744628906
							]
						},
						{
							"direction": [
								0.7084380388259888,
								-0.29169172048568726,
								0.6426753997802734
							],
							"id": "HEAD-3",
							"origin": [
								-45.65752410888672,
								17.00507926940918,
								-22.161863327026367
							]
						},
						{
							"direction": [
								0.6995618343353271,
								-0.2916414439678192,
								0.652348518371582
							],
							"id": "HEAD-4",
							"origin": [
								-45.19213104248047,
								17.00508689880371,
								-22.68204116821289
							]
						},
						{
							"direction": [
								0.7225880026817322,
								-0.30527836084365845,
								0.6202191114425659
							],
							"id": "HEAD-5",
							"origin": [
								-46.5888557434082,
								17.802988052368164,
								-21.12198257446289
							]
						},
						{
							"direction": [
								0.7139949202537537,
								-0.3053305149078369,
								0.6300670504570007
							],
							"id": "HEAD-6",
							"origin": [
								-46.1234245300293,
								17.802980422973633,
								-21.642135620117188
							]
						},
						{
							"direction": [
								0.7052784562110901,
								-0.3053305447101593,
								0.6398090720176697
							],
							"id": "HEAD-7",
							"origin": [
								-45.65800857543945,
								17.802980422973633,
								-22.162303924560547
							]
						},
						{
							"direction": [
								0.6964429020881653,
								-0.30527836084365845,
								0.6494400501251221
							],
							"id": "HEAD-8",
							"origin": [
								-45.19261169433594,
								17.802988052368164,
								-22.6824893951416
							]
						}
					],
					"profile": "MOGUL4-PREMIUM",
					"site": "PLIGHT-HL",
					"target": [
						-8.0,
						1.5,
						12.0
					]
				},
				{
					"heads": [
						{
							"direction": [
								-0.6995618343353271,
								-0.2916414439678192,
								0.652348518371582
							],
							"id": "HEAD-1",
							"origin": [
								45.19213104248047,
								17.00508689880371,
								-22.68204116821289
							]
						},
						{
							"direction": [
								-0.7084380388259888,
								-0.29169172048568726,
								0.6426753997802734
							],
							"id": "HEAD-2",
							"origin": [
								45.65752410888672,
								17.00507926940918,
								-22.161863327026367
							]
						},
						{
							"direction": [
								-0.717193603515625,
								-0.29169172048568726,
								0.6328897476196289
							],
							"id": "HEAD-3",
							"origin": [
								46.122928619384766,
								17.00507926940918,
								-21.641700744628906
							]
						},
						{
							"direction": [
								-0.7258239984512329,
								-0.2916414439678192,
								0.6229966878890991
							],
							"id": "HEAD-4",
							"origin": [
								46.588356018066406,
								17.00508689880371,
								-21.12155532836914
							]
						},
						{
							"direction": [
								-0.6964429020881653,
								-0.30527836084365845,
								0.6494400501251221
							],
							"id": "HEAD-5",
							"origin": [
								45.19261169433594,
								17.802988052368164,
								-22.6824893951416
							]
						},
						{
							"direction": [
								-0.7052784562110901,
								-0.3053305447101593,
								0.6398090720176697
							],
							"id": "HEAD-6",
							"origin": [
								45.65800857543945,
								17.802980422973633,
								-22.162303924560547
							]
						},
						{
							"direction": [
								-0.7139949202537537,
								-0.3053305149078369,
								0.6300670504570007
							],
							"id": "HEAD-7",
							"origin": [
								46.1234245300293,
								17.802980422973633,
								-21.642135620117188
							]
						},
						{
							"direction": [
								-0.7225880026817322,
								-0.30527836084365845,
								0.6202191114425659
							],
							"id": "HEAD-8",
							"origin": [
								46.5888557434082,
								17.802988052368164,
								-21.12198257446289
							]
						}
					],
					"profile": "MOGUL4-PREMIUM",
					"site": "PLIGHT-HR",
					"target": [
						8.0,
						1.5,
						12.0
					]
				},
				{
					"heads": [
						{
							"direction": [
								0.7168478965759277,
								-0.2986573874950409,
								-0.6300260424613953
							],
							"id": "HEAD-1",
							"origin": [
								-45.21326446533203,
								17.004005432128906,
								50.70613098144531
							]
						},
						{
							"direction": [
								0.7256391048431396,
								-0.2987113893032074,
								-0.6198543906211853
							],
							"id": "HEAD-2",
							"origin": [
								-45.662803649902344,
								17.003997802734375,
								50.17226028442383
							]
						},
						{
							"direction": [
								0.7343006730079651,
								-0.298711359500885,
								-0.60956871509552
							],
							"id": "HEAD-3",
							"origin": [
								-46.11236572265625,
								17.003997802734375,
								49.63840866088867
							]
						},
						{
							"direction": [
								0.7428278923034668,
								-0.2986573874950409,
								-0.5991747975349426
							],
							"id": "HEAD-4",
							"origin": [
								-46.561946868896484,
								17.004005432128906,
								49.10456848144531
							]
						},
						{
							"direction": [
								0.7134974002838135,
								-0.3125546872615814,
								-0.6270813345909119
							],
							"id": "HEAD-5",
							"origin": [
								-45.21377944946289,
								17.80186653137207,
								50.70658493041992
							]
						},
						{
							"direction": [
								0.7222462892532349,
								-0.3126106560230255,
								-0.6169561743736267
							],
							"id": "HEAD-6",
							"origin": [
								-45.663326263427734,
								17.80185890197754,
								50.172706604003906
							]
						},
						{
							"direction": [
								0.7308673858642578,
								-0.3126106560230255,
								-0.6067185997962952
							],
							"id": "HEAD-7",
							"origin": [
								-46.112892150878906,
								17.80185890197754,
								49.63884735107422
							]
						},
						{
							"direction": [
								0.7393560409545898,
								-0.3125546872615814,
								-0.5963742136955261
							],
							"id": "HEAD-8",
							"origin": [
								-46.56248092651367,
								17.80186653137207,
								49.105003356933594
							]
						}
					],
					"profile": "MOGUL4-PREMIUM",
					"site": "PLIGHT-OL",
					"target": [
						-8.0,
						1.5,
						18.0
					]
				},
				{
					"heads": [
						{
							"direction": [
								-0.7428278923034668,
								-0.2986573874950409,
								-0.5991747975349426
							],
							"id": "HEAD-1",
							"origin": [
								46.561946868896484,
								17.004005432128906,
								49.10456848144531
							]
						},
						{
							"direction": [
								-0.7343006730079651,
								-0.298711359500885,
								-0.60956871509552
							],
							"id": "HEAD-2",
							"origin": [
								46.11236572265625,
								17.003997802734375,
								49.63840866088867
							]
						},
						{
							"direction": [
								-0.7256391048431396,
								-0.2987113893032074,
								-0.6198543906211853
							],
							"id": "HEAD-3",
							"origin": [
								45.662803649902344,
								17.003997802734375,
								50.17226028442383
							]
						},
						{
							"direction": [
								-0.7168478965759277,
								-0.2986573874950409,
								-0.6300260424613953
							],
							"id": "HEAD-4",
							"origin": [
								45.21326446533203,
								17.004005432128906,
								50.70613098144531
							]
						},
						{
							"direction": [
								-0.7393560409545898,
								-0.3125546872615814,
								-0.5963742136955261
							],
							"id": "HEAD-5",
							"origin": [
								46.56248092651367,
								17.80186653137207,
								49.105003356933594
							]
						},
						{
							"direction": [
								-0.7308673858642578,
								-0.3126106560230255,
								-0.6067185997962952
							],
							"id": "HEAD-6",
							"origin": [
								46.112892150878906,
								17.80185890197754,
								49.63884735107422
							]
						},
						{
							"direction": [
								-0.7222462892532349,
								-0.3126106560230255,
								-0.6169561743736267
							],
							"id": "HEAD-7",
							"origin": [
								45.663326263427734,
								17.80185890197754,
								50.172706604003906
							]
						},
						{
							"direction": [
								-0.7134974002838135,
								-0.3125546872615814,
								-0.6270813345909119
							],
							"id": "HEAD-8",
							"origin": [
								45.21377944946289,
								17.80186653137207,
								50.70658493041992
							]
						}
					],
					"profile": "MOGUL4-PREMIUM",
					"site": "PLIGHT-OR",
					"target": [
						8.0,
						1.5,
						18.0
					]
				}
			]
		},
		"live_units": 0,
		"mapping": "WORKING",
		"owner": "npc-venue:AM-02:left-loft-v1",
		"property": "mogul",
		"receiver": {
			"catch": "npc-candidate:AM-02:left-loft-v1:RECEIVER-CATCH",
			"id": "RX-TARGET-026-073-v1:corrected-ST073-v2",
			"pair_version": 1,
			"primary": "npc-candidate:AM-02:left-loft-v1:RECEIVER-PRIMARY",
			"role": "RECEIVER_CONTAINMENT_FOUL"
		},
		"render_profile": {
			"headless": "no-op",
			"helper": "res://src/presentation/stadium/stadium_wall_render_quality.gd",
			"helper_sha256": "a342c1bda3e7c5d4d3d8f004eb76d6044a0f7a7305181429226f3c2e3c8c39d7",
			"higher_quality": "preserve",
			"id": "STADIUM-WALL-MSAA4X-v1",
			"native_minimum_msaa_3d": "4x",
			"ownership": "installed-property-viewport-lifetime",
			"restore": "last-owner-if-unchanged"
		},
		"source_contract":
		"Blueprint-v114:DE15892-15923:CM14400-14560:Working-shaped-away:corrected-ST073-v2",
		"status": "CANDIDATE",
		"structural_layers": {
			"baseline": "BASE-UPPER-ROOF-GUARD-v2",
			"bowl": "BOWL-LOWER-v1",
			"curved_concourses": 0,
			"curved_roofs": 0,
			"curved_uppers": 0,
			"finished_ends": "independent-baseline-upper-ends-beside-lower-only-neighbors",
			"roofs": 4,
			"transition_concourses": 0
		},
		"surface": {
			"bounds": [
				-52,
				-30,
				104,
				88
			],
			"geometry": "flat",
			"grass": "default",
			"ground": "default",
			"markings": "default"
		},
		"version": 1,
		"wall_piece_catalog": "fc95048f0179e7d18a58d0a6f50bfbf1a18bfc036f1ce4d8ddbf6076cc6b1383",
		"wall_piece_ownership": "3c544a7d07a07a76fe24bce6234c4c469f097eb8dec455d25a9e40b1b6ea9620"
	}

static func transform(values: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(values[0], values[1], values[2]),
		Vector3(values[3], values[4], values[5]), Vector3(values[6], values[7], values[8])),
		Vector3(values[9], values[10], values[11]))


static func canonical() -> Dictionary:
	# Finite declared scene vectors use engine float32 storage. All other authored data stays
	# exactly typed and valued. Raw payload text and archived bytes retain separate source pins.
	return _reconstruct(payload(), "$", _vector_paths())


static func normalized(value: Variant) -> Dictionary:
	var vectors: Dictionary = _vector_paths()
	if not _structure(value, payload(), "$", vectors):
		return {}
	var result: Dictionary = _reconstruct(value.duplicate(true), "$", vectors)
	return result if JSON.stringify(result, "", true, true) == JSON.stringify(
		canonical(), "", true, true) else {}


static func _vector_paths() -> Dictionary:
	# Explicit finite paths only. Camera authoring floats, physical scalar constants, prices,
	# versions, field exports and all other non-scene values are deliberately not reconstructed.
	var result: Dictionary = {"$.field.mound_origin": 3}
	var items: Array = payload().items
	for index in range(91):
		result["$.items[%d].transform" % index] = 12
		if items[index].wall.size() > 0:
			result["$.items[%d].wall.a" % index] = 2
			result["$.items[%d].wall.b" % index] = 2
	for index in range(18):
		result["$.graph.segments[%d].a" % index] = 2
		result["$.graph.segments[%d].b" % index] = 2
	for index in range(2):
		result["$.graph.poles[%d].position" % index] = 3
	for tower in range(4):
		result["$.lighting.towers[%d].target" % tower] = 3
		for head in range(8):
			result["$.lighting.towers[%d].heads[%d].origin" % [tower, head]] = 3
			result["$.lighting.towers[%d].heads[%d].direction" % [tower, head]] = 3
	return result


static func _structure(
	value: Variant, expected: Variant, path: String, vectors: Dictionary
) -> bool:
	if vectors.has(path):
		if not value is Array or value.size() != vectors[path]:
			return false
		for number: Variant in value:
			if not (number is int or number is float) or not is_finite(float(number)) \
				or number < -1000 or number > 1000:
				return false
		return true
	if expected is Dictionary:
		if not value is Dictionary or value.size() != expected.size():
			return false
		for key: Variant in expected:
			if not value.has(key) or not _structure(value[key], expected[key],
				path + "." + str(key), vectors):
				return false
		return true
	if expected is Array:
		if not value is Array or value.size() != expected.size():
			return false
		for index in range(expected.size()):
			if not _structure(value[index], expected[index], path + "[%d]" % index, vectors):
				return false
		return true
	return typeof(value) == typeof(expected) and value == expected


static func _reconstruct(value: Variant, path: String, vectors: Dictionary) -> Variant:
	if vectors.has(path):
		var result: Array = Array(PackedFloat32Array(value))
		for index in range(result.size()):
			if result[index] == 0.0:
				result[index] = 0.0
		return result
	if value is Dictionary:
		for key: Variant in value:
			value[key] = _reconstruct(value[key], path + "." + str(key), vectors)
	elif value is Array:
		for index in range(value.size()):
			value[index] = _reconstruct(value[index], path + "[%d]" % index, vectors)
	return value
