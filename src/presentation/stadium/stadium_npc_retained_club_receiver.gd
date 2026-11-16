class_name StadiumNpcRetainedClubReceiver
extends StadiumClubPitchReceiver
## Shared sweep/timing/camera-cut algorithm, with retained model animation and real NPC IDs.
## No authoring configure/build is called: detached staged transforms are checked exactly.

var flex_elapsed: float = StadiumNpcClubNetV1.SETTLE
var flex_surface: String = ""
var flex_impact: Vector3 = Vector3.ZERO
var _rest_meshes: Dictionary = {}


func configure_pair(target: Node3D, catching_net: Node3D,
	sound_player: PlaySounds = null) -> bool:
	if target == null or catching_net == null \
		or target.get_meta("npc_instance", "") != "npc:AC-01:r1:RECEIVER-PRIMARY" \
		or catching_net.get_meta("npc_instance", "") != "npc:AC-01:r1:RECEIVER-CATCH" \
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


func _flex(elapsed: float) -> void:
	if is_instance_valid(chair):
		StadiumNpcClubTargetV1.flex(chair, elapsed)


func present_contact(hit: Dictionary, kind: String) -> void:
	if not is_instance_valid(chair) or not is_instance_valid(net) \
		or kind not in ["pitch", "batted"]:
		return
	if hit.get("copy") == chair.get_meta("npc_instance"):
		contacts.append({"kind": kind, "copy": hit.copy, "surface": hit.surface,
			"elapsed": hit.elapsed, "position": [hit.position.x, hit.position.y, hit.position.z]})
		if is_instance_valid(sounds):
			sounds.play(target_cue(hit.surface))
		if _rock != null and _rock.is_valid():
			_rock.kill()
		if hit.surface == "ST026_PANEL":
			_rock = chair.create_tween().bind_node(chair)
			_rock.tween_method(_flex, 0.0, 0.18, 0.18)
		return
	if hit.get("copy") != net.get_meta("npc_instance"):
		return
	contacts.append({"kind": kind, "copy": hit.copy, "surface": hit.surface,
		"elapsed": hit.elapsed, "position": [hit.position.x, hit.position.y, hit.position.z]})
	if is_instance_valid(sounds):
		sounds.play(&"net_cord" if StadiumNpcClubNetV1.PANELS.has(hit.surface) else &"net_frame")
	if _pocket != null and _pocket.is_valid():
		_pocket.kill()
	if not flex_surface.is_empty():
		# Restore exact retained rest data before switching panels.
		_restore_panel(flex_surface)
	flex_surface = ""
	_flex_surface = ""
	if StadiumNpcClubNetV1.PANELS.has(hit.surface):
		_flex_surface = hit.surface
		_flex_net(0, hit.surface, hit.position)
		_pocket = net.create_tween().bind_node(net)
		_pocket.tween_method(_flex_net.bind(hit.surface, hit.position),
			0.0, StadiumNpcClubNetV1.SETTLE, StadiumNpcClubNetV1.SETTLE)


func _restore_panel(surface: String) -> void:
	# Restore original retained mesh bytes, including signed zero and unchanged array channels.
	net.get_node("Visual/" + surface).mesh = _rest_meshes[surface]


func _flex_net(elapsed: float, surface: String, point: Vector3) -> void:
	if is_instance_valid(net):
		if not flex_surface.is_empty() and flex_surface != surface:
			_restore_panel(flex_surface)
		flex_elapsed = elapsed
		flex_surface = surface
		flex_impact = point
		StadiumNpcClubNetV1.flex(net, surface, elapsed, point)


func _exit_tree() -> void:
	_cancel_active()
	if _rock != null and _rock.is_valid():
		_rock.kill()
	if is_instance_valid(chair):
		StadiumNpcClubTargetV1.flex(chair, 0.18)
	if _pocket != null and _pocket.is_valid():
		_pocket.kill()
	if is_instance_valid(net) and not flex_surface.is_empty():
		_restore_panel(flex_surface)
