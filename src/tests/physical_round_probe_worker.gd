extends PhysicalRoundWorker
## Explicit test-only child: observe live parameters with the same existing probes.

var _recovery_probe: OpponentRecoveryProbe = OpponentRecoveryProbe.new()
var _tactical_probe: OpponentTacticalProbe = OpponentTacticalProbe.new()


func _process(delta: float) -> void:
	super._process(delta)
	if _runner != null:
		_recovery_probe.observe(_runner._lab, _check)
		_tactical_probe.observe(_runner._lab, _check)


func _complete(report: Dictionary) -> void:
	var wrote: bool = PhysicalJobFiles.write(_folder.path_join("diagnostics.json"), {
		"activations": _recovery_probe.activations, "releases": _recovery_probe.releases,
		"tape_frames": _tactical_probe.tape_frames, "plan_frames": _tactical_probe.plan_frames})
	if not wrote:
		_fail("Live physical diagnostics could not be written.")
		return
	await super._complete(report)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
