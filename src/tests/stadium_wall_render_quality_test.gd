extends Node3D
## Repeated/replaced native field lifetimes restore graphics without touching saved settings.

var _failures: int = 0


func _ready() -> void:
	var viewport: Viewport = get_viewport()
	var original: int = int(viewport.msaa_3d)
	var first: Node3D = Node3D.new()
	var second: Node3D = Node3D.new()
	add_child(first)
	add_child(second)
	if DisplayServer.get_name() == "headless":
		_check(not StadiumWallRenderQuality.attach(first) and int(viewport.msaa_3d) == original,
			"headless verification does not pretend to enable native antialiasing")
	else:
		viewport.msaa_3d = Viewport.MSAA_DISABLED
		_check(StadiumWallRenderQuality.attach(first) and viewport.msaa_3d == Viewport.MSAA_4X,
			"native wall scene raises only its viewport sampling quality")
		_check(not StadiumWallRenderQuality.attach(first), "repeated attachment is idempotent")
		_check(StadiumWallRenderQuality.attach(second), "overlapping replacement owns its own lease")
		first.queue_free()
		await get_tree().process_frame
		_check(viewport.msaa_3d == Viewport.MSAA_4X, "old scene cannot undo its replacement's quality")
		second.queue_free()
		await get_tree().process_frame
		_check(viewport.msaa_3d == Viewport.MSAA_DISABLED
			and not viewport.has_meta(StadiumWallRenderQuality.META), "last owner restores prior quality")
		var high: Node3D = Node3D.new()
		add_child(high)
		viewport.msaa_3d = Viewport.MSAA_4X
		StadiumWallRenderQuality.attach(high)
		_check(viewport.msaa_3d == Viewport.MSAA_4X, "adequate preexisting quality is not lowered")
		high.queue_free()
		await get_tree().process_frame
		_check(viewport.msaa_3d == Viewport.MSAA_4X, "adequate preexisting quality survives exit")
		viewport.msaa_3d = Viewport.MSAA_DISABLED
		var changed: Node3D = Node3D.new()
		add_child(changed)
		StadiumWallRenderQuality.attach(changed)
		viewport.msaa_3d = Viewport.MSAA_2X
		changed.queue_free()
		await get_tree().process_frame
		_check(viewport.msaa_3d == Viewport.MSAA_2X, "later external quality choice is preserved")
	viewport.set("msaa_3d", original)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro wall render quality checks passed: scoped, reference-counted and reversible.")
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
