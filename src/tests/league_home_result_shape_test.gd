extends Node
## Structural adapter tests only. These fixtures do not claim a played game or reward.
var checks: int = 0
var failures: int = 0


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)


func _ready() -> void:
	var adapter = load("res://src/gameplay/season/league_home_result.gd")
	var first: Array = [0, 1, 0, {}, [], [], {}, [], [], {}, {}, [], {}]
	for doubleheader: bool in [false, true]:
		for sale: bool in [false, true]:
			var human: Array = first.duplicate(true)
			if doubleheader:
				human.append([{}, {}])
			if sale:
				human.append({"structural_only": true})
			human.append_array([[], "property-key"])
			check(adapter.shape(human, [], doubleheader), "composed structure")
			check(not adapter.shape(human, [], not doubleheader), "wrong league grammar")
			check(not adapter.shape(human, [{}], doubleheader), "invalid physical report")
			check(not adapter.shape(human, {}, doubleheader), "reports must be array")
			for index: int in range(human.size()):
				var bad: Array = human.duplicate(true)
				bad[index] = null
				check(not adapter.shape(bad, [], doubleheader), "null field %d" % index)
			var bad: Array = human.duplicate(true)
			bad[-2] = [{}]
			check(not adapter.shape(bad, [], doubleheader), "legacy replay placeholder stays empty")
			bad = human.duplicate(true)
			bad.append({})
			check(not adapter.shape(bad, [], doubleheader), "extra evidence rejects")
			if sale:
				bad = human.duplicate(true)
				bad[14 if doubleheader else 13] = {}
				check(not adapter.shape(bad, [], doubleheader), "empty inventory evidence rejects")
			check(not SeasonRoundSettlement._inventory_shape(
				{"human": human, "reports": []}, doubleheader
			), "legacy inventory grammar not expanded")
	check(not adapter.shape(null, [], false), "null input")
	check(not adapter.record(null, first), "null season")
	check(not adapter.replay(null, null, {}, {}, {}, []), "null replay")
	print("League home result shape checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
