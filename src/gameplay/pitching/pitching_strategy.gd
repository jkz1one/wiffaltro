class_name PitchingStrategy
extends RefCounted


# Tactical quality changes selection, not player ratings, aim accuracy or physics.
static func choose(
	options: Array[PitchDefinition],
	pitcher: PlayerDefinition,
	balls: int,
	strikes: int,
	previous: int,
	seed_value: int,
	quality: float,
	batter_left: bool
) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var q: float = clampf(quality, 0.0, 1.0)
	var weights: Array[float] = []
	var total: float = 0.0
	for index in range(options.size()):
		var pitch: PitchDefinition = options[index]
		var weight: float = 1.0
		if index == pitcher.signature_pitch_index:
			weight += 2.6
		if pitcher.pitching_style == 1 and pitch.category == PitchDefinition.Category.FASTBALL:
			weight += 2.0
		if pitcher.pitching_style == 2 and pitch.category == PitchDefinition.Category.BREAKING:
			weight += 2.8
		if balls > strikes and pitch.category == PitchDefinition.Category.FASTBALL:
			weight += 1.4
		if strikes == 2 and balls < 3 and pitch.category == PitchDefinition.Category.BREAKING:
			weight += 1.6 * q
		if previous >= 0 and previous < options.size():
			if absf(pitch.nominal_velocity_mps - options[previous].nominal_velocity_mps) > 5.0:
				weight += 1.2 * q
			if index == previous and pitcher.pitching_style != 2:
				weight *= lerpf(0.90, 0.55, q)
		weights.append(weight)
		total += weight
	var roll: float = rng.randf() * total
	var chosen: int = 0
	for index in range(weights.size()):
		roll -= weights[index]
		if roll <= 0.0:
			chosen = index
			break
	var attack: float = 0.80
	if balls >= 3:
		attack = 0.94 if strikes < 2 else 0.87
	elif strikes >= 2:
		attack = lerpf(0.72, 0.48, q)
	var in_zone: bool = rng.randf() < attack
	var corner: bool = (
		rng.randf() < (0.25 + 0.45 * q + (0.16 if pitcher.pitching_style == 3 else 0.0))
	)
	var side: float = -1.0 if rng.randf() < 0.5 else 1.0
	var target: Vector2
	if in_zone:
		target = (
			Vector2(side * rng.randf_range(0.24, 0.35), rng.randf_range(0.72, 1.38))
			if corner
			else (Vector2(rng.randf_range(-0.24, 0.24), rng.randf_range(0.78, 1.32)))
		)
	else:
		var outside: float = 1.0 if batter_left else -1.0
		target = Vector2(outside * rng.randf_range(0.47, 0.61), rng.randf_range(0.66, 1.22))
		if options[chosen].category == PitchDefinition.Category.BREAKING and rng.randf() < 0.5:
			target = Vector2(outside * rng.randf_range(0.10, 0.30), rng.randf_range(0.39, 0.51))
	return {
		"pitch_index": chosen,
		"target": target,
		"effort": rng.randf_range(0.94, 1.04),
		"intent": "ATTACK" if in_zone else "EXPAND"
	}
