extends "res://src/tests/stadium_net_ui_test.gd"
## Bounded synthetic-paid ownership and public Workshop route. No played/earned-career claim.

const SL_SEED: int = 163
# Independently measured in the unchanged pre-ST036 baseline under native Godot4.6.3.
const SL_LEGACY_SIGNATURES: Dictionary = {
	"StadiumAdvancedWallLayout": "17ef584e0e983492cbca78a3d2bf636e513c95ac40985f40a2ba4416c99c7847",
	"StadiumBleacherItems": "b06983a912d77b916b42b61c6be99156360e7007c445009a9053e189a707ccdb",
	"StadiumBoundaryGraph": "93859ee6fb839243e6ac471b45027547e4a47e09e7e57bc957f19c7410b542e9",
	"StadiumBoundaryItems": "2d8dc8f487cdf0cbc93f32131c6267f40628606a80a571c3ecfa262298ea1a9e",
	"StadiumCatalog": "5210c3c47688b06faa35a50ec211f65de0a881debc5d7567a4c0e2abe6df204f",
	"StadiumClubItems": "b54cce18570e7090188427ce56a4f010871e52e2d3c5b88c0f2905fee9b05378",
	"StadiumFacilityItems": "566aa5fb0d9016ca0cca97fc372507f54ced2acc625815b5e955c02e426f65fc",
	"StadiumFieldStyles": "915736379c04e5fb85fb9a7001bfe8d7c924244a43bcf7541d12caaf863bf28e",
	"StadiumFlagItems": "8f31865b2bf9b4b720d6b63f914006479854bfd69d72a6c6c135542f204bb91b",
	"StadiumFloodlightOwnedItems":
	"9b894d3cdb5490619ca538faef93fe877e5f33d6082a16cd9f4c8a7475aa3fff",
	"StadiumGroundBoxItems": "6282785e7d4b24ad51b4e87345358db3c8548d86ea94bc9a547edbbfd9d71262",
	"StadiumGroundPropsItems": "47ddfc7dbb5b3f74c57f53eb19fa28645f5697469d0a6fc567cfbb246f68fa50",
	"StadiumGroundStyles": "a9f3988666769505bed650c0651a9e24b681d9ff1700b2b6178797195e7ac8a0",
	"StadiumHillsideDefinitionV1":
	"8a58cdce595d27fb1f3c19e2fe16c81a32b5049a1d0c69ab5dcef3ea8299ae0d",
	"StadiumHomeLayout": "fa464256bb38fc7173580e31b43d98353234d65451595685c1d006e95d566051",
	"StadiumInfieldStyles": "5d540e1d3817ade6661399b06011bfcfd5370ba08fbe105c2ae3478b95e17b9c",
	"StadiumLand": "cbb6f586396ddf2e467c6c2afd8b34c53556b8ffd944d0e32c72dc5ad73f3c06",
	"StadiumLandmarkItems": "0e21e8b471e67dc05bc48af42b4222a51875e5c073236e3fc035dca5e36204d4",
	"StadiumLandscapeOwnedItems":
	"8a08be94026f6a2a69e8eefdb5b672a5a56919224247d5755abb3fb16b00b0aa",
	"StadiumLightItems": "c81acca7d1965e73df8a28e3abc0e59335d1e3b34f9a433d1a9688d89760ac78",
	"StadiumLiveFurnishingItems":
	"b0c5b175cec7d7367a1eec97ac06a95bcfd817db82c5f338a2a6e737a287089d",
	"StadiumMoldedSeatItems": "78058d4748ac2433fa68f586033f216c284a3fb020dd004f39a463b0462a467a",
	"StadiumMountedDisplayItems":
	"e9e65627803ffa714a8117a42fd06e8e4588874e2cf4ae56dbbd0088cc78bf82",
	"StadiumMountedScoreboardLayout":
	"decb00b104d2490c777700c9a021d0f2ecf993d76989091252bc3b6aba1a7f0e",
	"StadiumNetItems": "2cf29e636023aaf4f107b8b1997c3d78db32ce5668fdbfbb80f4b2d4960e495b",
	"StadiumOutfieldBleacherItems":
	"ffc8613c853591ef49b2a54988f60e3a633de15a8dd14e843b5de18bc496a149",
	"StadiumPennantRewards": "e6c9bb5df65cffa3955d6c488f1546fa6cfb33e2a7909066ada3a81db7153caa",
	"StadiumPlayerTunnelItems": "7040498ea4d86354292786b9aed1b146b8b984c52081676344dd2dfb44217aaf",
	"StadiumPoolOwnedFootprint": "18dcc77450bb94cff02e5102c846ff773d7b0a2f77f3db1bd683a4a1375f81ce",
	"StadiumPoolOwnedLayout": "a612a2f1034dd0c3c75df856ed3370f47572eee3dec396531382c64195985db5",
	"StadiumPracticeFacilityItems":
	"d08f46d10678aba804327383be247dc6b6225c587bd9ae73e731c3a18b8b20af",
	"StadiumReceiverOwnedItems": "e2aef8add157360353408c08a7ad45218deb585dd1f4759c415bd799b09181d0",
	"StadiumRisingAppleItems": "0fe55cac574c72ddfc87395bb5ae2c4f841b804ec7910c6481f1fa2c82b4a385",
	"StadiumRoofItems": "e8d8dd4f0d603b4e4b63a6b42af429b5fad4e145f42c5cb5abad4dfae132cfa6",
	"StadiumScoreboardCatalog": "efd9053c016cefeb36e21324193906734c57ea70cd62560fc4f19dfc335460dc",
	"StadiumScoreboardLayout": "4462e457ba67e63c98c6dd582c8bc29f4b9913a355ba814fa83d2e1b1620a1bf",
	"StadiumScoreboardPurchases":
	"be6df72a81071276a5171344a663a04321871db4b08e196c14c377d062683c6a",
	"StadiumScoreboardSites": "59aa3c9483fa946d7463c35892de8e79cc97a14e69dd57f4cbd289ed1b1f7567",
	"StadiumSmallYardSceneryItems":
	"3f8d094ef82d1ce69d8b2f49f1c33a618878f4b58594c1e06079889749ff02f5",
	"StadiumStarterLayout": "c8ae3ba50fce39f08bf612c975368e24323fe62c0c73f53f9403ce8f7fd93b64",
	"StadiumStraightItems": "881058afc15dd74aa0c5eb537792a54b6b3841cd9f34aa1204bda1af31a618aa",
	"StadiumSurfaceLayout": "3a419666b6257b6e97f3ed6ba3c763279e16f56f4b21319b94331dd946443999",
	"StadiumSurfaceNightLayout": "7a796ab1fface3e5952b97422b7b4052968c157d7c1840c1a6176c5e55e03952",
	"StadiumSurfaceNightSnapshot":
	"149123bd7faff57f9d04e77071d117a74e9fb8d1b8b73d3840f32088a53b227d",
	"StadiumSurfaceProgression": "f284e5bb58dbe2cb6739aa6e5d5678b3ff1c29e9ad82d7ccbed7abb8487d829d",
	"StadiumTargetItems": "98cc9ef7330d84074c6a5fe55fa8c03f491abb21d13af582094bd9573536b860",
	"StadiumTreehouseItems": "cc5f0f3cc14114327ecbd9c970529c0c60af6d85c60685077b8aa978108d184b",
	"StadiumWallItems": "6e81fce9c74250a4338b927ce087c76d71a8fa53f2153eb38e6c594b782caa40",
	"StadiumWallPieceCatalog": "fc95048f0179e7d18a58d0a6f50bfbf1a18bfc036f1ce4d8ddbf6076cc6b1383",
	"StadiumWallPieceOwnership": "3c544a7d07a07a76fe24bce6234c4c469f097eb8dec455d25a9e40b1b6ea9620",
	"StadiumWallTopTerraceItems":
	"6cbd4113d66e090a60725fe20cd0481c846ed28cf7b998aec2a6e6916e5e3945",
	"catalog": "5210c3c47688b06faa35a50ec211f65de0a881debc5d7567a4c0e2abe6df204f",
	"empty38_geometry": "8313ef10816ec239811a3e8d28b038dba5975168e5adf048f9384c199c5542d4",
	"mounted_layout": "e9e65627803ffa714a8117a42fd06e8e4588874e2cf4ae56dbbd0088cc78bf82",
	"mounted_price": "acad9986d8f936d0f03aa4cd3310c0a74171dc4bce4f7ed21cf3e93e3491ada3",
	"night_candidate1": "7a796ab1fface3e5952b97422b7b4052968c157d7c1840c1a6176c5e55e03952",
	"night_candidate2": "9509c245db79f7cce61a646a6eb6ebbb809f55e795b3af1bfabaaf49b1cdb2e3",
	"player_tunnel_layout": "7040498ea4d86354292786b9aed1b146b8b984c52081676344dd2dfb44217aaf",
	"player_tunnel_price": "b475b81ff0807a4ca88e438413dab52bc7a827f7f8833015c6d09c50aa2cd04d",
	"price_1": "54ca8d9ca13cbe57103c1804faa2b217dcd128c604e80c59bd89353ac9227902",
	"price_10": "7c36f0e6ce8cee820b0544a49d75105af3168d8578e7b9de0b64b42159b7cfac",
	"price_11": "d0214e4353c3362b49cd7b92fc8013867dd366b14ec27776cc2e396733ed0ca3",
	"price_12": "485abed2d2543895aa461e5dd65d04e29e00ed9459e3e31746a8b9ebef2311a4",
	"price_13": "35db82ca4eb3e0780415a8968636a7863c58cdc2d187a893eec23053f67fc97e",
	"price_14": "eb9d90c622ad9091215cd008ee97d9ccefcd9f347613cf4a96b9c6c15086fee1",
	"price_15": "ab85f224ac88ca4f624f31446f23d595dd82548649ec1fb27ec6378968300bc4",
	"price_16": "653e7b93e3f44694b3c129d99dd2fffecf4438b2c360944da18a038b9cf0fc2d",
	"price_17": "3aed0bee22072cf9ca6e8cecb3870ba011e627a86d2b9c06159a1fdd7a49b1ca",
	"price_18": "d2988fb16b10a43e1b0c0a46150049332b31c7f75666eec62aefc3efe58bc6b3",
	"price_19": "ca27755c2796575a298676d387eb206c479bb720f4329d9a8aad47305ab034ca",
	"price_2": "624ba7d4847b1051da5c28e411ceccdd0b7550480cd8459c98fe14f8a9732ef9",
	"price_20": "830148a3191cb64c867133d81e844739e126e6d95cb3abb34d675f425840b61d",
	"price_21": "1311e46103b97deb04a4824ff8080f51198d9465ec3c444f67560e5590d337f8",
	"price_22": "1c9d329927795a259725d9a95b4af9859b1569450f09a0536c202aa1068d09b8",
	"price_23": "432363029c12fb9eccf65d501d56e843fb0bffadebd751da733916f611856ba3",
	"price_24": "3ea968df45c54ca2c2f3a9e20eb53aa66fdb9b124e026c725db5ce83a456ec83",
	"price_25": "064a26f8b4479f66bdb2065ac9015cb1278a6d28b8b7f4820be40e2b4e27b687",
	"price_26": "7d5294deffe61ea0a4d33afafdbe9d9b3f9d90e43f98e8020af13738a88f2ced",
	"price_27": "8d659d07033d50e1aa40e09978947983f846a229dc0ab49fc58a4ebb6c22540a",
	"price_28": "b475b81ff0807a4ca88e438413dab52bc7a827f7f8833015c6d09c50aa2cd04d",
	"price_29": "acad9986d8f936d0f03aa4cd3310c0a74171dc4bce4f7ed21cf3e93e3491ada3",
	"price_3": "bf5a55df4ddf0f9ea5216f90a08bc9c7d220ae0cb807beb37b37821df69b9dce",
	"price_4": "e65b777255eb5595843f4b1d0e387ce4feb8926434db2d61db727a16b94cdff8",
	"price_5": "6b86d3b900720085b2a1933bf5c2ea25f3a50936241889918784f1de922548e2",
	"price_6": "a8912baf92be918c244df834261f43fdb7d7afa9ddb657904758b2a6a7d2954d",
	"price_7": "e0f3089b8f84db4839c38f0aac23186b046885607d67acf1933c63407b208e13",
	"price_8": "0d1d1cd0093e0ad26cb459d6b4ffd8338607598eed7a513736939f2519f4a80b",
	"price_9": "f37759e0ca598e4f1c149c5d459530048d3f5d08b6b6879aded3d197855a0ee6",
	"starter": "c8ae3ba50fce39f08bf612c975368e24323fe62c0c73f53f9403ce8f7fd93b64",
	"stock": "ac1d1db9723a4fd6f70aa17db3f50e482a84093d42f10e0aba87c54e3cf442b6"
}
var _sl_checks: int = 0
var _sl_phase: String = "setup"
var _sl_rows: Array[Dictionary] = []
var _sl_credits: Array = []
var _sl_progress: Array = []
var _sl_paid: ClubAssetLedger
var _sl_copies: Dictionary = {}
var _sl_output: String = ""


