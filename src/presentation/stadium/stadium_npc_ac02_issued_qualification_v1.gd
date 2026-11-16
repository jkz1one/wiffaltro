class_name StadiumNpcAc02IssuedQualificationV1
extends RefCounted
## Issuance-only deployment proof. No result is cached or used by a frame callback.
const PROFILE = preload(
	"res://src/presentation/stadium/stadium_npc_ac02_issued_runtime_profile_v1.gd"
)


static func eligible() -> bool:
	var engine: Dictionary = Engine.get_version_info()
	if (
		PROFILE.REVIEW_STATUS != "reviewed"
		or PROFILE.PROFILE_ID.is_empty()
		or PROFILE.SOURCE_PROFILE_ID.is_empty()
		or StadiumNpcSourceQualification.PROFILE.REVIEW_STATUS != "reviewed"
		or StadiumNpcSourceQualification.PROFILE.PROFILE_ID != PROFILE.SOURCE_PROFILE_ID
		or PROFILE.NATIVE_FACTORY_CONTRACT != "ac02-reviewed-factories-no-extensions-v1"
		or Engine.is_editor_hint()
		or OS.has_feature("mono")
		or engine.get("hash", "") != PROFILE.ENGINE_HASH
		or engine.get("major") != 4
		or engine.get("minor") != 6
		or engine.get("patch") != 3
		or engine.get("status") != "stable"
		or engine.get("build") != "official"
		or not GDExtensionManager.get_loaded_extensions().is_empty()
		or FileAccess.get_sha256(OS.get_executable_path()) != PROFILE.EXECUTABLE_SHA256
	):
		return false
	# Eligibility precedes observation; the original installed() source proof must
	# then succeed in this same synchronous issuance before any ACTIVE publication.
	# Do not scan/hash sources again or turn the result into a reusable cache.
	return true
