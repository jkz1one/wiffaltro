extends Node
## Synthetic inventory/model/serialization checks only. No authentic title or rendered claim.

const LOWER: String = "purchase:mastery-lowers:0"
const SPARE: String = "purchase:mastery-lowers:1"
const CREST: String = "purchase:mastery-crest:0"
var checks: int = 0
var failures: Array[String] = []
var stock: StadiumStock
var earned: Dictionary
var empty: Dictionary
var mounted: Dictionary
var banner: String


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("MASTERY_BANNER_LAYOUT: " + label)


func _ready() -> void:
	_setup()
	if stock != null and not empty.is_empty():
		_layout()
		_model()
		_snapshot()
	print(
		(
			"MASTERY_BANNER_LAYOUT_RESULT "
			+ JSON.stringify(
				{
					"checks": checks,
					"failures": failures,
					"synthetic_inventory": true,
					"physical_games": 0,
					"rendered_acceptance": false,
					"night_qualified": false
				}
			)
		)
	)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures.is_empty() else 1)


func _setup() -> void:
	stock = StadiumStock.new_club()
	for purchase: Array in [["ST-029", 2, "mastery-lowers"], ["ST-042", 1, "mastery-crest"]]:
		var quote: Dictionary = stock.quote(
			purchase[0], purchase[1], {"seasons": 99, "wins": 999}, purchase[2]
		)
		check(quote.ok, "synthetic paid setup " + purchase[0])
		if not quote.ok:
			stock = null
			return
		stock = StadiumStock.from_data(quote.state)
	var era: Dictionary = StadiumClubIdentity.current()
	era.name = "First Era Club"
	era.palette = ["392863", "f0df8b"]
	earned = {
		"version": 1,
		"season_id": 5,
		"season_number": 5,
		"league_id": "standard",
		"difficulty_id": "standard.d4",
		"mastery_contract": "standard.d4",
		"era": era
	}
	var award: Dictionary = stock.mastery_quote(earned)
	check(award.ok, "synthetic valid mastery inventory proposal")
	if not award.ok:
		stock = null
		return
	stock = StadiumStock.from_data(award.state)
	banner = StadiumPennantRewards.mastery_key()
	empty = StadiumMasteryBannerItems.upgrade(
		StadiumStarterLayout.empty(), StadiumSurfaceProgression.INITIAL_LEGACY
	)
	check(
		empty.version == 41 and empty.mastery_banners.is_empty(),
		"explicit empty family41 on family40"
	)
	check(
		StadiumSalvageCarItems.is_family(StadiumMasteryBannerItems.base(empty)),
		"base remains exact salvage40"
	)
	check(
		StadiumHomeLayout.validate(empty, stock, "club").ok,
		"empty41 validates with earned copy stored"
	)
	check(
		StadiumHomeLayout.validate(empty, stock, "backyard").ok,
		"canonical empty41 preserves inherited Backyard bridge"
	)


