class_name StadiumPoolPartyDefinitionV1
extends RefCounted
## Immutable exact65-copy DB recipe. Existing assets and neutral ownership only.
## Canonical data is not admission, physics qualification or progression authority.
# gdlint: disable=max-file-lines

const SHA256: String = "1bb5e932ded093771946e72a40d38efea13468a14fee18c6dc9fee6c628cf67b"


static func canonical() -> Dictionary:
	return StadiumNpcManifest.canonical_shape(payload())


static func payload() -> Dictionary:
	return {
		"version": 1,
		"id": "POOL-PARTY",
		"revision": 1,
		"assembly": {
			"id": "POOL-PARTY-public-straight-v1",
			"version": 1
		},
		"field": "field.npc_venue",
		"tier": "expanded",
		"shape": "straight",
		"rules_version": 1,
		"graph": {
			"id": "PERIM-POOL-PARTY-TIMBER-STRAIGHT-v1",
			"version": 1,
			"sha256": "a2e51d2a9b8f1238dfec870afc0cf7940237e8fb1f1e74f6363dbe3145aa71cb"
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
			"dugout-boundary-base": {
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
			"timber-dugout": {
				"version": 1,
				"sha256": "e12ec8c7dd758229202a51d4f5111e0bbcf5dc55a49930495802e91977886566"
			},
			"timber-contract": {
				"version": 1,
				"sha256": "83ac392468373e1add76f9bbddd04917ab9be862985cf1fd2e511e6ced00277d"
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
			"portable-net": {
				"version": 2,
				"sha256": "e54036913c3937c78d18cdfe857bd54a55ec883158f27eac13aa7e1080185398"
			},
			"side-seating": {
				"version": 1,
				"sha256": "56f1ed7ceb4576b6887a48ad785209bf964965e8eb9bbcd708345a8ee4aa03eb"
			},
			"side-seating-sites": {
				"version": 1,
				"sha256": "c3deb4bd8d844299438f0e0376185d57d545d0a02d365043762baa2a1e84983c"
			},
			"manual-board": {
				"version": 1,
				"sha256": "c05a9a6c77791a12cbc9b5191240e3f96e94adec6aa239db5ce6e3f974eaa61f"
			},
			"score-display": {
				"version": 1,
				"sha256": "a0d660fe489aaf487b8dca84d350e83efb41163abd39d75385319c45fdcb151c"
			},
			"starter-parts": {
				"version": 1,
				"sha256": "c9e92051b1627a3043ebf6cb802940a24570851676cd8718ae1c475bda964138"
			},
			"pool-geometry": {
				"version": 1,
				"sha256": "f1a52e86332860738bf473fce8bfa4a503049e43528a0e28b24dcaed9d121b76"
			},
			"pool-model": {
				"version": 2,
				"sha256": "0c87e65213cdb81e092a9d25e08daed2bb3ed4800927a0e37868db1fecc3d6cf"
			},
			"pool-contract": {
				"version": 1,
				"sha256": "94f06f487e3d020d5b26441a252e3e1c38d493ec588df69cda8735f40e8db9bd"
			},
			"pool-interior": {
				"version": 2,
				"sha256": "b855b7fd50069188a8426611cd164b0b4cb6a99bf3ff24a84435c14c5cd77ce0"
			},
			"asset-integrity": {
				"version": 1,
				"sha256": "5da71e546e50af6e69aaf1574655c463036ac72e6ab2043886c7828ce5be6a1e"
			},
			"expanded-surface": {
				"version": 1,
				"sha256": "309016beb60b8512b3170e5d558e496cbfec248c6a386911c7b4f4baee96edf8"
			},
			"shared-cold-construction": {
				"version": 1,
				"sha256": "3077470204e07a9786241bfb720ec0449ed1f11f75272e2474e5f4c31c554860"
			},
			"wall-render-quality": {
				"version": 1,
				"sha256": "a342c1bda3e7c5d4d3d8f004eb76d6044a0f7a7305181429226f3c2e3c8c39d7"
			},
			"public-construction": {
				"version": 1,
				"sha256": "c91479f4c84bc9da02a78dfb0c2a655fb022c937e2f3987604d2b6442a2c136c"
			},
			"public-boundary-source": {
				"version": 1,
				"sha256": "d329a6e28b86d9a89fa6ffdcdd78ecdcde1b9f2f1fb6ebf331bed387cf263bb5"
			},
			"timber-boundary": {
				"version": 1,
				"sha256": "915566128388e2ea3d6a0530fc46a9830ce26754fbef41e999c40b93daa90c44"
			}
		},
		"instances": [
			{
				"instance": "npc:POOL-PARTY:r1:DUGOUT-L",
				"item": "ST-032",
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
				"instance": "npc:POOL-PARTY:r1:DUGOUT-R",
				"item": "ST-032",
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
				"instance": "npc:POOL-PARTY:r1:FOUL-POLE-L",
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
					-21.0694580078125,
					0.0,
					23.40000343322754
				]
			},
			{
				"instance": "npc:POOL-PARTY:r1:FOUL-POLE-R",
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
					21.0694580078125,
					0.0,
					23.40000343322754
				]
			},
			{
				"instance": "npc:POOL-PARTY:r1:OL-R",
				"item": "ST-006",
				"site": "OL-R",
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
					12.0,
					0.0,
					18.0
				]
			},
			{
				"instance": "npc:POOL-PARTY:r1:RECEIVER-CATCH",
				"item": "ST-025",
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
					-2.200000047683716
				]
			},
			{
				"instance": "npc:POOL-PARTY:r1:RECEIVER-PRIMARY",
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
				"instance": "npc:POOL-PARTY:r1:SCORE-SMALL",
				"item": "ST-039",
				"site": "SCORE-SMALL",
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
					-20.0,
					0.0,
					30.0
				]
			},
			{
				"instance": "npc:POOL-PARTY:r1:SIDE-SEAT-L",
				"item": "ST-027",
				"site": "SIDE-SEAT-L",
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
					12.5
				]
			},
			{
				"instance": "npc:POOL-PARTY:r1:SIDE-SEAT-R",
				"item": "ST-027",
				"site": "SIDE-SEAT-R",
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
					12.5
				]
			},
			{
				"instance": "npc:POOL-PARTY:r1:ST-022-01",
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
				"instance": "npc:POOL-PARTY:r1:ST-022-02",
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
				"instance": "npc:POOL-PARTY:r1:ST-022-03",
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
				"instance": "npc:POOL-PARTY:r1:ST-022-04",
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
				"instance": "npc:POOL-PARTY:r1:ST-022-05",
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
				"instance": "npc:POOL-PARTY:r1:ST-022-06",
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
				"instance": "npc:POOL-PARTY:r1:ST-022-07",
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
				"instance": "npc:POOL-PARTY:r1:ST-022-08",
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
				"instance": "npc:POOL-PARTY:r1:ST-022-09",
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
				"instance": "npc:POOL-PARTY:r1:ST-022-10",
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
				"instance": "npc:POOL-PARTY:r1:ST-022-11",
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
				"instance": "npc:POOL-PARTY:r1:ST-022-15",
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
				"instance": "npc:POOL-PARTY:r1:ST-022-16",
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
				"instance": "npc:POOL-PARTY:r1:ST-022-17",
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
				"instance": "npc:POOL-PARTY:r1:ST-022-18",
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
				"instance": "npc:POOL-PARTY:r1:ST-022-19",
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
				"instance": "npc:POOL-PARTY:r1:ST-023-01",
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
				"instance": "npc:POOL-PARTY:r1:ST-023-02",
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
				"instance": "npc:POOL-PARTY:r1:ST-023-03",
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
				"instance": "npc:POOL-PARTY:r1:ST-023-04",
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
				"instance": "npc:POOL-PARTY:r1:ST-023-05",
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
				"instance": "npc:POOL-PARTY:r1:ST-023-09",
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
				"instance": "npc:POOL-PARTY:r1:ST-023-10",
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
				"instance": "npc:POOL-PARTY:r1:ST-023-11",
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
				"instance": "npc:POOL-PARTY:r1:ST-023-12",
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
				"instance": "npc:POOL-PARTY:r1:ST-023-13",
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
				"instance": "npc:POOL-PARTY:r1:ST-023-14",
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
				"instance": "npc:POOL-PARTY:r1:ST-023-15",
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
				"instance": "npc:POOL-PARTY:r1:ST-023-16",
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
				"instance": "npc:POOL-PARTY:r1:ST-023-17",
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
				"instance": "npc:POOL-PARTY:r1:ST-023-18",
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
				"instance": "npc:POOL-PARTY:r1:ST-023-19",
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
				"instance": "npc:POOL-PARTY:r1:ST-024-01",
				"item": "ST-024",
				"site": "ST-024-01",
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
					21.259727478027344,
					0.0,
					23.399999618530273
				]
			},
			{
				"instance": "npc:POOL-PARTY:r1:ST-024-02",
				"item": "ST-024",
				"site": "ST-024-02",
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
					20.0,
					0.0,
					23.399999618530273
				]
			},
			{
				"instance": "npc:POOL-PARTY:r1:ST-024-03",
				"item": "ST-024",
				"site": "ST-024-03",
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
					18.0,
					0.0,
					23.399999618530273
				]
			},
			{
				"instance": "npc:POOL-PARTY:r1:ST-024-04",
				"item": "ST-024",
				"site": "ST-024-04",
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
					16.0,
					0.0,
					23.399999618530273
				]
			},
			{
				"instance": "npc:POOL-PARTY:r1:ST-024-05",
				"item": "ST-024",
				"site": "ST-024-05",
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
					14.0,
					0.0,
					23.399999618530273
				]
			},
			{
				"instance": "npc:POOL-PARTY:r1:ST-024-06",
				"item": "ST-024",
				"site": "ST-024-06",
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
					12.0,
					0.0,
					23.399999618530273
				]
			},
			{
				"instance": "npc:POOL-PARTY:r1:ST-024-07",
				"item": "ST-024",
				"site": "ST-024-07",
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
					10.0,
					0.0,
					23.399999618530273
				]
			},
			{
				"instance": "npc:POOL-PARTY:r1:ST-024-08",
				"item": "ST-024",
				"site": "ST-024-08",
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
					7.999999523162842,
					0.0,
					23.399999618530273
				]
			},
			{
				"instance": "npc:POOL-PARTY:r1:ST-024-09",
				"item": "ST-024",
				"site": "ST-024-09",
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
					6.0,
					0.0,
					23.399999618530273
				]
			},
			{
				"instance": "npc:POOL-PARTY:r1:ST-024-10",
				"item": "ST-024",
				"site": "ST-024-10",
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
					4.0,
					0.0,
					23.399999618530273
				]
			},
			{
				"instance": "npc:POOL-PARTY:r1:ST-024-11",
				"item": "ST-024",
				"site": "ST-024-11",
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
					2.0,
					0.0,
					23.399999618530273
				]
			},
			{
				"instance": "npc:POOL-PARTY:r1:ST-024-12",
				"item": "ST-024",
				"site": "ST-024-12",
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
					-9.5367431640625e-07,
					0.0,
					23.399999618530273
				]
			},
			{
				"instance": "npc:POOL-PARTY:r1:ST-024-13",
				"item": "ST-024",
				"site": "ST-024-13",
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
					-2.000001907348633,
					0.0,
					23.399999618530273
				]
			},
			{
				"instance": "npc:POOL-PARTY:r1:ST-024-14",
				"item": "ST-024",
				"site": "ST-024-14",
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
					-4.000000953674316,
					0.0,
					23.399999618530273
				]
			},
			{
				"instance": "npc:POOL-PARTY:r1:ST-024-15",
				"item": "ST-024",
				"site": "ST-024-15",
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
					-6.0,
					0.0,
					23.399999618530273
				]
			},
			{
				"instance": "npc:POOL-PARTY:r1:ST-024-16",
				"item": "ST-024",
				"site": "ST-024-16",
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
					-8.0,
					0.0,
					23.399999618530273
				]
			},
			{
				"instance": "npc:POOL-PARTY:r1:ST-024-17",
				"item": "ST-024",
				"site": "ST-024-17",
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
					-10.0,
					0.0,
					23.399999618530273
				]
			},
			{
				"instance": "npc:POOL-PARTY:r1:ST-024-18",
				"item": "ST-024",
				"site": "ST-024-18",
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
					-12.0,
					0.0,
					23.399999618530273
				]
			},
			{
				"instance": "npc:POOL-PARTY:r1:ST-024-19",
				"item": "ST-024",
				"site": "ST-024-19",
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
					-14.0,
					0.0,
					23.399999618530273
				]
			},
			{
				"instance": "npc:POOL-PARTY:r1:ST-024-20",
				"item": "ST-024",
				"site": "ST-024-20",
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
					-16.0,
					0.0,
					23.399999618530273
				]
			},
			{
				"instance": "npc:POOL-PARTY:r1:ST-024-21",
				"item": "ST-024",
				"site": "ST-024-21",
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
					-18.0,
					0.0,
					23.399999618530273
				]
			},
			{
				"instance": "npc:POOL-PARTY:r1:ST-024-22",
				"item": "ST-024",
				"site": "ST-024-22",
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
					-20.0,
					0.0,
					23.399999618530273
				]
			},
			{
				"instance": "npc:POOL-PARTY:r1:ST-024-23",
				"item": "ST-024",
				"site": "ST-024-23",
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
					-21.259727478027344,
					0.0,
					23.399999618530273
				]
			}
		],
		"blueprints": [
			"ST-006",
			"ST-021",
			"ST-022",
			"ST-023",
			"ST-024",
			"ST-025",
			"ST-026",
			"ST-027",
			"ST-032",
			"ST-039"
		],
		"land": {
			"version": 1,
			"tier": "expanded",
			"stages": [
				"expanded"
			]
		},
		"surface_version": 1,
		"routing_version": 1,
		"environment_certificates": [],
		"presentation": {
			"profile": "POOL-PARTY-1310-CLEAR-v1",
			"options": {}
		},
		"live_units": 4,
		"valuation": {
			"price_version": 1,
			"price_sha256": "5210c3c47688b06faa35a50ec211f65de0a881debc5d7567a4c0e2abe6df204f",
			"blueprints": 3330,
			"copies": 2550,
			"land": 600,
			"total": 6480
		}
	}


static func source_layout() -> Dictionary:
	return {
		"id": "POOL-PARTY-v1",
		"version": 1,
		"owner": "finals-venue:pool-party:v1",
		"recipe": "DB-existing65-copy",
		"status": "Working-qualification-pending",
		"ground": {
			"tier": "expanded",
			"bounds": [
				-32,
				-16,
				64,
				54
			],
			"geometry": "flat"
		},
		"pool": {
			"item": "ST-006",
			"site": "OL-R",
			"position": [
				12,
				0,
				18
			],
			"yaw": 0,
			"scale": [
				1,
				1,
				1
			],
			"ladder_world_direction": "+X",
			"live_units": 4
		},
		"optional_sites": "all-other-sites-empty",
		"crowd": {
			"wooden_bleachers": 2,
			"represented_seats": 20
		},
		"time": "13:10",
		"weather": "clear",
		"night_lighting": false,
		"qualification": "source-only-native-cold-runtime-tests-pending",
		"progression_held": true
	}
