class_name SeasonSponsorEffects
extends RefCounted
## Working match contracts. Derived from the paid build, never an editable save blob.


static func snapshot(
	active: Array, book: SeasonDevelopment, roster: Array, stamps: Dictionary = {}
) -> Dictionary:
	var result: Dictionary = {}
	for receipt: Dictionary in active:
		if (
			receipt.item
			in [
				"A07",
				"B03",
				"E07",
				"F01",
				"F02",
				"F03",
				"G04",
				"J08",
				"G05",
				"E04",
				"G03",
				"E10",
				"F06",
				"J04",
				"F08",
				"B01",
				"E09"
			]
		):
			result[receipt.item] = true
		elif receipt.item == "E05":
			result.E05 = mini(4, stamps.get(receipt.id, []).size())
		elif receipt.item == "B02":
			result.B02 = mini(4, book.earned_players(roster).size())
	return result


static func workload(player: PlayerDefinition, pitch: PitchDefinition) -> float:
	if player.natural_delivery == null or pitch == null or pitch.delivery_profile == null:
		return 1.0
	if pitch.delivery_profile.id != player.natural_delivery.id:
		return 1.0
	return 1.0 - 0.03 * clampi(int(player.season_sponsors.get("B02", 0)), 0, 4)


static func swing(source: SwingProfileDefinition, state: MatchState) -> SwingProfileDefinition:
	var player: PlayerDefinition = state.batter().definition
	var result: SwingProfileDefinition = SeasonGearCatalog.swing(source, player)
	if source.id == &"swing.contact":
		# Deli is additive with the Bat's exit modifier. Gloves retain their separate
		# once-only multiplicative penalty, including when the Bat penalty is offset.
		var misc: Dictionary = SeasonGearCatalog.item(player.season_gear.get("misc", ""))
		var bonus: float = (
			SeasonCarbonCopy.deli_bonus(state)
			+ 0.01 * clampi(int(player.season_sponsors.get("E05", 0)), 0, 4)
		)
		result.gear_fair_exit_scale += bonus * float(misc.get("exit", 1.0))
	state.abilities.swing(result, source, player)
	state.cold.swing(result, source, state.batter())
	state.sides.swing(result, state)
	if source.id == &"swing.contact" and player.season_sponsors.get("F03", false):
		var axes: Vector2 = optics_axes(state.optics_mode)
		result.contact_radius_x_m *= axes.x
		result.contact_radius_y_m *= axes.y
	return MatchTactics.swing(result, state)


static func deli_active(state: MatchState) -> bool:
	return (
		state._deli_next_batter
		and bool(state.batter().definition.season_sponsors.get("A07", false))
	)


static func strikeout(state: MatchState) -> void:
	var pitcher: PlayerMatchState = state.pitcher()
	var team: TeamMatchState = state.defensive_team()
	if not pitcher.definition.season_sponsors.get("B03", false) or team.strikecraft_uses >= 2:
		return
	var costs: Array = state.pitch_ledger.first_costs(pitcher.definition.id)
	if costs.size() != 3:
		return
	var amount: float = minf(6.0, 0.25 * (costs[0] + costs[1] + costs[2]))
	var before: float = pitcher.stamina_remaining
	pitcher.stamina_remaining = minf(pitcher.stamina_max, before + amount)
	team.strikecraft_uses += 1
	team.strikecraft_refunded += pitcher.stamina_remaining - before


static func optics_axes(mode: String) -> Vector2:
	if mode == "wide":
		return Vector2(1.10, 0.90)
	if mode == "tall":
		return Vector2(0.90, 1.10)
	return Vector2.ONE


static func choose_optics(state: MatchState, mode: String) -> bool:
	if mode not in ["normal", "wide", "tall"] or not state.can_change_defense():
		return false
	if not state.batter().definition.season_sponsors.get("F03", false):
		return false
	state.optics_mode = mode
	return true


static func ground_margin(player: PlayerDefinition, grounded: bool) -> float:
	return -0.08 if grounded and player.season_sponsors.get("F02", false) else 0.0


static func gather_scale(player: PlayerDefinition) -> float:
	return 0.75 if player.season_sponsors.get("F02", false) else 1.0


static func tag_scale(player: PlayerDefinition) -> float:
	return 0.88 if player.season_sponsors.get("G04", false) else 1.0
