class_name StadiumNpcClubTwoDefinitionV1
extends RefCounted
## Immutable AC-02/r1 RightShelf daylight. Seventy-five exact existing copies, zero live units.
## Frozen descriptive valuation is nonspendable; no catalog recomputation or stock grant.
# gdlint: disable=max-file-lines

const SHA256: String = "81bf357269937420a99b7711ea4e96e0ead70982f20c6d963be710693ed95ceb"


static func payload() -> Dictionary:
	return {
		"assembly": {
			"id": "AC-02-public-right-shelf-r1",
			"version": 1
		},
		"blueprints": [
			"ST-021",
			"ST-022",
			"ST-023",
			"ST-026",
			"ST-029",
			"ST-038",
			"ST-039",
			"ST-053",
			"ST-065",
			"ST-065-L",
			"ST-073",
			"ST-074"
		],
		"catalog": {
			"sha256": "5210c3c47688b06faa35a50ec211f65de0a881debc5d7567a4c0e2abe6df204f",
			"version": 1
		},
		"environment_certificates": [],
		"field": "field.npc_venue",
		"graph": {
			"id": "PROTOTYPE-CLUB-DUGOUT-RIGHT-SHELF-v1",
			"version": 1,
			"sha256": "d9ee942c608d655f6d5814ec5f37f12da4790f0f0ff06430c3b11a62bf52f0ec"
		},
		"id": "AC-02",
		"instances": [
			{
				"host": "field",
				"instance": "npc:AC-02:r1:BASE-L1",
				"item": "ST-029",
				"site": "BASE-L1",
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
				"host": "field",
				"instance": "npc:AC-02:r1:BASE-L2",
				"item": "ST-029",
				"site": "BASE-L2",
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
				]
			},
			{
				"host": "npc:AC-02:r1:BASE-L2",
				"instance": "npc:AC-02:r1:BASE-L2.ROOF-LOWER",
				"item": "ST-053",
				"site": "BASE-L2.ROOF-LOWER",
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
				"host": "field",
				"instance": "npc:AC-02:r1:BASE-R1",
				"item": "ST-029",
				"site": "BASE-R1",
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
				"host": "field",
				"instance": "npc:AC-02:r1:BASE-R2",
				"item": "ST-029",
				"site": "BASE-R2",
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
				]
			},
			{
				"host": "npc:AC-02:r1:BASE-R2",
				"instance": "npc:AC-02:r1:BASE-R2.ROOF-LOWER",
				"item": "ST-053",
				"site": "BASE-R2.ROOF-LOWER",
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
				"host": "field",
				"instance": "npc:AC-02:r1:CLIGHT-HL",
				"site": "CLIGHT-HL",
				"item": "ST-038",
				"transform": [
					0.786318302154541,
					0.0,
					-0.6178215742111206,
					0.0,
					1.0,
					0.0,
					0.6178215742111206,
					0.0,
					0.786318302154541,
					-30.0,
					0.0,
					-16.0
				]
			},
			{
				"host": "field",
				"instance": "npc:AC-02:r1:CLIGHT-HR",
				"site": "CLIGHT-HR",
				"item": "ST-038",
				"transform": [
					0.786318302154541,
					0.0,
					0.6178215742111206,
					0.0,
					1.0,
					0.0,
					-0.6178215742111206,
					0.0,
					0.786318302154541,
					30.0,
					0.0,
					-16.0
				]
			},
			{
				"host": "field",
				"instance": "npc:AC-02:r1:CLIGHT-OL",
				"site": "CLIGHT-OL",
				"item": "ST-038",
				"transform": [
					-0.6919053792953491,
					0.0,
					-0.7219882011413574,
					0.0,
					1.0,
					0.0,
					0.7219882011413574,
					0.0,
					-0.6919053792953491,
					-32.0,
					0.0,
					38.0
				]
			},
			{
				"host": "field",
				"instance": "npc:AC-02:r1:CLIGHT-OR",
				"site": "CLIGHT-OR",
				"item": "ST-038",
				"transform": [
					-0.6919053792953491,
					0.0,
					0.7219882011413574,
					0.0,
					1.0,
					0.0,
					-0.7219882011413574,
					0.0,
					-0.6919053792953491,
					32.0,
					0.0,
					38.0
				]
			},
			{
				"host": "field",
				"instance": "npc:AC-02:r1:DUGOUT-L",
				"item": "ST-074",
				"site": "DUGOUT-L",
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
				"host": "field",
				"instance": "npc:AC-02:r1:DUGOUT-R",
				"item": "ST-074",
				"site": "DUGOUT-R",
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
				"host": "field",
				"instance": "npc:AC-02:r1:FOUL-POLE-L",
				"site": "FOUL-POLE-L",
				"item": "ST-021",
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
					-21.165977478027344,
					0.0,
					23.507200241088867
				]
			},
			{
				"host": "field",
				"instance": "npc:AC-02:r1:FOUL-POLE-R",
				"site": "FOUL-POLE-R",
				"item": "ST-021",
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
					20.657140731811523,
					0.0,
					22.94207763671875
				]
			},
			{
				"host": "field",
				"instance": "npc:AC-02:r1:RECEIVER-CATCH",
				"item": "ST-073",
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
					0.0
				]
			},
			{
				"host": "field",
				"instance": "npc:AC-02:r1:RECEIVER-PRIMARY",
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
				"instance": "npc:AC-02:r1:SCORE-SMALL",
				"site": "SCORE-SMALL",
				"item": "ST-039",
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
				"host": "field",
				"instance": "npc:AC-02:r1:ST-022-01",
				"item": "ST-022",
				"site": "ST-022-01",
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
				"host": "field",
				"instance": "npc:AC-02:r1:ST-022-02",
				"item": "ST-022",
				"site": "ST-022-02",
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
				"host": "field",
				"instance": "npc:AC-02:r1:ST-022-03",
				"item": "ST-022",
				"site": "ST-022-03",
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
				"host": "field",
				"instance": "npc:AC-02:r1:ST-022-04",
				"item": "ST-022",
				"site": "ST-022-04",
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
				"host": "field",
				"instance": "npc:AC-02:r1:ST-022-05",
				"item": "ST-022",
				"site": "ST-022-05",
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
				"host": "field",
				"instance": "npc:AC-02:r1:ST-022-06",
				"item": "ST-022",
				"site": "ST-022-06",
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
				"host": "field",
				"instance": "npc:AC-02:r1:ST-022-07",
				"item": "ST-022",
				"site": "ST-022-07",
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
				"host": "field",
				"instance": "npc:AC-02:r1:ST-022-08",
				"item": "ST-022",
				"site": "ST-022-08",
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
				"host": "field",
				"instance": "npc:AC-02:r1:ST-022-09",
				"item": "ST-022",
				"site": "ST-022-09",
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
				"host": "field",
				"instance": "npc:AC-02:r1:ST-022-10",
				"item": "ST-022",
				"site": "ST-022-10",
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
				"host": "field",
				"instance": "npc:AC-02:r1:ST-022-11",
				"item": "ST-022",
				"site": "ST-022-11",
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
				"host": "field",
				"instance": "npc:AC-02:r1:ST-022-15",
				"item": "ST-022",
				"site": "ST-022-15",
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
				"host": "field",
				"instance": "npc:AC-02:r1:ST-022-16",
				"item": "ST-022",
				"site": "ST-022-16",
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
				"host": "field",
				"instance": "npc:AC-02:r1:ST-022-17",
				"item": "ST-022",
				"site": "ST-022-17",
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
				"host": "field",
				"instance": "npc:AC-02:r1:ST-022-18",
				"item": "ST-022",
				"site": "ST-022-18",
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
				"host": "field",
				"instance": "npc:AC-02:r1:ST-022-19",
				"item": "ST-022",
				"site": "ST-022-19",
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
				"host": "field",
				"instance": "npc:AC-02:r1:ST-023-01",
				"item": "ST-023",
				"site": "ST-023-01",
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
				"host": "field",
				"instance": "npc:AC-02:r1:ST-023-02",
				"item": "ST-023",
				"site": "ST-023-02",
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
				"host": "field",
				"instance": "npc:AC-02:r1:ST-023-03",
				"item": "ST-023",
				"site": "ST-023-03",
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
				"host": "field",
				"instance": "npc:AC-02:r1:ST-023-04",
				"item": "ST-023",
				"site": "ST-023-04",
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
				"host": "field",
				"instance": "npc:AC-02:r1:ST-023-05",
				"item": "ST-023",
				"site": "ST-023-05",
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
				"host": "field",
				"instance": "npc:AC-02:r1:ST-023-09",
				"item": "ST-023",
				"site": "ST-023-09",
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
				"host": "field",
				"instance": "npc:AC-02:r1:ST-023-10",
				"item": "ST-023",
				"site": "ST-023-10",
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
				"host": "field",
				"instance": "npc:AC-02:r1:ST-023-11",
				"item": "ST-023",
				"site": "ST-023-11",
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
				"host": "field",
				"instance": "npc:AC-02:r1:ST-023-12",
				"item": "ST-023",
				"site": "ST-023-12",
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
				"host": "field",
				"instance": "npc:AC-02:r1:ST-023-13",
				"item": "ST-023",
				"site": "ST-023-13",
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
				"host": "field",
				"instance": "npc:AC-02:r1:ST-023-14",
				"item": "ST-023",
				"site": "ST-023-14",
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
				"host": "field",
				"instance": "npc:AC-02:r1:ST-023-15",
				"item": "ST-023",
				"site": "ST-023-15",
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
				"host": "field",
				"instance": "npc:AC-02:r1:ST-023-16",
				"item": "ST-023",
				"site": "ST-023-16",
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
				"host": "field",
				"instance": "npc:AC-02:r1:ST-023-17",
				"item": "ST-023",
				"site": "ST-023-17",
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
				"host": "field",
				"instance": "npc:AC-02:r1:ST-023-18",
				"item": "ST-023",
				"site": "ST-023-18",
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
				"host": "field",
				"instance": "npc:AC-02:r1:ST-023-19",
				"item": "ST-023",
				"site": "ST-023-19",
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
				"host": "field",
				"instance": "npc:AC-02:r1:right_shelf-00",
				"site": "right_shelf-00",
				"item": "ST-065-L",
				"transform": [
					-0.8831937313079834,
					0.0,
					-0.46900832653045654,
					0.0,
					1.0,
					0.0,
					0.46900832653045654,
					0.0,
					-0.8831937313079834,
					20.636260986328125,
					0.0,
					22.930992126464844
				]
			},
			{
				"host": "field",
				"instance": "npc:AC-02:r1:right_shelf-01",
				"site": "right_shelf-01",
				"item": "ST-065-L",
				"transform": [
					-0.8831937313079834,
					0.0,
					-0.46900832653045654,
					0.0,
					1.0,
					0.0,
					0.46900832653045654,
					0.0,
					-0.8831937313079834,
					18.869873046875,
					0.0,
					21.99297332763672
				]
			},
			{
				"host": "field",
				"instance": "npc:AC-02:r1:right_shelf-02",
				"site": "right_shelf-02",
				"item": "ST-065-L",
				"transform": [
					-0.8831937313079834,
					0.0,
					-0.4690083861351013,
					0.0,
					1.0,
					0.0,
					0.4690083861351013,
					0.0,
					-0.8831937313079834,
					17.49333953857422,
					0.0,
					21.26198387145996
				]
			},
			{
				"host": "field",
				"instance": "npc:AC-02:r1:right_shelf-03",
				"site": "right_shelf-03",
				"item": "ST-065-L",
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
					16.0,
					0.0,
					21.0
				]
			},
			{
				"host": "field",
				"instance": "npc:AC-02:r1:right_shelf-04",
				"site": "right_shelf-04",
				"item": "ST-065-L",
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
					14.0,
					0.0,
					21.0
				]
			},
			{
				"host": "field",
				"instance": "npc:AC-02:r1:right_shelf-05",
				"site": "right_shelf-05",
				"item": "ST-065-L",
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
					12.0,
					0.0,
					21.0
				]
			},
			{
				"host": "field",
				"instance": "npc:AC-02:r1:right_shelf-06",
				"site": "right_shelf-06",
				"item": "ST-065-L",
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
					10.5,
					0.0,
					21.0
				]
			},
			{
				"host": "field",
				"instance": "npc:AC-02:r1:right_shelf-07",
				"site": "right_shelf-07",
				"item": "ST-065",
				"transform": [
					-0.7999998927116394,
					0.0,
					0.6000001430511475,
					0.0,
					1.0,
					0.0,
					-0.6000001430511475,
					0.0,
					-0.7999998927116394,
					9.199999809265137,
					0.0,
					21.600000381469727
				]
			},
			{
				"host": "field",
				"instance": "npc:AC-02:r1:right_shelf-08",
				"site": "right_shelf-08",
				"item": "ST-065",
				"transform": [
					-0.7999998331069946,
					0.0,
					0.6000003218650818,
					0.0,
					1.0,
					0.0,
					-0.6000003218650818,
					0.0,
					-0.7999998331069946,
					7.59999942779541,
					0.0,
					22.80000114440918
				]
			},
			{
				"host": "field",
				"instance": "npc:AC-02:r1:right_shelf-09",
				"site": "right_shelf-09",
				"item": "ST-065",
				"transform": [
					-0.7999998331069946,
					0.0,
					0.6000003218650818,
					0.0,
					1.0,
					0.0,
					-0.6000003218650818,
					0.0,
					-0.7999998331069946,
					6.0,
					0.0,
					24.000001907348633
				]
			},
			{
				"host": "field",
				"instance": "npc:AC-02:r1:right_shelf-10",
				"site": "right_shelf-10",
				"item": "ST-065",
				"transform": [
					-0.8000001311302185,
					0.0,
					0.5999998450279236,
					0.0,
					1.0,
					0.0,
					-0.5999998450279236,
					0.0,
					-0.8000001311302185,
					4.599999904632568,
					0.0,
					25.050003051757812
				]
			},
			{
				"host": "field",
				"instance": "npc:AC-02:r1:right_shelf-11",
				"site": "right_shelf-11",
				"item": "ST-065",
				"transform": [
					-0.986393928527832,
					0.0,
					0.1643991470336914,
					0.0,
					1.0,
					0.0,
					-0.1643991470336914,
					0.0,
					-0.986393928527832,
					3.013606071472168,
					0.0,
					25.664398193359375
				]
			},
			{
				"host": "field",
				"instance": "npc:AC-02:r1:right_shelf-12",
				"site": "right_shelf-12",
				"item": "ST-065",
				"transform": [
					-0.986393928527832,
					0.0,
					0.1643991619348526,
					0.0,
					1.0,
					0.0,
					-0.1643991619348526,
					0.0,
					-0.986393928527832,
					1.040818214416504,
					0.0,
					25.99319839477539
				]
			},
			{
				"host": "field",
				"instance": "npc:AC-02:r1:right_shelf-13",
				"site": "right_shelf-13",
				"item": "ST-065",
				"transform": [
					-0.986393928527832,
					0.0,
					0.1643991619348526,
					0.0,
					1.0,
					0.0,
					-0.1643991619348526,
					0.0,
					-0.986393928527832,
					-0.9319694638252258,
					0.0,
					26.32199478149414
				]
			},
			{
				"host": "field",
				"instance": "npc:AC-02:r1:right_shelf-14",
				"site": "right_shelf-14",
				"item": "ST-065",
				"transform": [
					-0.986393928527832,
					0.0,
					0.1643991619348526,
					0.0,
					1.0,
					0.0,
					-0.1643991619348526,
					0.0,
					-0.986393928527832,
					-2.904757022857666,
					0.0,
					26.650794982910156
				]
			},
			{
				"host": "field",
				"instance": "npc:AC-02:r1:right_shelf-15",
				"site": "right_shelf-15",
				"item": "ST-065",
				"transform": [
					-0.986393928527832,
					0.0,
					0.1643991470336914,
					0.0,
					1.0,
					0.0,
					-0.1643991470336914,
					0.0,
					-0.986393928527832,
					-4.87754487991333,
					0.0,
					26.979591369628906
				]
			},
			{
				"host": "field",
				"instance": "npc:AC-02:r1:right_shelf-16",
				"site": "right_shelf-16",
				"item": "ST-065",
				"transform": [
					-0.9863938689231873,
					0.0,
					0.16439911723136902,
					0.0,
					1.0,
					0.0,
					-0.16439911723136902,
					0.0,
					-0.9863938689231873,
					-6.397953987121582,
					0.0,
					27.232994079589844
				]
			},
			{
				"host": "field",
				"instance": "npc:AC-02:r1:right_shelf-17",
				"site": "right_shelf-17",
				"item": "ST-065",
				"transform": [
					-0.9863938689231873,
					0.0,
					0.16439911723136902,
					0.0,
					1.0,
					0.0,
					-0.16439911723136902,
					0.0,
					-0.9863938689231873,
					-7.465984344482422,
					0.0,
					27.410999298095703
				]
			},
			{
				"host": "field",
				"instance": "npc:AC-02:r1:right_shelf-18",
				"site": "right_shelf-18",
				"item": "ST-065",
				"transform": [
					-0.9569616317749023,
					0.0,
					-0.29021453857421875,
					0.0,
					1.0,
					0.0,
					0.29021453857421875,
					0.0,
					-0.9569616317749023,
					-8.956961631774902,
					0.0,
					27.20978546142578
				]
			},
			{
				"host": "field",
				"instance": "npc:AC-02:r1:right_shelf-19",
				"site": "right_shelf-19",
				"item": "ST-065",
				"transform": [
					-0.9569616317749023,
					0.0,
					-0.29021453857421875,
					0.0,
					1.0,
					0.0,
					0.29021453857421875,
					0.0,
					-0.9569616317749023,
					-10.870884895324707,
					0.0,
					26.629356384277344
				]
			},
			{
				"host": "field",
				"instance": "npc:AC-02:r1:right_shelf-20",
				"site": "right_shelf-20",
				"item": "ST-065",
				"transform": [
					-0.9569616317749023,
					0.0,
					-0.29021453857421875,
					0.0,
					1.0,
					0.0,
					0.29021453857421875,
					0.0,
					-0.9569616317749023,
					-12.784808158874512,
					0.0,
					26.048927307128906
				]
			},
			{
				"host": "field",
				"instance": "npc:AC-02:r1:right_shelf-21",
				"site": "right_shelf-21",
				"item": "ST-065",
				"transform": [
					-0.9569616317749023,
					0.0,
					-0.29021453857421875,
					0.0,
					1.0,
					0.0,
					0.29021453857421875,
					0.0,
					-0.9569616317749023,
					-14.698731422424316,
					0.0,
					25.46849822998047
				]
			},
			{
				"host": "field",
				"instance": "npc:AC-02:r1:right_shelf-22",
				"site": "right_shelf-22",
				"item": "ST-065",
				"transform": [
					-0.9569616317749023,
					0.0,
					-0.29021453857421875,
					0.0,
					1.0,
					0.0,
					0.29021453857421875,
					0.0,
					-0.9569616317749023,
					-16.612655639648438,
					0.0,
					24.88806915283203
				]
			},
			{
				"host": "field",
				"instance": "npc:AC-02:r1:right_shelf-23",
				"site": "right_shelf-23",
				"item": "ST-065",
				"transform": [
					-0.9569616317749023,
					0.0,
					-0.29021453857421875,
					0.0,
					1.0,
					0.0,
					0.29021453857421875,
					0.0,
					-0.9569616317749023,
					-18.52657699584961,
					0.0,
					24.307640075683594
				]
			},
			{
				"host": "field",
				"instance": "npc:AC-02:r1:right_shelf-24",
				"site": "right_shelf-24",
				"item": "ST-065",
				"transform": [
					-0.9569618105888367,
					0.0,
					-0.29021403193473816,
					0.0,
					1.0,
					0.0,
					0.29021403193473816,
					0.0,
					-0.9569618105888367,
					-19.99251937866211,
					0.0,
					23.863069534301758
				]
			},
			{
				"host": "field",
				"instance": "npc:AC-02:r1:right_shelf-25",
				"site": "right_shelf-25",
				"item": "ST-065",
				"transform": [
					-0.9569618105888367,
					0.0,
					-0.29021403193473816,
					0.0,
					1.0,
					0.0,
					0.29021403193473816,
					0.0,
					-0.9569618105888367,
					-21.010475158691406,
					0.0,
					23.554357528686523
				]
			}
		],
		"land": {
			"stages": [
				"expanded",
				"club"
			],
			"tier": "club",
			"version": 1
		},
		"live_units": 0,
		"models": {
			"starter_field": {
				"version": 1,
				"sha256": "b4cb96881a07e3980ecf4aba157bd7137b82ec75cb3d21b155d5bd2f699e1416"
			},
			"field_definition": {
				"version": 1,
				"sha256": "39cf09ce92b00c8c0d784f5e738623b810b512a12c3b3c9294a5133b33f413d2"
			},
			"stadium_height_wall_recipes": {
				"version": 1,
				"sha256": "30db6125b6c027ad762ebf4efbf84610f461c0f5def0c61f1591859cd90a768c"
			},
			"stadium_height_boundary": {
				"version": 1,
				"sha256": "6f39aff94fd087469348afa40ebf55799d07ac0b4f1407d66ad4101d803e388f"
			},
			"stadium_recipe_boundary": {
				"version": 1,
				"sha256": "a98381fd78d1f32fcd58ad7dbd2f29b29634c7b3572159980e781ffb6c66aca8"
			},
			"stadium_dugout_boundary": {
				"version": 1,
				"sha256": "8e7cb6c7ede2e74c399df58ecb7bfe509a26ff0f0aedb23644baf39e3c0cf888"
			},
			"stadium_dugout_recipe": {
				"version": 1,
				"sha256": "9426ec13fc1ab673cafd856c0611dbd6aa6f90056d0315197cfb6313f6cc38a4"
			},
			"stadium_wall_recipes": {
				"version": 1,
				"sha256": "2225255afd3ded7bddb8a94ac1ee639e91a4c2c77806e17f70db21f13fd822e5"
			},
			"stadium_foul_pole_sites": {
				"version": 1,
				"sha256": "1e5f4c4c106c3b15f587ab2d46a81ec64d10ddafe434919643b973c51f067ff1"
			},
			"stadium_baseline_sites": {
				"version": 1,
				"sha256": "e59935264c2da05b2e009048a089284006826094715e28f656c3f2b48450efff"
			},
			"stadium_height_wall_study": {
				"version": 1,
				"sha256": "6ea91b74375790034a7252ed9b97cd06afe5292bc4034bd83ac6ce25e8cd032b"
			},
			"stadium_wall_panel_models": {
				"version": 1,
				"sha256": "aa2cb103cf6998f81466c9173bdb3eb206a91835f84857e73380ca98e38ada7b"
			},
			"stadium_concrete_dugout_models": {
				"version": 1,
				"sha256": "ac4ab6504e2c24b08e2693d1b0f821dcac2849b98b5a5be836eace0044c8ed21"
			},
			"stadium_foul_pole_models": {
				"version": 1,
				"sha256": "5e28063a3e8bc26412279df18861640c63604f8d3adbf8934f4363337d73eb53"
			},
			"stadium_target_models": {
				"version": 1,
				"sha256": "0334e3bc2588f17a2a7ec1f6d64209dedea8336c67461930415248f228d7ba0a"
			},
			"stadium_receiver_net_models": {
				"version": 1,
				"sha256": "cec34955f5d8d52b9a7df68034667cb2ba10fab29aaf612f257f0fe20a2ad7ef"
			},
			"stadium_baseline_stand_models": {
				"version": 1,
				"sha256": "75e3700469a43ac53c6e3778a8de614893d7b154e66d5c5295bca341fd4ac13a"
			},
			"stadium_four_head_tower_models": {
				"version": 1,
				"sha256": "4bfe5bb1b81e8f2db5698a0a8456863d790b8a605bb1cfa7c00b2f5840e30119"
			},
			"stadium_npc_club_board_v1": {
				"version": 1,
				"sha256": "792fb4ec6ebe637fcfcf9da73137d2c509853106d655ed8d894d47162aad5411"
			},
			"stadium_npc_club_v1": {
				"version": 1,
				"sha256": "7c2a80cd6b1110be93799ccb7046272c745f22c830bb0b3536a39647c403c081"
			},
			"stadium_npc_retained_ball_readability": {
				"version": 1,
				"sha256": "31d98283912ab0b748df3cb5d3208dcda0d54913502959f3ba37928a66d7503e"
			},
			"stadium_wall_render_quality": {
				"version": 1,
				"sha256": "a342c1bda3e7c5d4d3d8f004eb76d6044a0f7a7305181429226f3c2e3c8c39d7"
			},
			"stadium_npc_ac02_public_graph": {
				"version": 1,
				"sha256": "7c7a63a44feb7c1e4fa443c9241cb084744c4c4381870d5e372f3abd5546c367"
			},
			"stadium_npc_ac02_public_boundary": {
				"version": 1,
				"sha256": "be575a88d5581110152cb474e4c646eb6bfae01ff2e7cb75f37e62d172ad6cca"
			},
			"stadium_npc_ac02_public_boundary_source": {
				"version": 1,
				"sha256": "59fd392368b4ba96cb1b292b59974f780219c8b98847b2e8ff349a88cec701e4"
			},
			"stadium_npc_ac02_public_camera": {
				"version": 1,
				"sha256": "4dc6ec4df48f2e26989cace001e915bcf68e179829f50dd3bc0dd5769bd10745"
			},
			"stadium_npc_ac02_public_construction": {
				"version": 1,
				"sha256": "24873743264f1854870ff1c215796da04c2d05fc1ec16c0e9e00f543d17c789b"
			},
			"stadium_npc_ac02_public_guides": {
				"version": 1,
				"sha256": "58f5350b895cfba5260b5f9c45709fecbbd8e4f9d70e04736f5dc664d2683f87"
			},
			"stadium_npc_ac02_public_light_sites": {
				"version": 1,
				"sha256": "90e850ddaa6cc8bc3a35dc7b837af039e46020ece3b4beb689b5a63eda36d6fc"
			},
			"stadium_npc_ac02_public_receiver": {
				"version": 1,
				"sha256": "4570a9d1f45ba8cf481bcbe2a2b6ebee9fd6f6a4569c0c8fedef88b4a069ba44"
			},
			"stadium_npc_ac02_public_sweep": {
				"version": 1,
				"sha256": "c0a8a865fa247f00a2813fe267c154e8588c2cc742b831d1bff6eec58e8d8aa6"
			},
			"stadium_npc_ac02_public_visibility": {
				"version": 1,
				"sha256": "dd921f01e0bf6a3d393ecd29c599ed46a77e183a6041658a221d8bd6fd12cf6a"
			}
		},
		"presentation": {
			"profile": "AC-02-right-shelf-daylight-v1",
			"options": {}
		},
		"revision": 1,
		"routing_version": 1,
		"rules_version": 1,
		"shape": "right_shelf",
		"surface_version": 1,
		"tier": "club",
		"valuation": {
			"blueprints": 4790,
			"copies": 3465,
			"land": 2200,
			"price_sha256": "5210c3c47688b06faa35a50ec211f65de0a881debc5d7567a4c0e2abe6df204f",
			"price_version": 1,
			"total": 10455
		},
		"version": 1
	}
