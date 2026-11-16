extends StadiumPoolOwnedIntegrity
## Inherited instance collectors must retain the original unqualified static override route.

static var metadata_calls: int = 0
static var compact_traps: int = 0
static var expansion_traps: int = 0


static func _metadata(node: Node) -> Array:
	metadata_calls += 1
	return StadiumPoolOwnedIntegrity._metadata(node)


static func _metadata_compact(_node: Node) -> Array:
	compact_traps += 1
	return [["unexpected compact override"]]


static func _metadata_expand(_rows: Array) -> Array:
	expansion_traps += 1
	return [["unexpected expansion override"]]


static func _tree_legacy_bytes(_rows: Array) -> PackedByteArray:
	expansion_traps += 1
	return PackedByteArray([255])
