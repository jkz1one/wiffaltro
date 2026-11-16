class_name StadiumTargetReceiver
extends StadiumPitchReceiver
## Target-only post-call routing. Reuses bounded sweeps without changing the old chair's geometry.


const VERSION: int = 2
const TARGET_CLEANUP_Z: float = -1.85


func configure(model: Node3D, sound_player: PlaySounds = null) -> bool:
	if model == null or model.get_meta("stadium_item", "") != "ST-026" \
		or not model.has_meta("owned_copy"):
		return false
	chair = model
	chair.process_mode = Node.PROCESS_MODE_PAUSABLE
	sounds = sound_player
	for body: StaticBody3D in chair.get_node("Collision").get_children():
		body.collision_layer |= LAYER
	return true


func cleanup_z() -> float:
	return TARGET_CLEANUP_Z


func present_contact(hit: Dictionary, kind: String) -> void:
	if not is_instance_valid(chair) or kind not in ["pitch", "batted"] \
		or hit.get("copy") != chair.get_meta("owned_copy"):
		return
	contacts.append({"kind": kind, "copy": hit.copy, "surface": hit.surface,
		"elapsed": hit.elapsed, "position": [hit.position.x, hit.position.y, hit.position.z]})
	if is_instance_valid(sounds):
		sounds.play(target_cue(hit.surface))
	if _rock != null and _rock.is_valid():
		_rock.kill()
	if hit.surface == "ST026_PANEL":
		_rock = chair.create_tween().bind_node(chair)
		_rock.tween_method(_flex, 0.0, 0.18, 0.18)


func _flex(elapsed: float) -> void:
	if is_instance_valid(chair):
		StadiumTargetModels.flex(chair, elapsed)


static func target_cue(surface: String) -> StringName:
	if surface == "ST026_PANEL":
		return &"target_panel"
	if surface.begins_with("ST026_LEGS"):
		return &"target_legs"
	if surface.begins_with("ST026_BASE"):
		return &"target_base"
	return &"target_frame"
