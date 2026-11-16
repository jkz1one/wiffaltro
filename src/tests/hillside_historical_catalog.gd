extends RefCounted
## Working 101-row stadium register. Data/access only; no placement or purchase is certified.
## Source: WIFFALTRO_STADIUMS v5, CP with CS/DL overrides. Numeric tuning remains Working.

const VERSION: int = 1
const STARTERS: Array[String] = ["ST-001", "ST-003", "ST-079"]
# Name, required progress, blueprint/style price, copy price, kind, access label, detail annex.
const ROWS: Dictionary = {
	"ST-001": ["Orange traffic cone", {}, 0, 40, "copy", "Starter entitlement, DL", "archive-s080"],
	"ST-002": ["Striped beach ball", {"seasons": 2}, 160, 45, "copy", "S>=2", "archive-s080"],
	"ST-003":
	["Woven folding lawn chair", {}, 0, 45, "copy", "Starter entitlement, DL", "archive-s080"],
	"ST-004":
	["Old push mower", {"seasons": 3, "wins": 8}, 240, 70, "copy", "S>=3; W>=8", "archive-s080"],
	"ST-005":
	[
		"Rusty compact car",
		{"seasons": 7, "wins": 20},
		620,
		190,
		"copy",
		"S>=7; W>=20",
		"archive-s080"
	],
	"ST-006":
	[
		"Round above-ground pool",
		{"seasons": 6, "wins": 18},
		540,
		160,
		"copy",
		"S>=6; W>=18",
		"archive-s080"
	],
	"ST-007":
	[
		"Wood-sided hot tub",
		{"seasons": 8, "wins": 25},
		680,
		200,
		"copy",
		"S>=8; W>=25",
		"archive-s080"
	],
	"ST-008":
	[
		"Kettle charcoal BBQ",
		{"seasons": 2, "wins": 5},
		190,
		55,
		"copy",
		"S>=2; W>=5",
		"archive-s080"
	],
	"ST-009": ["Red picnic cooler", {"seasons": 2}, 145, 40, "copy", "S>=2", "archive-s080"],
	"ST-010":
	[
		"Wooden picnic table",
		{"seasons": 3, "wins": 7},
		240,
		70,
		"copy",
		"S>=3; W>=7",
		"archive-s080"
	],
	"ST-011":
	[
		"Striped patio umbrella",
		{"seasons": 4, "wins": 10},
		260,
		75,
		"copy",
		"S>=4; W>=10",
		"archive-s080"
	],
	"ST-012":
	[
		"Weathered timber shed",
		{"seasons": 5, "wins": 15},
		430,
		130,
		"copy",
		"S>=5; W>=15",
		"archive-s080"
	],
	"ST-013": ["Broad-canopy shade tree", {"seasons": 3}, 260, 80, "copy", "S>=3", "archive-s075"],
	"ST-014": ["Box hedge section", {"seasons": 3}, 200, 45, "copy", "S>=3", "archive-s075"],
	"ST-015": ["Potted fern", {"seasons": 2}, 140, 35, "copy", "S>=2", "archive-s075"],
	"ST-016":
	[
		"Wildflower cluster",
		{"seasons": 2, "wins": 4},
		145,
		40,
		"copy",
		"S>=2; W>=4",
		"archive-s075"
	],
	"ST-017": ["Timber raised flowerbed", {"seasons": 4}, 220, 65, "copy", "S>=4", "archive-s075"],
	"ST-018":
	[
		"Stone-edged koi pond",
		{"seasons": 8, "wins": 24},
		720,
		220,
		"copy",
		"S>=8; W>=24",
		"archive-s075"
	],
	"ST-019": ["Boulder rock garden", {"seasons": 5}, 350, 100, "copy", "S>=5", "archive-s075"],
	"ST-020":
	[
		"Weathered wood fence segment",
		{"seasons": 2, "wins": 5},
		200,
		25,
		"copy",
		"S>=2; W>=5",
		"archive-s071"
	],
	"ST-021":
	[
		"Yellow steel foul pole",
		{"seasons": 3, "wins": 10},
		280,
		90,
		"copy",
		"S>=3; W>=10",
		"archive-s095"
	],
	"ST-022":
	[
		"Painted plywood left-field wall",
		{"seasons": 3, "wins": 8},
		280,
		25,
		"copy",
		"S>=3; W>=8",
		"archive-s095"
	],
	"ST-023":
	[
		"Painted plywood right-field wall",
		{"seasons": 3, "wins": 8},
		280,
		25,
		"copy",
		"S>=3; W>=8",
		"archive-s095"
	],
	"ST-024":
	[
		"Painted plywood outfield wall",
		{"seasons": 3, "wins": 10},
		360,
		30,
		"copy",
		"S>=3; W>=10",
		"archive-s095"
	],
	"ST-025":
	[
		"Rectangular framed-net backstop",
		{"seasons": 3, "wins": 8},
		300,
		90,
		"copy",
		"S>=3; W>=8",
		"archive-s087"
	],
	"ST-026":
	[
		"Framed strike-zone target",
		{"strikeouts": 40, "seasons": 1},
		230,
		70,
		"copy",
		"K>=40",
		"archive-s086"
	],
	"ST-027":
	[
		"Two-row wooden bleachers",
		{"seasons": 3, "wins": 8},
		300,
		100,
		"copy",
		"S>=3; W>=8",
		"archive-s081"
	],
	"ST-028":
	[
		"Four-row aluminum bleachers",
		{"seasons": 5, "wins": 15},
		480,
		150,
		"copy",
		"S>=5; W>=15",
		"archive-s081"
	],
	"ST-029":
	[
		"Straight concrete lower grandstand",
		{"seasons": 10, "wins": 30},
		420,
		100,
		"copy",
		"S>=10; W>=30",
		"archive-s099"
	],
	"ST-030":
	[
		"Straight upper-deck section",
		{"seasons": 14, "wins": 45},
		600,
		150,
		"copy",
		"S>=14; W>=45",
		"archive-s099"
	],
	"ST-031":
	[
		"Straight concourse section",
		{"seasons": 10, "wins": 30},
		280,
		60,
		"copy",
		"S>=10; W>=30",
		"archive-s099"
	],
	"ST-032":
	[
		"Open timber dugout",
		{"seasons": 4, "wins": 12},
		420,
		130,
		"copy",
		"S>=4; W>=12",
		"archive-s096"
	],
	"ST-033":
	[
		"Snack-shack concession stand",
		{"seasons": 8, "wins": 24},
		580,
		170,
		"copy",
		"S>=8; W>=24",
		"archive-s076"
	],
	"ST-034":
	[
		"Club merch kiosk",
		{"seasons": 9, "wins": 28},
		620,
		180,
		"copy",
		"S>=9; W>=28",
		"archive-s076"
	],
	"ST-035":
	[
		"Brick stadium entrance gate",
		{"seasons": 20, "wins": 70},
		550,
		140,
		"copy",
		"S>=20; W>=70",
		"archive-s076"
	],
	"ST-036":
	[
		"Warm-bulb string-light span",
		{"seasons": 3, "wins": 8},
		260,
		45,
		"copy",
		"S>=3; W>=8",
		"archive-s120"
	],
	"ST-037":
	[
		"Single-head yard light pole",
		{"seasons": 3, "wins": 8},
		300,
		65,
		"copy",
		"S>=3; W>=8",
		"archive-s077"
	],
	"ST-038":
	[
		"Four-head floodlight tower",
		{"seasons": 10, "wins": 30},
		520,
		120,
		"copy",
		"S>=10; W>=30",
		"archive-s100"
	],
	"ST-039":
	[
		"Hand-operated wooden scoreboard",
		{"seasons": 4, "wins": 10},
		340,
		100,
		"copy",
		"S>=4; W>=10",
		"archive-s076"
	],
	"ST-040":
	[
		"Large stadium video board",
		{"seasons": 22, "wins": 80},
		800,
		220,
		"copy",
		"S>=22; W>=80",
		"archive-s076"
	],
	"ST-041":
	["Hand-painted wooden club sign", {"seasons": 1}, 100, 25, "copy", "S>=1", "archive-s076"],
	"ST-042":
	[
		"Mounted metal club crest",
		{"seasons": 5, "wins": 12},
		300,
		85,
		"copy",
		"S>=5; W>=12",
		"archive-s076"
	],
	"ST-043":
	["Club flag on pole", {"seasons": 2, "wins": 5}, 190, 55, "copy", "S>=2; W>=5", "archive-s076"],
	"ST-044":
	["Championship pennant", {}, 0, -1, "reward", "Each championship season, BU1", "archive-s082"],
	"ST-045":
	[
		"Backyard timber treehouse",
		{"seasons": 6, "wins": 18},
		560,
		170,
		"copy",
		"S>=6; W>=18",
		"archive-s078"
	],
	"ST-046":
	[
		"Rock-face waterfall attraction",
		{"seasons": 24, "wins": 90},
		950,
		260,
		"copy",
		"S>=24; W>=90",
		"archive-s078"
	],
	"ST-047":
	[
		"Rising home-run apple landmark",
		{"seasons": 20, "homers": 40},
		900,
		240,
		"copy",
		"S>=20; R>=40, or CO4 earned route",
		"archive-s078"
	],
	"ST-048":
	[
		"Giant wiffle-ball sculpture",
		{"seasons": 18, "wins": 60},
		600,
		160,
		"copy",
		"S>=18; W>=60",
		"archive-s078"
	],
	"ST-049":
	[
		"Scrap-metal pitching robot statue",
		{"seasons": 18, "strikeouts": 250},
		650,
		170,
		"copy",
		"S>=18; K>=250",
		"archive-s078"
	],
	"ST-050":
	[
		"Giant tiki-head fountain",
		{"seasons": 20, "wins": 70},
		750,
		200,
		"copy",
		"S>=20; W>=70",
		"archive-s078"
	],
	"ST-051":
	[
		"Individual molded stadium seat",
		{"seasons": 4, "wins": 10},
		220,
		45,
		"copy",
		"S>=4; W>=10",
		"archive-s070"
	],
	"ST-052":
	[
		"Rail-enclosed box-seat section",
		{"seasons": 6, "wins": 18},
		520,
		160,
		"copy",
		"S>=6; W>=18",
		"archive-s081"
	],
	"ST-053":
	[
		"Straight steel grandstand canopy",
		{"seasons": 12, "wins": 36},
		420,
		110,
		"copy",
		"S>=12; W>=36",
		"archive-s099"
	],
	"ST-054":
	[
		"Backless outfield bleacher section",
		{"seasons": 11, "wins": 32},
		450,
		120,
		"copy",
		"S>=11; W>=32",
		"archive-s099"
	],
	"ST-055":
	[
		"Glass-front press box",
		{"seasons": 14, "wins": 45},
		520,
		140,
		"copy",
		"S>=14; W>=45",
		"archive-s076"
	],
	"ST-056":
	[
		"Wooden announcer booth",
		{"seasons": 9, "wins": 25},
		540,
		160,
		"copy",
		"S>=9; W>=25",
		"archive-s076"
	],
	"ST-057":
	[
		"Glass-front luxury suite",
		{"seasons": 17, "wins": 55},
		650,
		180,
		"copy",
		"S>=17; W>=55",
		"archive-s076"
	],
	"ST-058":
	[
		"Covered player entrance tunnel",
		{"seasons": 12, "wins": 36},
		420,
		110,
		"copy",
		"S>=12; W>=36",
		"archive-s096"
	],
	"ST-059":
	[
		"Vintage ticket booth",
		{"seasons": 8, "wins": 22},
		450,
		130,
		"copy",
		"S>=8; W>=22",
		"archive-s076"
	],
	"ST-060":
	[
		"Chain-link bullpen enclosure",
		{"seasons": 10, "strikeouts": 120},
		750,
		220,
		"copy",
		"S>=10; K>=120",
		"archive-s078"
	],
	"ST-061":
	[
		"Freestanding net batting cage",
		{"seasons": 10, "hits": 160},
		750,
		220,
		"copy",
		"S>=10; H>=160",
		"archive-s078"
	],
	"ST-062a":
	["Hand-chalked white baselines", {"seasons": 1}, 115, -1, "style", "S>=1", "archive-s071"],
	"ST-062b":
	[
		"Crisp painted white baselines",
		{"seasons": 5, "wins": 12},
		300,
		-1,
		"style",
		"S>=5; W>=12",
		"archive-s071"
	],
	"ST-062c":
	[
		"Flat rubber base-marker set",
		{"seasons": 2, "wins": 5},
		190,
		-1,
		"style",
		"S>=2; W>=5",
		"archive-s071"
	],
	"ST-062d":
	[
		"Raised white base-marker set",
		{"seasons": 6, "wins": 18},
		360,
		-1,
		"style",
		"S>=6; W>=18",
		"archive-s071"
	],
	"ST-063a":
	[
		"Straight-stripe grass cut",
		{"seasons": 2, "wins": 4},
		200,
		-1,
		"style",
		"S>=2; W>=4",
		"archive-s071"
	],
	"ST-063b":
	[
		"Checkerboard grass cut",
		{"seasons": 6, "wins": 18},
		400,
		-1,
		"style",
		"S>=6; W>=18",
		"archive-s071"
	],
	"ST-063c":
	[
		"Diamond grass cut",
		{"seasons": 9, "wins": 28},
		550,
		-1,
		"style",
		"S>=9; W>=28",
		"archive-s071"
	],
	"ST-063d":
	[
		"Concentric-arc grass cut",
		{"seasons": 12, "wins": 36},
		700,
		-1,
		"style",
		"S>=12; W>=36",
		"archive-s071"
	],
	"ST-063e":
	["Worn backyard dirt patches", {"seasons": 2}, 160, -1, "style", "S>=2", "archive-s071"],
	"ST-063f":
	[
		"Red-clay plate-area oval",
		{"seasons": 4, "wins": 10},
		270,
		-1,
		"style",
		"S>=4; W>=10",
		"archive-s071"
	],
	"ST-063g":
	[
		"Brown-dirt basepath strips",
		{"seasons": 6, "wins": 16},
		340,
		-1,
		"style",
		"S>=6; W>=16",
		"archive-s071"
	],
	"ST-063h":
	[
		"Full red-clay infield treatment",
		{"seasons": 10, "wins": 30},
		650,
		-1,
		"style",
		"S>=10; W>=30",
		"archive-s071"
	],
	"ST-063i":
	[
		"Pale-sand plate-area oval",
		{"seasons": 5, "wins": 12},
		300,
		-1,
		"style",
		"S>=5; W>=12",
		"archive-s071"
	],
	"ST-063j":
	[
		"Parallel-raked sand infield",
		{"seasons": 9, "wins": 26},
		520,
		-1,
		"style",
		"S>=9; W>=26",
		"archive-s071"
	],
	"ST-064":
	[
		"Mounted field-distance panel",
		{"seasons": 4, "wins": 10},
		180,
		35,
		"copy",
		"S>=4; W>=10",
		"archive-s095"
	],
	"ST-065":
	[
		"Padded outfield wall panel",
		{"seasons": 10, "wins": 30},
		520,
		35,
		"copy",
		"S>=10; W>=30",
		"archive-s095"
	],
	"ST-066":
	["Retired-number plaque", {}, 0, -1, "reward", "Club Legend record under BU3", "archive-s082"],
	"ST-067":
	["Championship wall banner", {}, 0, -1, "reward", "League mastery under BU2", "archive-s082"],
	"ST-068":
	[
		"LED ribbon-board section",
		{"seasons": 18, "wins": 60},
		480,
		80,
		"copy",
		"S>=18; W>=60",
		"archive-s076"
	],
	"ST-069":
	[
		"Round analog stadium clock",
		{"seasons": 7, "wins": 20},
		330,
		90,
		"copy",
		"S>=7; W>=20",
		"archive-s076"
	],
	"ST-070":
	[
		"Twin-horn PA speaker assembly",
		{"seasons": 6, "wins": 16},
		300,
		85,
		"copy",
		"S>=6; W>=16",
		"archive-s076"
	],
	"ST-071":
	[
		"Chain-link property fence segment",
		{"seasons": 4, "wins": 10},
		280,
		35,
		"copy",
		"S>=4; W>=10",
		"archive-s071"
	],
	"ST-072":
	[
		"Chain-link cage backstop",
		{"seasons": 5, "wins": 14},
		470,
		140,
		"copy",
		"S>=5; W>=14",
		"archive-s089"
	],
	"ST-073":
	[
		"Tall stadium-net backstop",
		{"seasons": 11, "wins": 32},
		480,
		130,
		"copy",
		"S>=11; W>=32",
		"archive-s090"
	],
	"ST-074":
	[
		"Roofed concrete dugout",
		{"seasons": 8, "wins": 24},
		500,
		140,
		"copy",
		"S>=8; W>=24",
		"archive-s096"
	],
	"ST-075":
	[
		"Roofed timber bleacher section",
		{"seasons": 9, "wins": 26},
		480,
		140,
		"copy",
		"S>=9; W>=26",
		"archive-s081"
	],
	"ST-076":
	[
		"Eight-head floodlight tower",
		{"seasons": 24, "wins": 90},
		750,
		180,
		"copy",
		"S>=24; W>=90",
		"archive-s100"
	],
	"ST-077":
	[
		"Brick outfield wall segment",
		{"seasons": 15, "wins": 48},
		700,
		45,
		"copy",
		"S>=15; W>=48",
		"archive-s095"
	],
	"ST-078":
	[
		"Chain-link outfield wall segment",
		{"seasons": 6, "wins": 18},
		450,
		30,
		"copy",
		"S>=6; W>=18",
		"archive-s095"
	],
	"ST-079":
	["Plastic backstop chair", {}, 0, 35, "copy", "Starter entitlement, DL", "archive-s088"],
	"ST-080":
	[
		"Plastic spectator chair",
		{"seasons": 2, "wins": 4},
		150,
		40,
		"copy",
		"S>=2; W>=4",
		"archive-s081"
	],
	"ST-081":
	[
		"Curved home-plate lower grandstand",
		{"seasons": 20, "wins": 70},
		650,
		140,
		"copy",
		"S>=20; W>=70",
		"archive-s099"
	],
	"ST-082":
	[
		"Curved home-plate upper deck",
		{"seasons": 26, "wins": 95},
		800,
		180,
		"copy",
		"S>=26; W>=95",
		"archive-s099"
	],
	"ST-083":
	[
		"Curved home-plate concourse",
		{"seasons": 20, "wins": 70},
		400,
		80,
		"copy",
		"S>=20; W>=70",
		"archive-s099"
	],
	"ST-084":
	[
		"Curved home-plate canopy",
		{"seasons": 24, "wins": 85},
		600,
		140,
		"copy",
		"S>=24; W>=85",
		"archive-s099"
	],
	"ST-085":
	[
		"Right transition grandstand",
		{"seasons": 20, "wins": 70},
		420,
		100,
		"copy",
		"S>=20; W>=70",
		"archive-s099"
	],
	"ST-086":
	[
		"Right transition concourse",
		{"seasons": 21, "wins": 75},
		260,
		60,
		"copy",
		"S>=21; W>=75",
		"archive-s099"
	],
	"ST-087":
	[
		"Wall-top spectator terrace",
		{"seasons": 14, "wins": 44},
		950,
		280,
		"copy",
		"S>=14; W>=44",
		"archive-s099"
	],
	"ST-088":
	[
		"Left transition grandstand",
		{"seasons": 20, "wins": 70},
		420,
		100,
		"copy",
		"S>=20; W>=70",
		"archive-s099"
	],
	"ST-089":
	[
		"Left transition concourse",
		{"seasons": 21, "wins": 75},
		260,
		60,
		"copy",
		"S>=21; W>=75",
		"archive-s099"
	],
}

