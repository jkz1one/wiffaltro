extends RefCounted
## Fixed normal-main dispatch for binaries that prohibit engine path overrides.
## A token selects local transport only; PhysicalRoundWorker validates the request.

const NORMAL: int = 0
const INVALID: int = -1
const WORKER: int = 1
const DIAGNOSTIC: int = 2
const WORKER_SCENE: PackedScene = preload(
	"res://src/gameplay/simulation/physical_round_worker.tscn"
)
const DIAGNOSTIC_SCENE: PackedScene = preload("res://src/tests/physical_round_probe_worker.tscn")


static func route(arguments: PackedStringArray) -> int:
	var jobs: int = 0
	var probes: int = 0
	var token: String = ""
	var unexpected: bool = false
	for argument: String in arguments:
		if argument.begins_with("--physical-job"):
			jobs += 1
			if argument.begins_with("--physical-job="):
				token = argument.trim_prefix("--physical-job=")
		elif argument == "--physical-probes":
			probes += 1
		else:
			unexpected = true
	if jobs == 0:
		return NORMAL
	if jobs != 1 or probes > 1 or unexpected or PhysicalJobFiles.directory(token).is_empty():
		return INVALID
	return DIAGNOSTIC if probes == 1 else WORKER


static func scene_for(route_value: int) -> PackedScene:
	if route_value == WORKER:
		return WORKER_SCENE
	if route_value == DIAGNOSTIC:
		return DIAGNOSTIC_SCENE
	return null
