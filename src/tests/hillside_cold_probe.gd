extends Node
const C = preload("res://src/presentation/stadium/stadium_hillside_public_construction.gd")


func _ready() -> void:
	var c = C.build()
	print(
		"HILL_DIAG raw structure=",
		c._structure_valid(),
		" sources=",
		StadiumHillsideDefinitionV1.sources_valid(),
		" cold=",
		c.cold_valid()
	)
	var owner = StadiumNpcPublicProperty.new()
	owner.venue_id = "HILLSIDE"
	owner.tier = c.tier
	owner.construction = c
	owner.field = c.field
	owner.objects = c.objects
	owner.add_child(c)
	var adapter = StadiumHillsidePublicContactAdapter.new()
	owner.add_child(adapter)
	owner.boundary = adapter
	print(
		"HILL_DIAG adapter=",
		adapter.configure(c.boundary),
		" bind=",
		adapter.bind_public_property(owner),
		" cold=",
		c.cold_valid()
	)
	var receiver = StadiumHillsidePublicReceiver.new()
	owner.add_child(receiver)
	owner.receiver = receiver
	print(
		"HILL_DIAG receiver=",
		receiver.configure_pair(
			c.objects[C.INSTANCE_PREFIX + "RECEIVER-PRIMARY"],
			c.objects[C.INSTANCE_PREFIX + "RECEIVER-CATCH"]
		),
		" structure=",
		c._structure_valid(),
		" cold=",
		c.cold_valid()
	)
	var reference = C.build()
	reference._contact_labels()
	print(
		"HILL_DIAG policies actual=",
		StadiumNpcRetainedGeometry._receiver_policies(c),
		" reference=",
		StadiumNpcRetainedGeometry._receiver_policies(reference),
		" same=",
		C._same_construction(c, reference)
	)
	var a = StadiumPoolPartyAssetIntegrity.snapshot(c)
	var b = StadiumPoolPartyAssetIntegrity.snapshot(reference)
	for tree in [a, b]:
		tree.erase("name")
		tree.properties.erase("name")
	for site in ["RECEIVER-PRIMARY", "RECEIVER-CATCH"]:
		var n = c.objects[C.INSTANCE_PREFIX + site]
		var n2 = reference.objects[C.INSTANCE_PREFIX + site]
		print("HILL_DIAG receiver same ", site, "=", StadiumNpcRetainedGeometry.same(n, n2))
		C._normalize_receiver(n, a.children[n.get_index()], b.children[n2.get_index()])
	var out = OS.get_environment("HILLSIDE_DIAG")
	for pair in [["actual", a], ["reference", b]]:
		var f = FileAccess.open(out.path_join(pair[0] + ".json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(pair[1], "\t", true, true))
	owner.free()
	reference.free()
	get_tree().quit()
