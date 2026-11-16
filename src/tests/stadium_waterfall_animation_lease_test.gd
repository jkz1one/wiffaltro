extends Node3D
const LIVE: String = "purchase:animated-water:0"
const PLAZA: String = "purchase:animated-water:1"
const KIT: String = "purchase:animated-plaza:0"
var checks: int = 0
var failures: Array[String] = []
var stock: StadiumStock
var layout: Dictionary


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("WATERFALL_ANIMATION_LEASE " + label)


func _ready() -> void:
	var credits: Array = []
	var progress: Array = []
	for index in range(40):
		credits.append(10000)
		progress.append({"seasons": 1, "wins": 5, "homers": 5})
	var paid: ClubAssetLedger = ClubAssetLedger.new(216, credits, progress)
	for tier: String in ["expanded", "club", "mogul"]:
		check(
			(
				paid
				. commit(
					{
						"id": "land-" + tier,
						"rev": paid.revision(),
						"op": "stadium_land",
						"tier": tier,
						"through": 40,
						"progress_through": 40,
						"price_version": 1
					}
				)
				. ok
			),
			"real paid land " + tier
		)
	for buy: Array in [["animated-water", "ST-046", 2, 32], ["animated-plaza", "ST-112", 1, 34]]:
		check(
			(
				paid
				. commit(
					{
						"id": buy[0],
						"rev": paid.revision(),
						"op": "stadium_buy",
						"item": buy[1],
						"quantity": buy[2],
						"price_version": buy[3],
						"through": 40,
						"progress_through": 40
					}
				)
				. ok
			),
			"paid stock " + buy[1]
		)
	stock = paid.construction()
	layout = StadiumWaterfallLiveItems.place(
		paid.view().stadium_draft, stock, LIVE, "WF-LIVE-LF", 0, paid.surface_owned()
	)
	layout = StadiumOutfieldPlazaItems.place(
		layout, stock, KIT, "promenade_court", paid.surface_owned()
	)
	layout = StadiumOutfieldPlazaItems.place_occupant(layout, PLAZA, "PLAZA-W")
	check(
		StadiumHomeLayout.validate(layout, stock, "mogul").ok,
		"paid full-size live and separate plaza composition"
	)
	var property: StadiumPropertyGeometry = _build()
	check(property != null, "isolated property installs both explicit animated variants")
	if property != null:
		var lease: StadiumWaterfallAnimationLease = property._waterfall_animation
		check(
			property.props_intact() and lease != null and lease.presentation_intact(),
			"all original infrastructure and native trap seals intact"
		)
		check(
			(
				not StadiumWaterfallLiveModels.valid(property.objects[LIVE])
				and not StadiumWaterfallModels.valid(property.objects[PLAZA])
			),
			"new variants never masquerade as old frozen factories"
		)
		check(
			(
				(
					(
						property
						. objects[LIVE]
						. find_children("*", "CollisionShape3D", true, false)
						. size()
					)
					== 13
				)
				and (
					property
					. objects[PLAZA]
					. find_children("*", "CollisionObject3D", true, false)
					. is_empty()
				)
			),
			"only exact live copy has13 native solids; plaza remains out of play"
		)
		var began: int = Time.get_ticks_usec()
		for index in range(12):
			check(
				lease.advance(0.05, false, false) and property.props_intact(),
				"phase advances with all native and infrastructure seals " + str(index)
			)
		print(
			"ANIMATED_LEASE_TIMING ",
			{
				"steps": 12,
				"elapsed_us": Time.get_ticks_usec() - began,
				"models": 2,
				"water_materials": 16
			}
		)
		var phase: float = lease.phase
		check(
			(
				phase > 0
				and StadiumWaterfallAnimatedModels.valid(property.objects[LIVE], phase)
				and StadiumWaterfallAnimatedModels.valid(property.objects[PLAZA], phase)
			),
			"both full-scale explicit models retain exact phase"
		)
		check(
			lease.advance(0.1, true, false) and lease.phase == phase, "action freezes exact phase"
		)
		check(lease.advance(0.1, false, true) and lease.phase == phase, "pause freezes exact phase")
		check(
			lease.advance(0.3, false, false) and lease.phase == phase,
			"hitch does not advance or catch up phase"
		)
		check(
			lease.reset() and lease.phase == 0 and property.props_intact(),
			"owned reset changes only allowed uniforms"
		)
		property.free()
	for mode: String in [
		"phase",
		"shader",
		"shader_identity",
		"material_identity",
		"base_color",
		"mesh",
		"pose",
		"copy",
		"copy_selection",
		"native_shape",
		"foreign_listener",
		"seal_phase",
		"internal_child"
	]:
		_tamper(mode)
	var static_property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	add_child(static_property)
	check(
		(
			static_property.build("mogul", layout, stock)
			and static_property._waterfall_animation == null
			and StadiumWaterfallModels.valid(static_property.objects[PLAZA])
			and StadiumWaterfallLiveModels.valid(static_property.objects[LIVE])
		),
		"old family45 build remains completely static without opt-in"
	)
	static_property.free()
	print(
		(
			"WATERFALL_ANIMATION_LEASE_RESULT "
			+ JSON.stringify(
				{
					"checks": checks,
					"failures": failures,
					"synthetic_progression": true,
					"owned_snapshot_integration": false,
					"native_visual_qualification": false
				}
			)
		)
	)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures.is_empty() else 1)


