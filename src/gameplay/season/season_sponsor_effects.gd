class_name SeasonSponsorEffects
extends RefCounted
## Working match contracts. Derived from the paid build, never an editable save blob.


static func snapshot(active: Array, book: SeasonDevelopment, roster: Array) -> Dictionary:
	var result: Dictionary = {}
	for receipt: Dictionary in active:
		if receipt.item == "A07":
			result.A07 = true
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
	if source.id == &"swing.contact" and deli_active(state):
		# Deli is additive with the Bat's exit modifier. Gloves retain their separate
		# once-only multiplicative penalty, including when the Bat penalty is offset.
		var misc: Dictionary = SeasonGearCatalog.item(player.season_gear.get("misc", ""))
		result.gear_fair_exit_scale += 0.04 * float(misc.get("exit", 1.0))
	return result


static func deli_active(state: MatchState) -> bool:
	return (
		state._deli_next_batter
		and bool(state.batter().definition.season_sponsors.get("A07", false))
	)