func _check(ok: bool, message: String) -> void:
	_sl_checks += 1
	_sl_rows.append({"phase": _sl_phase, "ok": ok, "message": message})
	if not ok:
		print("STRING_LIGHT_OWNERSHIP_FAILURE " + JSON.stringify(_sl_rows[-1]))
	super._check(ok, message)


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--string-light-report="):
			_sl_output = argument.trim_prefix("--string-light-report=")
	_sl_signatures()
	_sl_preexisting38()
	_sl_ownership()
	if _failures == 0:
		await _sl_ui()
	var report: Dictionary = {
		"checks": _sl_checks,
		"failures": _failures,
		"assertions": _sl_rows,
		"synthetic_funding": true,
		"synthetic_progression": true,
		"executed_games": 0,
		"earned_career_claim": false,
		"night_qualification_claim": false,
		"whole_game_acceptance_claim": false,
		"renderer": DisplayServer.get_name()
	}
	if not _sl_output.is_empty():
		var file: FileAccess = FileAccess.open(_sl_output, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t", true, true) + "\n")
			file.close()
		else:
			_check(false, "explicit ownership report path opens")
	print(
		(
			"STRING_LIGHT_OWNERSHIP_RESULT "
			+ JSON.stringify({"checks": _sl_checks, "failures": _failures, "executed_games": 0})
		)
	)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)


