class_name StadiumWaterfallAnimationLowBoundary
extends StadiumLowWallBoundaryRuntime


## Explicit47/base46 adapter. Receipt/context stay47; low native graph stays46.
func _motion_context(deep: bool) -> bool:
	if (
		not is_instance_valid(_property)
		or _property.get_script() != StadiumWaterfallAnimationProperty
		or (
			(_property as StadiumWaterfallAnimationProperty).animation_layout.get("animation_base")
			!= 46
		)
		or not (_property as StadiumWaterfallAnimationProperty).motion_context_intact(deep)
	):
		_retire()
		return false
	return true


func intact() -> bool:
	return _motion_context(false) and super.intact()


func deep_intact() -> bool:
	return _motion_context(true) and super.deep_intact()


func bind_issued_ball(ball: BattedBallBody, resolver: BallPlayResolver) -> bool:
	# Exact47 direct bind is a supported transition too, not only the outer API.
	if (
		not _motion_context(true)
		or not (_property as StadiumWaterfallAnimationProperty).deep_props_intact()
	):
		return false
	return super.bind_issued_ball(ball, resolver)