const LIVE_UNITS: Dictionary = {
	"ST-001": 1,
	"ST-002": 1,
	"ST-003": 1,
	"ST-004": 2,
	"ST-005": 4,
	"ST-006": 4,
	"ST-007": 3,
	"ST-008": 1,
	"ST-009": 1,
	"ST-010": 2,
	"ST-011": 2,
	"ST-012": 4
}
const LAND: Dictionary = {
	"backyard": {"level": 0, "price": 0, "seasons": 0, "wins": 0},
	"expanded": {"level": 1, "price": 600, "seasons": 4, "wins": 10},
	"club": {"level": 2, "price": 1600, "seasons": 10, "wins": 30},
	"mogul": {"level": 3, "price": 4200, "seasons": 20, "wins": 70}
}
# Archived CO4 proposals are retained as metadata only, not automatic grants/access.
const PROPOSED_EARNED_BLUEPRINTS: Dictionary = {
	"ST-026": {"strikeouts": 150}, "ST-047": {"homers": 75}
}


static func item(id: String) -> Dictionary:
	if not ROWS.has(id):
		return {}
	var row: Array = ROWS[id]
	return {
		"id": id,
		"name": row[0],
		"requires": row[1].duplicate(true),
		"blueprint_price": row[2],
		"copy_price": row[3],
		"kind": row[4],
		"requirement": row[5],
		"annex": row[6],
		"starter": STARTERS.has(id),
		"live_units": int(LIVE_UNITS.get(id, 0)),
		"placement_verified": false
	}


static func eligible(id: String, progress: Dictionary) -> bool:
	var entry: Dictionary = item(id)
	if entry.is_empty() or entry.kind == "reward":
		return false
	for key: String in entry.requires:
		if not SeasonOwnership._whole(progress.get(key), int(entry.requires[key]), 1000000000):
			return false
	return true


static func land_eligible(id: String, owned_level: int, progress: Dictionary) -> bool:
	if not LAND.has(id) or id == "backyard":
		return false
	var entry: Dictionary = LAND[id]
	return (
		owned_level == int(entry.level) - 1
		and SeasonOwnership._whole(progress.get("seasons"), int(entry.seasons), 1024)
		and SeasonOwnership._whole(progress.get("wins"), int(entry.wins), 10240)
	)


static func within_live_budget(items: Array) -> bool:
	if items.size() > 4:
		return false
	var units: int = 0
	for id: Variant in items:
		if not id is String or not LIVE_UNITS.has(id):
			return false
		units += int(LIVE_UNITS[id])
	return units <= 4


static func signature() -> String:
	return "5210c3c47688b06faa35a50ec211f65de0a881debc5d7567a4c0e2abe6df204f"
