class_name StadiumLongYardPublicCamera
extends StadiumLongYardCamera
## Reuses authored -6.5 batting entry and inherited Club live motion unchanged.
## Public current-authority ownership replaces the private authoring fixture gate.


func _entry_owned() -> bool:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	var property: StadiumNpcPublicProperty = StadiumNpcPublicRuntime._property(lab)
	return lab != null and property != null and property.venue_id == "LONG-YARD" \
		and not property.suspended and property.lab_ref != null \
		and property.lab_ref.get_ref() == lab and lab._camera_director == self \
		and is_instance_valid(lab._camera) and lab.get_node_or_null("LabCamera") == lab._camera \
		and is_instance_valid(lab._pitch_actor) \
		and lab.get_node_or_null("PitchFlightActor") == lab._pitch_actor \
		and lab.get_node_or_null("StarterFieldGeometry/HomeProperty") == property \
		and lab._field_definition == property.field \
		and property.receiver is StadiumLongYardPublicReceiver \
		and property.receiver.get_parent() == property and property.callback_intact()


func refresh_actor_cutaway(camera: Camera3D, _ball_live: bool) -> void:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	var property: StadiumNpcPublicProperty = StadiumNpcPublicRuntime._property(lab)
	if property == null or property.venue_id != "LONG-YARD" or camera != lab._camera \
		or lab._camera_director != self:
		return
	property.refresh_actor_presentation(lab)
