extends Node

func _ready() -> void:
	var menu := SeasonMenu.new()
	var body := VBoxContainer.new()
	menu.add_child(body)
	menu._body = body
	menu.page = "stadium"
	add_child(menu)
	await get_tree().process_frame
	menu._settle_workshop_focus.call_deferred(body)
	remove_child(menu)
	print("DEFERRED_DETACH_PROBE detached_before_deferred_entry=", not menu.is_inside_tree())
	for frame in range(5):
		await get_tree().process_frame
	menu.free()
	print("DEFERRED_DETACH_PROBE completed")
	get_tree().quit(0)
