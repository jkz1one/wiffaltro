extends "res://src/tests/league_home_modern_origin_test.gd"
## Real isolated owner protocol on a synthetic earned D4 prefix. No games.


func _tier() -> int:
	return 4


func _modern_controls() -> void:
	var selected: SeasonState = SeasonSave.restore()
	check(selected != null and selected._dynasty_career_session.tier == 4
		and selected.league_rules.tier == 4, "durable selected modern Dugout D4 retains tier")
	if selected == null:
		return
	var saved: Dictionary = SeasonSave.snapshot(selected)
	check(saved.version == 91 and saved.checkpoint.checkpoint.version == 85
		and saved.checkpoint.checkpoint.checkpoint.version == 84
		and saved.checkpoint.checkpoint.checkpoint.checkpoint.version == 86,
		"durable modern D4 retains exact 91/85/84/86 owner checkpoint")
	super._modern_controls()
