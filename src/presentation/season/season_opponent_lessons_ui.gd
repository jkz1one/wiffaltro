class_name SeasonOpponentLessonsUI
extends RefCounted
## Read-only public repertoire and paid provenance from the committed opponent build.


static func preview(card: VBoxContainer, club: Dictionary, show_pool: bool = true) -> void:
	if show_pool:
		SeasonPages.wrapped(card, "Opponent stock includes stat training, Pitch Mastery, Round Out, "
			+ "13 initial Gear and five Common pitch lessons. Sponsors, abilities and supplies remain gated."
		).set_meta("opponent_lesson_pool", true)
	var box: VBoxContainer = SeasonPlayerCard.panel(card, false)
	var player: String = club.roles.secondary
	var definition: PlayerDefinition = club.build.definition(player)
	SeasonPages.wrapped(box, "SECOND PITCHER • " + definition.display_name)
	var repertoire: Array[String] = []
	for pitch: PitchDefinition in definition.starting_pitches:
		repertoire.append("%s Lv%d" % [pitch.display_name, pitch.mastery_level])
	SeasonPages.wrapped(box, " / ".join(repertoire)).set_meta("opponent_lesson_repertoire", true)
	var goal: Dictionary = SeasonOpponentLessons.target(club.build, club)
	var rule: String = "Adds the matching missing slider for 10 Cash when a learned slot is free. "
	if club.profile == "Featured hitter":
		rule = "This club skips pitch lessons. "
	elif goal.is_empty():
		rule = "No missing slider with a free learned slot. "
	else:
		rule = "%s • 10 Cash when offered and affordable. " % [
			ContentDB.get_pitch(StringName(goal.pitch)).display_name]
	SeasonPages.wrapped(box, rule + "%d / %d pitches known. Lessons keep personal mastery; "
		% [repertoire.size(), club.build.player(player).capacity]
		+ "this policy never replaces a pitch.")
	for row: Dictionary in club.decisions:
		if row.stat == "lesson":
			purchase(box, row)


static func purchase(card: VBoxContainer, row: Dictionary) -> void:
	SeasonPages.wrapped(card, "Learned %s for %s • Lv%d • %d Cash • %s" % [
		ContentDB.get_pitch(StringName(row.pitch)).display_name,
		ContentDB.get_player(StringName(row.player)).display_name,
		row.level, row.paid, row.reason]).set_meta("opponent_lesson_purchase", true)