func _layout() -> void:
	var old: Dictionary = empty.duplicate(true)
	var layout: Dictionary = StadiumStraightItemsUI.select(
		empty, stock, LOWER, {"site": "BASE-L1", "lower": "", "concourse": ""}
	)
	check(
		StadiumMasteryBannerItems.is_family(layout) and layout.hosts.size() == 1,
		"old host editor preserves family41"
	)
	check(StadiumHomeLayout.validate(layout, stock, "club").ok, "exact paid lower host validates")
	var choices: Array[Dictionary] = StadiumMasteryBannerItems.candidates(layout, stock)
	check(
		choices.size() == 1 and choices[0].host == LOWER and choices[0].socket == "BANNER-WALL",
		"only exact installed lower is offered"
	)
	var adapted: Dictionary = layout.duplicate(true)
	adapted.player_tunnels = [{"lower": LOWER}]
	check(
		StadiumMasteryBannerItems.candidates(adapted, stock).is_empty(),
		"tunnel-adapted lower facade never offered as unchanged BANNER-WALL"
	)
	mounted = StadiumMasteryBannerItems.place(layout, stock, banner, LOWER)
	var checked: Dictionary = StadiumHomeLayout.validate(mounted, stock, "club")
	check(checked.ok, "complete banner validates: " + checked.get("error", ""))
	if not checked.ok:
		return
	check(
		checked.mastery_banner_placements.size() == 1 and not checked.stored.has(banner),
		"single exact banner leaves storage"
	)
	check(
		checked.live_units == 0 and not checked.night_qualified,
		"static display adds no live capacity or Night claim"
	)
	check(
		ClubCareer.same(checked.mastery_banner_placements[0].earned, earned),
		"placement preserves full first-title era"
	)
	check(ClubCareer.same(empty, old), "editing never mutates the original layout")
	check(
		ClubCareer.same(StadiumMasteryBannerItems.place(mounted, stock, banner, LOWER), mounted),
		"same selection is idempotent"
	)
	check(
		ClubCareer.same(StadiumMasteryBannerItems.upgrade(mounted), mounted),
		"upgrade is idempotent"
	)
	check(
		ClubCareer.same(StadiumSalvageCarItems.upgrade(mounted), mounted),
		"old salvage upgrade preserves banner wrapper"
	)
	for change: Dictionary in [
		{"host": SPARE},
		{"socket": "crest"},
		{"socket": "BANNER-WALL-2"},
		{"copy": LOWER},
		{"yaw": 90},
		{"support": LOWER}
	]:
		var bad: Dictionary = mounted.duplicate(true)
		bad.mastery_banners[0].merge(change, true)
		check(
			not StadiumHomeLayout.validate(bad, stock, "club").ok,
			"reject malformed/uninstalled mount " + str(change)
		)
	var bad: Dictionary = mounted.duplicate(true)
	bad.mastery_banners.append(bad.mastery_banners[0].duplicate(true))
	check(not StadiumHomeLayout.validate(bad, stock, "club").ok, "duplicate banner/socket rejected")
	bad = mounted.duplicate(true)
	bad["unknown"] = true
	check(not StadiumHomeLayout.validate(bad, stock, "club").ok, "unknown wrapper field rejected")
	bad = StadiumStraightItemsUI.select(
		mounted, stock, CREST, {"host": LOWER, "socket": "crest", "support": ""}
	)
	check(
		not StadiumHomeLayout.validate(bad, stock, "club").ok,
		"banner excludes overlapping crest on exact facade"
	)
	check(
		StadiumStraightItemsUI.options(mounted, stock, "ST-042", "club").is_empty(),
		"editor hides crest socket occupied by banner"
	)
	var crested: Dictionary = StadiumStraightItemsUI.select(
		layout, stock, CREST, {"host": LOWER, "socket": "crest", "support": ""}
	)
	check(
		StadiumHomeLayout.validate(crested, stock, "club").ok,
		"unchanged crest validates without banner"
	)
	check(
		not (
			StadiumHomeLayout
			. validate(
				StadiumMasteryBannerItems.place(crested, stock, banner, LOWER), stock, "club"
			)
			. ok
		),
		"crest excludes later banner without displacement"
	)
	var stored: Dictionary = StadiumMasteryBannerItems.store_copy(mounted, banner)
	check(
		(
			stored.mastery_banners.is_empty()
			and StadiumHomeLayout.validate(stored, stock, "club").stored.has(banner)
		),
		"free banner storage preserves owned copy"
	)
	var host_stored: Dictionary = StadiumStraightItemsUI.select(mounted, stock, LOWER, {})
	check(
		host_stored.mastery_banners.is_empty() and host_stored.hosts.is_empty(),
		"storing exact host stores dependent banner"
	)
	var restored: Dictionary = StadiumStraightItemsUI.select(
		host_stored, stock, LOWER, {"site": "BASE-L1", "lower": "", "concourse": ""}
	)
	check(
		restored.mastery_banners.is_empty(), "restoring host does not remount history automatically"
	)
	var replaced: Dictionary = StadiumStraightItemsUI.select(
		mounted, stock, SPARE, {"site": "BASE-L1", "lower": "", "concourse": ""}
	)
	check(
		replaced.mastery_banners.is_empty() and replaced.hosts[0].copy == SPARE,
		"same-site replacement does not transfer banner"
	)
	var moved: Dictionary = StadiumStraightItemsUI.select(
		mounted, stock, LOWER, {"site": "BASE-R1", "lower": "", "concourse": ""}
	)
	check(moved.mastery_banners.is_empty(), "moving exact host stores its banner")
	bad = mounted.duplicate(true)
	bad.hosts[0].site = "BASE-R1"
	check(
		not StadiumMasteryBannerItems.transition(mounted, bad).ok,
		"direct host movement cannot carry saved banner through transition"
	)
	check(
		StadiumMasteryBannerItems.transition(mounted, host_stored).ok,
		"host-plus-banner storage transition allowed"
	)
	var preview: Dictionary = StadiumHomeLayout.preview(mounted, host_stored, stock, "club")
	check(
		(
			preview.ok
			and preview.displaced.has(banner)
			and preview.displaced.has(LOWER)
			and preview.cost == 0
		),
		"movement preview names host and dependent banner, no fee"
	)
	for site: String in StadiumBaselineSites.SITES:
		var candidate: Dictionary = StadiumStraightItemsUI.select(
			empty, stock, LOWER, {"site": site, "lower": "", "concourse": ""}
		)
		candidate = StadiumMasteryBannerItems.place(candidate, stock, banner, LOWER)
		check(
			StadiumHomeLayout.validate(candidate, stock, "club").ok,
			"whole exact facade fits Club " + site
		)
	check(
		(
			StadiumMasteryBannerModels.socket("ST-031").is_empty()
			and StadiumMasteryBannerModels.socket("ST-035").is_empty()
		),
		"no inferred facade sockets on other hosts"
	)