func _sl_buy(item: String, count: int, version: int) -> void:
	var command: Dictionary = {
		"id": "string-test-buy:%d" % _sl_paid.revision(),
		"rev": _sl_paid.revision(),
		"op": "stadium_buy",
		"item": item,
		"quantity": count,
		"price_version": version,
		"through": _sl_credits.size(),
		"progress_through": _sl_progress.size()
	}
	var catalog: Dictionary = StadiumCatalog.item(item)
	var price: int = (
		count * int(catalog.copy_price)
		+ (0 if _sl_paid.construction().blueprints.has(item) else int(catalog.blueprint_price))
	)
	var balance: int = _sl_paid.balance()
	var size: int = _sl_paid.construction().copies.size()
	var result: Dictionary = _sl_paid.commit(command)
	_check(
		(
			result.ok
			and _sl_paid.balance() == balance - price
			and _sl_paid.construction().copies.size() == size + count
		),
		"exact ordinary blueprint/copy charge " + item + ": " + result.error
	)
	_sl_copies[item] = []
	for index in range(count):
		var copy: String = "purchase:%s:%d" % [command.id, index]
		_sl_copies[item].append(copy)
		_check(
			ClubCareer.same(
				_sl_paid.construction().copies.get(copy, {}),
				{"item": item, "paid": catalog.copy_price, "source": "purchase-v1"}
			),
			"exact paid source and identity " + copy
		)
	var before: Dictionary = _sl_paid.to_data().duplicate(true)
	var replay: Dictionary = _sl_paid.commit(command)
	_check(
		replay.get("replayed", false) and ClubCareer.same(before, _sl_paid.to_data()),
		"purchase idempotent exact retry " + item
	)


func _sl_apply(layout: Dictionary) -> bool:
	var balance: int = _sl_paid.balance()
	var inventory: Dictionary = _sl_paid.construction().to_data()
	var draft: Dictionary = {
		"id": "string-test-draft:%d" % _sl_paid.revision(),
		"rev": _sl_paid.revision(),
		"op": "stadium_draft",
		"layout": layout
	}
	var saved: Dictionary = _sl_paid.commit(draft)
	_check(saved.ok, "ordinary draft accepts: " + saved.error)
	if not saved.ok:
		return false
	var command: Dictionary = {
		"id": "string-test-apply:%d" % _sl_paid.revision(),
		"rev": _sl_paid.revision(),
		"op": "stadium_apply",
		"layout": layout,
		"geometry": StadiumOwnedLayout.geometry(_sl_paid.view().land, layout)
	}
	var applied: Dictionary = _sl_paid.commit(command)
	_check(
		(
			applied.ok
			and _sl_paid.balance() == balance
			and ClubCareer.same(inventory, _sl_paid.construction().to_data())
		),
		"atomic Apply is free and preserves every owned copy: " + applied.error
	)
	var before: Dictionary = _sl_paid.to_data().duplicate(true)
	_check(
		(
			_sl_paid.commit(draft).get("replayed", false)
			and _sl_paid.commit(command).get("replayed", false)
			and ClubCareer.same(before, _sl_paid.to_data())
		),
		"saved draft and Apply retry without journal mutation"
	)
	return applied.ok


