class_name StadiumExpandedProperty
extends StadiumPropertyGeometry
## Candidate-only display rebinding. No production factory or saved-layout registration.

const CAMERA_LAYER: int = 64

var receiver: StadiumPairedReceiver
var display: StadiumScoreboardDisplay
var lab_ref: WeakRef


func _process(_delta: float) -> void:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	if lab != null and is_instance_valid(display) and display._match != lab._match_state:
		display.bind_match(lab._match_state)


func prepare_receiver(lab: PitchBatLab) -> bool:
	# Configuration is fallible and must finish while the original lab scene is intact.
	if lab == null or is_instance_valid(receiver) or get_parent() != null:
		return false
	var target: Node3D = objects.get("npc-candidate:AE-01:RECEIVER-PRIMARY")
	var net: Node3D = objects.get("npc-candidate:AE-01:RECEIVER-CATCH")
	if (
		not is_instance_valid(target)
		or not is_instance_valid(net)
		or target.get_meta("stadium_item", "") != "ST-026"
		or net.get_meta("stadium_item", "") != "ST-025"
		or target.transform != StadiumExpandedVenueStudy.pose("RECEIVER-PRIMARY")
		or net.transform != StadiumExpandedVenueStudy.pose("RECEIVER-CATCH")
	):
		return false
	var prepared: StadiumPairedReceiver = StadiumPairedReceiver.new()
	prepared.name = "PitchReceiverPresentation"
	add_child(prepared)
	if not prepared.configure_pair(target, net, lab._sounds):
		prepared.free()
		return false
	receiver = prepared
	for body: StaticBody3D in find_children("*", "StaticBody3D", true, false):
		body.collision_layer |= CAMERA_LAYER
	return true
