extends RefCounted
## Detached actual instance schema; not a native Node member shadow.
static var reads: int = 0
var process_thread_group: int:
	get:
		reads += 1
		return 0
