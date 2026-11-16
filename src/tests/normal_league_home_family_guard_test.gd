extends Node
const Normal = preload("res://src/gameplay/season/normal_league_home.gd")
func _ready() -> void:
	var rules: Dictionary = LeagueRules.capture("dugout")
	var home: Dictionary = StadiumLayoutSnapshot.capture(ClubAssetLedger.new_club(), true)
	var failures: int = 0
	if not Normal._supported(home, rules): failures += 1
	var cleared: Dictionary = home.duplicate(true)
	cleared.layout.salvage_cars = []
	if not Normal._supported(cleared, rules): failures += 1
	var later: Dictionary = home.duplicate(true)
	later.layout.version = 41
	if Normal._supported(later, rules): failures += 1
	if Normal._supported(home, LeagueRules.capture_tier("dynasty", 0)): failures += 1
	print("NORMAL_HOME_FAMILY_GUARD 4 checks, %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)
