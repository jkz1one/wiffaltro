class_name StadiumGrandIPublicReceiver
extends StadiumNpcRetainedClubReceiver
## GRAND-I/r1 identity admission only. Retained Club sweep, timing, audio and flex stay inherited.


func configure_pair(target: Node3D, catching_net: Node3D,
	sound_player: PlaySounds = null) -> bool:
	return configure_identity(target, catching_net, sound_player, "npc:GRAND-I:r1:")


func configure_identity(target: Node3D, catching_net: Node3D,
	sound_player: PlaySounds, prefix: String) -> bool:
	if target == null or catching_net == null \
		or not target.has_meta("npc_instance") or not catching_net.has_meta("npc_instance") \
		or not target.has_meta("owned_copy") or not catching_net.has_meta("owned_copy") \
		or target.get_meta("npc_instance", "") != prefix + "RECEIVER-PRIMARY" \
		or catching_net.get_meta("npc_instance", "") != prefix + "RECEIVER-CATCH" \
		or target.get_meta("owned_copy", "") != target.get_meta("npc_instance") \
		or catching_net.get_meta("owned_copy", "") != catching_net.get_meta("npc_instance") \
		or target.get_meta("stadium_item", "") != "ST-026" \
		or catching_net.get_meta("stadium_item", "") != "ST-073" \
		or target.transform != Transform3D(Basis.IDENTITY, StadiumNpcClubTargetV1.POSITION) \
		or catching_net.transform != Transform3D.IDENTITY:
		return false
	for surface: String in StadiumNpcClubNetV1.PANELS:
		_rest_meshes[surface] = catching_net.get_node("Visual/" + surface).mesh
	chair = target
	net = catching_net
	sounds = sound_player
	for model: Node3D in [chair, net]:
		model.process_mode = Node.PROCESS_MODE_PAUSABLE
		for body: StaticBody3D in model.get_node("Collision").get_children():
			body.collision_layer |= LAYER
	return true

