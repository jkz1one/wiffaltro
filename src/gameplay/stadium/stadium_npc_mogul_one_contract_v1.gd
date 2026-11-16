class_name StadiumNpcMogulOneContractV1
extends RefCounted
## Complete literal semantic/pose contract from the byte-pinned archived authoring record.
## The separately pinned raw packet retains its complete 1,500-file qualification source table.
## No disk read, factory lookup or environment authority; fresh deeply isolated data only.
# gdlint: disable=max-file-lines,max-line-length


static func payload() -> Dictionary:
	return {
		"batting_home": "ordinary-match-role-independent-of-venue-owner",
		"blueprint_entitlements": [
			"ST-021",
			"ST-022",
			"ST-023",
			"ST-026",
			"ST-029",
			"ST-038",
			"ST-039",
			"ST-065",
			"ST-073",
			"ST-074",
			"ST-081"
		],
		"boundary": "329df908c5c38c496a73cb2c4265d5eed53f2d2da7bfbbb7ade04c808e0a6dcf",
		"camera_profile": {
			"acquisition": "pre-pitch-only-no-pitch-no-batted-body-no-contact-cut",
			"focus": [
				0,
				1.1,
				7.1
			],
			"id": "AM01-BATTING-BEHIND-RECEIVER-v2",
			"left_entry": [
				-0.18,
				2.1,
				-6.5
			],
			"live_motion": "unchanged-inherited-continuous-motion-turn-and-collision",
			"optics": "unchanged-inherited-75-degree-base-and-Club-live-FOV",
			"predecessor": "inherited-Club-batting-entry-v1:z=-3.38",
			"predecessor_failed_source": "247d9a744292550e16cf658240d2d00cfc7e42048522bf6cee6fad580045a2e6",
			"right_entry": [
				0.18,
				2.1,
				-6.5
			],
			"scope": "installed-AM01-precontact-batting-entry-only"
		},
		"catalog": "5210c3c47688b06faa35a50ec211f65de0a881debc5d7567a4c0e2abe6df204f",
		"crowd": {
			"baseline_lower": 100,
			"bowl_lower": 108,
			"status": "Working-art-density",
			"sway": 0.04,
			"total": 208
		},
		"empty_sites": [
			"BASE-L2",
			"BASE-R2",
			"BOWL-01",
			"BOWL-05",
			"JOIN-L",
			"JOIN-R",
			"LANDMARK-A",
			"SCORE-LARGE-A"
		],
		"endowment": {
			"blueprint_value": 4500,
			"copy_value": 3670,
			"land_value": 6400,
			"total_value": 14570
		},
		"environment": {
			"certificates": [],
			"future_night_profile": "MOGUL6-STANDARD",
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
			"id": "PROTOTYPE-CLUB-DUGOUT-DEEPER-CENTER-v1",
			"ordering": "first-sphere-contact-or-clear-v1",
			"poles": [
				{
					"height": 8.0,
					"position": [
						-21.145462036132812,
						0.0,
						23.48441505432129
					],
					"radius": 0.09,
					"segment": "BACK-03",
					"site": "FOUL-POLE-L",
					"split": 3.25
				},
				{
					"height": 8.0,
					"position": [
						21.145462036132812,
						0.0,
						23.48441505432129
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
						10.0,
						26.0
					],
					"height": 3.25,
					"id": "BACK-01",
					"priority": 200,
					"role": "BACK_WALL_TERMINAL"
				},
				{
					"a": [
						10.0,
						26.0
					],
					"b": [
						-10.0,
						26.0
					],
					"height": 3.25,
					"id": "BACK-02",
					"priority": 200,
					"role": "BACK_WALL_TERMINAL"
				},
				{
					"a": [
						-10.0,
						26.0
					],
					"b": [
						-21.519454956054688,
						23.399999618530273
					],
					"height": 3.25,
					"id": "BACK-03",
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
			"signature": "329df908c5c38c496a73cb2c4265d5eed53f2d2da7bfbbb7ade04c808e0a6dcf",
			"thickness": 0.35,
			"version": 1
		},
		"id": "AM-01",
		"items": [
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-065-01",
				"item": "ST-065",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-065-01",
				"span": "angled_end",
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
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-065-02",
				"item": "ST-065",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-065-02",
				"span": "full",
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
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-065-03",
				"item": "ST-065",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-065-03",
				"span": "full",
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
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-065-04",
				"item": "ST-065",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-065-04",
				"span": "full",
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
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-065-05",
				"item": "ST-065",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-065-05",
				"span": "full",
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
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-065-06",
				"item": "ST-065",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-065-06",
				"span": "full",
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
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-065-07",
				"item": "ST-065",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-065-07",
				"span": "full",
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
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-065-08",
				"item": "ST-065",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-065-08",
				"span": "full",
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
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-065-09",
				"item": "ST-065",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-065-09",
				"span": "full",
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
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-065-10",
				"item": "ST-065",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-065-10",
				"span": "full",
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
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-065-11",
				"item": "ST-065",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-065-11",
				"span": "full",
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
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-065-12",
				"item": "ST-065",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-065-12",
				"span": "full",
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
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-065-13",
				"item": "ST-065",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-065-13",
				"span": "full",
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
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-065-14",
				"item": "ST-065",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-065-14",
				"span": "full",
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
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-065-15",
				"item": "ST-065",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-065-15",
				"span": "full",
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
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-065-16",
				"item": "ST-065",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-065-16",
				"span": "full",
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
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-065-17",
				"item": "ST-065",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-065-17",
				"span": "full",
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
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-065-18",
				"item": "ST-065",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-065-18",
				"span": "full",
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
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-065-19",
				"item": "ST-065",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-065-19",
				"span": "full",
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
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-065-20",
				"item": "ST-065",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-065-20",
				"span": "full",
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
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-065-21",
				"item": "ST-065",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-065-21",
				"span": "full",
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
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-065-22",
				"item": "ST-065",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-065-22",
				"span": "angled_end",
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
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-023-01",
				"item": "ST-023",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-023-01",
				"span": "full",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-023-02",
				"item": "ST-023",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-023-02",
				"span": "full",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-023-03",
				"item": "ST-023",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-023-03",
				"span": "full",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-023-04",
				"item": "ST-023",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-023-04",
				"span": "full",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-023-05",
				"item": "ST-023",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-023-05",
				"span": "full",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-023-09",
				"item": "ST-023",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-023-09",
				"span": "full",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-023-10",
				"item": "ST-023",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-023-10",
				"span": "full",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-023-11",
				"item": "ST-023",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-023-11",
				"span": "full",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-023-12",
				"item": "ST-023",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-023-12",
				"span": "full",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-023-13",
				"item": "ST-023",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-023-13",
				"span": "full",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-023-14",
				"item": "ST-023",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-023-14",
				"span": "full",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-023-15",
				"item": "ST-023",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-023-15",
				"span": "full",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-023-16",
				"item": "ST-023",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-023-16",
				"span": "full",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-023-17",
				"item": "ST-023",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-023-17",
				"span": "side_end",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-023-18",
				"item": "ST-023",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-023-18",
				"span": "full",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-023-19",
				"item": "ST-023",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-023-19",
				"span": "return_end",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-022-01",
				"item": "ST-022",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-022-01",
				"span": "return_end",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-022-02",
				"item": "ST-022",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-022-02",
				"span": "full",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-022-03",
				"item": "ST-022",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-022-03",
				"span": "side_end",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-022-04",
				"item": "ST-022",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-022-04",
				"span": "full",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-022-05",
				"item": "ST-022",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-022-05",
				"span": "full",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-022-06",
				"item": "ST-022",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-022-06",
				"span": "full",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-022-07",
				"item": "ST-022",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-022-07",
				"span": "full",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-022-08",
				"item": "ST-022",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-022-08",
				"span": "full",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-022-09",
				"item": "ST-022",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-022-09",
				"span": "full",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-022-10",
				"item": "ST-022",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-022-10",
				"span": "full",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-022-11",
				"item": "ST-022",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-022-11",
				"span": "full",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-022-15",
				"item": "ST-022",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-022-15",
				"span": "full",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-022-16",
				"item": "ST-022",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-022-16",
				"span": "full",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-022-17",
				"item": "ST-022",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-022-17",
				"span": "full",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-022-18",
				"item": "ST-022",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-022-18",
				"span": "full",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:ST-022-19",
				"item": "ST-022",
				"model_variant": "",
				"model_version": 2,
				"site": "ST-022-19",
				"span": "full",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:DUGOUT-R",
				"item": "ST-074",
				"model_variant": "",
				"model_version": 1,
				"site": "DUGOUT-R",
				"span": "",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:DUGOUT-L",
				"item": "ST-074",
				"model_variant": "",
				"model_version": 1,
				"site": "DUGOUT-L",
				"span": "",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:FOUL-POLE-L",
				"item": "ST-021",
				"model_variant": "",
				"model_version": 1,
				"site": "FOUL-POLE-L",
				"span": "",
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
					-21.145462036132812,
					0.0,
					23.48441505432129
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:FOUL-POLE-R",
				"item": "ST-021",
				"model_variant": "",
				"model_version": 1,
				"site": "FOUL-POLE-R",
				"span": "",
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
					21.145462036132812,
					0.0,
					23.48441505432129
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:RECEIVER-PRIMARY",
				"item": "ST-026",
				"model_variant": "",
				"model_version": 1,
				"site": "RECEIVER-PRIMARY",
				"span": "",
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
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:RECEIVER-CATCH",
				"item": "ST-073",
				"model_variant": "",
				"model_version": 2,
				"site": "RECEIVER-CATCH",
				"span": "",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:BASE-L1",
				"item": "ST-029",
				"model_variant": "BASE-LOWER-SIGHTLINE-v2",
				"model_version": 2,
				"site": "BASE-L1",
				"span": "",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:BASE-R1",
				"item": "ST-029",
				"model_variant": "BASE-LOWER-SIGHTLINE-v2",
				"model_version": 2,
				"site": "BASE-R1",
				"span": "",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:BOWL-02",
				"item": "ST-081",
				"model_variant": "",
				"model_version": 1,
				"site": "BOWL-02",
				"span": "",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:BOWL-03",
				"item": "ST-081",
				"model_variant": "",
				"model_version": 1,
				"site": "BOWL-03",
				"span": "",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:BOWL-04",
				"item": "ST-081",
				"model_variant": "",
				"model_version": 1,
				"site": "BOWL-04",
				"span": "",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:SCORE-SMALL",
				"item": "ST-039",
				"model_variant": "",
				"model_version": 1,
				"site": "SCORE-SMALL",
				"span": "",
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
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:MLIGHT-HL",
				"item": "ST-038",
				"model_variant": "",
				"model_version": 1,
				"site": "MLIGHT-HL",
				"span": "",
				"transform": [
					0.6643638014793396,
					0.0,
					-0.7474093437194824,
					0.0,
					1.0,
					0.0,
					0.7474093437194824,
					0.0,
					0.6643638014793396,
					-46.0,
					0.0,
					-22.0
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:MLIGHT-HR",
				"item": "ST-038",
				"model_variant": "",
				"model_version": 1,
				"site": "MLIGHT-HR",
				"span": "",
				"transform": [
					0.6643638014793396,
					0.0,
					0.7474093437194824,
					0.0,
					1.0,
					0.0,
					-0.7474093437194824,
					0.0,
					0.6643638014793396,
					46.0,
					0.0,
					-22.0
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:MLIGHT-ML",
				"item": "ST-038",
				"model_variant": "",
				"model_version": 1,
				"site": "MLIGHT-ML",
				"span": "",
				"transform": [
					0.02438299171626568,
					0.0,
					-0.9997026920318604,
					0.0,
					1.0,
					0.0,
					0.9997026920318604,
					0.0,
					0.02438299171626568,
					-47.0,
					0.0,
					14.0
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:MLIGHT-MR",
				"item": "ST-038",
				"model_variant": "",
				"model_version": 1,
				"site": "MLIGHT-MR",
				"span": "",
				"transform": [
					0.02438299171626568,
					0.0,
					0.9997026920318604,
					0.0,
					1.0,
					0.0,
					-0.9997026920318604,
					0.0,
					0.02438299171626568,
					47.0,
					0.0,
					14.0
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:MLIGHT-OL",
				"item": "ST-038",
				"model_variant": "",
				"model_version": 1,
				"site": "MLIGHT-OL",
				"span": "",
				"transform": [
					-0.6643638014793396,
					0.0,
					-0.7474093437194824,
					0.0,
					1.0,
					0.0,
					0.7474093437194824,
					0.0,
					-0.6643638014793396,
					-46.0,
					0.0,
					50.0
				]
			},
			{
				"host": "npc-venue:AM-01:deeper-center-v1",
				"instance": "npc-candidate:AM-01:deeper-center-v1:MLIGHT-OR",
				"item": "ST-038",
				"model_variant": "",
				"model_version": 1,
				"site": "MLIGHT-OR",
				"span": "",
				"transform": [
					-0.6643638014793396,
					0.0,
					0.7474093437194824,
					0.0,
					1.0,
					0.0,
					-0.7474093437194824,
					0.0,
					-0.6643638014793396,
					46.0,
					0.0,
					50.0
				]
			}
		],
		"kind": "npc-authored-candidate",
		"lighting": {
			"active_lights": 0,
			"dormant": true,
			"preset": "LIGHT-MOGUL-6X038-v1",
			"profile": "MOGUL6-STANDARD",
			"towers": [
				{
					"heads": [
						{
							"direction": [
								0.7355253100395203,
								-0.2502133548259735,
								0.6295996904373169
							],
							"id": "HEAD-1",
							"origin": [
								-46.495689392089844,
								13.915220260620117,
								-21.239816665649414
							]
						},
						{
							"direction": [
								0.7276199460029602,
								-0.2502497434616089,
								0.6387051939964294
							],
							"id": "HEAD-2",
							"origin": [
								-46.09817123413086,
								13.915215492248535,
								-21.686996459960938
							]
						},
						{
							"direction": [
								0.7196075320243835,
								-0.2502497434616089,
								0.6477190852165222
							],
							"id": "HEAD-3",
							"origin": [
								-45.70066452026367,
								13.915215492248535,
								-22.13418960571289
							]
						},
						{
							"direction": [
								0.7114917039871216,
								-0.2502133846282959,
								0.6566376090049744
							],
							"id": "HEAD-4",
							"origin": [
								-45.30317687988281,
								13.915220260620117,
								-22.581396102905273
							]
						}
					],
					"profile": "MOGUL6-STANDARD",
					"site": "MLIGHT-HL",
					"target": [
						-10.0,
						1.5,
						10.0
					]
				},
				{
					"heads": [
						{
							"direction": [
								-0.7114917039871216,
								-0.2502133846282959,
								0.6566376090049744
							],
							"id": "HEAD-1",
							"origin": [
								45.30317687988281,
								13.915220260620117,
								-22.581396102905273
							]
						},
						{
							"direction": [
								-0.7196075320243835,
								-0.2502497434616089,
								0.6477190852165222
							],
							"id": "HEAD-2",
							"origin": [
								45.70066452026367,
								13.915215492248535,
								-22.13418960571289
							]
						},
						{
							"direction": [
								-0.7276199460029602,
								-0.2502497434616089,
								0.6387051939964294
							],
							"id": "HEAD-3",
							"origin": [
								46.09817123413086,
								13.915215492248535,
								-21.686996459960938
							]
						},
						{
							"direction": [
								-0.7355253100395203,
								-0.2502133548259735,
								0.6295996904373169
							],
							"id": "HEAD-4",
							"origin": [
								46.495689392089844,
								13.915220260620117,
								-21.239816665649414
							]
						}
					],
					"profile": "MOGUL6-STANDARD",
					"site": "MLIGHT-HR",
					"target": [
						10.0,
						1.5,
						10.0
					]
				},
				{
					"heads": [
						{
							"direction": [
								0.956898033618927,
								-0.29041483998298645,
								0.0023388902191072702
							],
							"id": "HEAD-1",
							"origin": [
								-46.88893508911133,
								13.909631729125977,
								14.900057792663574
							]
						},
						{
							"direction": [
								0.9567441940307617,
								-0.29047173261642456,
								0.016333825886249542
							],
							"id": "HEAD-2",
							"origin": [
								-46.87432861328125,
								13.909624099731445,
								14.302181243896484
							]
						},
						{
							"direction": [
								0.9564028382301331,
								-0.2904717028141022,
								0.0303282979875803
							],
							"id": "HEAD-3",
							"origin": [
								-46.859745025634766,
								13.909624099731445,
								13.704304695129395
							]
						},
						{
							"direction": [
								0.9558742046356201,
								-0.29041481018066406,
								0.04431409016251564
							],
							"id": "HEAD-4",
							"origin": [
								-46.84518814086914,
								13.909631729125977,
								13.106427192687988
							]
						}
					],
					"profile": "MOGUL6-STANDARD",
					"site": "MLIGHT-ML",
					"target": [
						-6.0,
						1.5,
						15.0
					]
				},
				{
					"heads": [
						{
							"direction": [
								-0.9558742046356201,
								-0.29041481018066406,
								0.04431409016251564
							],
							"id": "HEAD-1",
							"origin": [
								46.84518814086914,
								13.909631729125977,
								13.106427192687988
							]
						},
						{
							"direction": [
								-0.9564028382301331,
								-0.2904717028141022,
								0.0303282979875803
							],
							"id": "HEAD-2",
							"origin": [
								46.859745025634766,
								13.909624099731445,
								13.704304695129395
							]
						},
						{
							"direction": [
								-0.9567441940307617,
								-0.29047173261642456,
								0.016333825886249542
							],
							"id": "HEAD-3",
							"origin": [
								46.87432861328125,
								13.909624099731445,
								14.302181243896484
							]
						},
						{
							"direction": [
								-0.956898033618927,
								-0.29041483998298645,
								0.0023388902191072702
							],
							"id": "HEAD-4",
							"origin": [
								46.88893508911133,
								13.909631729125977,
								14.900057792663574
							]
						}
					],
					"profile": "MOGUL6-STANDARD",
					"site": "MLIGHT-MR",
					"target": [
						6.0,
						1.5,
						15.0
					]
				},
				{
					"heads": [
						{
							"direction": [
								0.7114916443824768,
								-0.2502133548259735,
								-0.6566376090049744
							],
							"id": "HEAD-1",
							"origin": [
								-45.30317687988281,
								13.915220260620117,
								50.58139419555664
							]
						},
						{
							"direction": [
								0.7196075320243835,
								-0.2502497434616089,
								-0.647719144821167
							],
							"id": "HEAD-2",
							"origin": [
								-45.70066452026367,
								13.915215492248535,
								50.13418960571289
							]
						},
						{
							"direction": [
								0.7276199460029602,
								-0.2502497732639313,
								-0.6387052536010742
							],
							"id": "HEAD-3",
							"origin": [
								-46.09817123413086,
								13.915215492248535,
								49.68699645996094
							]
						},
						{
							"direction": [
								0.7355253100395203,
								-0.2502133846282959,
								-0.6295998096466064
							],
							"id": "HEAD-4",
							"origin": [
								-46.495689392089844,
								13.915220260620117,
								49.23981857299805
							]
						}
					],
					"profile": "MOGUL6-STANDARD",
					"site": "MLIGHT-OL",
					"target": [
						-10.0,
						1.5,
						18.0
					]
				},
				{
					"heads": [
						{
							"direction": [
								-0.7355253100395203,
								-0.2502133846282959,
								-0.6295998096466064
							],
							"id": "HEAD-1",
							"origin": [
								46.495689392089844,
								13.915220260620117,
								49.23981857299805
							]
						},
						{
							"direction": [
								-0.7276199460029602,
								-0.2502497732639313,
								-0.6387052536010742
							],
							"id": "HEAD-2",
							"origin": [
								46.09817123413086,
								13.915215492248535,
								49.68699645996094
							]
						},
						{
							"direction": [
								-0.7196075320243835,
								-0.2502497434616089,
								-0.647719144821167
							],
							"id": "HEAD-3",
							"origin": [
								45.70066452026367,
								13.915215492248535,
								50.13418960571289
							]
						},
						{
							"direction": [
								-0.7114916443824768,
								-0.2502133548259735,
								-0.6566376090049744
							],
							"id": "HEAD-4",
							"origin": [
								45.30317687988281,
								13.915220260620117,
								50.58139419555664
							]
						}
					],
					"profile": "MOGUL6-STANDARD",
					"site": "MLIGHT-OR",
					"target": [
						10.0,
						1.5,
						18.0
					]
				}
			]
		},
		"live_units": 0,
		"mapping": "WORKING",
		"owner": "npc-venue:AM-01:deeper-center-v1",
		"property": "mogul",
		"receiver": {
			"catch": "npc-candidate:AM-01:deeper-center-v1:RECEIVER-CATCH",
			"id": "RX-TARGET-026-073-v1:corrected-ST073-v2",
			"pair_version": 1,
			"primary": "npc-candidate:AM-01:deeper-center-v1:RECEIVER-PRIMARY",
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
		"source_contract": "Blueprint-v114:DE15891:CY15484-15505:CM14400-14560:Working-shaped-away:corrected-ST073-v2",
		"status": "CANDIDATE",
		"structural_layers": {
			"baseline": "BASE-LOWER-SIGHTLINE-v2",
			"bowl": "BOWL-LOWER-v1",
			"roofs": 0,
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
		"version": 1
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
	for index in range(72):
		result["$.items[%d].transform" % index] = 12
	for index in range(16):
		result["$.graph.segments[%d].a" % index] = 2
		result["$.graph.segments[%d].b" % index] = 2
	for index in range(2):
		result["$.graph.poles[%d].position" % index] = 3
	for tower in range(6):
		result["$.lighting.towers[%d].target" % tower] = 3
		for head in range(4):
			result["$.lighting.towers[%d].heads[%d].origin" % [tower, head]] = 3
			result["$.lighting.towers[%d].heads[%d].direction" % [tower, head]] = 3
	return result


static func _structure(value: Variant, expected: Variant, path: String, vectors: Dictionary) -> bool:
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
