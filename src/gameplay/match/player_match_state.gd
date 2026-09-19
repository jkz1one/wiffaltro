class_name PlayerMatchState
extends RefCounted

const BASE_STAMINA: float = 45.0
const STAMINA_PER_RATING: float = 10.0

var definition: PlayerDefinition
var stamina_max: float = 0.0
var stamina_remaining: float = 0.0
var pitch_count: int = 0

static func create(player_definition: PlayerDefinition) -> PlayerMatchState:
	var result: PlayerMatchState = PlayerMatchState.new()
	result.definition = player_definition
	result.stamina_max = (
		BASE_STAMINA
		+ float(player_definition.stamina) * STAMINA_PER_RATING
	)
	result.stamina_remaining = result.stamina_max
	return result

func spend_stamina(amount: float) -> void:
	stamina_remaining = maxf(0.0, stamina_remaining - maxf(0.0, amount))
	pitch_count += 1

func fatigue_ratio() -> float:
	if stamina_max <= 0.0:
		return 1.0
	return clampf(1.0 - stamina_remaining / stamina_max, 0.0, 1.0)

func stamina_percent() -> float:
	if stamina_max <= 0.0:
		return 0.0
	return clampf(stamina_remaining / stamina_max, 0.0, 1.0)
