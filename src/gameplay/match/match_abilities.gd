class_name MatchAbilities
extends RefCounted
## Per-PA called-ball evidence, never inferred from a synthetic starting count.

var called_balls: int = 0
var released: bool = false


func reset() -> void:
	called_balls = 0
	released = false


func called(state: MatchState, strike: bool) -> void:
	if released and state.phase == MatchState.Phase.PITCH_IN_FLIGHT and not strike:
		called_balls = mini(2, called_balls + 1)
	released = false


func swing(
	result: SwingProfileDefinition, source: SwingProfileDefinition, player: PlayerDefinition
) -> void:
	if called_balls >= 2 and player.season_abilities.has(SeasonAbilities.COUNT):
		result.contact_radius_x_m += source.contact_radius_x_m * 0.06
		result.contact_radius_y_m += source.contact_radius_y_m * 0.06


func label(player: PlayerDefinition) -> String:
	if not player.season_abilities.has(SeasonAbilities.COUNT):
		return ""
	return (
		"WORK THE COUNT • +6% spatial coverage"
		if called_balls >= 2
		else "WORK THE COUNT • %d/2 called balls" % called_balls
	)


static func ground_margin(
	player: PlayerDefinition, grounded: bool, reaction_margin: float
) -> float:
	return (
		0.10
		if (
			grounded
			and reaction_margin >= 0.0
			and player.season_abilities.has(SeasonAbilities.HANDS)
		)
		else 0.0
	)


static func sky_delay(base: float, launch: BattedBallLaunch) -> float:
	if launch == null or launch.is_foul:
		return base
	var horizontal: float = Vector2(launch.velocity.x, launch.velocity.z).length()
	var angle: float = rad_to_deg(atan2(launch.velocity.y, horizontal))
	return maxf(SeasonGearCatalog.MIN_REACTION_SECONDS, base * 0.60) if angle >= 25.0 else base
