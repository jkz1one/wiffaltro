class_name PitchMastery
extends RefCounted
## Physical calibration candidates for the explicit Working progression playtest.
## Ladder order follows Players/Pitches v17; numeric magnitudes are not approved balance.

const MOVEMENT_STEP: float = 0.06
const AMPLITUDE_STEP: float = 0.08
const LATE_STEP: float = 0.18
const VELOCITY_STEP: float = 0.025
const RELIABILITY_STEP: float = 0.92


static func apply(recipe: PitchDefinition, level: int) -> PitchDefinition:
	if recipe == null or level < 1 or level > SeasonDevelopment.PITCH_CAP:
		return null
	if not SeasonPlayerCatalog.RECIPES.values().has(String(recipe.id)):
		return null
	recipe = ContentDB.get_pitch(recipe.id)
	var result: PitchDefinition = recipe.duplicate() as PitchDefinition
	result.command_only_quality = true
	result.mastery_level = level
	# Always build from the exact authored recipe, never compound a prior level.
	result.mastery_movement_scale = 1.0
	result.mastery_late_bias = 0.0
	result.mastery_noise_scale = 1.0
	var movement_steps: int = int(level >= 2) + int(level >= 4)
	var amplitude_steps: int = int(level >= 3) + int(level >= 5)
	match recipe.id:
		&"pitch.overhand_four_seam", &"pitch.riser":
			result.mastery_movement_scale += MOVEMENT_STEP * movement_steps
			result.nominal_velocity_mps *= 1.0 + VELOCITY_STEP * amplitude_steps
		&"pitch.eephus", &"pitch.knuckleball":
			result.mastery_noise_scale = pow(RELIABILITY_STEP, level - 1)
		_:
			result.mastery_late_bias = LATE_STEP * movement_steps
			result.mastery_movement_scale += AMPLITUDE_STEP * amplitude_steps
	return result


static func next_effect(recipe: PitchDefinition) -> String:
	if recipe.mastery_level >= SeasonDevelopment.PITCH_CAP:
		return "Level 5 cap reached."
	match recipe.id:
		&"pitch.overhand_four_seam", &"pitch.riser":
			return (
				"+6 percentage points to this recipe's aerodynamic movement scale."
				if recipe.mastery_level % 2 == 1
				else "+2.5% of authored recipe speed (m/s), before effort and temporary modifiers."
			)
		&"pitch.eephus", &"pitch.knuckleball":
			return "Execution spread ×0.92; speed identity and seeded natural wobble remain."
		_:
			return (
				"Redistribute continuous movement later: early weight −0.18, late weight +0.18."
				if recipe.mastery_level % 2 == 1
				else "+8 percentage points to this recipe's aerodynamic movement scale."
			)