func _model() -> void:
	var model: Node3D = StadiumMasteryBannerModels.create(earned)
	check(model != null, "valid historical static model created")
	if model == null:
		return
	add_child(model)
	check(
		model.get_script() == null and not model is StadiumPennantMotion,
		"no animated pennant substitution"
	)
	check(
		model.get_node("Collision").get_child_count() == 0,
		"commemorative banner has no gameplay collider"
	)
	check(
		(
			ClubCareer.same(model.get_meta("earned"), earned)
			and model.get_meta("identity_mode") == "frozen_era"
		),
		"model retains exact immutable-era snapshot"
	)
	check(
		model.get_node("Visual/EraClubName").text == "FIRST ERA CLUB",
		"printed historical name, not current brand"
	)
	check(
		model.get_node("Visual/FirstSeasonMarker").text == "FIRST TITLE / S5",
		"first qualifying season printed"
	)
	check(
		model.get_node("Visual/EraCrestBall").get_meta("crest_reference") == earned.era.crest,
		"printed crest reference retained"
	)
	for visual: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = visual
		var local: AABB = (
			model.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		)
		check(
			StadiumMasteryBannerModels.ENVELOPE.grow(0.0001).encloses(local),
			"full mesh stays inside authored envelope " + mesh.name
		)
	var copy: Dictionary = earned.duplicate(true)
	copy.era.name = "Later Era"
	check(
		(
			model.get_node("Visual/EraClubName").text == "FIRST ERA CLUB"
			and model.get_meta("earned").era.name == "First Era Club"
		),
		"later unrelated rebrand cannot repaint generated model"
	)
	model.free()
	check(StadiumMasteryBannerModels.create({}) == null, "no missing-record historical fallback")
	copy = earned.duplicate(true)
	copy.mastery_contract = "standard.d5"
	check(
		StadiumMasteryBannerModels.create(copy) == null,
		"unsupported future tier cannot relabel old mastery"
	)
	if mounted.is_empty() or not StadiumHomeLayout.validate(mounted, stock, "club").ok:
		return
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	add_child(property)
	check(property.build("club", mounted, stock), "complete native property includes earned banner")
	if property.objects.has(banner):
		check(property.props_intact(), "initial complete geometry seal intact")
		check(
			(
				property.objects[banner].get_meta("host_copy") == LOWER
				and property.objects[banner].get_meta("socket") == "BANNER-WALL"
			),
			"bound geometry retains exact host and socket"
		)
		check(property.route_obstacles().is_empty(), "decorative banner adds no defender obstacle")
		property.objects[banner].get_node("Visual/MasteryCloth").position.x += 0.01
		check(not property.props_intact(), "changed banner geometry breaks finite seal")
	property.free()


