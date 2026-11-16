class_name StadiumBleacherPrototype
extends StadiumSeatingPrototype
## Explicit authoring-only seating assembly. No production save/editor registration.

func build(rows: Array, stock: StadiumStock, tier: String = "backyard") -> bool:
	if get_child_count() != 0:
		return false
	var checked: Dictionary = StadiumBleacherSites.validate(rows, stock, tier)
	if not checked.ok:
		return false
	for placement: Dictionary in checked.placements:
		var model: Node3D = StadiumBleacherModels.create(placement.item)
		model.position = placement.position
		model.rotation.y = deg_to_rad(placement.yaw)
		model.set_meta("owned_copy", placement.copy)
		model.set_meta("site", placement.site)
		add_child(model)
		objects[placement.copy] = model
		for body: Node in model.get_node("Collision").get_children():
			body.set_meta("owned_copy", placement.copy)
	return true
