class_name StadiumNpcManifest
extends RefCounted
## Structural canonicalization only. A well-formed manifest is NOT NPC venue authority.
# gdlint: disable=max-returns

const VERSION: int = 1
const MAX_INSTANCES: int = 128
const MAX_BYTES: int = 262144
const KEYS: Array[String] = ["version", "id", "revision", "assembly", "field", "tier",
	"shape", "rules_version", "graph", "catalog", "models", "instances", "blueprints",
	"land", "surface_version", "routing_version", "environment_certificates",
	"presentation", "live_units", "valuation"]
const TIERS: Array[String] = ["backyard", "expanded", "club", "mogul"]


static func canonical_shape(value: Variant) -> Dictionary:
	# JSON can change integer types and float64 by an ulp. Validate raw values first;
	# only then round scene transforms to float32, before comparison or hashing.
	if not _shape(value):
		return {}
	var result: Dictionary = value.duplicate(true)
	for key: String in ["version", "revision", "rules_version", "surface_version",
		"routing_version", "live_units"]:
		result[key] = int(result[key])
	for key: String in ["assembly", "graph", "catalog", "land"]:
		result[key].version = int(result[key].version)
	for model: Dictionary in result.models.values():
		model.version = int(model.version)
	for certificate: Dictionary in result.environment_certificates:
		certificate.version = int(certificate.version)
	for key: String in ["price_version", "blueprints", "copies", "land", "total"]:
		result.valuation[key] = int(result.valuation[key])
	for row: Dictionary in result.instances:
		row.transform = Array(PackedFloat32Array(row.transform))
		for index in range(12):
			if row.transform[index] == 0:
				row.transform[index] = 0.0
	var bytes: int = JSON.stringify(result, "", true, true).to_utf8_buffer().size()
	return result if bytes <= MAX_BYTES else {}


static func payload_key(value: Variant) -> String:
	# Pure structural subject identity only, never evidence or registry authority.
	var canonical: Dictionary = canonical_shape(value)
	if canonical.is_empty():
		return ""
	canonical.erase("environment_certificates")
	return JSON.stringify(canonical, "", true, true).sha256_text()


static func _shape(value: Variant) -> bool:
	if not _keys(value, KEYS) or not SeasonOwnership._whole(value.version, VERSION, VERSION):
		return false
	for key: String in ["id", "field", "tier", "shape"]:
		if not _text(value[key]):
			return false
	if not TIERS.has(value.tier):
		return false
	for key: String in ["revision", "rules_version", "surface_version", "routing_version"]:
		if not _version(value[key]):
			return false
	if not SeasonOwnership._whole(value.live_units, 0, MAX_INSTANCES) \
		or not _keys(value.assembly, ["id", "version"]) \
		or not _text(value.assembly.id) or not _version(value.assembly.version) \
		or not _keys(value.graph, ["id", "version", "sha256"]) \
		or not _text(value.graph.id) or not _version(value.graph.version) \
		or not _hash(value.graph.sha256) or not _signature(value.catalog):
		return false
	# These exact authored r1 families need their frozen model-source capacities.
	# Structural capacity is not authority; the final record still requires its exact manifest.
	var model_limit: int = 52 if value.id == "GRAND-III" and value.revision == 1 \
		and value.assembly.id == "GRAND-III-public-straight-v1" else 32
	if value.id == "HILLSIDE" and value.revision == 1 \
		and value.assembly.id == "HILLSIDE-public-deeper-center-v1":
		model_limit = 44
	if not value.models is Dictionary or value.models.is_empty() \
		or value.models.size() > model_limit:
		return false
	for key: Variant in value.models:
		if not _text(key) or not _signature(value.models[key]):
			return false
	return _land(value.land, value.tier) and _presentation(value.presentation) \
		and _valuation(value.valuation) and _certificates(value.environment_certificates) \
		and _instances(value.instances, value.id, int(value.revision), value.blueprints)


