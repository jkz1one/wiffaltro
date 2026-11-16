extends Node3D
var checks: int = 0
var failures: Array[String] = []


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)


func _ready() -> void:
	var original: Node3D = StadiumWaterfallModels.create()
	add_child(original)
	check(StadiumWaterfallModels.valid(original), "frozen factory remains exact static decoration")
	var model: Node3D = StadiumWaterfallMotionModels.create()
	model.set_meta("owned_copy", "synthetic-motion-copy")
	add_child(model)
	check(
		StadiumWaterfallMotionModels.valid(model, 0.0),
		"explicit animated variant starts exact and bounded"
	)
	check(
		not StadiumWaterfallModels.valid(model),
		"animated variant cannot masquerade as old static v1"
	)
	for id: String in StadiumWaterfallModels.PARTS:
		check(
			(
				original.get_node(id).transform == model.get_node(id).transform
				and original.get_node(id).mesh.size == model.get_node(id).mesh.size
			),
			"full-size frozen geometry retained " + id
		)
	check(
		(
			model.find_children("*", "CollisionObject3D", true, false).is_empty()
			and model.find_children("*", "Light3D", true, false).is_empty()
		),
		"animation adds no collision, trigger or lighting authority"
	)
	check(
		(
			not StadiumWaterfallMotionModels.CODE.contains("TIME")
			and not StadiumWaterfallMotionModels.CODE.contains("VERTEX =")
		),
		"shader has no autonomous clock or geometry deformation; reads world height only"
	)
	var owner: StadiumWaterfallMotionOwner = StadiumWaterfallMotionOwner.install(self, model)
	check(owner != null and owner.intact(), "variant binds exact nodes/resources")
	if owner != null:
		check(
			owner.advance(0.1, false, false) and owner.phase > 0 and owner.intact(),
			"bounded idle animation advances owned phase"
		)
		var phase: float = owner.phase
		check(
			owner.advance(0.1, true, false) and owner.phase == phase,
			"actionable pitch or ball flight freezes water motion"
		)
		check(
			owner.advance(0.1, false, true) and owner.phase == phase,
			"explicit pause freezes water motion"
		)
		check(owner.reset() and owner.phase == 0, "owned reset is exact")
		model.get_node("Pool").material_override.set_shader_parameter("phase", 0.7)
		check(
			(
				not owner.advance(0.1, false, false)
				and owner.retired
				and model.get_node("Pool").material_override.get_shader_parameter("phase") == 0.7
			),
			"foreign material phase retires without overwrite"
		)
	for mode: String in [
		"mesh",
		"stone_color",
		"stone_depth",
		"water_color",
		"shader",
		"shader_identity",
		"material_identity",
		"pose",
		"visibility",
		"layer",
		"render_state",
		"root_meta"
	]:
		_tamper(mode)
	check(
		StadiumWaterfallModels.valid(original),
		"new animation leaves original instance byte-contract unchanged"
	)
	model.queue_free()
	original.queue_free()
	await TestAudioDrain.finish(get_tree())
	print(
		(
			"WATERFALL_MOTION_RESULT "
			+ JSON.stringify(
				{
					"checks": checks,
					"failures": failures,
					"integration": false,
					"native_visual_qualification": false
				}
			)
		)
	)
	get_tree().quit(0 if failures.is_empty() else 1)


func _tamper(mode: String) -> void:
	var model: Node3D = StadiumWaterfallMotionModels.create()
	add_child(model)
	var owner: StadiumWaterfallMotionOwner = StadiumWaterfallMotionOwner.install(self, model)
	var stone: MeshInstance3D = model.get_node("BasinFront")
	var water: MeshInstance3D = model.get_node("Pool")
	match mode:
		"mesh":
			stone.mesh.size = Vector3.ONE
		"stone_color":
			stone.material_override.albedo_color = Color.RED
		"stone_depth":
			stone.material_override.no_depth_test = true
		"water_color":
			water.material_override.set_shader_parameter("base_color", Color.RED)
		"shader":
			water.material_override.shader.code = (
				StadiumWaterfallMotionModels.CODE + "\n// foreign code"
			)
		"shader_identity":
			water.material_override.shader = water.material_override.shader.duplicate()
		"material_identity":
			stone.material_override = stone.material_override.duplicate()
		"pose":
			stone.position.x += 0.1
		"visibility":
			stone.visible = false
		"layer":
			stone.layers = 2
		"render_state":
			stone.extra_cull_margin = 100.0
		"root_meta":
			model.set_meta("obstacle_units", 4)
	check(
		owner != null and not owner.advance(0.1, false, false) and owner.retired,
		"cached exact seal rejects foreign " + mode
	)
	owner.free()
	model.free()
