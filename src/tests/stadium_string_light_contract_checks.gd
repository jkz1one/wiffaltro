extends Node
## Finite DG1 contract checks. These do not qualify photometry or earned progression.
var checks: int = 0
var failures: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("STRING_CONTRACT_FAILURE " + label)


func _ready() -> void:
	for site: String in StadiumStringLightItems.SITES:
		var points: Array = StadiumStringLightItems.SITES[site]
		var placed: Dictionary = StadiumStringLightItems.row("owned:" + site, site)
		var pose: Transform3D = Transform3D(
			Basis(Vector3.UP, deg_to_rad(placed.yaw)), placed.position
		)
		check(points[0].distance_to(points[1]) == 14.0, site + " exact fourteen meter span")
		check((pose * Vector3(14, 0, 0)).is_equal_approx(points[1]), site + " rigid endpoint")
		check(
			(
				pose.basis.determinant() > 0.9999
				and pose.basis.get_scale().is_equal_approx(Vector3.ONE)
			),
			site + " no mirror or scaling"
		)
		check(
			StadiumStringLightItems.SITES[site] == StadiumStringLightModels.SITES[site],
			site + " model ownership authority agrees"
		)
		var boxes: Array[AABB] = StadiumStringLightItems.reservations(site)
		check(boxes.size() == 3, site + " two posts and overhead corridor")
		for box: AABB in boxes:
			check(
				StadiumProperty.contains("backyard", box),
				site + " entire clearance inside backyard"
			)
		for excluded: String in StadiumStringLightItems.EXCLUSIONS[site]:
			check(
				StadiumStringLightItems.conflicts(site, {"site": excluded}),
				site + " explicit occupied exclusion " + excluded
			)
		var far: Dictionary = {
			"copy": "far",
			"item": "ST-037",
			"site": "unrelated",
			"position": Vector3(100, 0, 100),
			"yaw": 0.0
		}
		check(not StadiumStringLightItems.conflicts(site, far), site + " no false remote overlap")
		far.position = points[0]
		check(StadiumStringLightItems.conflicts(site, far), site + " full envelope post overlap")
	var festoon: Array = []
	for site: String in StadiumStringLightItems.PRESETS["FESTOON-6X036-DG1"]:
		festoon.append({"copy": "paid:" + site, "site": site})
	var mixed: Array = []
	for site: String in StadiumStringLightItems.PRESETS["MIXED-2X037-3X036-DG1"]:
		mixed.append({"copy": "paid:" + site, "site": site})
	var rear: Array = [{"site": "YLIGHT-RL"}, {"site": "YLIGHT-RR"}]
	check(
		StadiumStringLightItems.complete_profile(festoon, []) == "FESTOON-6X036-DG1",
		"six exact complete spans"
	)
	check(
		StadiumStringLightItems.complete_profile(mixed, rear) == "MIXED-2X037-3X036-DG1",
		"exact rear mixed combination"
	)
	for size in range(6):
		check(
			StadiumStringLightItems.complete_profile(festoon.slice(0, size), []).is_empty(),
			"partial festoon no complete credit %d" % size
		)
	for size in range(3):
		check(
			StadiumStringLightItems.complete_profile(mixed.slice(0, size), rear).is_empty(),
			"partial mixed no complete credit %d" % size
		)
	check(
		(
			StadiumStringLightItems
			. complete_profile(mixed, [{"site": "YLIGHT-FL"}, {"site": "YLIGHT-FR"}])
			. is_empty()
		),
		"front poles not rear substitutes"
	)
	check(
		StadiumStringLightItems.complete_profile(festoon, rear).is_empty(),
		"extra poles no festoon qualification"
	)
	check(
		StadiumStringLightItems.complete_profile(mixed, rear + [rear[0]]).is_empty(),
		"duplicate pole no qualification"
	)
	check(
		StadiumStringLightItems.complete_profile(festoon + [festoon[0]], []).is_empty(),
		"duplicate span no qualification"
	)
	check(
		StadiumStringLightItems.complete_profile([null], []).is_empty(),
		"malformed complete-profile rows refuse"
	)
	check(
		StadiumStringLightItems.row("paid", "UNKNOWN").is_empty(),
		"unknown socket no arbitrary cable"
	)
	check(
		(
			StadiumStringLightItems.UNSUPPORTED_CHANNELS.has("wall_top_terrace")
			and not StadiumStringLightItems.UNSUPPORTED_CHANNELS.has("wall_top_terraces")
		),
		"exact inherited terrace field guarded"
	)
	var stock: StadiumStock = StadiumStock.new_club()
	check(
		not (
			StadiumStringLightItems
			. quote(stock, "ST-036", 1, "locked", {"seasons": 2, "wins": 8})
			. ok
		),
		"unchanged season3 unlock"
	)
	check(
		not (
			StadiumStringLightItems
			. quote(stock, "ST-036", 1, "locked", {"seasons": 3, "wins": 7})
			. ok
		),
		"unchanged wins8 unlock"
	)
	var quote: Dictionary = StadiumStringLightItems.quote(
		stock, "ST-036", 6, "paid", {"seasons": 3, "wins": 8}
	)
	check(
		quote.ok and quote.blueprint_cost == 260 and quote.copy_cost == 270,
		"unchanged260 blueprint and45 per whole copy"
	)
	print(
		(
			"STRING_CONTRACT_RESULT "
			+ JSON.stringify(
				{
					"checks": checks,
					"failures": failures,
					"night_qualified": false,
					"games": 0,
					"engine": Engine.get_version_info().string
				}
			)
		)
	)
	get_tree().quit(0 if failures == 0 else 1)
