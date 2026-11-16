class_name StadiumGrandIIIDefinitionV1
extends RefCounted
## Immutable public r1 of existing GRAND-III-VIDEO-v2: 107 copies / 22 types.
## Working-owner-acceptance-pending. Four dormant ST076 / 32 heads, nine canopies.
## No environment certificate, owner approval, gameplay or progression grant.
# gdlint: disable=max-file-lines

const SHA256: String = "04c82260ff8e5f3682ff355a7a5e9fc8357028f02db920b43983680a23f9d589"


static func canonical() -> Dictionary:
	return StadiumNpcManifest.canonical_shape(payload())


static func payload() -> Dictionary:
	return {
		"version": 1,
		"id": "GRAND-III",
		"revision": 1,
		"assembly": {
			"id": "GRAND-III-public-straight-v1",
			"version": 1
		},
		"field": "field.npc_venue",
		"tier": "mogul",
		"shape": "straight",
		"rules_version": 1,
		"graph": {
			"id": "PROTOTYPE-CLUB-DUGOUT-STRAIGHT-v1",
			"version": 1,
			"sha256": "588f552562b931db0645cbcf65ba45fc6a2bfd635cb1782a2ace7abaec0d4ca2"
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
			"curved-lower": {
				"version": 1,
				"sha256": "816a7a7792450d73440bce70f60e15d0be8446b03b16e8bf214cf596a28b7c17"
			},
			"curved-sites": {
				"version": 1,
				"sha256": "96ade65b25151036696636a86c6f09ceeeabe54dd8b9bab00599b6b6f28cdef8"
			},
			"tower-geometry": {
				"version": 1,
				"sha256": "4bfe5bb1b81e8f2db5698a0a8456863d790b8a605bb1cfa7c00b2f5840e30119"
			},
			"tower-sites": {
				"version": 1,
				"sha256": "71664f9063f38a142b0416ab7be21eec15207298bb0f432d335482b15af7441d"
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
				"sha256": "42194e237db6c501acb8305e84ff7a0aa57050971fbb99024e3e7ae380c95b5e"
			},
			"public-boundary-source": {
				"version": 1,
				"sha256": "bd78c004d56528fcb148f0ac09a4dafd0cf5d41096bbe5879dd5d93cba86fe84"
			},
			"shared-public-construction": {
				"version": 1,
				"sha256": "2188367d2e77c982f1981dbde605661a41ef90cae6be19b7585890728efc0712"
			},
			"curved-stack": {
				"version": 1,
				"sha256": "bf51952cac0741a4720664ad712a2c6fcce7d361a7883e536d4deb6af2319366"
			},
			"curved-stack-sites": {
				"version": 1,
				"sha256": "be49339c61e0e42ddecb86a58e8cdc42846594ce0991d31b7a9e1a1765e7cc80"
			},
			"lower-transition": {
				"version": 1,
				"sha256": "6906b2fb169942c79578bb2b2821f3d4b4fe7abbe4117c0107ed8b239d51407c"
			},
			"lower-transition-sites": {
				"version": 1,
				"sha256": "d8119bceb6e56543fdfb14d598a7dfd72e8b24f53f42e933fb3cc159359efb22"
			},
			"shared-grand-ii-construction": {
				"version": 1,
				"sha256": "ed5ceb346833223dbe582fa0d8ed4788345d4d870e7f4fe5ab18b55cdfed7176"
			},
			"grand-three-stack": {
				"version": 2,
				"sha256": "d39bc2e7c4c205014f07f2439f3ce0f5c756842e5b2a9c613bf5b7c7047ce4a2"
			},
			"grand-three-stack-sites": {
				"version": 2,
				"sha256": "03d86cb7464688a0a3ec861ca6d7b3a43ca55c6b0772063a362b25b43e99c414"
			},
			"straight-stack": {
				"version": 1,
				"sha256": "205a6fac539b4de8b51e59b088274d6e6794e0f2725a23d22b1c0a681b5720ad"
			},
			"straight-stack-sites": {
				"version": 1,
				"sha256": "42f9d01c4b0d4887d25b6243658ea85451aaec0d73de33e02ce76698bcf5f712"
			},
			"curved-canopy": {
				"version": 1,
				"sha256": "6843c66ceed1b5af20cc59c625a8e1e76bbb641a0c7086b6690b62ff3051f4b8"
			},
			"curved-canopy-sites": {
				"version": 1,
				"sha256": "8b4dfc28ab41a3e8b3f7883d5457640e19b006b975896779641d449cf02e1399"
			},
			"transition-concourse": {
				"version": 1,
				"sha256": "7a39445aeaeec6d3963bc981856aaa17e84913970d9382d392028fdb71ff8170"
			},
			"transition-concourse-sites": {
				"version": 1,
				"sha256": "c8c0ec8ec0f2a21223bc631f232b63bebcf1413bef65e95ff2d277b3a1e07036"
			},
			"premium-tower": {
				"version": 1,
				"sha256": "ce1356ae6f1fc11c6363b2aa3f1bd03ba950a5da1813e88f780f862cddb6ad6c"
			},
			"premium-tower-sites": {
				"version": 1,
				"sha256": "6c0e0e8c821e8f0ade13fe7ba7223521c4572ba8acfb064df720e0ceb8b738cc"
			},
			"waterfall": {
				"version": 1,
				"sha256": "49e65674e040be17db057d883be28702e80934ac29463ae6156cdd0183e9409c"
			},
			"waterfall-sites": {
				"version": 1,
				"sha256": "22e1e5d03f42510c588b622bc6e20df2aa640bff8f2b05eff183e77826c187d9"
			},
			"scoreboard-models": {
				"version": 1,
				"sha256": "ab5d5f2c6b49d6d9f47830cf4e83dd7acd1611f92bfddaca8b087c50490851d1"
			},
			"scoreboard-tiers": {
				"version": 2,
				"sha256": "b8ffe92afcf58cd0ec684d42006f5a86ab4fddd7683d80480ca276c4323bb921"
			},
			"scoreboard-tier-display": {
				"version": 1,
				"sha256": "42f93d4acd2d8b4dfc9b25d8fdb40c9df2fa2128dac02e720184df6e703317fb"
			},
			"scoreboard-readout": {
				"version": 1,
				"sha256": "5aeca515729de240e4fa18772ee56ab52aed62746b85a5f69ecc3b179727ae39"
			},
			"scoreboard-catalog": {
				"version": 1,
				"sha256": "30482f13892d0245109e9cf9b7f63558620a53da433eda7542380257198d39ad"
			},
			"scoreboard-sites": {
				"version": 1,
				"sha256": "1e06360bdbc88fb45cc4321b84a6393c6f90bbefa8c74a1e30757a2d6d3e18af"
			},
			"scoreboard-tier-sites": {
				"version": 2,
				"sha256": "2877a534dce360a82dd15e54b6c81259042dfe6f0077889cee864d227fad6908"
			}
		},
		"instances": [
			{
				"instance": "npc:GRAND-III:r1:BASE-L1",
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
				"instance": "npc:GRAND-III:r1:BASE-L1:CONCOURSE",
				"item": "ST-031",
				"site": "BASE-L1:CONCOURSE",
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
				"instance": "npc:GRAND-III:r1:BASE-L1:ROOF",
				"item": "ST-053",
				"site": "BASE-L1:ROOF",
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
				"instance": "npc:GRAND-III:r1:BASE-L1:UPPER",
				"item": "ST-030",
				"site": "BASE-L1:UPPER",
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
				"instance": "npc:GRAND-III:r1:BASE-L2",
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
				"instance": "npc:GRAND-III:r1:BASE-L2:CONCOURSE",
				"item": "ST-031",
				"site": "BASE-L2:CONCOURSE",
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
					-21.112539291381836,
					0.0,
					10.772337913513184
				]
			},
			{
				"instance": "npc:GRAND-III:r1:BASE-L2:ROOF",
				"item": "ST-053",
				"site": "BASE-L2:ROOF",
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
					-21.112539291381836,
					0.0,
					10.772337913513184
				]
			},
			{
				"instance": "npc:GRAND-III:r1:BASE-L2:UPPER",
				"item": "ST-030",
				"site": "BASE-L2:UPPER",
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
					-21.112539291381836,
					0.0,
					10.772337913513184
				]
			},
			{
				"instance": "npc:GRAND-III:r1:BASE-R1",
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
				"instance": "npc:GRAND-III:r1:BASE-R1:CONCOURSE",
				"item": "ST-031",
				"site": "BASE-R1:CONCOURSE",
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
				"instance": "npc:GRAND-III:r1:BASE-R1:ROOF",
				"item": "ST-053",
				"site": "BASE-R1:ROOF",
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
				"instance": "npc:GRAND-III:r1:BASE-R1:UPPER",
				"item": "ST-030",
				"site": "BASE-R1:UPPER",
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
				"instance": "npc:GRAND-III:r1:BASE-R2",
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
				"instance": "npc:GRAND-III:r1:BASE-R2:CONCOURSE",
				"item": "ST-031",
				"site": "BASE-R2:CONCOURSE",
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
					21.112539291381836,
					0.0,
					10.772337913513184
				]
			},
			{
				"instance": "npc:GRAND-III:r1:BASE-R2:ROOF",
				"item": "ST-053",
				"site": "BASE-R2:ROOF",
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
					21.112539291381836,
					0.0,
					10.772337913513184
				]
			},
			{
				"instance": "npc:GRAND-III:r1:BASE-R2:UPPER",
				"item": "ST-030",
				"site": "BASE-R2:UPPER",
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
					21.112539291381836,
					0.0,
					10.772337913513184
				]
			},
			{
				"instance": "npc:GRAND-III:r1:BOARD-LARGE-v2",
				"item": "ST-040",
				"site": "BOARD-LARGE-v2",
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
					36.5,
					0.0,
					31.5
				]
			},
			{
				"instance": "npc:GRAND-III:r1:BOWL-01",
				"item": "ST-081",
				"site": "BOWL-01",
				"host": "field",
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
				]
			},
			{
				"instance": "npc:GRAND-III:r1:BOWL-01:CONCOURSE",
				"item": "ST-083",
				"site": "BOWL-01:CONCOURSE",
				"host": "field",
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
				]
			},
			{
				"instance": "npc:GRAND-III:r1:BOWL-01:ROOF",
				"item": "ST-084",
				"site": "BOWL-01:ROOF",
				"host": "field",
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
				]
			},
			{
				"instance": "npc:GRAND-III:r1:BOWL-01:UPPER",
				"item": "ST-082",
				"site": "BOWL-01:UPPER",
				"host": "field",
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
				]
			},
			{
				"instance": "npc:GRAND-III:r1:BOWL-02",
				"item": "ST-081",
				"site": "BOWL-02",
				"host": "field",
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
				"instance": "npc:GRAND-III:r1:BOWL-02:CONCOURSE",
				"item": "ST-083",
				"site": "BOWL-02:CONCOURSE",
				"host": "field",
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
				"instance": "npc:GRAND-III:r1:BOWL-02:ROOF",
				"item": "ST-084",
				"site": "BOWL-02:ROOF",
				"host": "field",
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
				"instance": "npc:GRAND-III:r1:BOWL-02:UPPER",
				"item": "ST-082",
				"site": "BOWL-02:UPPER",
				"host": "field",
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
				"instance": "npc:GRAND-III:r1:BOWL-03",
				"item": "ST-081",
				"site": "BOWL-03",
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
					0.0,
					0.0,
					0.0
				]
			},
			{
				"instance": "npc:GRAND-III:r1:BOWL-03:CONCOURSE",
				"item": "ST-083",
				"site": "BOWL-03:CONCOURSE",
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
					0.0,
					0.0,
					0.0
				]
			},
			{
				"instance": "npc:GRAND-III:r1:BOWL-03:ROOF",
				"item": "ST-084",
				"site": "BOWL-03:ROOF",
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
					0.0,
					0.0,
					0.0
				]
			},
			{
				"instance": "npc:GRAND-III:r1:BOWL-03:UPPER",
				"item": "ST-082",
				"site": "BOWL-03:UPPER",
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
					0.0,
					0.0,
					0.0
				]
			},
			{
				"instance": "npc:GRAND-III:r1:BOWL-04",
				"item": "ST-081",
				"site": "BOWL-04",
				"host": "field",
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
				"instance": "npc:GRAND-III:r1:BOWL-04:CONCOURSE",
				"item": "ST-083",
				"site": "BOWL-04:CONCOURSE",
				"host": "field",
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
				"instance": "npc:GRAND-III:r1:BOWL-04:ROOF",
				"item": "ST-084",
				"site": "BOWL-04:ROOF",
				"host": "field",
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
				"instance": "npc:GRAND-III:r1:BOWL-04:UPPER",
				"item": "ST-082",
				"site": "BOWL-04:UPPER",
				"host": "field",
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
				"instance": "npc:GRAND-III:r1:BOWL-05",
				"item": "ST-081",
				"site": "BOWL-05",
				"host": "field",
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
				]
			},
			{
				"instance": "npc:GRAND-III:r1:BOWL-05:CONCOURSE",
				"item": "ST-083",
				"site": "BOWL-05:CONCOURSE",
				"host": "field",
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
				]
			},
			{
				"instance": "npc:GRAND-III:r1:BOWL-05:ROOF",
				"item": "ST-084",
				"site": "BOWL-05:ROOF",
				"host": "field",
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
				]
			},
			{
				"instance": "npc:GRAND-III:r1:BOWL-05:UPPER",
				"item": "ST-082",
				"site": "BOWL-05:UPPER",
				"host": "field",
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
				]
			},
			{
				"instance": "npc:GRAND-III:r1:DUGOUT-L",
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
				"instance": "npc:GRAND-III:r1:DUGOUT-R",
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
				"instance": "npc:GRAND-III:r1:FOUL-POLE-L",
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
				"instance": "npc:GRAND-III:r1:FOUL-POLE-R",
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
				"instance": "npc:GRAND-III:r1:JOIN-L",
				"item": "ST-088",
				"site": "JOIN-L",
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
				"instance": "npc:GRAND-III:r1:JOIN-L:CONCOURSE",
				"item": "ST-089",
				"site": "JOIN-L:CONCOURSE",
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
				"instance": "npc:GRAND-III:r1:JOIN-R",
				"item": "ST-085",
				"site": "JOIN-R",
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
				"instance": "npc:GRAND-III:r1:JOIN-R:CONCOURSE",
				"item": "ST-086",
				"site": "JOIN-R:CONCOURSE",
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
				"instance": "npc:GRAND-III:r1:LANDMARK-A",
				"item": "ST-046",
				"site": "LANDMARK-A",
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
					36.5,
					0.0,
					44.0
				]
			},
			{
				"instance": "npc:GRAND-III:r1:PLIGHT-HL",
				"item": "ST-076",
				"site": "PLIGHT-HL",
				"host": "field",
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
				]
			},
			{
				"instance": "npc:GRAND-III:r1:PLIGHT-HR",
				"item": "ST-076",
				"site": "PLIGHT-HR",
				"host": "field",
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
				]
			},
			{
				"instance": "npc:GRAND-III:r1:PLIGHT-OL",
				"item": "ST-076",
				"site": "PLIGHT-OL",
				"host": "field",
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
				]
			},
			{
				"instance": "npc:GRAND-III:r1:PLIGHT-OR",
				"item": "ST-076",
				"site": "PLIGHT-OR",
				"host": "field",
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
				]
			},
			{
				"instance": "npc:GRAND-III:r1:RECEIVER-CATCH",
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
				"instance": "npc:GRAND-III:r1:RECEIVER-PRIMARY",
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
				"instance": "npc:GRAND-III:r1:ST-022-01",
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
				"instance": "npc:GRAND-III:r1:ST-022-02",
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
				"instance": "npc:GRAND-III:r1:ST-022-03",
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
				"instance": "npc:GRAND-III:r1:ST-022-04",
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
				"instance": "npc:GRAND-III:r1:ST-022-05",
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
				"instance": "npc:GRAND-III:r1:ST-022-06",
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
				"instance": "npc:GRAND-III:r1:ST-022-07",
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
				"instance": "npc:GRAND-III:r1:ST-022-08",
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
				"instance": "npc:GRAND-III:r1:ST-022-09",
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
				"instance": "npc:GRAND-III:r1:ST-022-10",
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
				"instance": "npc:GRAND-III:r1:ST-022-11",
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
				"instance": "npc:GRAND-III:r1:ST-022-15",
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
				"instance": "npc:GRAND-III:r1:ST-022-16",
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
				"instance": "npc:GRAND-III:r1:ST-022-17",
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
				"instance": "npc:GRAND-III:r1:ST-022-18",
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
				"instance": "npc:GRAND-III:r1:ST-022-19",
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
				"instance": "npc:GRAND-III:r1:ST-023-01",
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
				"instance": "npc:GRAND-III:r1:ST-023-02",
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
				"instance": "npc:GRAND-III:r1:ST-023-03",
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
				"instance": "npc:GRAND-III:r1:ST-023-04",
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
				"instance": "npc:GRAND-III:r1:ST-023-05",
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
				"instance": "npc:GRAND-III:r1:ST-023-09",
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
				"instance": "npc:GRAND-III:r1:ST-023-10",
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
				"instance": "npc:GRAND-III:r1:ST-023-11",
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
				"instance": "npc:GRAND-III:r1:ST-023-12",
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
				"instance": "npc:GRAND-III:r1:ST-023-13",
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
				"instance": "npc:GRAND-III:r1:ST-023-14",
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
				"instance": "npc:GRAND-III:r1:ST-023-15",
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
				"instance": "npc:GRAND-III:r1:ST-023-16",
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
				"instance": "npc:GRAND-III:r1:ST-023-17",
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
				"instance": "npc:GRAND-III:r1:ST-023-18",
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
				"instance": "npc:GRAND-III:r1:ST-023-19",
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
				"instance": "npc:GRAND-III:r1:ST-065-01",
				"item": "ST-065",
				"site": "ST-065-01",
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
				"instance": "npc:GRAND-III:r1:ST-065-02",
				"item": "ST-065",
				"site": "ST-065-02",
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
				"instance": "npc:GRAND-III:r1:ST-065-03",
				"item": "ST-065",
				"site": "ST-065-03",
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
				"instance": "npc:GRAND-III:r1:ST-065-04",
				"item": "ST-065",
				"site": "ST-065-04",
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
				"instance": "npc:GRAND-III:r1:ST-065-05",
				"item": "ST-065",
				"site": "ST-065-05",
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
				"instance": "npc:GRAND-III:r1:ST-065-06",
				"item": "ST-065",
				"site": "ST-065-06",
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
				"instance": "npc:GRAND-III:r1:ST-065-07",
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
					10.0,
					0.0,
					23.399999618530273
				]
			},
			{
				"instance": "npc:GRAND-III:r1:ST-065-08",
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
					7.999999523162842,
					0.0,
					23.399999618530273
				]
			},
			{
				"instance": "npc:GRAND-III:r1:ST-065-09",
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
					6.0,
					0.0,
					23.399999618530273
				]
			},
			{
				"instance": "npc:GRAND-III:r1:ST-065-10",
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
					4.0,
					0.0,
					23.399999618530273
				]
			},
			{
				"instance": "npc:GRAND-III:r1:ST-065-11",
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
					2.0,
					0.0,
					23.399999618530273
				]
			},
			{
				"instance": "npc:GRAND-III:r1:ST-065-12",
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
					-9.5367431640625e-07,
					0.0,
					23.399999618530273
				]
			},
			{
				"instance": "npc:GRAND-III:r1:ST-065-13",
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
					-2.000001907348633,
					0.0,
					23.399999618530273
				]
			},
			{
				"instance": "npc:GRAND-III:r1:ST-065-14",
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
					-4.000000953674316,
					0.0,
					23.399999618530273
				]
			},
			{
				"instance": "npc:GRAND-III:r1:ST-065-15",
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
					-6.0,
					0.0,
					23.399999618530273
				]
			},
			{
				"instance": "npc:GRAND-III:r1:ST-065-16",
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
					-8.0,
					0.0,
					23.399999618530273
				]
			},
			{
				"instance": "npc:GRAND-III:r1:ST-065-17",
				"item": "ST-065",
				"site": "ST-065-17",
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
				"instance": "npc:GRAND-III:r1:ST-065-18",
				"item": "ST-065",
				"site": "ST-065-18",
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
				"instance": "npc:GRAND-III:r1:ST-065-19",
				"item": "ST-065",
				"site": "ST-065-19",
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
				"instance": "npc:GRAND-III:r1:ST-065-20",
				"item": "ST-065",
				"site": "ST-065-20",
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
				"instance": "npc:GRAND-III:r1:ST-065-21",
				"item": "ST-065",
				"site": "ST-065-21",
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
				"instance": "npc:GRAND-III:r1:ST-065-22",
				"item": "ST-065",
				"site": "ST-065-22",
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
				"instance": "npc:GRAND-III:r1:ST-065-23",
				"item": "ST-065",
				"site": "ST-065-23",
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
			"ST-021",
			"ST-022",
			"ST-023",
			"ST-026",
			"ST-029",
			"ST-030",
			"ST-031",
			"ST-040",
			"ST-046",
			"ST-053",
			"ST-065",
			"ST-073",
			"ST-074",
			"ST-076",
			"ST-081",
			"ST-082",
			"ST-083",
			"ST-084",
			"ST-085",
			"ST-086",
			"ST-088",
			"ST-089"
		],
		"land": {
			"version": 1,
			"tier": "mogul",
			"stages": [
				"expanded",
				"club",
				"mogul"
			]
		},
		"surface_version": 1,
		"routing_version": 1,
		"environment_certificates": [],
		"presentation": {
			"profile": "GRAND-III-1910-CLEAR-v1",
			"options": {}
		},
		"live_units": 0,
		"valuation": {
			"price_version": 1,
			"price_sha256": "5210c3c47688b06faa35a50ec211f65de0a881debc5d7567a4c0e2abe6df204f",
			"blueprints": 10600,
			"copies": 8165,
			"land": 6400,
			"total": 25165
		}
	}


