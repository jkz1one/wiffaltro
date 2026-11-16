class_name StadiumNpcRetainedReceiver
extends StadiumPairedReceiver
## Legacy contact spelling only: owned_copy contains the real npc instance, never a paid ID.
## Keep the shared swept-contact algorithm; animate the retained model implementation.


func _flex(elapsed: float) -> void:
	if is_instance_valid(chair):
		StadiumNpcExpandedTargetV1.flex(chair, elapsed)


func _flex_net(elapsed: float) -> void:
	if is_instance_valid(net):
		StadiumNpcExpandedNetV1.pocket(net, elapsed)