func _snapshot() -> void:
	if mounted.is_empty() or not StadiumHomeLayout.validate(mounted, stock, "club").ok:
		return
	var snapshot: Dictionary = {
		"version": 8,
		"tier": "club",
		"revision": 0,
		"geometry": StadiumHomeLayout.geometry("club", mounted),
		"layout": mounted.duplicate(true),
		"inventory": stock.to_data(),
		"surface_access": StadiumSurfaceProgression.INITIAL_LEGACY.duplicate(),
		"boundary": StadiumOwnedLayout.boundary_signature(mounted)
	}
	check(
		StadiumLayoutSnapshot.valid(snapshot), "synthetic structural snapshot admits exact family41"
	)
	var cold: Variant = JSON.parse_string(JSON.stringify(snapshot))
	check(StadiumLayoutSnapshot.valid(cold), "family41 structural snapshot cold JSON roundtrip")
	check(
		(
			not StadiumLayoutSnapshot.key(cold).is_empty()
			and StadiumLayoutSnapshot.key(snapshot) == StadiumLayoutSnapshot.key(cold)
		),
		"canonical frozen snapshot key stable"
	)
	var bad: Dictionary = snapshot.duplicate(true)
	bad.layout.mastery_banners[0].host = SPARE
	check(not StadiumLayoutSnapshot.valid(bad), "snapshot rejects replacement host substitution")
	check(
		(
			StadiumHomeLayout.geometry("club", StadiumMasteryBannerItems.base(mounted))
			!= snapshot.geometry
		),
		"new geometry version never aliases old family40"
	)
	var access: Array[String] = ["ground_prep"]
	var terrain: Dictionary = StadiumSurfaceLayout.terrain_upgrade(
		StadiumSurfaceLayout.upgrade(StadiumStarterLayout.empty(), access), access
	)
	terrain = StadiumMasteryBannerItems.upgrade(terrain, access)
	terrain = StadiumStraightItemsUI.select(
		terrain, stock, LOWER, {"site": "BASE-L1", "lower": "", "concourse": ""}
	)
	terrain = StadiumMasteryBannerItems.place(terrain, stock, banner, LOWER)
	check(
		(
			StadiumMasteryBannerItems.is_terrain(terrain)
			and StadiumHomeLayout.validate(terrain, stock, "club").ok
		),
		"family41 preserves supported prepared-dirt ancestry"
	)
	var flat: Dictionary = StadiumMasteryBannerItems.contacts_layout(terrain)
	check(
		(
			flat.version == 41
			and flat.base_version == 12
			and flat.mastery_banners.size() == 1
			and StadiumHomeLayout.validate(flat, stock, "club").ok
		),
		"contact projection preserves exact banner while flattening only terrain ancestry"
	)
	var terrain_snapshot: Dictionary = {
		"version": 28,
		"tier": "club",
		"revision": 0,
		"geometry": StadiumOwnedLayout.geometry("club", terrain),
		"layout": terrain,
		"inventory": stock.to_data(),
		"surface_access": access,
		"boundary": StadiumOwnedLayout.boundary_signature(terrain),
		"terrain": StadiumMasteryBannerItems.terrain_contract(terrain)
	}
	var terrain_cold: Variant = JSON.parse_string(JSON.stringify(terrain_snapshot))
	check(
		StadiumLayoutSnapshot.valid(terrain_snapshot) and StadiumLayoutSnapshot.valid(terrain_cold),
		"terrain family41 snapshot cold-validates"
	)
	check(
		(
			not StadiumLayoutSnapshot.key(terrain_cold).is_empty()
			and (
				StadiumLayoutSnapshot.key(terrain_snapshot)
				== StadiumLayoutSnapshot.key(terrain_cold)
			)
		),
		"terrain frozen replay key is warm/cold stable"
	)