static func source_layout() -> Dictionary:
	return {
		"id": "GRAND-III-VIDEO-v2",
		"version": 2,
		"archive_layout": "GRAND-III-v1",
		"owner": "npc-venue:grandstand-gardens:grand-iii-video-v2",
		"layout_revision": {
			"id": "GRAND-III-VIDEO-v2",
			"status": "Working-owner-acceptance-pending",
			"change": "ST040-video-v2-at-qualified-BOARD-LARGE-v2-replaces-historic-SCORE-LARGE-A",
			"original_reservation": [
				30,
				0,
				29,
				13,
				12,
				5
			],
			"reservation": [
				29,
				0,
				30.5,
				15,
				14,
				2
			],
			"field_changed": false,
			"land_changed": false
		},
		"board": {
			"item": "ST-040",
			"model": "video-v2",
			"factory_version": 1,
			"art_version": 2,
			"site": "BOARD-LARGE-v2",
			"mount": "upright",
			"collision": "none-after-terminal-only"
		},
		"structural_layers": {
			"baseline": "BASE-UPPER-ROOF-v1:guard-v2",
			"bowl": "BOWL-UPPER-ROOF-v1",
			"transitions": "roofless-concourse-v2",
			"roofs": 9,
			"transition_concourses": 2
		},
		"crowd": {
			"baseline_lower": 200,
			"baseline_upper": 64,
			"bowl_lower": 180,
			"bowl_upper": 80,
			"transitions": 36,
			"total": 560,
			"sway": 0.04,
			"status": "Working-art-density"
		},
		"qualification": "unqualified-nine-canopy-video-waterfall",
		"owner_acceptance_required": true,
		"progression_held": true
	}
