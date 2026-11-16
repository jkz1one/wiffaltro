class_name StadiumNpcAe02PublicReceiver
extends StadiumNpcRetainedReceiver
## Public identity admission; paired sweep, sound, timing, target flex and net pocket stay frozen.


func configure_pair(target: Node3D, catching_net: Node3D,
	sound_player: PlaySounds = null) -> bool:
	var property: StadiumNpcPublicProperty = get_parent() as StadiumNpcPublicProperty
	if property == null or property.venue_id != "AE-02" or property.get_parent() != null \
		or target == null or catching_net == null \
		or property.objects.get("npc:AE-02:r1:RECEIVER-PRIMARY") != target \
		or property.objects.get("npc:AE-02:r1:RECEIVER-CATCH") != catching_net:
		return false
	for row: Array in [[target, "RECEIVER-PRIMARY", "ST-026", -1.05],
		[catching_net, "RECEIVER-CATCH", "ST-025", -2.20]]:
		var model: Node3D = row[0]
		var identity: String = "npc:AE-02:r1:" + row[1]
		if model.get_parent() != property.construction \
			or not StadiumNpcAe02PublicConstruction.exact_meta(model, "npc_instance", identity) \
			or not StadiumNpcAe02PublicConstruction.exact_meta(model, "owned_copy", identity) \
			or not StadiumNpcAe02PublicConstruction.exact_meta(model, "stadium_item", row[2]) \
			or model.transform != Transform3D(Basis.IDENTITY, Vector3(0, 0, row[3])):
			return false
	return super.configure_pair(target, catching_net, sound_player)
