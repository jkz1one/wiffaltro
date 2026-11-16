class_name SeasonFrozenRope
extends RefCounted
## Selected Working final Alley tier. Keep SeasonAlleyGear.ITEMS frozen for Build40.

const ID: String = "BAT-ALY-03"
const ITEMS: Dictionary = {
	"BAT-ALY-03":
	{
		"name": "Frozen Rope",
		"slot": "bat",
		"price": 20,
		"strength": 0.75,
		"power_exit": 0.84,
		"status": "Working gap calibration",
		"effect":
		(
			"Clean elevated Contact flattens 75% toward 10°. Fair Power exit speed −16%. "
			+ "Contact above 80% quality favors nearby gaps, up to 4° at perfect contact. "
			+ "Stays in the original pull/center/opposite sector. No better lane or an exact tie "
			+ "leaves direction unchanged. No added speed or guaranteed hit."
		)
	}
}


static func configure(profile: SwingProfileDefinition, player: PlayerDefinition) -> void:
	if player.season_gear.get("bat", "") != ID:
		return
	if profile.id == &"swing.contact":
		profile.gear_line_drive_strength = 0.75
		profile.gear_line_drive_calibrated = player.season_alley_calibrated
		profile.gear_gap_bias = player.season_alley_calibrated
	elif profile.id == &"swing.power":
		profile.gear_fair_exit_scale *= 0.84
