class_name SeasonDoubleheaderRules
extends RefCounted
## Closed candidate only. Pair order and venues retain the ordinary round robin;
## its return legs move next to their first legs without consuming any RNG.

const SWEEP_BONUS: int = 6


static func schedule() -> Array[Dictionary]:
	var fixtures: Array[Dictionary] = []
	var rotation: Array[int] = [0, 1, 2, 3, 4, 5]
	for round_number in range(5):
		for pair in range(3):
			var away: int = rotation[pair]
			var home: int = rotation[5 - pair]
			if (round_number + pair) % 2 == 1:
				var held: int = away
				away = home
				home = held
			fixtures.append({"id": round_number * 6 + pair, "round": round_number * 2,
				"away": away, "home": home})
			fixtures.append({"id": round_number * 6 + 3 + pair, "round": round_number * 2 + 1,
				"away": home, "home": away})
		rotation.insert(1, rotation.pop_back())
	return fixtures


static func first(game: Variant) -> int:
	# Integral JSON numbers are accepted; booleans, coercions and playoffs are not.
	if not (game is int or game is float) or not is_finite(float(game)) \
		or float(game) != floor(float(game)) or game < 0 or game >= 30:
		return -1
	return int(game) - 3 if int(game) % 6 >= 3 else -1


static func bonus(rules: Variant, game: Variant, win: Variant, rewards: Variant) -> int:
	if not LeagueRules.doubleheader(rules) or not win is bool or not win \
		or not rewards is Dictionary:
		return 0
	var first_game: int = first(game)
	if first_game < 0:
		return 0
	var paid_first: Variant = rewards.get(str(first_game))
	return SWEEP_BONUS if paid_first is bool and paid_first else 0
