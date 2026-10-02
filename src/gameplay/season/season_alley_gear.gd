class_name SeasonAlleyGear
extends RefCounted
## User-selected Working calibration, 2026-10-02. Historical A02 identity is retained.

const BASE: String = "A02"
const GAP: String = "BAT-ALY-02"
const ITEMS: Dictionary = {
	"A02":
	{
		"name": "Alley Bat",
		"slot": "bat",
		"price": 12,
		"strength": 0.25,
		"power_exit": 0.92,
		"status": "Working calibration",
		"effect":
		(
			"Clean elevated Contact flattens 25% toward 10°. Fair Power exit speed −8%. "
			+ "Smooth entry: quality 65–70%, launch 12–14°; fades at 38–40°. No added speed or steering."
		)
	},
	"BAT-ALY-02":
	{
		"name": "Gap Driver",
		"slot": "bat",
		"price": 16,
		"strength": 0.50,
		"power_exit": 0.88,
		"status": "Working calibration",
		"effect":
		(
			"Clean elevated Contact flattens 50% toward 10°. Fair Power exit speed −12%. "
			+ "Smooth entry: quality 65–70%, launch 12–14°; fades at 38–40°. No added speed or steering."
		)
	}
}


static func angle(launch: float, quality: float, strength: float) -> float:
	if strength == 0.0 or quality <= 0.65 or launch <= 12.0 or launch >= 40.0:
		return launch
	var weight: float = smoothstep(0.65, 0.70, quality)
	weight *= smoothstep(12.0, 14.0, launch) * (1.0 - smoothstep(38.0, 40.0, launch))
	return lerpf(launch, 10.0, strength * weight)


static func configure(profile: SwingProfileDefinition, player: PlayerDefinition) -> void:
	var id: String = player.season_gear.get("bat", "")
	if not ITEMS.has(id):
		return
	if profile.id == &"swing.contact":
		profile.gear_line_drive_strength = ITEMS[id].strength
		profile.gear_line_drive_calibrated = player.season_alley_calibrated
	elif profile.id == &"swing.power":
		profile.gear_fair_exit_scale *= ITEMS[id].power_exit