static func _instances(value: Variant, id: String, revision: int, blueprints: Variant) -> bool:
	if not value is Array or value.is_empty() or value.size() > MAX_INSTANCES \
		or not _strings(blueprints, MAX_INSTANCES, false):
		return false
	var instances: Dictionary = {}
	var sites: Array[String] = []
	var items: Array[String] = []
	var prefix: String = "npc:%s:r%d:" % [id, revision]
	for row: Variant in value:
		if not _keys(row, ["instance", "item", "site", "host", "transform"]):
			return false
		for key: String in ["instance", "item", "site", "host"]:
			if not _text(row[key]):
				return false
		if row.instance != prefix + row.site or instances.has(row.instance) or sites.has(row.site) \
			or not row.transform is Array or row.transform.size() != 12:
			return false
		for component: Variant in row.transform:
			if not (component is int or component is float) or not is_finite(float(component)) \
				or component < -1000 or component > 1000:
				return false
		instances[row.instance] = row
		sites.append(row.site)
		if not items.has(row.item):
			items.append(row.item)
	var sorted_sites: Array[String] = sites.duplicate()
	sorted_sites.sort()
	items.sort()
	if sites != sorted_sites or not ClubCareer.same(items, blueprints):
		return false
	for row: Dictionary in value:
		var seen: Array[String] = [row.instance]
		var host: String = row.host
		while host != "field":
			if seen.has(host) or not instances.has(host):
				return false
			seen.append(host)
			host = instances[host].host
	return true


static func _land(value: Variant, tier: String) -> bool:
	return _keys(value, ["version", "tier", "stages"]) and _version(value.version) \
		and value.tier is String and value.tier == tier and _strings(value.stages, 4, true)


static func _presentation(value: Variant) -> bool:
	# First family permits a named fixed presentation only. Options await a bounded schema.
	return _keys(value, ["profile", "options"]) and _text(value.profile) \
		and value.options is Dictionary and value.options.is_empty()


static func _valuation(value: Variant) -> bool:
	if not _keys(value, ["price_version", "price_sha256", "blueprints", "copies", "land", "total"]) \
		or not _version(value.price_version) or not _hash(value.price_sha256):
		return false
	for key: String in ["blueprints", "copies", "land", "total"]:
		if not SeasonOwnership._whole(value[key], 0, 10000000):
			return false
	return value.total == value.blueprints + value.copies + value.land


static func _certificates(value: Variant) -> bool:
	if not value is Array or value.size() > 8:
		return false
	var identities: Array[String] = []
	for row: Variant in value:
		if not _keys(row, ["mode", "profile", "version", "assembly_sha256"]) \
			or not row.mode is String or row.mode not in ["day", "night"] \
			or not row.profile is String or row.profile.length() > 128 \
			or (row.mode == "day" and not row.profile.is_empty()) \
			or (row.mode == "night" and row.profile.is_empty()) \
			or not _version(row.version) or not _hash(row.assembly_sha256):
			return false
		var identity: String = row.mode + ":" + row.profile
		if identities.has(identity):
			return false
		identities.append(identity)
	return true


static func _signature(value: Variant) -> bool:
	return _keys(value, ["version", "sha256"]) and _version(value.version) and _hash(value.sha256)


static func _keys(value: Variant, keys: Array) -> bool:
	return value is Dictionary and SeasonOwnership._keys(value, keys)


static func _version(value: Variant) -> bool:
	return SeasonOwnership._whole(value, 1, 1000000)


static func _text(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length() <= 128


static func _hash(value: Variant) -> bool:
	if not value is String or value.length() != 64:
		return false
	for character: String in value:
		if not "0123456789abcdef".contains(character):
			return false
	return true


static func _strings(value: Variant, maximum: int, empty: bool) -> bool:
	if not value is Array or value.size() > maximum or (not empty and value.is_empty()):
		return false
	var seen: Array[String] = []
	for item: Variant in value:
		if not _text(item) or seen.has(item):
			return false
		seen.append(item)
	return true
