class_name StadiumLongYardDefinitionV1
extends RefCounted
## Immutable LONG-YARD authored v2 / public r1, exact67 existing copies.
## Descriptive endowment is nonspendable. Fixed-slot presentation is not certification.
## Neutral owner lives in the separate finals contract, never an NPC owner_club field.
# gdlint: disable=max-file-lines

const SHA256: String = "3e8acd3047f510f5128cf51e2f759a6ed04db8f7ee166e0f67c25099136fc01c"


static func canonical() -> Dictionary:
	return StadiumNpcManifest.canonical_shape(payload())


static func payload() -> Dictionary:
	return {
		"version": 1,
		"id": "LONG-YARD",
		"revision": 1,
		"assembly": {
			"id": "LONG-YARD-public-deeper-center-v2",
			"version": 2
		},
		"field": "field.npc_venue",
		"tier": "club",
		"shape": "deeper_center",
		"rules_version": 1,
		"graph": {
			"id": "PROTOTYPE-CLUB-DUGOUT-DEEPER-CENTER-v1",
			"version": 1,
			"sha256": "329df908c5c38c496a73cb2c4265d5eed53f2d2da7bfbbb7ade04c808e0a6dcf"
		},
		"catalog": {
			"version": 1,
			"sha256": "5210c3c47688b06faa35a50ec211f65de0a881debc5d7567a4c0e2abe6df204f"
		},
		"models": {
			"field-resource": {
				"version": 1,
				"sha256": "a9df5523562f2a237d205e72b252729a6a248dc2bbfd789d51d6f1e4c587b598"
			},
			"field-semantics": {
				"version": 1,
				"sha256": "39cf09ce92b00c8c0d784f5e738623b810b512a12c3b3c9294a5133b33f413d2"
			},
			"field-base": {
				"version": 1,
				"sha256": "d03b3f1f855f51f1f2e3a99f1be99a626cfe523e39c76bd9576b16cb6af4876f"
			},
			"common-club-surface": {
				"version": 1,
				"sha256": "7c2a80cd6b1110be93799ccb7046272c745f22c830bb0b3536a39647c403c081"
			},
			"boundary-semantics": {
				"version": 1,
				"sha256": "8e7cb6c7ede2e74c399df58ecb7bfe509a26ff0f0aedb23644baf39e3c0cf888"
			},
			"recipe-semantics": {
				"version": 1,
				"sha256": "a98381fd78d1f32fcd58ad7dbd2f29b29634c7b3572159980e781ffb6c66aca8"
			},
			"wall-recipes": {
				"version": 1,
				"sha256": "2225255afd3ded7bddb8a94ac1ee639e91a4c2c77806e17f70db21f13fd822e5"
			},
			"wall-panels": {
				"version": 2,
				"sha256": "aa2cb103cf6998f81466c9173bdb3eb206a91835f84857e73380ca98e38ada7b"
			},
			"dugout-recipes": {
				"version": 1,
				"sha256": "9426ec13fc1ab673cafd856c0611dbd6aa6f90056d0315197cfb6313f6cc38a4"
			},
			"concrete-dugout": {
				"version": 1,
				"sha256": "ac4ab6504e2c24b08e2693d1b0f821dcac2849b98b5a5be836eace0044c8ed21"
			},
			"foul-pole-sites": {
				"version": 1,
				"sha256": "1e5f4c4c106c3b15f587ab2d46a81ec64d10ddafe434919643b973c51f067ff1"
			},
			"foul-pole": {
				"version": 1,
				"sha256": "5e28063a3e8bc26412279df18861640c63604f8d3adbf8934f4363337d73eb53"
			},
			"primary-target": {
				"version": 1,
				"sha256": "0334e3bc2588f17a2a7ec1f6d64209dedea8336c67461930415248f228d7ba0a"
			},
			"catch-net": {
				"version": 2,
				"sha256": "cec34955f5d8d52b9a7df68034667cb2ba10fab29aaf612f257f0fe20a2ad7ef"
			},
			"baseline-sites": {
				"version": 1,
				"sha256": "e59935264c2da05b2e009048a089284006826094715e28f656c3f2b48450efff"
			},
			"baseline-lower": {
				"version": 1,
				"sha256": "75e3700469a43ac53c6e3778a8de614893d7b154e66d5c5295bca341fd4ac13a"
			},
			"baseline-guard": {
				"version": 2,
				"sha256": "4fd7a994315acd1705f707ac36a18716d7f4304d2a2aa12bf464438c57d3d215"
			},
			"lower-roof": {
				"version": 2,
				"sha256": "6e9e2327dceff712af8cdfd41c13ea2ccdabd3a4b14bd9e8fe5b6760a5efdacc"
			},
			"lower-roof-sites": {
				"version": 1,
				"sha256": "a56270540ba3ae0dd9dbdd670a65c4634caebc3bb28b50f3fed244b061b88106"
			},
			"manual-board": {
				"version": 1,
				"sha256": "c05a9a6c77791a12cbc9b5191240e3f96e94adec6aa239db5ce6e3f974eaa61f"
			},
			"score-display": {
				"version": 1,
				"sha256": "a0d660fe489aaf487b8dca84d350e83efb41163abd39d75385319c45fdcb151c"
			},
			"seating-parts": {
				"version": 1,
				"sha256": "56f1ed7ceb4576b6887a48ad785209bf964965e8eb9bbcd708345a8ee4aa03eb"
			},
			"starter-parts": {
				"version": 1,
				"sha256": "c9e92051b1627a3043ebf6cb802940a24570851676cd8718ae1c475bda964138"
			},
			"wall-render-quality": {
				"version": 1,
				"sha256": "a342c1bda3e7c5d4d3d8f004eb76d6044a0f7a7305181429226f3c2e3c8c39d7"
			},
			"public-construction": {
				"version": 1,
				"sha256": "3077470204e07a9786241bfb720ec0449ed1f11f75272e2474e5f4c31c554860"
			},
			"public-boundary-source": {
				"version": 1,
				"sha256": "86cd303e1402c17d3faad0ea7c876b8872ae068f9a9faea2acc79c0fc59945b6"
			}
		},
		"instances": [
			{
				"instance": "npc:LONG-YARD:r1:BASE-L1",
				"item": "ST-029",
				"site": "BASE-L1",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:BASE-L2",
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
				"instance": "npc:LONG-YARD:r1:BASE-R1",
				"item": "ST-029",
				"site": "BASE-R1",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:BASE-R2",
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
				"instance": "npc:LONG-YARD:r1:DUGOUT-L",
				"item": "ST-074",
				"site": "DUGOUT-L",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:DUGOUT-R",
				"item": "ST-074",
				"site": "DUGOUT-R",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:FOUL-POLE-L",
				"item": "ST-021",
				"site": "FOUL-POLE-L",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:FOUL-POLE-R",
				"item": "ST-021",
				"site": "FOUL-POLE-R",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:RECEIVER-CATCH",
				"item": "ST-073",
				"site": "RECEIVER-CATCH",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:RECEIVER-PRIMARY",
				"item": "ST-026",
				"site": "RECEIVER-PRIMARY",
				"host": "field",
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
				"host": "npc:LONG-YARD:r1:BASE-L2",
				"instance": "npc:LONG-YARD:r1:ROOF:BASE-L2",
				"item": "ST-053",
				"site": "ROOF:BASE-L2",
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
				"host": "npc:LONG-YARD:r1:BASE-R2",
				"instance": "npc:LONG-YARD:r1:ROOF:BASE-R2",
				"item": "ST-053",
				"site": "ROOF:BASE-R2",
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
				"instance": "npc:LONG-YARD:r1:SCORE-SMALL",
				"item": "ST-039",
				"site": "SCORE-SMALL",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-022-01",
				"item": "ST-022",
				"site": "ST-022-01",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-022-02",
				"item": "ST-022",
				"site": "ST-022-02",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-022-03",
				"item": "ST-022",
				"site": "ST-022-03",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-022-04",
				"item": "ST-022",
				"site": "ST-022-04",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-022-05",
				"item": "ST-022",
				"site": "ST-022-05",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-022-06",
				"item": "ST-022",
				"site": "ST-022-06",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-022-07",
				"item": "ST-022",
				"site": "ST-022-07",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-022-08",
				"item": "ST-022",
				"site": "ST-022-08",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-022-09",
				"item": "ST-022",
				"site": "ST-022-09",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-022-10",
				"item": "ST-022",
				"site": "ST-022-10",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-022-11",
				"item": "ST-022",
				"site": "ST-022-11",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-022-15",
				"item": "ST-022",
				"site": "ST-022-15",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-022-16",
				"item": "ST-022",
				"site": "ST-022-16",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-022-17",
				"item": "ST-022",
				"site": "ST-022-17",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-022-18",
				"item": "ST-022",
				"site": "ST-022-18",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-022-19",
				"item": "ST-022",
				"site": "ST-022-19",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-023-01",
				"item": "ST-023",
				"site": "ST-023-01",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-023-02",
				"item": "ST-023",
				"site": "ST-023-02",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-023-03",
				"item": "ST-023",
				"site": "ST-023-03",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-023-04",
				"item": "ST-023",
				"site": "ST-023-04",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-023-05",
				"item": "ST-023",
				"site": "ST-023-05",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-023-09",
				"item": "ST-023",
				"site": "ST-023-09",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-023-10",
				"item": "ST-023",
				"site": "ST-023-10",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-023-11",
				"item": "ST-023",
				"site": "ST-023-11",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-023-12",
				"item": "ST-023",
				"site": "ST-023-12",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-023-13",
				"item": "ST-023",
				"site": "ST-023-13",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-023-14",
				"item": "ST-023",
				"site": "ST-023-14",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-023-15",
				"item": "ST-023",
				"site": "ST-023-15",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-023-16",
				"item": "ST-023",
				"site": "ST-023-16",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-023-17",
				"item": "ST-023",
				"site": "ST-023-17",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-023-18",
				"item": "ST-023",
				"site": "ST-023-18",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-023-19",
				"item": "ST-023",
				"site": "ST-023-19",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-065-01",
				"item": "ST-065",
				"site": "ST-065-01",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-065-02",
				"item": "ST-065",
				"site": "ST-065-02",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-065-03",
				"item": "ST-065",
				"site": "ST-065-03",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-065-04",
				"item": "ST-065",
				"site": "ST-065-04",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-065-05",
				"item": "ST-065",
				"site": "ST-065-05",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-065-06",
				"item": "ST-065",
				"site": "ST-065-06",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-065-07",
				"item": "ST-065",
				"site": "ST-065-07",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-065-08",
				"item": "ST-065",
				"site": "ST-065-08",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-065-09",
				"item": "ST-065",
				"site": "ST-065-09",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-065-10",
				"item": "ST-065",
				"site": "ST-065-10",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-065-11",
				"item": "ST-065",
				"site": "ST-065-11",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-065-12",
				"item": "ST-065",
				"site": "ST-065-12",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-065-13",
				"item": "ST-065",
				"site": "ST-065-13",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-065-14",
				"item": "ST-065",
				"site": "ST-065-14",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-065-15",
				"item": "ST-065",
				"site": "ST-065-15",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-065-16",
				"item": "ST-065",
				"site": "ST-065-16",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-065-17",
				"item": "ST-065",
				"site": "ST-065-17",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-065-18",
				"item": "ST-065",
				"site": "ST-065-18",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-065-19",
				"item": "ST-065",
				"site": "ST-065-19",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-065-20",
				"item": "ST-065",
				"site": "ST-065-20",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-065-21",
				"item": "ST-065",
				"site": "ST-065-21",
				"host": "field",
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
				"instance": "npc:LONG-YARD:r1:ST-065-22",
				"item": "ST-065",
				"site": "ST-065-22",
				"host": "field",
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
			}
		],
		"blueprints": [
			"ST-021",
			"ST-022",
			"ST-023",
			"ST-026",
			"ST-029",
			"ST-039",
			"ST-053",
			"ST-065",
			"ST-073",
			"ST-074"
		],
		"land": {
			"version": 1,
			"tier": "club",
			"stages": [
				"expanded",
				"club"
			]
		},
		"surface_version": 1,
		"routing_version": 1,
		"environment_certificates": [],
		"presentation": {
			"profile": "LONG-YARD-1610-CLEAR-v1",
			"options": {}
		},
		"live_units": 0,
		"valuation": {
			"price_version": 1,
			"price_sha256": "5210c3c47688b06faa35a50ec211f65de0a881debc5d7567a4c0e2abe6df204f",
			"blueprints": 3750,
			"copies": 2950,
			"land": 2200,
			"total": 8900
		}
	}