func _sl_refuse(label: String, layout: Dictionary, stale: bool = false) -> void:
	var before: Dictionary = _sl_paid.to_data().duplicate(true)
	var generation: int = _sl_paid.mutation_generation()
	var rejected: Dictionary = _sl_paid.commit(
		{
			"id": "string-test-refuse:" + label,
			"rev": _sl_paid.revision() - (1 if stale else 0),
			"op": "stadium_draft",
			"layout": layout
		}
	)
	_check(
		(
			not rejected.ok
			and ClubCareer.same(before, _sl_paid.to_data())
			and _sl_paid.mutation_generation() == generation
		),
		"refusal preserves complete journal/inventory/generation " + label
	)


func _sl_validate(layout: Dictionary) -> Dictionary:
	return StadiumHomeLayout.validate(layout, _sl_paid.construction(), _sl_paid.view().land)


func _sl_ownership() -> void:
	_sl_phase = "legacy-identity-and-paid-journal"
	for index in range(40):
		_sl_credits.append(1000)
		_sl_progress.append({"seasons": 1, "wins": 5})
	_sl_paid = ClubAssetLedger.new(SL_SEED, _sl_credits, _sl_progress)
	_check(
		(
			StadiumCareerProgress.valid(_sl_progress, _sl_credits)
			and _sl_paid.construction().copies.size() == 3
		),
		"synthetic ledger starts with exactly the three unchanged starter copies"
	)
	var original: Dictionary = _sl_paid.to_data().duplicate(true)
	var original_snapshot: Dictionary = StadiumLayoutSnapshot.capture(_sl_paid)
	var original_stock: Dictionary = _sl_paid.construction().to_data()
	var old_geometry: String = StadiumHomeLayout.geometry(
		"backyard", _sl_paid.view().stadium_active
	)
	var old: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(original)), SL_SEED, _sl_credits, _sl_progress
	)
	_check(
		old != null and ClubCareer.same(old.to_data(), original),
		"pre-ST036 legacy journal cold-reloads byte-equivalent data"
	)
	var entry: Dictionary = StadiumCatalog.item("ST-036")
	_check(
		(
			entry.blueprint_price == 260
			and entry.copy_price == 45
			and ClubCareer.same(entry.requires, {"seasons": 3, "wins": 8})
		),
		"unchanged Working ST036 prices and both unlock thresholds"
	)
	for gate: Dictionary in [{"seasons": 2, "wins": 8}, {"seasons": 3, "wins": 7}]:
		_check(
			not (
				StadiumPurchases
				. quote(_sl_paid.construction(), "ST-036", 1, "string-locked", 30, gate)
				. ok
			),
			"each below-threshold quote refuses"
		)
	_check(
		(
			StadiumPurchases
			. quote(
				_sl_paid.construction(),
				"ST-036",
				1,
				"string-threshold",
				30,
				{"seasons": 3, "wins": 8}
			)
			. ok
		),
		"exact ST036 threshold quote succeeds"
	)
	for version in range(1, 30):
		_check(
			not (
				StadiumPurchases
				. quote(
					_sl_paid.construction(),
					"ST-036",
					1,
					"string-old",
					version,
					{"seasons": 40, "wins": 200}
				)
				. ok
			),
			"old price family cannot grant ST036: %d" % version
		)
	_check(
		(
			ClubCareer.same(original, _sl_paid.to_data())
			and ClubCareer.same(original_stock, _sl_paid.construction().to_data())
		),
		"all exploratory quotes preserve preexisting journal and ownership"
	)
	_sl_buy("ST-036", 7, 30)
	_sl_buy("ST-037", 4, 7)
	_sl_buy("ST-039", 1, 3)
	_sl_buy("ST-069", 1, 29)
	if _failures != 0:
		return
	_check(
		(
			_sl_paid.to_data().version == 47
			and StadiumLayoutSnapshot.matches(original_snapshot, _sl_paid)
			and old_geometry == StadiumHomeLayout.geometry("backyard", original_snapshot.layout)
		),
		"new ledger47 preserves original snapshot/prefix and geometry"
	)
	_check(
		ClubCareer.same(_sl_paid.prefix(0).to_data(), original),
		"journal rewind before ST036 restores exact original header and fields"
	)
	var only_purchase: ClubAssetLedger = _sl_paid.prefix(1)
	_check(
		(
			only_purchase != null
			and only_purchase.to_data().version == 47
			and not only_purchase.to_data().has("mounted_display_catalog")
		),
		"ST036-only purchase needs no unrelated mounted-display event catalog"
	)
	var empty38: Dictionary = StadiumMountedDisplayItems.upgrade(
		StadiumStarterLayout.empty(), _sl_paid.surface_owned()
	)
	var empty: Dictionary = StadiumStringLightItems.upgrade(empty38, _sl_paid.surface_owned())
	var parent_checked: Dictionary = StadiumHomeLayout.validate(
		StadiumGroundBoxItems.base(empty38), _sl_paid.construction(), "backyard"
	)
	_check(
		not _sl_validate(empty38).ok, "historical empty family38 Backyard refusal remains unchanged"
	)
	var checked: Dictionary = _sl_validate(empty)
	_check(
		(
			empty.version == 39
			and empty.string_lights.is_empty()
			and ClubCareer.same(StadiumStringLightItems.base(empty), empty38)
		),
		"empty39 is additive over the exact family38 data"
	)
	_check(
		(
			checked.ok
			and parent_checked.ok
			and (
				checked.get("night_qualified", false)
				== parent_checked.get("night_qualified", false)
			)
			and checked.placements == parent_checked.placements
			and checked.stored == parent_checked.stored
		),
		(
			"empty39 preserves inherited family28 Backyard placements storage and Night flag "
			+ "without promotion"
		)
	)
	_check(
		(
			ClubCareer.same(StadiumStringLightItems.upgrade(empty), empty)
			and ClubCareer.same(StadiumMountedDisplayItems.upgrade(empty), empty)
		),
		"both old/new upgrade calls retain existing family39 unchanged"
	)
	_check(_sl_apply(empty), "empty additive wrapper applies")
	if _failures != 0:
		return
	_sl_phase = "partial-festoon-mixed-and-store"
	var partial: Dictionary = StadiumStringLightItems.place(
		empty, _sl_paid.construction(), _sl_copies["ST-036"][0], "STR-LF"
	)
	checked = _sl_validate(partial)
	_check(
		(
			checked.ok
			and checked.string_light_placements.size() == 1
			and not checked.string_light_complete
			and not checked.night_qualified
			and checked.live_units == 0
		),
		"one paid span is partial decorative daylight-only, with no live budget"
	)
	_check(_sl_apply(partial), "partial span activates through ordinary journal")
	if _failures != 0:
		return
	var festoon: Dictionary = empty.duplicate(true)
	var festoon_sites: Array = StadiumStringLightItems.PRESETS["FESTOON-6X036-DG1"]
	for index in range(festoon_sites.size()):
		festoon = StadiumStringLightItems.place(
			festoon, _sl_paid.construction(), _sl_copies["ST-036"][index], festoon_sites[index]
		)
	checked = _sl_validate(festoon)
	_check(
		(
			checked.ok
			and checked.string_light_complete
			and checked.string_light_profile == "FESTOON-6X036-DG1"
			and not checked.night_qualified
			and checked.stored.has(_sl_copies["ST-036"][6])
		),
		"six exact Festoon spans complete candidate counts only; spare remains stored"
	)
	_check(_sl_apply(festoon), "full Festoon applies atomically")
	if _failures != 0:
		return
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(_sl_paid)
	_check(
		(
			not snapshot.is_empty()
			and StadiumLayoutSnapshot.matches(snapshot, _sl_paid)
			and PhysicalStadiumContacts.valid([], [], snapshot)
		),
		"family39 snapshot and empty contact report bind exact paid property"
	)
	var environment: Dictionary = StadiumFixtureEnvironment.capture(snapshot, 163, 0)
	_check(
		(
			environment.mode == "day"
			and environment.profile.is_empty()
			and StadiumSurfaceNightLayout.capture(_sl_paid).is_empty()
		),
		"complete strings never gain a Night rig or fixture profile"
	)
	var mixed: Dictionary = festoon.duplicate(true)
	for row: Dictionary in festoon.string_lights:
		if row.site not in ["STR-LF", "STR-RF"]:
			mixed = StadiumStringLightItems.store_copy(mixed, row.copy)
	mixed = StadiumStringLightItems.place(
		mixed, _sl_paid.construction(), _sl_copies["ST-036"][0], "STR-BC"
	)
	mixed.lights = [
		{"copy": _sl_copies["ST-037"][0], "site": "YLIGHT-RL"},
		{"copy": _sl_copies["ST-037"][1], "site": "YLIGHT-RR"}
	]
	checked = _sl_validate(mixed)
	_check(
		(
			checked.ok
			and checked.string_light_complete
			and checked.string_light_profile == "MIXED-2X037-3X036-DG1"
			and not checked.night_qualified
		),
		"three exact strings plus independently owned rear pair complete Mixed counts only"
	)
	_check(_sl_apply(mixed), "same paid copies move Festoon-to-Mixed without a moving fee")
	if _failures != 0:
		return
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	_check(
		property.build("backyard", mixed, _sl_paid.construction()) and property.props_intact(),
		"ordinary property factory builds exact Mixed owned models with intact guards"
	)
	_check(
		property.objects.size() == 5 and property.route_obstacles().is_empty(),
		"three spans and two poles are complete scenery with no fielder-route obstacles"
	)
	for placed: Dictionary in checked.string_light_placements:
		var model: Node3D = property.objects.get(placed.copy)
		_check(
			(
				model != null
				and model.get_meta("owned_copy", "") == placed.copy
				and model.get_meta("site", "") == placed.site
				and model.find_children("*", "Light3D", true, false).is_empty()
			),
			"ordinary fixed span binds its exact copy/socket without a Night light"
		)
		if model != null:
			var bulb: Node3D = model.get_node("Visual/Bulb00")
			var previous: Vector3 = bulb.position
			bulb.position.y += 0.01
			var refused: bool = not property.props_intact()
			bulb.position = previous
			_check(
				refused and property.props_intact(),
				"nested bulb displacement refuses and exact restoration restores the complete-copy guard"
			)
	property.free()
	var source: Dictionary = _sl_paid.to_data().duplicate(true)
	var cold: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(source)), SL_SEED, _sl_credits, _sl_progress
	)
	_check(
		(
			cold != null
			and ClubCareer.same(cold.to_data(), source)
			and ClubCareer.same(cold.view(), _sl_paid.view())
		),
		"ledger47 JSON cold replay retains exact charges copies placements and active layout"
	)
	for field: String in [
		"string_light_catalog",
		"string_light_layout_catalog",
		"mounted_display_catalog",
		"mounted_display_layout_catalog"
	]:
		var bad_data: Dictionary = source.duplicate(true)
		bad_data[field] = "foreign"
		_check(
			ClubAssetLedger.from_data(bad_data, SL_SEED, _sl_credits, _sl_progress) == null,
			"cold replay refuses changed catalog " + field
		)
	var downgraded: Dictionary = source.duplicate(true)
	downgraded.version = 46
	downgraded.erase("string_light_catalog")
	downgraded.erase("string_light_layout_catalog")
	_check(
		ClubAssetLedger.from_data(downgraded, SL_SEED, _sl_credits, _sl_progress) == null,
		"older journal header cannot smuggle ST036 events"
	)
	for kind: String in [
		"wrong-copy",
		"unowned",
		"duplicate-copy",
		"duplicate-site",
		"unsorted",
		"unknown-site",
		"extra-field",
		"bad-type",
		"wrong-family",
		"wrong-version",
		"extra-copy",
		"bad-ancestry",
		"nonempty-later-channel",
		"unknown-wrapper-field",
		"stale"
	]:
		var bad: Dictionary = mixed.duplicate(true)
		match kind:
			"wrong-copy":
				bad.string_lights[0].copy = _sl_copies["ST-037"][0]
			"unowned":
				bad.string_lights[0].copy = "purchase:foreign:0"
			"duplicate-copy":
				bad.string_lights[1].copy = bad.string_lights[0].copy
			"duplicate-site":
				bad.string_lights[1].site = bad.string_lights[0].site
			"unsorted":
				bad.string_lights.reverse()
			"unknown-site":
				bad.string_lights[0].site = "STR-FREEFORM"
			"extra-field":
				bad.string_lights[0]["yaw"] = 0
			"bad-type":
				bad.string_lights[0].copy = 7
			"wrong-family":
				bad.family = "foreign"
			"wrong-version":
				bad.version = 38
			"extra-copy":
				bad.string_lights.append({"copy": _sl_copies["ST-036"][6], "site": "STR-LF"})
			"bad-ancestry":
				bad.ground_box_base_version = 29
			"nonempty-later-channel":
				bad.practice_facilities = [
					{"copy": _sl_copies["ST-036"][6], "site": "PRACTICE-CLUB"}
				]
			"unknown-wrapper-field":
				bad["unknown_ancestor_channel"] = []
		_sl_refuse(kind, bad, kind == "stale")
	var stored: Dictionary = mixed.duplicate(true)
	for copy: String in _sl_copies["ST-036"]:
		stored = StadiumStringLightItems.store_copy(stored, copy)
	_check(
		_sl_apply(stored) and _sl_validate(stored).string_light_placements.is_empty(),
		"Store removes complete spans only and retains every exact owned copy"
	)
	_sl_phase = "inherited-mounted-route-and-legacy-night"
	var land: Dictionary = _sl_paid.commit(
		{
			"id": "string-test-expanded",
			"rev": _sl_paid.revision(),
			"op": "stadium_land",
			"tier": "expanded",
			"through": _sl_credits.size(),
			"progress_through": _sl_progress.size(),
			"price_version": StadiumLand.VERSION
		}
	)
	_check(land.ok, "ordinary Expanded purchase supports inherited mounted-host route")
	var host: Dictionary = stored.duplicate(true)
	host.displays = [{"copy": _sl_copies["ST-039"][0], "site": "SCORE-SMALL"}]
	var mount: Dictionary = StadiumMountedDisplayItems.place(
		host,
		_sl_paid.construction(),
		_sl_copies["ST-069"][0],
		_sl_copies["ST-039"][0],
		"CLOCK-MANUAL-HEADER"
	)
	_check(
		(
			mount.version == 39
			and mount.string_lights.is_empty()
			and _sl_validate(mount).ok
			and _sl_apply(mount)
		),
		"underlying host and mounted-display selectors preserve family39 and its empty channel"
	)
	var removed: Dictionary = mount.duplicate(true)
	removed.displays = []
	_sl_refuse("mounted-host-first", removed)
	var simultaneous: Dictionary = StadiumMountedDisplayItems.store_copy(
		removed, _sl_copies["ST-069"][0]
	)
	_sl_refuse("mounted-host-and-accessory-same-save", simultaneous)
	var mount_stored: Dictionary = StadiumMountedDisplayItems.store_copy(
		mount, _sl_copies["ST-069"][0]
	)
	_check(
		_sl_apply(mount_stored) and mount_stored.string_lights.is_empty(),
		"older mount Store-first transaction survives the new wrapper"
	)
	var yard: Dictionary = StadiumLightItems.upgrade(StadiumStarterLayout.empty())
	var sites: Array = StadiumYardLightModels.SITES.keys()
	sites.sort()
	for index in range(sites.size()):
		yard.lights.append({"copy": _sl_copies["ST-037"][index], "site": sites[index]})
	var yard_checked: Dictionary = _sl_validate(yard)
	_check(
		yard_checked.ok and yard_checked.night_qualified and yard.version == 9,
		"unchanged historical family9 four-pole Night remains independently qualified"
	)
	old = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(original)), SL_SEED, _sl_credits, _sl_progress
	)
	_check(
		(
			old != null
			and ClubCareer.same(old.to_data(), original)
			and ClubCareer.same(old.construction().to_data(), original_stock)
		),
		"pre-ST036 ownership remains unmodified and cold-readable after all newer operations"
	)
	for unsupported in range(13, 17):
		_check(
			StadiumStringLightItems.upgrade({"version": unsupported}).is_empty(),
			"separate paid family is not silently migrated: %d" % unsupported
		)


