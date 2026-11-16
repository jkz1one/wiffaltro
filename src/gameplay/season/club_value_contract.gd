extends RefCounted
## Pure scalar contract; no career, scene, or ledger dependency.


static func whole(value: Variant, minimum: int, maximum: int) -> bool:
	return (
		(value is int or value is float)
		and is_finite(float(value))
		and value >= minimum
		and value <= maximum
		and float(value) == floorf(float(value))
	)
