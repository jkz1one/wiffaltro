class_name StadiumPoolPartyPublicReceiver
extends StadiumPairedReceiver
## Exact neutral ST026/ST025 admission; original pair contact, flex, timing and sound.

var camera_protection: Callable


func configure_pair(target: Node3D, catching_net: Node3D,
	sound_player: PlaySounds = null) -> bool:
	if target == null or catching_net == null \
		or target.get_meta("npc_instance", "") != "npc:POOL-PARTY:r1:RECEIVER-PRIMARY" \
		or catching_net.get_meta("npc_instance", "") != "npc:POOL-PARTY:r1:RECEIVER-CATCH" \
		or target.transform != Transform3D(Basis.IDENTITY, StadiumTargetModels.POSITION) \
		or catching_net.transform != Transform3D(Basis.IDENTITY, StadiumNetModels.POSITION):
		return false
	return super.configure_pair(target, catching_net, sound_player)
