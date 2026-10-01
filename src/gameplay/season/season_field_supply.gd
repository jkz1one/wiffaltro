class_name SeasonFieldSupply
extends RefCounted
# gdlint: disable=max-returns
## Working B01: six clean outs in one season earn future paid access.

const ITEMS: Dictionary = {
	"B01":
	{
		"name": "Field Supply Co.",
		"price": 14,
		"rarity": "Uncommon",
		"weight": 1.0,
		"effect":
		(
			"After your third clean fielded out, gain one Grip Tape at the next batter boundary. "
			+ "Once per game. A full shared bag forfeits it; no queue. No Cash or training grant."
		)
	}
}


static func settle(build: SeasonBuild, command: Dictionary) -> String:
	if build._field_start == null or not command.has("fielding"):
		return ""
	if not SeasonJumpstart.valid(build, command.fielding, command.get("performance", {})):
		return "Invalid clean fielded-out evidence."
	for row: Dictionary in command.fielding:
		if row.clean:
			build._field_outs += 1
	return ""


static func access(club: ClubCareer, before_current: bool = false) -> bool:
	for run: Dictionary in club.runs:
		if before_current and run.id == club.current:
			break
		if run.field_outs != null and run.field_outs >= 6:
			return true
	return false


static func matches(club: ClubCareer, season: SeasonState, exact: bool) -> bool:
	var build: SeasonBuild = season.build
	var run: Dictionary = club.runs[-1]
	if (run.field_outs != null) != (build._field_start != null):
		return false
	return (
		build._field_start == null
		or (
			build._field_start == access(club, true)
			and (not exact or run.field_outs == build._field_outs)
		)
	)


static func progress(menu: SeasonMenu) -> void:
	var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(
		card,
		"Field Supply Co. • " + ("SHOP ELIGIBLE" if access(menu.app.season.career) else "LOCKED"),
		22
	)
	SeasonPages.wrapped(
		card,
		(
			"Season: six clean fielded outs across completed games. Any credited defender. "
			+ "No Ks, foul catches or prior bobbles. 14 Cash • Uncommon • Working. "
			+ ITEMS.B01.effect
		)
	)
	if menu.app.season.build != null and menu.app.season.build._field_start != null:
		SeasonPages.wrapped(
			card, "%d / 6 clean fielded outs this season" % menu.app.season.build._field_outs
		)
	if menu.app.season.build == null or menu.app.season.build._field_start == null:
		SeasonPages.wrapped(card, "This older active save begins tracking next Working season.")
