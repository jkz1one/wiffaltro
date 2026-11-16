class_name StadiumInfieldNightPresentation
extends RefCounted
## Authored night palette keeps pale sand from washing out the ball under warm yard lamps.

const VERSION: int = 1
const SAND_MULTIPLIER: Color = Color("707070")


static func apply(property: StadiumPropertyGeometry, night: bool = true) -> void:
	var ground: Node3D = property.get_node_or_null("InfieldTreatment")
	if ground == null or ground.get_meta("ground_style", "") != "ST-063j":
		return
	var mesh: MeshInstance3D = ground.get_node("SurfaceVisual")
	var material: StandardMaterial3D = mesh.material_override
	material.albedo_color = SAND_MULTIPLIER if night else Color.WHITE
