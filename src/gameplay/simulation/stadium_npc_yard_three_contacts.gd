class_name StadiumNpcYardThreeContacts
extends RefCounted
## AY03 has boundary outcomes and separate decorative-body provenance, no live item rules.


static func matches(snapshot: Dictionary) -> bool:
	return StadiumNpcSnapshot.valid(snapshot) and snapshot.manifest.id == "AY-03" \
		and snapshot.manifest.revision == 1


static func valid(value: Variant, plays: Array, snapshot: Dictionary) -> bool:
	# The shared Yard boundary validator derives no live placements for ST037/ST080.
	# Its item-event branch therefore rejects every purported live AY03 item outcome.
	return matches(snapshot) and StadiumNpcYardTwoContacts.valid(value, plays, snapshot)


static func provenance(value: Variant, snapshot: Dictionary) -> bool:
	if not matches(snapshot) or not value is Array or value.size() > 4096:
		return false
	var instances: Dictionary = {}
	for row: Dictionary in snapshot.manifest.instances:
		instances[row.instance] = row.item
	for row: Variant in value:
		if not row is Dictionary or not SeasonOwnership._keys(row,
			["instance", "surface", "preterminal", "elapsed"]) \
			or not row.instance is String or not instances.has(row.instance) \
			or not row.surface is String or not row.preterminal is bool or not row.preterminal \
			or not PhysicalMatchReport.number(row.elapsed, 0, 3600) \
			or not _surfaces(instances[row.instance]).has(row.surface):
			return false
	return true


static func _surfaces(item: String) -> Array:
	if item == "ST-037":
		return ["Footing", "BasePlate", "Pole", "Arm", "LampHousing"]
	if item == "ST-080":
		# Back ribs are visual-only in the immutable seating model.
		return ["SpectatorSeat", "SpectatorBack", "SpectatorLeg-1_-1", "SpectatorLeg-1_1",
			"SpectatorLeg1_-1", "SpectatorLeg1_1"]
	return []
