extends "res://src/tests/dynasty_carried_home_owner_test.gd"
const Reuse = preload("res://src/tests/dynasty_league_qualified_reuse_controls.gd")
func _run() -> void:
	super._run()
	var owner: Dictionary = Store.inspect(path).get("owner", {})
	if owner.is_empty(): return
	Reuse.run(owner, Store.read_snapshot(path, owner.dynasty.reference), check, "92-carried")
