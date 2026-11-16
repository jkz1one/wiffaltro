extends Node
const OLD = preload("res://src/tests/hillside_historical_geometry.gd")
const CAT = preload("res://src/tests/hillside_historical_catalog.gd")
const C = preload("res://src/presentation/stadium/stadium_hillside_public_construction.gd")
var checks: int = 0
var failures: int = 0


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print("PARITY ", label, " ", value)


func _ready() -> void:
	check(not StadiumHillsideDefinitionV1.sources_valid(), "unreviewed source change fails closed")
	for item in ["ST-021", "ST-025", "ST-026", "ST-027", "ST-032"]:
		check(
			var_to_bytes(CAT.item(item)) == var_to_bytes(StadiumCatalog.item(item)),
			"catalog " + item
		)
	var a = C.build()
	var b = C.build()
	for site in C.SITES:
		var x = a.objects[C.INSTANCE_PREFIX + site]
		var y = b.objects[C.INSTANCE_PREFIX + site]
		check(
			(
				var_to_bytes(OLD._geometry(x))
				== var_to_bytes(StadiumNpcRetainedGeometry._geometry(x, {}))
			),
			"snapshot " + site
		)
		check(OLD.same(x, y) and StadiumNpcRetainedGeometry.same(x, y), "same " + site)
		x.position.x += 0.125
		check(
			not OLD.same(x, y) and not StadiumNpcRetainedGeometry.same(x, y),
			"position refusal " + site
		)
		x.position.x -= 0.125
		check(OLD.same(x, y) and StadiumNpcRetainedGeometry.same(x, y), "position restore " + site)
		var meshes = x.find_children("*", "MeshInstance3D", true, false)
		for mesh in meshes:
			if mesh.material_override is StandardMaterial3D:
				var material = mesh.material_override
				var prior = material.roughness
				material.roughness = 0.12345
				check(
					not OLD.same(x, y) and not StadiumNpcRetainedGeometry.same(x, y),
					"material refusal " + site
				)
				material.roughness = prior
				check(
					OLD.same(x, y) and StadiumNpcRetainedGeometry.same(x, y),
					"material restore " + site
				)
				break
	a.free()
	b.free()
	print("HILLSIDE_HISTORICAL_PARITY checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
