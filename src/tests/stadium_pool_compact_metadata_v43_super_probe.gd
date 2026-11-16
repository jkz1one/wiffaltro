extends "res://src/tests/stadium_pool_compact_metadata_v43_probe.gd"
## Explicit super calls retain recursive virtual dispatch and the legacy metadata shape.

var tree_calls: int = 0
var topology_calls: int = 0


func _tree(node: Node) -> Array:
	tree_calls += 1
	return super._tree(node)


func _topology(node: Node) -> Array:
	topology_calls += 1
	return super._topology(node)
