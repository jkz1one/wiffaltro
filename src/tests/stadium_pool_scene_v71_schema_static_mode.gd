extends RefCounted
## Detached actual static schema; not a native Node member shadow.
static var reads: int = 0
static var process_mode: int:
	get:
		reads += 1
		return 0
