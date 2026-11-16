class_name StadiumYardFieldVisibility
extends BallTrackingVisibility
## AY-01 only: exact joined free-template wall prisms, never independently inflated wall boxes.


class TemplateView extends StadiumRecipeBoundary:
	## Presentation adapter only; the template's physics, dimensions and identity remain unchanged.
	func polygon() -> PackedVector2Array:
		return PackedVector2Array(StadiumBoundaryGraph.VERTICES)

	func segments() -> Array[Dictionary]:
		return StadiumBoundaryGraph.segments()

	func outer_vertex(index: int) -> Vector2:
		return StadiumBoundaryGraph.outer_vertex(index)

	func identity() -> String:
		return StadiumBoundaryGraph.ID


func configure(geometry: Node) -> void:
	super.configure(geometry)
	var property: StadiumPropertyGeometry = geometry.get_node_or_null("HomeProperty")
	if property == null or not property.get_node_or_null("BoundaryGraph") is StadiumBoundaryPrototype:
		return
	# The superclass template branch places each broad wall box in scenery. Replace those
	# boxes with the exact 0.20 m joined template prisms, retaining actual chair occluders.
	_obstacles.clear()
	_uprights.clear()
	_wall_bounds.clear()
	_recipe = TemplateView.new()
	_wall_prisms = StadiumWallViewPrisms.new(_recipe)
	for model: Node3D in property.objects.values():
		_collect(model.get_node("Visual"), false)
