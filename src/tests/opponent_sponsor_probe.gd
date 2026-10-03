class_name OpponentSponsorProbe
extends RefCounted
## Read-only frame observations; counts are samples, not distinct hits or swings.

var deli_swings: int = 0
var college_releases: int = 0
var refunds: int = 0
var _release_count: int = 0
var _uses: int = 0
var _lab_id: int = 0


func observe(lab: PitchBatLab, check: Callable) -> void:
	if lab == null or lab._match_state == null:
		return
	if lab.get_instance_id() != _lab_id:
		_lab_id = lab.get_instance_id()
		_release_count = 0
		_uses = 0
	var state: MatchState = lab._match_state
	if (SeasonSponsorEffects.deli_active(state) and lab._swing_tracker.active
		and lab._swing_tracker.profile.id == &"swing.contact"):
		var batter: PlayerDefinition = state.batter().definition
		var source: SwingProfileDefinition = ContentDB.get_swing(&"swing.contact")
		var gear: SwingProfileDefinition = SeasonGearCatalog.swing(source, batter)
		var misc: Dictionary = SeasonGearCatalog.item(batter.season_gear.get("misc", ""))
		check.call(is_equal_approx(lab._swing_tracker.profile.gear_fair_exit_scale,
			gear.gear_fair_exit_scale + 0.04 * float(misc.get("exit", 1.0))),
			"paid Deli reaches actual Contact profile exactly once")
		deli_swings += 1
	if lab._automation != null and lab._automation.releases.size() > _release_count:
		_release_count = lab._automation.releases.size()
		var pitcher: PlayerMatchState = state.pitcher()
		var pitch: PitchDefinition = lab._selected_pitch()
		if (pitcher.definition.season_sponsors.get("B02", 0) > 0
			and pitch.delivery_profile.id == pitcher.definition.natural_delivery.id):
			var cost: float = MatchLabSupport.stamina_cost(pitch, lab._pitch_effort)
			cost *= SeasonGearCatalog.workload(pitcher, lab._pitch_effort)
			cost *= SeasonSponsorEffects.workload(pitcher.definition, pitch)
			check.call(is_equal_approx(lab._automation.releases[-1].paid, cost),
				"paid College reduces actual natural-delivery cost once")
			college_releases += 1
	var uses: int = state.away_team.strikecraft_uses + state.home_team.strikecraft_uses
	if uses > _uses:
		for team: TeamMatchState in [state.away_team, state.home_team]:
			check.call(team.strikecraft_uses <= 2 and team.strikecraft_refunded <= 12.0,
				"actual Strikecraft sequences obey team caps")
		refunds += uses - _uses
		_uses = uses


func summary() -> String:
	return "deli_swing_frames=%d college_releases=%d strikecraft_uses=%d" % [
		deli_swings, college_releases, refunds]
