class_name StadiumPoolPartyRuntime
extends RefCounted
## Separate neutral authority around unchanged Pool geometry and ground-rule mechanics.
## No paid layout, stock token, private controller entitlement, or new navigation policy.

const COPY: String = "npc:POOL-PARTY:r1:OL-R"


static func owns_node(property: StadiumNpcPublicProperty, node: Node) -> bool:
	if property == null or property.venue_id != "POOL-PARTY" or not is_instance_valid(node):
		return false
	var pool: Node3D = property.objects.get(COPY) as Node3D
	return is_instance_valid(pool) and (node == pool or pool.is_ancestor_of(node))


static func origin_clean(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> bool:
	# Cold strict boundary only. The unchanged factory ST006 bears its descriptive
	# stadium_candidate_only marker; it is not authority to adopt any other candidate.
	if not is_instance_valid(lab) or not is_instance_valid(property) \
		or property.venue_id != "POOL-PARTY" \
		or StadiumNpcPublicRuntime._property(lab) != property:
		return false
	var pool: Node3D = property.objects.get(COPY) as Node3D
	if not is_instance_valid(property.construction) \
		or property.construction.get_script() != StadiumPoolPartyPublicConstruction \
		or property.construction.pool_model != pool \
		or not is_instance_valid(pool) or not property.construction.is_ancestor_of(pool) \
		or not pool.has_meta("stadium_candidate_only") \
		or typeof(pool.get_meta("stadium_candidate_only")) != TYPE_BOOL \
		or pool.get_meta("stadium_candidate_only") != true \
		or not StadiumPoolPartyPublicConstruction._pool_intact(pool):
		return false
	var node: Node = lab
	while node != null:
		if not StadiumMountedScoreboardContract._clean(node):
			return false
		node = node.get_parent()
	var host: Node = lab.get_node_or_null("StarterFieldGeometry")
	if not host is Node3D or host.top_level or not host.is_visible_in_tree():
		return false
	# Preserve the common origin predicate on every other actual descendant.
	# Only the root marker is exempt; all descendants retain the common predicate.
	for child: Node in lab.find_children("*", "", true, false):
		if child == pool:
			continue
		if not StadiumMountedScoreboardContract._clean(child):
			return false
	return true


static func installed_bound(lab: PitchBatLab, snapshot: Dictionary) -> bool:
	return StadiumNpcPublicRuntime.installed_bound(lab, snapshot) \
		and snapshot.get("version") == StadiumNpcSnapshot.POOL_PARTY_FINAL_FIXTURE_VERSION


static func capture_evidence(lab: PitchBatLab) -> Dictionary:
	var property: StadiumNpcPublicProperty = StadiumNpcPublicRuntime._property(lab)
	if property == null or property.venue_id != "POOL-PARTY" \
		or not installed_bound(lab, lab._match_state.stadium) \
		or not property.boundary is StadiumPoolPartyPublicBoundary:
		return {}
	var outcomes: Array[Dictionary] = []
	for index in range(lab._play_records.size()):
		var play: PlayRecord = lab._play_records[index]
		if String(play.resolution_reason) not in ["pool_party_controller_water_double",
			"pool_party_controller_water_foul"]:
			continue
		outcomes.append({"play": index, "reason": String(play.resolution_reason),
			"resolution_position": [play.resolution_position.x, play.resolution_position.y,
				play.resolution_position.z], "result_floor": play.result_floor,
			"last_defender_touch": String(play.last_defender_touch),
			"has_first_ground": play.has_first_ground, "result": String(play.result)})
	var source: String = StadiumPoolPartyAssetIntegrity.source_sha256()
	return {"version": 1, "copy": COPY, "pose": [12, 0, 18, 0],
		"geometry": StadiumPoolPartyPublicContacts.geometry(source), "source_sha256": source,
		"water_commits": property.boundary.water_commits.duplicate(true), "water_outcomes": outcomes}
