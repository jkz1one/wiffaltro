class_name OpponentAbilityProbe
extends RefCounted
## Read-only sampling of actual paid definitions in managed/offscreen physical play.

var count_swings: int = 0
var count_ready: int = 0
var sky_launches: int = 0
var ground_samples: int = 0
var _ball: int = 0


func observe(lab: PitchBatLab, check: Callable) -> void:
	if lab == null or lab._match_state == null:
		return
	var state: MatchState = lab._match_state
	var batter: PlayerDefinition = state.batter().definition
	if batter.season_abilities.has(SeasonAbilities.COUNT) and state.abilities.called_balls >= 2:
		count_ready += 1
		if lab._swing_tracker != null and lab._swing_tracker.active:
			var actual: SwingProfileDefinition = lab._swing_tracker.profile
			var source: SwingProfileDefinition = ContentDB.get_swing(actual.id)
			var gear: SwingProfileDefinition = SeasonGearCatalog.swing(source, batter)
			check.call(is_equal_approx(actual.contact_radius_x_m,
				gear.contact_radius_x_m + source.contact_radius_x_m * 0.06)
				and is_equal_approx(actual.contact_radius_y_m,
				gear.contact_radius_y_m + source.contact_radius_y_m * 0.06),
				"paid AI Work the Count reaches actual swing coverage once")
			count_swings += 1
	if not is_instance_valid(lab._batted_ball):
		return
	var fielder: FielderController = lab._primary_fielder
	if (fielder._sky_reader and fielder.reaction_delay_seconds < fielder._base_reaction_delay
		and lab._batted_ball.get_instance_id() != _ball):
		_ball = lab._batted_ball.get_instance_id()
		check.call(is_equal_approx(fielder.reaction_delay_seconds,
			maxf(SeasonGearCatalog.MIN_REACTION_SECONDS, fielder._base_reaction_delay * 0.60)),
			"paid AI Sky Reader reaches actual high-launch reaction once")
		sky_launches += 1
	if (state.fielder().definition.season_abilities.has(SeasonAbilities.HANDS)
		and lab._ball_play_resolver.state.has_grounded and fielder.reaction_ready()
		and fielder.last_reaction_margin_seconds >= 0.0):
		check.call(MatchAbilities.ground_margin(state.fielder().definition, true,
			fielder.last_reaction_margin_seconds) == 0.10,
			"paid AI Soft Hands eligible ground control uses shared margin")
		ground_samples += 1


func summary() -> String:
	return "count_ready=%d count_swings=%d sky_launches=%d ground_frames=%d" % [
		count_ready, count_swings, sky_launches, ground_samples]