func _sl_ui() -> void:
	_sl_phase = "public-workshop-purchase-place-store-and-cold-save"
	SeasonSave.path = "user://string-light-ui-%d.json" % OS.get_process_id()
	_fund_net()
	if _failures != 0:
		return
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.begin_season(196, true)
	if app.season == null:
		_check(false, "synthetic closed-career Workshop opens")
		app.queue_free()
		return
	var season: SeasonState = app.season
	StadiumEditorUI.show(app.menu)
	var buy: Button = _buy_button(app, "ST-036")
	_check(buy != null and not buy.disabled, "public Workshop exposes enabled ST036 buy control")
	if buy == null or buy.disabled:
		app.queue_free()
		return
	var before: Dictionary = SeasonSave.snapshot(season)
	var path: String = SeasonSave.path
	var bytes: String = FileAccess.get_file_as_string(path)
	SeasonSave.path = path + "/missing/profile.json"
	await _click(buy)
	_check(
		(
			ClubCareer.same(before, SeasonSave.snapshot(season))
			and FileAccess.get_file_as_string(path) == bytes
		),
		"failed public purchase write preserves both live state and prior save bytes"
	)
	SeasonSave.path = path
	var balance: int = season.career.balance()
	var revision: int = ClubPlayers.assets(season.career).revision()
	await _click(_buy_button(app, "ST-036"))
	var copy: String = "purchase:stadium-buy:%d:0" % revision
	_check(
		(
			season.career.balance() == balance - 305
			and ClubPlayers.assets(season.career).construction().copies.has(copy)
		),
		"public purchase charges 260 blueprint plus45 once and creates exact paid copy"
	)
	var choice: OptionButton = _paid_choice(app, copy)
	_check(
		choice != null and choice.item_count == 8 and choice.selected == 0,
		"one owned card exposes Stored and all seven exact fixed sockets"
	)
	if choice == null:
		app.queue_free()
		return
	var slot: int = StadiumStringLightItemsUI.choices().find("STR-LF")
	await _pick_copy(app, copy, slot)
	_check(
		(
			_paid_choice(app, copy).selected == slot
			and (
				ClubPlayers
				. assets(season.career)
				. view()
				. stadium_draft
				. get("string_lights", [])
				. is_empty()
			)
		),
		"actual keyboard selection changes preview only before Save Draft"
	)
	await _click(_button(app.menu, "SAVE DRAFT"))
	await _click(_button(app.menu, "APPLY LAYOUT"))
	_check(
		(
			season.home_property.layout.version == 39
			and season.home_property.layout.string_lights == [{"copy": copy, "site": "STR-LF"}]
		),
		"public Save and Apply publish the exact owned span once"
	)
	var installed_restore: SeasonState = SeasonSave.restore()
	_check(
		(
			installed_restore != null
			and ClubCareer.same(installed_restore.home_property, season.home_property)
			and ClubCareer.same(
				ClubPlayers.assets(installed_restore.career).to_data(),
				ClubPlayers.assets(season.career).to_data()
			)
		),
		"populated family39 SeasonSave cold restore retains installed span and exact paid journal"
	)
	var preview: StadiumDraftPreview = _preview(app)
	_check(
		(
			preview != null
			and preview.positions.has(copy)
			and preview.board_bounds.has(copy)
			and not preview.night_eligible
		),
		"ordinary preview includes exact complete bounds with no Night toggle eligibility"
	)
	await _click(_focus_button(app, copy))
	preview = _preview(app)
	var box: AABB = preview.board_bounds.get(copy, AABB())
	var screen: Rect2 = preview.camera.get_viewport().get_visible_rect()
	for index in range(8):
		var point: Vector3 = box.get_endpoint(index)
		_check(
			(
				not preview.camera.is_position_behind(point)
				and screen.has_point(preview.camera.unproject_position(point))
			),
			"focus contains full span/support envelope corner%d" % index
		)
	var saved_inventory: Dictionary = ClubPlayers.assets(season.career).construction().to_data()
	await _pick_copy(app, copy, 0)
	await _click(_button(app.menu, "RELOAD SAVED"))
	_check(
		_paid_choice(app, copy).selected == slot,
		"Reload Saved discards unsaved Store and restores exact socket"
	)
	await _pick_copy(app, copy, 0)
	await _click(_button(app.menu, "SAVE DRAFT"))
	await _click(_button(app.menu, "APPLY LAYOUT"))
	_check(
		(
			season.home_property.layout.string_lights.is_empty()
			and ClubCareer.same(
				saved_inventory, ClubPlayers.assets(season.career).construction().to_data()
			)
		),
		"public Store removes both supports and span together without deleting paid ownership"
	)
	var restored: SeasonState = SeasonSave.restore()
	_check(
		(
			restored != null
			and ClubCareer.same(restored.home_property, season.home_property)
			and ClubCareer.same(
				ClubPlayers.assets(restored.career).to_data(),
				ClubPlayers.assets(season.career).to_data()
			)
		),
		"strict saved-season cold restore retains family39 exact journal and stored copy"
	)
	app.queue_free()
	await _frames()
	_cleanup()


