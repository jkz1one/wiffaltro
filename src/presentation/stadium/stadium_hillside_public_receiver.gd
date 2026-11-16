class_name StadiumHillsidePublicReceiver
extends StadiumPairedReceiver
## Exact neutral Hillside ST026/ST025 identities; unchanged paired receiver behavior.

var camera_protection: Callable


func configure_pair(target: Node3D, catching_net: Node3D,
	sound_player: PlaySounds = null) -> bool:
	if target == null or catching_net == null \
		or target.get_meta("npc_instance", "") != "npc:HILLSIDE:r1:RECEIVER-PRIMARY" \
		or catching_net.get_meta("npc_instance", "") != "npc:HILLSIDE:r1:RECEIVER-CATCH" \
		or target.get_meta("owned_copy", "") != target.get_meta("npc_instance", "") \
		or catching_net.get_meta("owned_copy", "") != catching_net.get_meta("npc_instance", "") \
		or target.transform != Transform3D(Basis.IDENTITY, StadiumTargetModels.POSITION) \
		or catching_net.transform != Transform3D(Basis.IDENTITY, StadiumNetModels.POSITION) \
		or not target.get_parent() is StadiumHillsidePublicConstruction \
		or catching_net.get_parent() != target.get_parent():
		return false
	return super.configure_pair(target, catching_net, sound_player)
