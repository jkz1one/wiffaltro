extends Node
## Detached actual factory shapes only. No installed source qualification or game claim.
var checks: int = 0
var failed: Array[String] = []
var changed: int = 0
var rows: Array[Dictionary] = []


func _ready() -> void:
	_check(
		not StadiumNpcPublicRuntime.source_qualified(),
		"unreviewed production change remains rejected"
	)
	for family: String in ["pool", "timber"]:
		var owner: StadiumNpcPublicProperty = StadiumNpcPublicProperty.new()
		owner.venue_id = "POOL-PARTY"
		var model: Node3D = (
			StadiumPoolModelsV2.create(StadiumPoolContract.LIVE)
			if family == "pool"
			else StadiumTimberDugoutModels.create()
		)
		owner.add_child(model)
		owner.objects[StadiumPoolPartyRuntime.COPY] = model
		_check(not owner._pool_shape_parameters_intact(), family + " unsealed empty owner rejects")
		var nodes: Array[Node] = model.find_children("*", "CollisionShape3D", true, false)
		for node: CollisionShape3D in nodes:
			owner._capture_node(node)
		owner._pool_shape_parameters.make_read_only()
		owner._pool_shape_parameters_pin = owner._pool_shape_parameters
		_check(
			not nodes.is_empty() and owner._pool_shape_parameters_intact(),
			family + " actual captured shapes accept"
		)
		_check(owner._pool_shape_parameters.is_read_only(), family + " outer seal immutable")
		for row: Dictionary in owner._pool_shape_parameters:
			_check(row.is_read_only(), family + " each scalar/handle seal immutable")
		for node: CollisionShape3D in nodes:
			var shape: Shape3D = node.shape
			var margin: float = shape.margin
			var bias: float = shape.custom_solver_bias
			changed = 0
			shape.changed.connect(_changed)
			shape.margin = margin + 0.02
			var margin_rejected: bool = not owner._pool_shape_parameters_intact()
			_check(margin_rejected and changed == 0, family + " silent margin mutation rejects")
			shape.margin = margin
			_check(
				owner._pool_shape_parameters_intact(),
				family + " exact margin restores pure seal comparison"
			)
			shape.custom_solver_bias = bias + 0.2
			var bias_rejected: bool = not owner._pool_shape_parameters_intact()
			_check(bias_rejected and changed == 0, family + " silent solver bias mutation rejects")
			shape.custom_solver_bias = bias
			_check(
				owner._pool_shape_parameters_intact(),
				family + " exact bias restores pure seal comparison"
			)
			shape.changed.disconnect(_changed)
			node.shape = shape.duplicate(true)
			_check(
				not owner._pool_shape_parameters_intact(),
				family + " equal-valued replacement shape rejects"
			)
			node.shape = null
			_check(not owner._pool_shape_parameters_intact(), family + " missing shape rejects")
			node.shape = shape
			_check(
				owner._pool_shape_parameters_intact(),
				family + " captured shape identity restores pure comparison"
			)
			rows.append(
				{
					"family": family,
					"node": str(owner.get_path_to(node)),
					"margin_rejected": margin_rejected,
					"bias_rejected": bias_rejected,
					"native_changed_signals": changed
				}
			)
		var original: Array[Dictionary] = owner._pool_shape_parameters
		var replacement: Array[Dictionary] = []
		replacement.assign(original)
		replacement.make_read_only()
		owner._pool_shape_parameters = replacement
		_check(
			not owner._pool_shape_parameters_intact(),
			family + " copied outer snapshot cannot replace issued seal"
		)
		owner._pool_shape_parameters = original
		_check(
			owner._pool_shape_parameters_intact(),
			family + " original sealed snapshot identity preserved"
		)
		owner.free()
	var other: StadiumNpcPublicProperty = StadiumNpcPublicProperty.new()
	other.venue_id = "AC-02"
	_check(other._pool_shape_parameters_intact(), "non-Pool callback behavior remains unchanged")
	other.free()
	var output: String = OS.get_environment("POOL_SHAPE_OUTPUT")
	var file: FileAccess = FileAccess.open(output.path_join("result.json"), FileAccess.WRITE)
	(
		file
		. store_string(
			(
				JSON
				. stringify(
					{
						"checks": checks,
						"failures": failed,
						"shapes": rows,
						"scope":
						(
							"actual detached factory seal/unit checks only; installed callback retirement not "
							+ "yet qualified"
						)
					},
					"\t"
				)
			)
		)
	)
	print(
		"POOL_SHAPE_SCALAR_SEAL checks=",
		checks,
		" failures=",
		failed.size(),
		" shapes=",
		rows.size()
	)
	get_tree().quit(0 if failed.is_empty() else 1)


func _changed() -> void:
	changed += 1


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failed.append(label)
		push_error(label)
