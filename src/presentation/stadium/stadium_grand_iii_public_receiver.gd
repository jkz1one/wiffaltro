class_name StadiumGrandIIIPublicReceiver
extends StadiumGrandIPublicReceiver
## Exact II receiver identity; all retained contact/audio/flex mechanics stay shared.


func configure_pair(target: Node3D, catching_net: Node3D,
	sound_player: PlaySounds = null) -> bool:
	return configure_identity(target, catching_net, sound_player, "npc:GRAND-III:r1:")
