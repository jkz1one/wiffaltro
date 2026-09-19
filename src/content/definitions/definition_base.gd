class_name DefinitionBase
extends Resource

@export var id: StringName
@export var display_name: String = ""

func is_valid_definition() -> bool:
	return ContentId.is_valid(id) and not display_name.strip_edges().is_empty()
