extends Node3D
## Explicit private ordinary play entry. No menu, saved venue or career assignment.

var lab: PitchBatLab
var owner_runtime: StadiumHillsidePrivateRuntime


func _ready() -> void:
	lab = PitchBatLab.new()
	lab.name = "PitchBatLab"
	lab._field_id = &"field.npc_venue"
	add_child(lab)
	owner_runtime = StadiumHillsidePrivateRuntime.new()
	if not await owner_runtime.install(lab):
		if owner_runtime.get_parent() == null:
			lab.process_mode = Node.PROCESS_MODE_DISABLED
			if lab._status_label != null:
				lab._status_label.text = "Private Hillside held: " + owner_runtime.last_error
		return
	lab._status_label.text = "Private Hillside • Working terrain\n" + lab._status_label.text