func _build() -> StadiumPropertyGeometry:
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	property._waterfall_animation_copies.assign([LIVE, PLAZA])
	add_child(property)
	if not property.build("mogul", layout, stock):
		print(
			"LEASE_BUILD_FAILURE ",
			{
				"live": property._props_live,
				"lease": property._waterfall_animation,
				"objects": property.objects.keys(),
				"seals": property._infrastructure.size(),
				"traps": property._waterfall_traps.keys()
			}
		)
		property.free()
		return null
	return property


func _tamper(mode: String) -> void:
	var property: StadiumPropertyGeometry = _build()
	if property == null:
		check(false, "tamper fixture " + mode)
		return
	var lease: StadiumWaterfallAnimationLease = property._waterfall_animation
	var model: Node3D = property.objects[LIVE]
	var water: MeshInstance3D = model.get_node("Visual/Pool")
	match mode:
		"internal_child":
			var foreign: MeshInstance3D = MeshInstance3D.new()
			foreign.mesh = BoxMesh.new()
			water.add_child(foreign, false, Node.INTERNAL_MODE_BACK)
		"phase":
			water.material_override.set_shader_parameter("phase", 0.7)
		"shader":
			water.material_override.shader.code += "\n// foreign"
		"shader_identity":
			water.material_override.shader = water.material_override.shader.duplicate()
		"material_identity":
			water.material_override = water.material_override.duplicate()
		"base_color":
			water.material_override.set_shader_parameter("base_color", Color.RED)
		"mesh":
			water.mesh.size.x += 0.1
		"pose":
			model.position.x += 0.1
		"copy":
			model.set_meta("owned_copy", PLAZA)
		"copy_selection":
			property._waterfall_animation_copies.clear()
		"native_shape":
			model.get_node("Collision/WATERFALL_STONE/BasinFloor").shape.size.y += 0.1
		"foreign_listener":
			water.material_override.changed.connect(_foreign)
		"seal_phase":
			lease._tokens[0].refs[0].row.values[lease._tokens[0].refs[0].index] = 0.8
	var before: Variant = water.material_override.get_shader_parameter("phase")
	check(
		(
			not lease.advance(0.1, false, false)
			and lease.retired
			and not property._props_live
			and water.material_override.get_shader_parameter("phase") == before
		),
		"foreign " + mode + " retires without repair or phase overwrite"
	)
	property.free()


func _foreign() -> void:
	pass
