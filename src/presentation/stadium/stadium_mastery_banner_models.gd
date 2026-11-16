class_name StadiumMasteryBannerModels
extends RefCounted
## Static historical art only. No current-brand fallback, collision, animation or stats.

const VERSION: int = 1
const ENVELOPE: AABB = AABB(Vector3(-0.96, -2.20, -0.045), Vector3(1.92, 2.30, 0.205))
const POINT: Vector3 = Vector3(-3.025, 3.80, 3.85)


static func signature() -> String:
	return (
		JSON
		. stringify(
			{
				"version": VERSION,
				"item": "ST-067",
				"bounds": [-0.96, -2.20, -0.045, 1.92, 2.30, 0.205],
				"host": "ST-029",
				"surface": "Visual/SolidRow5",
				"point": [-3.025, 3.80, 3.85],
				"yaw": -90,
				"historical_print": "era-crest-name-standard-mastery-tier5-first-season",
				"static": true,
				"collision": false
			},
			"",
			true,
			true
		)
		. sha256_text()
	)


static func socket(host_item: String) -> Dictionary:
	if host_item != "ST-029":
		return {}
	var pose: Transform3D = Transform3D(Basis(Vector3.UP, -PI / 2.0), POINT)
	return {
		"id": "BANNER-WALL",
		"host_item": host_item,
		"surface": "Visual/SolidRow5",
		"transform": pose,
		"envelope": pose * ENVELOPE
	}


static func create(achievement: Dictionary) -> Node3D:
	if not StadiumPennantRewards.valid_mastery_record(achievement):
		return null
	var era: Dictionary = achievement.era.duplicate(true)
	var root: Node3D = Node3D.new()
	root.name = "ST067MasteryBanner"
	root.set_meta("stadium_item", "ST-067")
	root.set_meta("geometry_version", VERSION)
	root.set_meta("earned", achievement.duplicate(true))
	root.set_meta("identity_mode", "frozen_era")
	root.set_meta("mastery_contract", achievement.mastery_contract)
	root.set_meta("animation", "none")
	for id: String in ["Visual", "Collision"]:
		var child: Node3D = Node3D.new()
		child.name = id
		root.add_child(child)
	var primary: Color = StadiumStraightOwnedModels._color(era, "primary", 0, Color("42685c"))
	var accent: Color = StadiumStraightOwnedModels._color(era, "accent", 1, Color("e1dcc8"))
	var metal: Color = Color("b5a77b")
	StadiumStraightOwnedModels._art_box(
		root, "BannerHangingRail", Vector3(0, 0, 0), Vector3(1.88, 0.06, 0.06), metal
	)
	for side: int in [-1, 1]:
		StadiumStraightOwnedModels._art_box(
			root,
			"BannerFixing%d" % side,
			Vector3(side * 0.81, 0.015, -0.015),
			Vector3(0.10, 0.15, 0.06),
			metal
		)
	var outline: PackedVector2Array = [
		Vector2(-0.88, -0.07),
		Vector2(0.88, -0.07),
		Vector2(0.88, -2.02),
		Vector2(0.0, -2.15),
		Vector2(-0.88, -2.02)
	]
	var inset: PackedVector2Array = [
		Vector2(-0.82, -0.13),
		Vector2(0.82, -0.13),
		Vector2(0.82, -1.96),
		Vector2(0.0, -2.09),
		Vector2(-0.82, -1.96)
	]
	StadiumStraightOwnedModels._sheet(root, "MasteryClothBorder", outline, 0.025, 0.016, accent)
	StadiumStraightOwnedModels._sheet(root, "MasteryCloth", inset, 0.040, 0.012, primary)
	StadiumStraightOwnedModels._crest_mark(
		root, "EraCrest", era, Vector3(0, -0.74, 0.057), 0.83, false
	)
	StadiumStraightOwnedModels._text(
		root,
		"EraClubName",
		StadiumStraightOwnedModels._short_text(str(era.name), 22).to_upper(),
		Vector3(0, -0.31, 0.084),
		31,
		0.0030,
		accent
	)
	StadiumStraightOwnedModels._text(
		root, "MasteryMarker", "LEAGUE MASTERY", Vector3(0, -1.20, 0.084), 30, 0.0031, accent
	)
	StadiumStraightOwnedModels._text(
		root, "LeagueMarker", "STANDARD", Vector3(0, -1.44, 0.084), 27, 0.0034, accent
	)
	StadiumStraightOwnedModels._text(
		root, "DifficultyMarker", "TIER 5 CHAMPIONS", Vector3(0, -1.66, 0.084), 24, 0.0031, accent
	)
	StadiumStraightOwnedModels._text(
		root,
		"FirstSeasonMarker",
		"FIRST TITLE / S" + str(achievement.season_number),
		Vector3(0, -1.88, 0.084),
		24,
		0.0030,
		accent
	)
	return root
