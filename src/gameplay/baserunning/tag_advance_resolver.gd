class_name TagAdvanceResolver
extends RefCounted

const THIRD_TO_HOME_SECONDS: float = 2.35
const SECOND_TO_THIRD_SECONDS: float = 2.85
const SAFETY_MARGIN_SECONDS: float = 0.18

static func resolve(
	bases: BaseState,
	catch_position: Vector3,
	fielding_rating: int
) -> TagAdvanceResult:
	var result: TagAdvanceResult = TagAdvanceResult.new()
	var throw_speed_mps: float = 8.4 + float(fielding_rating) * 0.28
	var gather_seconds: float = 0.82 - float(fielding_rating) * 0.025
	var home_distance: float = Vector2(
		catch_position.x,
		catch_position.z
	).length()
	var home_return_seconds: float = (
		gather_seconds + home_distance / throw_speed_mps
	)

	if (
		not bases.third.is_empty()
		and THIRD_TO_HOME_SECONDS + SAFETY_MARGIN_SECONDS < home_return_seconds
	):
		bases.third = &""
		result.runs_scored = 1
		result.description = "Sac fly: runner scores"

	var third_base: Vector2 = Vector2(-9.0, 9.0)
	var catch_xz: Vector2 = Vector2(catch_position.x, catch_position.z)
	var third_return_seconds: float = (
		gather_seconds + catch_xz.distance_to(third_base) / throw_speed_mps
	)
	if (
		not bases.second.is_empty()
		and bases.third.is_empty()
		and SECOND_TO_THIRD_SECONDS + SAFETY_MARGIN_SECONDS
		< third_return_seconds
	):
		bases.third = bases.second
		bases.second = &""
		result.advanced_from_second = true
		if result.runs_scored > 0:
			result.description += "; runner reaches third"
		else:
			result.description = "Tag: runner reaches third"

	return result
