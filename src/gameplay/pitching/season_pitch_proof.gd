class_name SeasonPitchProof
extends RefCounted
## Explicit build-scoped dispatch, never inferred from evidence shape.
static func enabled(build: SeasonBuild) -> bool:
	return ExpandedCalledProof.enabled(build) or WorkingPitchCalledProof.enabled(build)

static func accepts(build: SeasonBuild, value: Variant, legacy: Variant = null) -> bool:
	return ExpandedCalledProof.accepts(build, value, legacy) if build != null and build.pitch_catalog_expanded() else WorkingPitchCalledProof.accepts(build, value, legacy)

static func install_human(build: SeasonBuild, human: Array, value: Variant) -> bool:
	return ExpandedCalledProof.install_human(build, human, value) if build != null and build.pitch_catalog_expanded() else WorkingPitchCalledProof.install_human(build, human, value)
