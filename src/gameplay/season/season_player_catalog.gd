class_name SeasonPlayerCatalog
extends RefCounted
## Working v17 player rows for explicit progression playtests.
## Source: WIFFALTRO_PLAYERS_PITCHES.md, 2026-09-26. These are not approved balance.
## Authored resources remain the authority for IDs, names, hands and natural delivery.

const STATUS: String = "Working"
const STATS: Array[String] = ["contact", "power", "fielding", "pitching"]
const RECIPES: Dictionary = {
	"OF": "pitch.overhand_four_seam",
	"ON": "pitch.overhand_sinker",
	"OS": "pitch.overhand_slider",
	"SN": "pitch.sidearm_sinker",
	"SS": "pitch.sidearm_slider",
	"R": "pitch.riser",
	"D": "pitch.drop",
	"K": "pitch.knuckleball",
	"E": "pitch.eephus"
}
# Four ratings, ordered repertoire (E2 is Alex's sole level-2 exception), capacity.
const ROWS: Dictionary = {
	"player.alex_finch": [[2, 1, 2, 5], ["OF", "OS", "ON", "E2"], 5],
	"player.ari_banks": [[2, 3, 2, 3], ["OF", "ON", "D"], 4],
	"player.ash_cole": [[2, 1, 2, 4], ["OF", "OS", "ON"], 4],
	"player.bailey_quinn": [[2, 1, 2, 4], ["OF", "OS", "ON", "R", "D"], 6],
	"player.cal_mercer": [[1, 2, 3, 3], ["SN", "SS", "R"], 3],
	"player.casey_rivers": [[3, 2, 2, 3], ["OF", "ON", "D"], 4],
	"player.dakota_wells": [[2, 2, 2, 3], ["OF", "OS", "ON"], 4],
	"player.dev_lin": [[2, 1, 3, 3], ["SN", "SS", "R"], 4],
	"player.drew_sato": [[3, 3, 1, 2], ["OF", "K", "OS"], 3],
	"player.eli_frost": [[1, 2, 3, 3], ["OF", "OS", "ON"], 4],
	"player.emery_lane": [[2, 2, 3, 2], ["SN", "SS", "R"], 4],
	"player.finley_brooks": [[1, 2, 4, 2], ["SN", "SS", "R"], 3],
	"player.frankie_bell": [[1, 4, 1, 1], ["OF", "OS"], 3],
	"player.gray_west": [[2, 1, 4, 2], ["SN", "SS", "K"], 3],
	"player.harper_fox": [[4, 2, 2, 2], ["OF", "R", "D"], 3],
	"player.hayden_cole": [[2, 3, 1, 3], ["OF", "K", "ON"], 4],
	"player.indy_shaw": [[4, 1, 2, 2], ["ON", "OS", "OF"], 3],
	"player.jamie_nash": [[2, 2, 3, 3], ["OF", "OS", "ON"], 4],
	"player.jo_lane": [[2, 3, 1, 1], ["OF", "ON"], 3],
	"player.jordan_lake": [[1, 4, 2, 1], ["OF", "OS"], 2],
	"player.jules_moss": [[2, 3, 3, 2], ["OF", "ON", "D"], 4],
	"player.kai_soto": [[2, 2, 3, 3], ["OF", "ON", "D"], 4],
	"player.kendall_reed": [[3, 1, 3, 2], ["SN", "SS", "K"], 4],
	"player.kit_rowan": [[3, 1, 3, 2], ["ON", "OS", "OF"], 4],
	"player.lee_stone": [[3, 2, 3, 2], ["OF", "R", "D"], 4],
	"player.logan_ames": [[3, 2, 2, 3], ["OF", "R", "D"], 4],
	"player.marley_quinn": [[3, 1, 2, 3], ["ON", "OS", "OF"], 4],
	"player.mika_reed": [[3, 2, 1, 3], ["OF", "K", "OS"], 4],
	"player.morgan_pike": [[2, 1, 3, 3], ["SN", "SS", "R"], 4],
	"player.nico_vega": [[2, 4, 1, 1], ["OF", "E"], 2],
	"player.noel_hart": [[2, 3, 2, 2], ["OF", "K", "ON"], 4],
	"player.oakley_james": [[2, 3, 2, 1], ["OF", "ON"], 3],
	"player.parker_hayes": [[2, 2, 3, 3], ["OF", "ON", "D"], 4],
	"player.quinn_riley": [[3, 2, 3, 2], ["OF", "ON", "D"], 3],
	"player.reese_hart": [[3, 1, 2, 3], ["ON", "OS", "OF"], 4],
	"player.remy_cruz": [[2, 1, 4, 2], ["SN", "SS", "K"], 3],
	"player.ren_ellis": [[3, 2, 3, 2], ["OF", "R", "D"], 4],
	"player.riley_grant": [[4, 1, 2, 3], ["OF", "OS", "ON", "D"], 5],
	"player.river_blake": [[3, 3, 1, 2], ["OF", "K", "OS"], 3],
	"player.robin_sage": [[2, 2, 3, 2], ["SN", "SS", "R"], 4],
	"player.rowan_chase": [[1, 5, 1, 1], ["OF", "E"], 2],
	"player.sage_avery": [[2, 3, 2, 2], ["OF", "K", "ON"], 4],
	"player.sam_park": [[2, 1, 4, 2], ["SN", "SS", "K"], 3],
	"player.shiloh_dean": [[2, 1, 3, 3], ["SN", "SS", "K"], 4],
	"player.skyler_woods": [[3, 2, 2, 3], ["OF", "R", "D"], 4],
	"player.taylor_wren": [[3, 1, 3, 2], ["SN", "SS", "K"], 4],
	"player.tess_vale": [[4, 1, 2, 2], ["ON", "OS", "OF"], 3],
	"player.val_morgan": [[3, 1, 3, 2], ["ON", "OS", "OF"], 4]
}


static func ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(ROWS.keys())
	result.sort()
	return result


static func profile(player_id: String) -> Dictionary:
	if not ROWS.has(player_id):
		return {}
	var row: Array = ROWS[player_id]
	var stats: Dictionary = {}
	for index in range(STATS.size()):
		stats[STATS[index]] = row[0][index]
	var active: Array[String] = []
	var mastery: Dictionary = {}
	for code: String in row[1]:
		var recipe: String = RECIPES[code.trim_suffix("2")]
		active.append(recipe)
		mastery[recipe] = 2 if code.ends_with("2") else 1
	return {
		"id": player_id,
		"base": stats.duplicate(),
		"stats": stats,
		"capacity": row[2],
		"active": active,
		"mastery": mastery
	}


static func signature() -> String:
	return JSON.stringify(ROWS).sha256_text()


static func lesson_supported(recipe: String) -> bool:
	if not RECIPES.values().has(recipe):
		return false
	var pitch: PitchDefinition = ContentDB.get_pitch(StringName(recipe))
	# Current ordinary recipes all have a supported authored release. Natural
	# delivery is not a same-arm-slot restriction (the source has mixed repertoires).
	return (
		pitch != null
		and pitch.delivery_profile != null
		and pitch.delivery_profile.id in [&"delivery.overhand", &"delivery.sidearm"]
	)
