extends "res://src/tests/stadium_low_wall_plaza_capture_test.gd"


## Same paid kit; explicit new immutable authored revision, no free occupants.
func _views(layout_value: Dictionary, recipe: String) -> void:
	if recipe != "heritage_walk":
		return
	var old_snapshot: Dictionary = StadiumLayoutSnapshot.capture(_paid, true)
	var original45: Dictionary = StadiumWaterfallLiveItems.upgrade(
		layout_value, _paid.surface_owned()
	)
	check(_low_apply(original45), "original45 paid wrapper installs")
	var original45_snapshot: Dictionary = StadiumLayoutSnapshot.capture(_paid, true)
	var original45_data: Dictionary = _paid.to_data()
	check(
		StadiumLayoutSnapshot.valid(original45_snapshot) and _load(_json(original45_data)) != null,
		"original45 snapshot and save cold-valid"
	)
	check(_low_apply(layout_value), "restore original44 before revision selection")
	var old_balance: int = _paid.balance()
	var revised: Dictionary = layout_value.duplicate(true)
	for occupant: Dictionary in layout_value.outfield_plaza[0].occupants:
		revised = StadiumOutfieldPlazaItems.store_copy(revised, occupant.copy)
	revised = StadiumOutfieldPlazaItems.store_copy(revised, KIT)
	var empty: Dictionary = revised.duplicate(true)
	revised = StadiumOutfieldPlazaItems.place(
		revised, _paid.construction(), KIT, "heritage_walk_r2", _paid.surface_owned()
	)
	for occupant: Dictionary in layout_value.outfield_plaza[0].occupants:
		revised = StadiumOutfieldPlazaItems.place_occupant(revised, occupant.copy, occupant.site)
	_coexistence(empty, revised, "heritage_walk_r2")
	check(
		StadiumHomeLayout.validate(revised, _paid.construction(), "mogul").ok,
		"revised recipe exact same paid occupants"
	)
	check(
		(
			StadiumOutfieldPlazaRecipes.reservations("heritage_walk")
			== StadiumOutfieldPlazaRecipes.reservations("heritage_walk_r2")
		),
		"revision preserves every full reservation"
	)
	check(
		(
			StadiumOutfieldPlazaItems.geometry("mogul", layout_value)
			!= StadiumOutfieldPlazaItems.geometry("mogul", revised)
		),
		"new geometry seal is distinct"
	)
	var old_model: Node3D = StadiumOutfieldPlazaModels.create("heritage_walk")
	var new_model: Node3D = StadiumOutfieldPlazaModels.create("heritage_walk_r2")
	check(
		is_equal_approx(old_model.get_node("Backdrop00").mesh.size.y, 1.15),
		"original model height exact"
	)
	check(
		is_equal_approx(new_model.get_node("Backdrop00").mesh.size.y, 3.4),
		"revised partial backdrop height exact"
	)
	check(
		new_model.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"revised backdrop cannot affect baseball contacts"
	)
	old_model.free()
	new_model.free()
	check(_low_apply(revised), "explicit paid revised install")
	var revised_snapshot: Dictionary = StadiumLayoutSnapshot.capture(_paid, true)
	check(
		(
			StadiumLayoutSnapshot.valid(revised_snapshot)
			and StadiumLayoutSnapshot.valid(_json(revised_snapshot))
		),
		"new revision cold snapshot valid"
	)
	check(StadiumLayoutSnapshot.valid(old_snapshot), "original saved recipe remains valid")
	var forged: Dictionary = revised_snapshot.duplicate(true)
	forged.layout.outfield_plaza[0].recipe = "heritage_walk"
	check(not StadiumLayoutSnapshot.valid(forged), "revision swap cannot reuse sealed geometry")
	_cold(_paid, "revised heritage")
	check(
		StadiumLayoutSnapshot.valid(original45_snapshot) and _load(_json(original45_data)) != null,
		"historical45 remains exact after r2 apply"
	)
	var tampered: Dictionary = _paid.to_data()
	var changed: bool = false
	for event: Dictionary in tampered.events:
		if (
			event.get("op") == "stadium_apply"
			and event.has("layout")
			and not event.layout.get("outfield_plaza", []).is_empty()
			and event.layout.outfield_plaza[0].recipe == "heritage_walk_r2"
		):
			event.layout.outfield_plaza[0].recipe = "heritage_walk"
			changed = true
	check(changed and _load(_json(tampered)) == null, "tampered revision journal rejects")
	await super._views(revised, "heritage_walk_r2")
	check(_paid.balance() == old_balance, "existing kit revision has no new charge")
	check(_low_apply(layout_value), "explicit restore original authored recipe")


func _profile(_recipe: String) -> String:
	return "low_outfield"
