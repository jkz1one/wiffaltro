class_name RecruitCatalog
extends RefCounted
## Exact Working Players v17 / Economy v24 contracts, not approved balance.

const GROUPS: Array[Dictionary] = [
	{
		"ids": ["ash_cole", "dakota_wells", "eli_frost", "jamie_nash"],
		"track": "arm",
		"pitch": "OF",
		"prices": [20, 26, 32]
	},
	{"ids": ["bailey_quinn", "alex_finch"], "track": "arm", "pitch": "OF", "prices": [22, 28, 36]},
	{
		"ids":
		["cal_mercer", "dev_lin", "emery_lane", "finley_brooks", "morgan_pike", "robin_sage"],
		"track": "arm",
		"pitch": "SS",
		"prices": [20, 26, 32]
	},
	{
		"ids": ["drew_sato", "hayden_cole", "mika_reed", "noel_hart", "river_blake", "sage_avery"],
		"track": "arm",
		"pitch": "K",
		"prices": [20, 26, 32]
	},
	{
		"ids": ["gray_west", "kendall_reed", "remy_cruz", "sam_park", "shiloh_dean", "taylor_wren"],
		"track": "fielding",
		"pitch": "",
		"prices": [18, 22, 28]
	},
	{
		"ids":
		[
			"lee_stone",
			"logan_ames",
			"ren_ellis",
			"skyler_woods",
			"kit_rowan",
			"marley_quinn",
			"reese_hart",
			"val_morgan"
		],
		"track": "contact",
		"pitch": "",
		"prices": [18, 24, 30]
	},
	{
		"ids": ["harper_fox", "indy_shaw", "tess_vale"],
		"track": "contact",
		"pitch": "",
		"prices": [20, 26, 32]
	},
	{"ids": ["riley_grant"], "track": "contact", "pitch": "", "prices": [22, 28, 34]},
	{"ids": ["jo_lane", "oakley_james"], "track": "power", "pitch": "", "prices": [18, 24, 30]},
	{
		"ids": ["frankie_bell", "jordan_lake", "nico_vega"],
		"track": "power",
		"pitch": "",
		"prices": [20, 26, 32]
	},
	{"ids": ["rowan_chase"], "track": "power", "pitch": "", "prices": [22, 28, 36]},
	{
		"ids":
		["ari_banks", "casey_rivers", "jules_moss", "kai_soto", "parker_hayes", "quinn_riley"],
		"track": "two_way",
		"pitch": "OF",
		"prices": [20, 24, 30]
	}
]
const ADDITIONS: Dictionary = {
	"contact": [{"contact": 1}, {"contact": 2, "power": 1}, {"contact": 3, "power": 1}],
	"power": [{"contact": 1}, {"contact": 1, "power": 2}, {"contact": 1, "power": 3}],
	"fielding": [{"fielding": 1}, {"contact": 1, "fielding": 2}, {"contact": 1, "fielding": 3}],
	"arm": [{"pitching": 1}, {"fielding": 1, "pitching": 2}, {"fielding": 1, "pitching": 3}],
	"two_way": [{"contact": 1}, {"power": 1, "pitching": 1}, {"power": 2, "pitching": 1}]
}
const STAGES: Array[String] = ["early", "middle", "late"]


static func contract(player_id: String) -> Dictionary:
	for group: Dictionary in GROUPS:
		if group.ids.has(player_id.trim_prefix("player.")):
			return group.duplicate(true)
	return {}


static func fresh(player_id: String, stage: String) -> Dictionary:
	var row: Dictionary = contract(player_id)
	var index: int = STAGES.find(stage)
	if row.is_empty() or index < 0:
		return {}
	var profile: Dictionary = SeasonPlayerCatalog.profile(player_id)
	var additions: Dictionary = ADDITIONS[row.track][index]
	for stat: String in additions:
		profile.stats[stat] += additions[stat]
	if player_id == "player.alex_finch":
		profile.mastery[SeasonPlayerCatalog.RECIPES.E] = 2 if index == 0 else 3
		profile.mastery[SeasonPlayerCatalog.RECIPES.OF] = 2 if index == 2 else 1
	elif not row.pitch.is_empty():
		profile.mastery[SeasonPlayerCatalog.RECIPES[row.pitch]] += index
	# Distinct provenance: these additions are not club-earned training.
	profile["catchup"] = {"stage": stage, "price": row.prices[index]}
	return profile


static func stage_for_visit(visit: int) -> String:
	return STAGES[(visit - 1) / 2] if visit >= 1 and visit <= 6 else ""


static func appearance_chance(visit: int, appeared: bool) -> float:
	if visit < 1 or visit > 6:
		return 0.0
	return 0.5 if visit >= 5 and not appeared else 0.25


static func signature() -> String:
	return JSON.stringify([1, GROUPS, ADDITIONS, "alex:E2/E3/E3+OF2"]).sha256_text()
