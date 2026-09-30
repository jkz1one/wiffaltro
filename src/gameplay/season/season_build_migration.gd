class_name SeasonBuildMigration
extends RefCounted


static func apply(build: SeasonBuild) -> void:
	# Activate each newly supported pool at the next visit, preserving every
	# already enabled boundary and the exact generator of the saved current visit.
	var next_visit: int = int(build._visit.number) + 1
	if build._format < 2:
		build._recruit_from = next_visit
	if build._format < 3:
		build._gear_from = next_visit
	if build._format < 4:
		build._misc_from = next_visit
	if build._format < 5:
		build._mapped_gear_from = next_visit
	if build._format < 6:
		build._sponsor_from = next_visit
	if build._format < 7:
		build._gameplay_sponsor_from = next_visit
	if build._format < 8:
		build._sequence_sponsor_from = next_visit
	if build._format < 9:
		build._field_sponsor_from = next_visit
	if build._format < 10:
		build._shop_sponsor_from = next_visit
	if build._format < 11:
		build._school_sponsor_from = next_visit
	if build._format < 12:
		build._anchor_sponsor_from = next_visit
	if build._format < 13:
		build._wholesale_from = next_visit
	if build._format < 14:
		build._tactical_from = next_visit
	if build._format < 15:
		build._expanded_tactical_from = next_visit
	if build._format < 16:
		build._tactical_sponsor_from = next_visit
	if build._format < 17:
		build._budget_from = next_visit
	if build._format < 18:
		build._film_from = next_visit
	build._format = SeasonBuild.VERSION