func _sl_signatures() -> void:
	_sl_phase = "independently-pinned-legacy-signatures"
	var actual: Dictionary = {
		"mounted_price": StadiumMountedDisplayItems.price_signature(),
		"mounted_layout": StadiumMountedDisplayItems.signature(),
		"player_tunnel_price": StadiumPlayerTunnelItems.price_signature(),
		"player_tunnel_layout": StadiumPlayerTunnelItems.signature(),
		"night_candidate1": StadiumSurfaceNightLayout.signature(),
		"night_candidate2": StadiumSurfaceNightLayout.floodlight_signature(),
		"starter": StadiumStarterLayout.signature(),
		"stock": StadiumStock.grant_signature(),
		"catalog": StadiumCatalog.signature()
	}
	actual["StadiumAdvancedWallLayout"] = StadiumAdvancedWallLayout.signature()
	actual["StadiumBleacherItems"] = StadiumBleacherItems.signature()
	actual["StadiumBoundaryGraph"] = StadiumBoundaryGraph.signature()
	actual["StadiumBoundaryItems"] = StadiumBoundaryItems.signature()
	actual["StadiumCatalog"] = StadiumCatalog.signature()
	actual["StadiumClubItems"] = StadiumClubItems.signature()
	actual["StadiumFacilityItems"] = StadiumFacilityItems.signature()
	actual["StadiumFieldStyles"] = StadiumFieldStyles.signature()
	actual["StadiumFlagItems"] = StadiumFlagItems.signature()
	actual["StadiumFloodlightOwnedItems"] = StadiumFloodlightOwnedItems.signature()
	actual["StadiumGroundBoxItems"] = StadiumGroundBoxItems.signature()
	actual["StadiumGroundPropsItems"] = StadiumGroundPropsItems.signature()
	actual["StadiumGroundStyles"] = StadiumGroundStyles.signature()
	actual["StadiumHillsideDefinitionV1"] = StadiumHillsideDefinitionV1.signature()
	actual["StadiumHomeLayout"] = StadiumHomeLayout.signature()
	actual["StadiumInfieldStyles"] = StadiumInfieldStyles.signature()
	actual["StadiumLand"] = StadiumLand.signature()
	actual["StadiumLandmarkItems"] = StadiumLandmarkItems.signature()
	actual["StadiumLandscapeOwnedItems"] = StadiumLandscapeOwnedItems.signature()
	actual["StadiumLightItems"] = StadiumLightItems.signature()
	actual["StadiumLiveFurnishingItems"] = StadiumLiveFurnishingItems.signature()
	actual["StadiumMoldedSeatItems"] = StadiumMoldedSeatItems.signature()
	actual["StadiumMountedDisplayItems"] = StadiumMountedDisplayItems.signature()
	actual["StadiumMountedScoreboardLayout"] = StadiumMountedScoreboardLayout.signature()
	actual["StadiumNetItems"] = StadiumNetItems.signature()
	actual["StadiumOutfieldBleacherItems"] = StadiumOutfieldBleacherItems.signature()
	actual["StadiumPennantRewards"] = StadiumPennantRewards.signature()
	actual["StadiumPlayerTunnelItems"] = StadiumPlayerTunnelItems.signature()
	actual["StadiumPoolOwnedFootprint"] = StadiumPoolOwnedFootprint.signature()
	actual["StadiumPoolOwnedLayout"] = StadiumPoolOwnedLayout.signature()
	actual["StadiumPracticeFacilityItems"] = StadiumPracticeFacilityItems.signature()
	actual["StadiumReceiverOwnedItems"] = StadiumReceiverOwnedItems.signature()
	actual["StadiumRisingAppleItems"] = StadiumRisingAppleItems.signature()
	actual["StadiumRoofItems"] = StadiumRoofItems.signature()
	actual["StadiumScoreboardCatalog"] = StadiumScoreboardCatalog.signature()
	actual["StadiumScoreboardLayout"] = StadiumScoreboardLayout.signature()
	actual["StadiumScoreboardPurchases"] = StadiumScoreboardPurchases.signature()
	actual["StadiumScoreboardSites"] = StadiumScoreboardSites.signature()
	actual["StadiumSmallYardSceneryItems"] = StadiumSmallYardSceneryItems.signature()
	actual["StadiumStarterLayout"] = StadiumStarterLayout.signature()
	actual["StadiumStraightItems"] = StadiumStraightItems.signature()
	actual["StadiumSurfaceLayout"] = StadiumSurfaceLayout.signature()
	actual["StadiumSurfaceNightLayout"] = StadiumSurfaceNightLayout.signature()
	actual["StadiumSurfaceNightSnapshot"] = StadiumSurfaceNightSnapshot.signature()
	actual["StadiumSurfaceProgression"] = StadiumSurfaceProgression.signature()
	actual["StadiumTargetItems"] = StadiumTargetItems.signature()
	actual["StadiumTreehouseItems"] = StadiumTreehouseItems.signature()
	actual["StadiumWallItems"] = StadiumWallItems.signature()
	actual["StadiumWallPieceCatalog"] = StadiumWallPieceCatalog.signature()
	actual["StadiumWallPieceOwnership"] = StadiumWallPieceOwnership.signature()
	actual["StadiumWallTopTerraceItems"] = StadiumWallTopTerraceItems.signature()
	for version in range(1, 30):
		actual["price_%d" % version] = StadiumPurchases.signature(version)
	var base: Dictionary = StadiumMountedDisplayItems.upgrade(
		StadiumStarterLayout.empty(), StadiumSurfaceProgression.INITIAL_LEGACY
	)
	actual["empty38_geometry"] = StadiumHomeLayout.geometry("backyard", base)
	_check(
		actual.size() == SL_LEGACY_SIGNATURES.size(),
		"complete fixed legacy signature oracle is exercised"
	)
	for key: String in SL_LEGACY_SIGNATURES:
		_check(
			actual.get(key, "") == SL_LEGACY_SIGNATURES[key],
			"independent original-source signature remains byte-identical " + key
		)


