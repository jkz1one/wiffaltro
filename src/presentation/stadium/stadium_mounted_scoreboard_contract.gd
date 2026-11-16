class_name StadiumMountedScoreboardContract
extends RefCounted
## Raw fixture15 requires complete data and its exact paid journal prefix on every call.


static func context(value: Variant, ledger: ClubAssetLedger) -> Dictionary:
	if ledger == null or not value is Dictionary \
		or not SeasonOwnership._whole(value.get("version"), 15, 15):
		return {}
	var owners: Dictionary = StadiumMountedScoreboardSnapshot._validated_ownership(value)
	if owners.is_empty() or value.revision > ledger.revision():
		return {}
	var prefix: ClubAssetLedger = ledger.prefix(int(value.revision))
	if prefix == null or value.tier != prefix.view().land \
		or not ClubCareer.same(value.layout, prefix.view().stadium_active) \
		or not ClubCareer.same(value.inventory, prefix.construction().to_data()) \
		or not ClubCareer.same(value.wall_piece_inventory, prefix.wall_pieces().to_data()) \
		or not ClubCareer.same(value.scoreboard_inventory, prefix.scoreboards().to_data()) \
		or not ClubCareer.same(value.surface_access, prefix.surface_owned()):
		return {}
	return {"frozen": StadiumMountedScoreboardSnapshot._normalized_validated(value, owners),
		"owners": owners}


static func origin_clean(lab: PitchBatLab) -> bool:
	if not is_instance_valid(lab):
		return false
	var node: Node = lab
	while node != null:
		if not _clean(node):
			return false
		node = node.get_parent()
	var host: Node = lab.get_node_or_null("StarterFieldGeometry")
	return host is Node3D and not host.top_level and host.is_visible_in_tree() and _clean_tree(lab)


static func _clean_tree(node: Node) -> bool:
	if not _clean(node):
		return false
	for child: Node in node.get_children():
		if not _clean_tree(child):
			return false
	return true


static func _clean(node: Node) -> bool:
	for key: StringName in node.get_meta_list():
		if StadiumScoreboardRuntime.AUTHORING.has(key) or "lab_only" in String(key) \
			or ("authoring" in String(key) and key != &"wall_authoring_family"):
			return false
	return true
