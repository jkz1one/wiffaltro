class_name StadiumLightRuntime
extends RefCounted
## Consume the frozen per-fixture environment; never infer night from partial or stored copies.


static func bind(lab: PitchBatLab, snapshot: Dictionary) -> void:
	var property: StadiumPropertyGeometry = lab.get_meta("stadium_property")
	var night: bool = snapshot.get("version", 0) in [5, 7, 9] \
		and snapshot.environment.mode == "night"
	for model: Node3D in property.objects.values():
		if model.get_meta("stadium_item", "") == "ST-037":
			StadiumYardLightModels.night(model, night)
	if night:
		StadiumYardNightPrototype.apply(lab)
		StadiumInfieldNightPresentation.apply(property)
		StadiumNightBallStyle.apply(lab._pitch_actor)
	lab.set_meta("stadium_environment", "night" if night else "day")