func _sl_preexisting38() -> void:
	_sl_phase = "unchanged-baseline-family38-cold-replay"
	var path: String = "res://src/tests/stadium_string_light_legacy38_fixture.json"
	_check(
		(
			FileAccess.get_sha256(path)
			== "c8eb509e4e6500d138c7cf8ab65dd779ec68f8eaec4a47e02eb1842808ee04b8"
		),
		"independent pre-ST036 fixture bytes match original baseline pin"
	)
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var original: Dictionary = source.duplicate(true)
	var ledger: ClubAssetLedger = ClubAssetLedger.from_data(
		source.journal, source.seed, source.credits, source.progress
	)
	_check(ledger != null, "unchanged pre-ST036 populated family38/ledger46 fixture cold reloads")
	if ledger == null:
		return
	_check(ClubCareer.same(source, original), "legacy reload does not mutate input fixture")
	_check(
		(
			ClubCareer.same(ledger.to_data(), source.journal)
			and ledger.to_data().version == 46
			and not ledger.to_data().has("string_light_catalog")
		),
		"legacy46 journal remains exact with no migration or added catalog fields"
	)
	_check(
		(
			ClubCareer.same(ledger.view(), source.view)
			and ClubCareer.same(ledger.construction().to_data(), source.stock)
		),
		"legacy38 active draft copies charges and all view fields remain exact"
	)
	_check(
		(
			ClubCareer.same(StadiumLayoutSnapshot.capture(ledger), source.snapshot)
			and StadiumLayoutSnapshot.matches(source.snapshot, ledger)
		),
		"original baseline populated38 snapshot remains identical and binding"
	)
	var before: Dictionary = ledger.to_data().duplicate(true)
	var wrapper: Dictionary = StadiumStringLightItems.upgrade(
		ledger.view().stadium_active, ledger.surface_owned()
	)
	_check(
		(
			wrapper.version == 39
			and wrapper.string_lights.is_empty()
			and ClubCareer.same(StadiumStringLightItems.base(wrapper), source.view.stadium_active)
		),
		"new wrapper is pure and exactly reversible around preexisting populated38"
	)
	_check(
		ClubCareer.same(before, ledger.to_data()) and ClubCareer.same(source, original),
		"inspection and empty-wrapper construction cannot mutate preexisting ownership"
	)
