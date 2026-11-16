extends Node
func _ready() -> void:
	SeasonSave.path="user://confirmation-preview-only.json"
	get_window().content_scale_size=Vector2i.ZERO
	get_window().size=Vector2i(700,400)
	get_window().title="Wiffaltro isolated confirmation QA"
	var app: SeasonApp=SeasonApp.new()
	add_child(app)
	for index in range(8): await get_tree().process_frame
	app.ask_progression_season(4)
