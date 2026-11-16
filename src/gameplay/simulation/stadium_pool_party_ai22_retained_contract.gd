class_name StadiumPoolPartyAI22RetainedContract
extends RefCounted
## Separate exact completed AI22 and human6 producer policies; never live admission.
## The fixed aggregate includes every src file and project configuration except
## this exact definition, the independently qualified generated profile, uid/import.
## No cache: new paths and changed bytes must invalidate the retained contract.

const PRODUCER: String = "7fbe121edda3bcde3e79844cec10b75300fca46f4bf228a741b1886c4d34d437"
const QUALIFIED_SUCCESSOR: String = (
	"cedc801cde7c48795d624839541f5696f72ddc6bda8c84677df9e58aa61aab32"
)
const QUALIFIED_CURRENT: String = (
	"dcbccde54d9afcde87c40263208ac5ad3fa8764d8bbed486652f6a00f3c48081"
)
const HUMAN6_SUCCESSOR: String = (
	"064261574aae4f8503b0528f59800cc60140fb39f538f81b5f25824226ea19ae"
)
const HUMAN6_CURRENT: String = (
	"39cfbade3327c489bdb504a21956a51ea2fef26ff6c956cc27130d3ffc4c9714"
)
const HUMAN6_NORMALIZATION_BASELINE: String = (
	"680cea95edf7effe1d4ed054611ddd3bf2b10b8d51e1dccfb1875155542b30d8"
)
const HUMAN6_PRIVATE_HASH_BASELINE: String = (
	"fee52cd1fc00055bffc53975a90798a614339e49a610accd9797998c2acab2e1"
)
const HUMAN6_RELEASE_DISPATCH_BASELINE: String = (
	"fc1c56238a160b2e504e72eb6a205426594ba1c767b81c023c04a0c82263a32c"
)
const HUMAN6_LOADING_FEEDBACK_BASELINE: String = (
	"2a72d2039fc77444029c811940c5003c8344f375dc976accfd51756f27bdb2f2"
)
const HUMAN6_PID_GUARD_BASELINE: String = (
	"712b7ec0d05277bbb52e512da499d7a412e2a08aa6d681c9e8f2ee17c2afddc0"
)
const HUMAN6_DRAFT_RECOVERY_BASELINE: String = (
	"5736a8ca4e5bb0c0eecadcfabe9dd33d47486d1db86a9661a875260719a8a148"
)
const HUMAN6_INTEGRATED_DRAFT_BASELINE: String = (
	"5fa84a073381b573c0ba1266adef0d43a84037d351725c2af0aca4fa0bebced8"
)
const CONTRACT: String = "ad85282c54a39761b26807160da415a33199d9c9ffafad4f41725210140e1e29"
const DEFINITION: String = \
	"res://src/gameplay/simulation/stadium_pool_party_ai22_retained_contract.gd"
const PROFILE: String = "res://src/presentation/stadium/stadium_npc_current_source_profile.gd"


static func accepts(value: Variant) -> bool:
	return value is String and value in [PRODUCER, QUALIFIED_SUCCESSOR, QUALIFIED_CURRENT] \
		and inventory_matches() \
		and StadiumNpcSourceQualification.matches_current(StadiumNpcPublicRuntime.SOURCE_PINS)


# Only genuinely completed human6 producers; AI-only epochs confer no authority.
static func accepts_human6(value: Variant) -> bool:
	return value is String and value in [PRODUCER, HUMAN6_SUCCESSOR, HUMAN6_CURRENT,
		HUMAN6_NORMALIZATION_BASELINE, HUMAN6_PRIVATE_HASH_BASELINE,
		HUMAN6_RELEASE_DISPATCH_BASELINE, HUMAN6_LOADING_FEEDBACK_BASELINE,
		HUMAN6_PID_GUARD_BASELINE, HUMAN6_DRAFT_RECOVERY_BASELINE,
		HUMAN6_INTEGRATED_DRAFT_BASELINE] \
		and inventory_matches() \
		and StadiumNpcSourceQualification.matches_current(StadiumNpcPublicRuntime.SOURCE_PINS)


static func inventory_matches() -> bool:
	return inventory_sha256() == CONTRACT


static func inventory_sha256() -> String:
	var paths: Array[String] = ["res://project.godot"]
	if not StadiumPoolPartyAssetIntegrity._source_paths("res://src", paths):
		return ""
	paths.sort()
	var rows: PackedStringArray = []
	for path: String in paths:
		if path == DEFINITION or path == PROFILE:
			continue
		var digest: String = FileAccess.get_sha256(path)
		if digest.length() != 64:
			return ""
		rows.append(path.trim_prefix("res://") + "\n" + digest + "\n")
	return "".join(rows).sha256_text()
