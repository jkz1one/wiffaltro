class_name StadiumFieldStylePrototype
extends RefCounted
## Authoring-only owned visual styles. Production save/editor activation remains separate.


static func validate(selection: Variant, stock: StadiumStock) -> bool:
	if stock == null or not selection is Dictionary \
		or not SeasonOwnership._keys(selection, ["line", "grass"]):
		return false
	for channel: String in StadiumFieldStyleModels.CHANNELS:
		var id: Variant = selection[channel]
		if not id is String or (not id.is_empty() and (
			not StadiumFieldStyleModels.CHANNELS[channel].has(id) or not stock.styles.has(id))):
			return false
	return true


static func apply(property: StadiumPropertyGeometry, selection: Dictionary,
	stock: StadiumStock) -> bool:
	if not StadiumPropertyGeometry.construction_target_allowed(property):
		return false
	if property == null or not validate(selection, stock):
		return false
	var root: Node3D = Node3D.new()
	root.name = "FieldStylePreview"
	for channel: String in StadiumFieldStyleModels.CHANNELS:
		var id: String = selection[channel]
		if not id.is_empty():
			root.add_child(StadiumFieldStyleModels.create(id, property.field))
	var previous: Node = property.get_node_or_null("FieldStylePreview")
	if previous != null:
		property.remove_child(previous)
		previous.queue_free()
	property.add_child(root)
	for side in [-1, 1]:
		property.get_node("FoulLine" + str(side)).visible = selection.line.is_empty()
	return true
