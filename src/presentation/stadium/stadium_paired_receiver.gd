class_name StadiumPairedReceiver
extends StadiumTargetReceiver
## Explicit target + net recipe; logical plate calls still precede physical presentation.

const PAIR_VERSION: int = 1
const PAIR_CLEANUP_Z: float = -3.10
var net: Node3D
var _pocket: Tween


func configure(_model: Node3D, _sound_player: PlaySounds = null) -> bool:
	return false


func configure_pair(target_model: Node3D, net_model: Node3D,
	sound_player: PlaySounds = null) -> bool:
	if net_model == null or net_model.get_meta("stadium_item", "") != "ST-025" \
		or not net_model.has_meta("owned_copy"):
		return false
	if target_model == null or target_model.get_meta("owned_copy", "") == \
		net_model.get_meta("owned_copy"):
		return false
	if not super.configure(target_model, sound_player):
		return false
	net = net_model
	net.process_mode = Node.PROCESS_MODE_PAUSABLE
	for body: StaticBody3D in net.get_node("Collision").get_children():
		body.collision_layer |= LAYER
	return true


func cleanup_z() -> float:
	return PAIR_CLEANUP_Z


func _owned_hit(hit: Dictionary, fraction: float) -> Dictionary:
	var primary: Dictionary = super._owned_hit(hit, fraction)
	if not primary.is_empty() or hit.is_empty() or not is_instance_valid(net):
		return primary
	var body: Node = instance_from_id(int(hit.collider_id))
	if body == null or not net.is_ancestor_of(body) or not body.has_meta("owned_copy"):
		return {}
	return {"copy": body.get_meta("owned_copy"), "surface": body.get_meta("surface_id"),
		"position": hit.point, "fraction": fraction}


func present_contact(hit: Dictionary, kind: String) -> void:
	if is_instance_valid(chair) and hit.get("copy") == chair.get_meta("owned_copy"):
		super.present_contact(hit, kind)
		return
	if not is_instance_valid(net) or kind not in ["pitch", "batted"] \
		or hit.get("copy") != net.get_meta("owned_copy"):
		return
	contacts.append({"kind": kind, "copy": hit.copy, "surface": hit.surface,
		"elapsed": hit.elapsed, "position": [hit.position.x, hit.position.y, hit.position.z]})
	if is_instance_valid(sounds):
		sounds.play(net_cue(hit.surface))
	if _pocket != null and _pocket.is_valid():
		_pocket.kill()
	if hit.surface == "ST025_NET":
		_pocket = net.create_tween().bind_node(net)
		_pocket.tween_method(_flex_net, 0.0, 0.24, 0.24)


func _flex_net(elapsed: float) -> void:
	if is_instance_valid(net):
		StadiumNetModels.pocket(net, elapsed)


static func net_cue(surface: String) -> StringName:
	if surface == "ST025_NET":
		return &"net_cord"
	if surface.begins_with("ST025_BASE"):
		return &"net_base"
	if surface.begins_with("ST025_SUPPORTS"):
		return &"net_support"
	return &"net_frame"
